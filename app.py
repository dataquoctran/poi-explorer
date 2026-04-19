# ── Imports ───────────────────────────────────────────────
# flask: the web framework that creates our API
# flask_cors: allows the frontend (index.html) to talk to 
#             the backend — without this the browser blocks it
# anthropic: lets us call Claude AI
# snowflake.connector: lets us query our Snowflake database
# dotenv: reads our secret API key from the .env file
#         so we never hardcode secrets in our code
# math: for distance calculations
# os: to read environment variables
from flask import Flask, request, jsonify
from flask_cors import CORS
import anthropic
import snowflake.connector
from dotenv import load_dotenv
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.serialization import load_pem_private_key
import math
import os
load_dotenv()  # Load API keys from .env file

app = Flask(__name__)
CORS(app)  # Allow frontend to call this backend

# ── In-memory session storage ──────────────────────────────
# This dictionary stores each user's visit history
# during their session. It resets when the server restarts.
# Key = session ID, Value = list of visited places
sessions = {}

# ── Snowflake connection ───────────────────────────────────
# This function connects to your Snowflake account and
# pulls POI data using the table function you built.
# We call it every time we need fresh data.
def get_snowflake_pois(lat=44.9778, lon=-93.2650, category="ALL"):
    # No more city guessing — query all Twin Cities POIs at once
    # then filter by actual distance using real coordinates
    
    private_key_path = os.getenv("SNOWFLAKE_PRIVATE_KEY_PATH")
    with open(private_key_path, "rb") as key_file:
        private_key = load_pem_private_key(key_file.read(), password=None)

    pkb = private_key.private_bytes(
        encoding=serialization.Encoding.DER,
        format=serialization.PrivateFormat.PKCS8,
        encryption_algorithm=serialization.NoEncryption()
    )

    conn = snowflake.connector.connect(
        user=os.getenv("SNOWFLAKE_USER"),
        account=os.getenv("SNOWFLAKE_ACCOUNT"),
        private_key=pkb,
        role="TRAINING_ROLE",
        warehouse="EAGLE_WH",
        database="POI_PROJECT",
        schema="AGG_POI"
    )

    cur = conn.cursor()
    cur.execute("USE ROLE TRAINING_ROLE")
    cur.execute("USE WAREHOUSE EAGLE_WH")
    cur.execute("USE DATABASE POI_PROJECT")
    cur.execute("USE SCHEMA AGG_POI")

    # Query ALL POIs with coordinates directly from CUR_POI_PROCESSED
    # This way we don't need to guess the city at all
    # We filter by category if specified
    if category == "ALL":
        query = """
            SELECT 
                POI_ID, NAME, CATEGORY, SUB_CATEGORY_1, SUB_CATEGORY_2,
                ETHNICITY_REFERENCE, BUSINESS_TYPE, FULL_ADDRESS,
                CITY, POSTCODE, PHONE, WEBSITE, HOURS_CATEGORY,
                IS_LATE_NIGHT, IS_WHEELCHAIR_ACCESSIBLE,
                DATA_QUALITY_SCORE, CITY_TIER, GEO_QUADRANT,
                LATITUDE, LONGITUDE
            FROM POI_PROJECT.CUR_POI.CUR_POI_PROCESSED
            WHERE LATITUDE IS NOT NULL
              AND LONGITUDE IS NOT NULL
        """
    else:
        query = f"""
            SELECT 
                POI_ID, NAME, CATEGORY, SUB_CATEGORY_1, SUB_CATEGORY_2,
                ETHNICITY_REFERENCE, BUSINESS_TYPE, FULL_ADDRESS,
                CITY, POSTCODE, PHONE, WEBSITE, HOURS_CATEGORY,
                IS_LATE_NIGHT, IS_WHEELCHAIR_ACCESSIBLE,
                DATA_QUALITY_SCORE, CITY_TIER, GEO_QUADRANT,
                LATITUDE, LONGITUDE
            FROM POI_PROJECT.CUR_POI.CUR_POI_PROCESSED
            WHERE LATITUDE IS NOT NULL
              AND LONGITUDE IS NOT NULL
              AND CATEGORY = '{category}'
        """

    print(f"Running query for all POIs...")
    cur.execute(query)

    cols = [d[0].lower() for d in cur.description]
    rows = [dict(zip(cols, row)) for row in cur.fetchall()]
    conn.close()

    print(f"Total POIs from Snowflake: {len(rows)}")
    return rows

# ── Distance calculation ───────────────────────────────────
# Haversine formula: calculates the real-world distance
# between two lat/lon points on Earth's curved surface.
# More accurate than simple subtraction for map distances.
def haversine(lat1, lon1, lat2, lon2):
    R = 6371  # Earth radius in km
    dlat = math.radians(lat2 - lat1)
    dlon = math.radians(lon2 - lon1)
    a = (math.sin(dlat/2)**2 +
         math.cos(math.radians(lat1)) *
         math.cos(math.radians(lat2)) *
         math.sin(dlon/2)**2)
    return R * 2 * math.asin(math.sqrt(a))

# ── Filter nearby POIs ─────────────────────────────────────
# Takes the full list from Snowflake and keeps only
# those within radius_km of the user's current location.
# Sorted nearest-first so Claude sees the closest ones.
def get_nearby(pois, lat, lon, radius_km=100, limit=500):
    # Now we have real lat/lon so we can calculate actual distance
    # radius_km=10 gives a good coverage area around the user
    results = []
    for p in pois:
        try:
            p_lat = float(p.get("latitude") or 0)
            p_lon = float(p.get("longitude") or 0)
            if p_lat == 0 or p_lon == 0:
                continue
            dist = haversine(lat, lon, p_lat, p_lon)
            if dist <= radius_km:
                results.append({**p, "distance_km": round(dist, 2)})
        except:
            continue

    # Sort by distance first then quality score
    results.sort(key=lambda x: (
        x["distance_km"],
        -x.get("data_quality_score", 0)
    ))
    print(f"Found {len(results)} POIs within {radius_km}km of {lat},{lon}")
    return results[:limit]

# ── API Route: /api/recommend ──────────────────────────────
# This is the main route the frontend calls when the
# user sends a chat message. It:
#   1. Gets POIs from Snowflake near the user's location
#   2. Builds a prompt with their visit history + POI list
#   3. Sends it to Claude
#   4. Returns Claude's recommendation + POI list for the map
@app.route("/api/recommend", methods=["POST"])
def recommend():
    data = request.json
    lat        = float(data.get("lat", 44.9778))
    lon        = float(data.get("lon", -93.2650))
    message    = data.get("message", "What should I do next?")
    history    = data.get("history", [])
    session_id = data.get("session_id", "default")
    ethnicity  = data.get("ethnicity", "Any")
    category   = data.get("category", "ALL")

    # Save visit history to session
    sessions[session_id] = history

    # Get POIs from Snowflake
    try:
        all_pois = get_snowflake_pois(category=category)
    except Exception as e:
        return jsonify({"error": f"Snowflake error: {str(e)}"}), 500

    # Filter to nearby POIs
    nearby = get_nearby(all_pois, lat, lon)

    if not nearby:
        return jsonify({
            "reply": "I couldn't find any POIs near that location. Try moving the map or widening the radius.",
            "pois": []
        })

    # Build POI context for Claude
    # We give Claude structured info so it can reason well
    poi_lines = "\n".join([
        f"- {p['name']} | {p['category']}"
        f"{' / ' + p['sub_category_1'] if p.get('sub_category_1') else ''}"
        f"{' / ' + p['sub_category_2'] if p.get('sub_category_2') else ''}"
        f"{' | ethnicity: ' + p['ethnicity_reference'] if p.get('ethnicity_reference') else ''}"
        f" | {p['distance_km']}km away"
        f"{' | ' + p['city'] if p.get('city') else ''}"
        for p in nearby
    ])

    # Build visit history context
    history_text = ""
    if history:
        history_text = (
            f"\nThe user has visited these places today in this order: "
            f"{' → '.join(history)}.\n"
            f"Detect the pattern (category, cuisine, vibe) and suggest "
            f"what type of place would logically come next."
        )

    # Ethnicity preference
    ethnicity_text = ""
    if ethnicity and ethnicity != "Any":
        ethnicity_text = (
            f"\nThe user prefers {ethnicity} food/culture. "
            f"Prioritize POIs that match this preference."
        )

    # Claude system prompt
    # This tells Claude who it is and how to behave.
    # A good system prompt is the difference between
    # a generic answer and a genuinely useful one.
    system_prompt = """You are a friendly local guide for the Twin Cities metro area.

STRICT FORMAT — you MUST follow this exactly, no exceptions:

1. **Place Name** (X.Xkm away) — one sentence reason
2. **Place Name** (X.Xkm away) — one sentence reason
3. **Place Name** (X.Xkm away) — one sentence reason
4. **Place Name** (X.Xkm away) — one sentence reason
5. **Place Name** (X.Xkm away) — one sentence reason
6. **Place Name** (X.Xkm away) — one sentence reason
7. **Place Name** (X.Xkm away) — one sentence reason
8. **Place Name** (X.Xkm away) — one sentence reason
9. **Place Name** (X.Xkm away) — one sentence reason
10. **Place Name** (X.Xkm away) — one sentence reason

Continue up to 20 if enough POIs exist.

Rules:
- Only use place names from the POI list provided
- Use the EXACT name as it appears in the list
- Include real distance from the list
- After the numbered list add one Local Tip line
- Do NOT add any text before the numbered list"""

    user_prompt = f"""User location: {lat}, {lon}
{history_text}
{ethnicity_text}

Nearby POIs:
{poi_lines}

User says: "{message}"

Give your top recommendations from the list above."""

    # Call Claude API
    client = anthropic.Anthropic()
    response = client.messages.create(
        model="claude-sonnet-4-6",
        max_tokens=800,
        system=system_prompt,
        messages=[{"role": "user", "content": user_prompt}]
    )

    return jsonify({
        "reply": response.content[0].text,
        "pois": nearby
    })

# ── API Route: /api/nearby ─────────────────────────────────
# Simpler route — just returns nearby POIs for map display
# without calling Claude. Used when the user moves the map
# and we just want to refresh the pins.
@app.route("/api/nearby", methods=["POST"])
def nearby():
    data = request.json
    lat  = float(data.get("lat", 44.9778))
    lon  = float(data.get("lon", -93.2650))

    try:
        all_pois = get_snowflake_pois()
    except Exception as e:
        return jsonify({"error": str(e)}), 500

    close = get_nearby(all_pois, lat, lon, radius_km=100)
    return jsonify({"pois": close, "count": len(close)})

# ── API Route: /api/health ─────────────────────────────────
# A simple check route. If you visit localhost:5000/api/health
# in your browser and see {"status":"ok"} it means the
# backend is running correctly.
@app.route("/api/health", methods=["GET"])
def health():
    return jsonify({"status": "ok"})

# ── Start the server ───────────────────────────────────────
if __name__ == "__main__":
    print("Starting POI Recommendation backend...")
    print("Visit http://localhost:5000/api/health to verify")
    app.run(debug=True, port=5000)
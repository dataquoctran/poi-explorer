#  Twin Cities POI Explorer

> *Never lack of places to go and things to do.*

A conversational AI web application that helps you discover nearby Points of Interest in the **Minneapolis–Saint Paul metro area** 

Instead of tapping through filters on a map app, just ask:

> *"Where should I get coffee and read a book on a Sunday morning?"*

Claude answers with specific, context-aware recommendations drawn from real local data, with numbered pins that light up on the map as you chat.

---

##  Features

-  **Conversational recommendations** — ask in plain English, get back a named, numbered list of nearby places
-  **Live map sync** — recommended places appear as numbered green pins on a dark Leaflet.js map
-  **Click-to-fly navigation** — click any place name in the chat to fly the map to that location
-  **Two modes** — toggle between *Recommendation Search* (structured output) and *Q&A Chat* (freeform conversation)
-  **Reverse geocoding** — location bar shows your city name, not raw coordinates
-  **17,000+ POIs** — restaurants, parks, shops, museums, cafes, and more across the Twin Cities

---

##  Tech Stack

| Layer | Technology |
|---|---|
| Frontend | HTML / CSS / JavaScript, [Leaflet.js](https://leafletjs.com/) |
| Backend | Python, [Flask](https://flask.palletsprojects.com/) |
| AI Model | [Anthropic Claude 3.5 Sonnet](https://www.anthropic.com/claude) |
| Data Warehouse | [Snowflake](https://www.snowflake.com/) |
| POI Data | [OpenStreetMap](https://www.openstreetmap.org/) via Overpass API |
| Geocoding | OpenStreetMap Nominatim |

---

##  Architecture

```
User Browser (index.html)
       │
       │  GPS coordinates + user message
       ▼
Flask Backend (app.py)
       │
       ├──► Snowflake Query
       │    CUR_POI_PROCESSED
       │    (up to 1,000 POIs within 20 km)
       │
       └──► Claude API
            system prompt + POI context + user message
                    │
                    ▼
            Structured recommendation list
                    │
                    ▼
       Numbered pins on map + chat response
```

Every request is a **Retrieval-Augmented Generation (RAG)** call: the app retrieves the relevant slice of POI data from Snowflake at query time and injects it into Claude's prompt as grounding context. Claude reasons over real local data rather than guessing from training memory.

---

##  Data Pipeline

The POI data was collected from OpenStreetMap via the Overpass API across seven categories:

`Food & Drink` · `Shopping` · `Leisure` · `Tourism` · `Health` · `Education` · `Public Services`

It was loaded into Snowflake and processed through three layers:

| Schema | Purpose |
|---|---|
| `RAW_POI` | Immutable source data (17,270 rows, 23 columns) |
| `CUR_POI` | Curated layer — normalized fields, computed flags (`IS_LATE_NIGHT`, `DATA_QUALITY_SCORE`, `CITY_TIER`) |
| `AGG_POI` | Aggregation layer — zipcode summaries, category pivot tables, materialized views |

The app queries `CUR_POI.CUR_POI_PROCESSED` at runtime, filtered to a 50 km radius around the user's coordinates.

---

##  Getting Started

### Prerequisites

- Python 3.10+
- A [Snowflake](https://www.snowflake.com/) account with the POI data loaded (see `data/` folder)
- An [Anthropic API key](https://console.anthropic.com/)
- RSA key pair for Snowflake key-pair authentication

### Installation

```bash
git clone https://github.com/dataquoctran/poi-explorer.git
cd poi-explorer
pip install -r requirements.txt
```

### Configuration

Create a `.env` file in the project root:

```env
ANTHROPIC_API_KEY=your_anthropic_key_here
SNOWFLAKE_ACCOUNT=your_account
SNOWFLAKE_USER=your_username
SNOWFLAKE_PRIVATE_KEY_PATH=path/to/rsa_key.p8
SNOWFLAKE_DATABASE=POI_DB
SNOWFLAKE_SCHEMA=CUR_POI
SNOWFLAKE_WAREHOUSE=your_warehouse
```

### Run

```bash
python app.py
```

Open your browser to `http://localhost:5000` and allow location access when prompted.

---

##  How It Works

### Recommendation Mode
The `/recommend` endpoint injects the nearby POI list into Claude's prompt with a strict system instruction to return a numbered list. Each item includes:
- Place name and category
- Distance from your location
- Opening hours
- Website (if available)

The frontend parses the numbered response and plots each matched place as a pin on the map.

### Q&A Mode
The `/chat` endpoint sends your message and the POI context to Claude without the structured-output constraint. Useful for questions like *"Are any of those dog-friendly?"* or *"What's the vibe like in Uptown?"*

---

##  Known Limitations

- **No conversation memory** — each Claude call is stateless; follow-up questions that reference prior turns are not currently supported
- **Cold start latency** — first Snowflake query can take 10–30 seconds on a cold warehouse
- **OSM data gaps** — many venues are missing hours, phone numbers, or websites
- **Manual mode toggle** — the app does not yet auto-detect whether you want a recommendation or a conversation

---

##  Academic Context

This project was built as the final project for **SEIS 767 – Conversational AI** at the University of St. Thomas (Spring 2026). It demonstrates five LLM topics from *Hands-On Large Language Models* (Alammar & Grootendorst, 2024):

1. Prompt Engineering
2. Tokens and Context Windows
3. Generative Models and Sampling
4. Retrieval-Augmented Generation (RAG)
5. Conversational Memory and Multi-Turn Dialogue

---

##  License

MIT License. See `LICENSE` for details.

---


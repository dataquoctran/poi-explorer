# poi-explorer
Twin Cities POI Recommendation App

The general idea is to use a large language model (LLM) as the interface for finding nearby places
of interest, replacing the traditional keyword search and filter-based map UI with a natural conver-
sation. Instead of tapping through categories on a map app, you simply ask: “Where should I get
coffee and read a book on a Sunday morning?” and the AI responds with specific, context-aware
suggestions drawn from real local data.
Project Summary. The Twin Cities POI Explorer is a full-stack web application that helps
users discover Points of Interest (POIs) in the Minneapolis–Saint Paul metro area through a con-
versational AI interface. The app queries a Snowflake data warehouse containing over 17,000 POIs
(restaurants, parks, shops, museums, and more), injects the nearby results into a prompt sent to
the Anthropic Claude API, and renders the response in both a chat panel and as numbered pins on
an interactive map. The tagline I kept in mind throughout: “never lack of places to go and things
to do.”
Why I Chose It. I came into this class already working on a data warehouse project in SEIS
732, where I had built a full pipeline around a Twin Cities POI dataset in Snowflake. Rather than
starting from scratch, I wanted to extend that work into a conversational AI application. More
importantly, I wanted to build an AI that knows what is physically around me right now and can
have a real conversation about it.
Minimal Goal. Get a working end-to-end loop: user shares location → app queries Snowflake
for nearby POIs → POI list is injected into a Claude prompt → Claude returns recommendations
→ the chat panel shows the response.
Optimistic Goal. Make the app feel like a real conversational city guide: numbered map
pins that sync with Claude’s recommendation list, clickable place names that fly the map to that
location, a toggle between recommendation mode and open-ended Q&A, and a location bar that
shows a human-readable city name instead of raw coordinates.

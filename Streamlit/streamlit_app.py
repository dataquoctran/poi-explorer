import datetime as dt
import streamlit as st
import pandas as pd

# Set page config
st.set_page_config(page_title="EAGLE_PROJECT_DASHBOARD", layout="wide")

# Title
st.title("EAGLE_PROJECT_DASHBOARD")

# Initialize Snowflake session
session = st.connection("snowflake").session()

@st.cache_data(ttl="23h50m")
def execute_query(query: str) -> str:
  return session.sql(query).collect_nowait().query_id

def query_1_1() -> str:
  sql_query = r"""
SELECT COUNT(*) AS TOTAL_POIS
FROM POI_PROJECT.CUR_POI.CUR_POI_PROCESSED;  """

  return sql_query

execute_query(query_1_1())

@st.fragment
def cell_1_1():
  with st.container(border=True):
    with st.container(horizontal=True, horizontal_alignment="distribute", vertical_alignment="center"):
      with st.container(height=80, border=False, vertical_alignment="center"):
        st.markdown("### Total POIs in Twin Cities")
      if st.button(
        ":material/refresh:", type="tertiary", key=f"refresh_button_cell_1_1", help="Refresh total_pois_in_twin_cities data"
      ):
        execute_query.clear(query_1_1())

    try:
      with st.spinner("Executing query", show_time=True):
        df = session.create_async_job(
          execute_query(query_1_1())
        ).result("pandas")

      if any(df.columns.duplicated()):
        new_names = []
        name_indexes = {}
        for name in df.columns:
          name_index = name_indexes.get(name, 0) + 1
          name_indexes[name] = name_index
          new_names.append(f"{name}_{name_index}" if name_index > 1 else name)
        df.columns = new_names

      # Calculate metric for scorecard
      if len(df) > 0:
        value = df["TOTAL_POIS"].iloc[0]
        st.metric(
          label="TOTAL_POIS",
          value=f"{value:,.0f}"
        )
      else:
        st.warning("No data available")
    except Exception as e:
      st.error(f"Error: {str(e)}")

def query_1_2() -> str:
  sql_query = r"""
SELECT COUNT(DISTINCT CITY) AS TOTAL_CITIES
FROM POI_PROJECT.CUR_POI.CUR_POI_PROCESSED
WHERE CITY IS NOT NULL;  """

  return sql_query

execute_query(query_1_2())

@st.fragment
def cell_1_2():
  with st.container(border=True):
    with st.container(horizontal=True, horizontal_alignment="distribute", vertical_alignment="center"):
      with st.container(height=80, border=False, vertical_alignment="center"):
        st.markdown("### Cities Covered")
      if st.button(
        ":material/refresh:", type="tertiary", key=f"refresh_button_cell_1_2", help="Refresh cities_covered data"
      ):
        execute_query.clear(query_1_2())

    try:
      with st.spinner("Executing query", show_time=True):
        df = session.create_async_job(
          execute_query(query_1_2())
        ).result("pandas")

      if any(df.columns.duplicated()):
        new_names = []
        name_indexes = {}
        for name in df.columns:
          name_index = name_indexes.get(name, 0) + 1
          name_indexes[name] = name_index
          new_names.append(f"{name}_{name_index}" if name_index > 1 else name)
        df.columns = new_names

      # Calculate metric for scorecard
      if len(df) > 0:
        value = df["TOTAL_CITIES"].iloc[0]
        st.metric(
          label="TOTAL_CITIES",
          value=f"{value:,.0f}"
        )
      else:
        st.warning("No data available")
    except Exception as e:
      st.error(f"Error: {str(e)}")

def query_1_3() -> str:
  sql_query = r"""
SELECT COUNT(*) AS TOTAL_FOOD
FROM POI_PROJECT.CUR_POI.CUR_POI_PROCESSED
WHERE CATEGORY = 'Food & Drink';  """

  return sql_query

execute_query(query_1_3())

@st.fragment
def cell_1_3():
  with st.container(border=True):
    with st.container(horizontal=True, horizontal_alignment="distribute", vertical_alignment="center"):
      with st.container(height=80, border=False, vertical_alignment="center"):
        st.markdown("### Food & Drink Venues")
      if st.button(
        ":material/refresh:", type="tertiary", key=f"refresh_button_cell_1_3", help="Refresh food_&_drink_venues data"
      ):
        execute_query.clear(query_1_3())

    try:
      with st.spinner("Executing query", show_time=True):
        df = session.create_async_job(
          execute_query(query_1_3())
        ).result("pandas")

      if any(df.columns.duplicated()):
        new_names = []
        name_indexes = {}
        for name in df.columns:
          name_index = name_indexes.get(name, 0) + 1
          name_indexes[name] = name_index
          new_names.append(f"{name}_{name_index}" if name_index > 1 else name)
        df.columns = new_names

      # Calculate metric for scorecard
      if len(df) > 0:
        value = df["TOTAL_FOOD"].iloc[0]
        st.metric(
          label="TOTAL_FOOD",
          value=f"{value:,.0f}"
        )
      else:
        st.warning("No data available")
    except Exception as e:
      st.error(f"Error: {str(e)}")

def query_1_4() -> str:
  sql_query = r"""
SELECT ROUND(AVG(DATA_QUALITY_SCORE), 2) AS AVG_QUALITY
FROM POI_PROJECT.CUR_POI.CUR_POI_PROCESSED;  """

  return sql_query

execute_query(query_1_4())

@st.fragment
def cell_1_4():
  with st.container(border=True):
    with st.container(horizontal=True, horizontal_alignment="distribute", vertical_alignment="center"):
      with st.container(height=80, border=False, vertical_alignment="center"):
        st.markdown("### Avg Data Quality Score")
      if st.button(
        ":material/refresh:", type="tertiary", key=f"refresh_button_cell_1_4", help="Refresh avg_data_quality_score data"
      ):
        execute_query.clear(query_1_4())

    try:
      with st.spinner("Executing query", show_time=True):
        df = session.create_async_job(
          execute_query(query_1_4())
        ).result("pandas")

      if any(df.columns.duplicated()):
        new_names = []
        name_indexes = {}
        for name in df.columns:
          name_index = name_indexes.get(name, 0) + 1
          name_indexes[name] = name_index
          new_names.append(f"{name}_{name_index}" if name_index > 1 else name)
        df.columns = new_names

      # Calculate metric for scorecard
      if len(df) > 0:
        value = df["AVG_QUALITY"].iloc[0]
        st.metric(
          label="AVG_QUALITY",
          value=f"{value:,.0f}"
        )
      else:
        st.warning("No data available")
    except Exception as e:
      st.error(f"Error: {str(e)}")

# Row 1: 4 Cells
col1_1, col1_2, col1_3, col1_4 = st.columns(4)
with col1_1:
  cell_1_1()
with col1_2:
  cell_1_2()
with col1_3:
  cell_1_3()
with col1_4:
  cell_1_4()

def query_2_1() -> str:
  sql_query = r"""
SELECT 
    CATEGORY,
    CITY_TIER,
    COUNT(*) AS TOTAL_POIS
FROM POI_PROJECT.CUR_POI.CUR_POI_PROCESSED
WHERE CITY_TIER != 'Unknown'
GROUP BY CATEGORY, CITY_TIER
ORDER BY TOTAL_POIS DESC;  """

  return sql_query

execute_query(query_2_1())

@st.fragment
def cell_2_1():
  with st.container(border=True):
    with st.container(horizontal=True, horizontal_alignment="distribute", vertical_alignment="center"):
      with st.container(height=80, border=False, vertical_alignment="center"):
        st.markdown("### POI Density by Category and City Tier")
      if st.button(
        ":material/refresh:", type="tertiary", key=f"refresh_button_cell_2_1", help="Refresh poi_density_by_category_and_city_tier data"
      ):
        execute_query.clear(query_2_1())

    try:
      with st.spinner("Executing query", show_time=True):
        df = session.create_async_job(
          execute_query(query_2_1())
        ).result("pandas")

      if any(df.columns.duplicated()):
        new_names = []
        name_indexes = {}
        for name in df.columns:
          name_index = name_indexes.get(name, 0) + 1
          name_indexes[name] = name_index
          new_names.append(f"{name}_{name_index}" if name_index > 1 else name)
        df.columns = new_names

      st.warning("This chart type is not supported in Streamlit. Displaying a table instead.")
      if len(df) == 1 and len(df.columns) == 1:
        st.metric(
          label=df.columns[0],
          value=str(df.iloc[0, 0]),
          label_visibility="collapsed"
        )
      else:
        st.dataframe(df, use_container_width=True, hide_index=True)
    except Exception as e:
      st.error(f"Error: {str(e)}")

# Row 2: Single Cell
cell_2_1()

def query_3_1() -> str:
  sql_query = r"""
SELECT CATEGORY, COUNT(*) AS TOTAL_POIS
FROM POI_PROJECT.CUR_POI.CUR_POI_PROCESSED
GROUP BY CATEGORY
ORDER BY TOTAL_POIS DESC;  """

  return sql_query

execute_query(query_3_1())

@st.fragment
def cell_3_1():
  with st.container(border=True):
    with st.container(horizontal=True, horizontal_alignment="distribute", vertical_alignment="center"):
      with st.container(height=80, border=False, vertical_alignment="center"):
        st.markdown("### POI Count by Category")
      if st.button(
        ":material/refresh:", type="tertiary", key=f"refresh_button_cell_3_1", help="Refresh poi_count_by_category data"
      ):
        execute_query.clear(query_3_1())

    try:
      with st.spinner("Executing query", show_time=True):
        df = session.create_async_job(
          execute_query(query_3_1())
        ).result("pandas")

      if any(df.columns.duplicated()):
        new_names = []
        name_indexes = {}
        for name in df.columns:
          name_index = name_indexes.get(name, 0) + 1
          name_indexes[name] = name_index
          new_names.append(f"{name}_{name_index}" if name_index > 1 else name)
        df.columns = new_names

      # Prepare data for bar chart
      if len(df) > 0:
        df = df[["CATEGORY","TOTAL_POIS"]]

        df["/* Order Key (Generated by Snowflake) */"] = df.drop(columns="CATEGORY").sum(axis=1)

        datetime_primary_column = None
        if pd.api.types.is_datetime64_dtype(df["CATEGORY"]):
          datetime_primary_column = df["CATEGORY"]
        elif df["CATEGORY"].dtype == "object" and isinstance(df["CATEGORY"].get(df["CATEGORY"].first_valid_index()), dt.date):
          datetime_primary_column = pd.to_datetime(df["CATEGORY"], errors="coerce")
        if datetime_primary_column is not None and (datetime_primary_column.max() - datetime_primary_column.min()).days > len(df) * 2:
          # Use string type for sparse date range
          df["CATEGORY"] = df["CATEGORY"].astype("string")

        st.bar_chart(
          df,
          x="CATEGORY",
          y=[c for c in df.columns if c != "CATEGORY" and c != "/* Order Key (Generated by Snowflake) */"],
          sort="-/* Order Key (Generated by Snowflake) */",
          use_container_width=True,
          height=400,
          horizontal=True,
          stack=False,
          x_label="TOTAL_POIS",
        )
      else:
        st.warning("No data available")
    except Exception as e:
      st.error(f"Error: {str(e)}")

def query_3_2() -> str:
  sql_query = r"""
SELECT CITY, FOOD_AND_DRINK
FROM POI_PROJECT.AGG_POI.AGG_CITY_CATEGORY_PIVOT
ORDER BY FOOD_AND_DRINK DESC
LIMIT 10;  """

  return sql_query

execute_query(query_3_2())

@st.fragment
def cell_3_2():
  with st.container(border=True):
    with st.container(horizontal=True, horizontal_alignment="distribute", vertical_alignment="center"):
      with st.container(height=80, border=False, vertical_alignment="center"):
        st.markdown("### Top 10 Cities — Food & Drink Venues")
      if st.button(
        ":material/refresh:", type="tertiary", key=f"refresh_button_cell_3_2", help="Refresh top_10_cities_—_food_&_drink_venues data"
      ):
        execute_query.clear(query_3_2())

    try:
      with st.spinner("Executing query", show_time=True):
        df = session.create_async_job(
          execute_query(query_3_2())
        ).result("pandas")

      if any(df.columns.duplicated()):
        new_names = []
        name_indexes = {}
        for name in df.columns:
          name_index = name_indexes.get(name, 0) + 1
          name_indexes[name] = name_index
          new_names.append(f"{name}_{name_index}" if name_index > 1 else name)
        df.columns = new_names

      # Prepare data for bar chart
      if len(df) > 0:
        df = df[["CITY","FOOD_AND_DRINK"]]

        df["/* Order Key (Generated by Snowflake) */"] = df.drop(columns="CITY").sum(axis=1)

        datetime_primary_column = None
        if pd.api.types.is_datetime64_dtype(df["CITY"]):
          datetime_primary_column = df["CITY"]
        elif df["CITY"].dtype == "object" and isinstance(df["CITY"].get(df["CITY"].first_valid_index()), dt.date):
          datetime_primary_column = pd.to_datetime(df["CITY"], errors="coerce")
        if datetime_primary_column is not None and (datetime_primary_column.max() - datetime_primary_column.min()).days > len(df) * 2:
          # Use string type for sparse date range
          df["CITY"] = df["CITY"].astype("string")

        st.bar_chart(
          df,
          x="CITY",
          y=[c for c in df.columns if c != "CITY" and c != "/* Order Key (Generated by Snowflake) */"],
          sort="-/* Order Key (Generated by Snowflake) */",
          use_container_width=True,
          height=400,
          horizontal=True,
          stack=False,
          x_label="FOOD_AND_DRINK",
        )
      else:
        st.warning("No data available")
    except Exception as e:
      st.error(f"Error: {str(e)}")

# Row 3: 2 Cells
col3_1, col3_2 = st.columns(2)
with col3_1:
  cell_3_1()
with col3_2:
  cell_3_2()

def query_4_1() -> str:
  sql_query = r"""
SELECT ETHNICITY_REFERENCE, TOTAL_VENUES
FROM POI_PROJECT.AGG_POI.AGG_SAINTPAUL_FOOD
ORDER BY TOTAL_VENUES DESC;  """

  return sql_query

execute_query(query_4_1())

@st.fragment
def cell_4_1():
  with st.container(border=True):
    with st.container(horizontal=True, horizontal_alignment="distribute", vertical_alignment="center"):
      with st.container(height=80, border=False, vertical_alignment="center"):
        st.markdown("### Saint Paul Food Culture by Ethnicity")
      if st.button(
        ":material/refresh:", type="tertiary", key=f"refresh_button_cell_4_1", help="Refresh saint_paul_food_culture_by_ethnicity data"
      ):
        execute_query.clear(query_4_1())

    try:
      with st.spinner("Executing query", show_time=True):
        df = session.create_async_job(
          execute_query(query_4_1())
        ).result("pandas")

      if any(df.columns.duplicated()):
        new_names = []
        name_indexes = {}
        for name in df.columns:
          name_index = name_indexes.get(name, 0) + 1
          name_indexes[name] = name_index
          new_names.append(f"{name}_{name_index}" if name_index > 1 else name)
        df.columns = new_names

      # Prepare data for bar chart
      if len(df) > 0:
        df = df.groupby(
          by="ETHNICITY_REFERENCE",
          sort=False
        ).agg(
          col1=("TOTAL_VENUES", "sum")
        ).rename(columns={
          "col1": "TOTAL_VENUES (sum)"
        }).reset_index()

        df["/* Order Key (Generated by Snowflake) */"] = df.drop(columns="ETHNICITY_REFERENCE").sum(axis=1)

        datetime_primary_column = None
        if pd.api.types.is_datetime64_dtype(df["ETHNICITY_REFERENCE"]):
          datetime_primary_column = df["ETHNICITY_REFERENCE"]
        elif df["ETHNICITY_REFERENCE"].dtype == "object" and isinstance(df["ETHNICITY_REFERENCE"].get(df["ETHNICITY_REFERENCE"].first_valid_index()), dt.date):
          datetime_primary_column = pd.to_datetime(df["ETHNICITY_REFERENCE"], errors="coerce")
        if datetime_primary_column is not None and (datetime_primary_column.max() - datetime_primary_column.min()).days > len(df) * 2:
          # Use string type for sparse date range
          df["ETHNICITY_REFERENCE"] = df["ETHNICITY_REFERENCE"].astype("string")

        st.bar_chart(
          df,
          x="ETHNICITY_REFERENCE",
          y=[c for c in df.columns if c != "ETHNICITY_REFERENCE" and c != "/* Order Key (Generated by Snowflake) */"],
          sort="-/* Order Key (Generated by Snowflake) */",
          use_container_width=True,
          height=400,
          stack=False,
        )
      else:
        st.warning("No data available")
    except Exception as e:
      st.error(f"Error: {str(e)}")

def query_4_2() -> str:
  sql_query = r"""
SELECT DATA_QUALITY_SCORE, COUNT(*) AS TOTAL_POIS
FROM POI_PROJECT.CUR_POI.CUR_POI_PROCESSED
GROUP BY DATA_QUALITY_SCORE
ORDER BY DATA_QUALITY_SCORE ASC;  """

  return sql_query

execute_query(query_4_2())

@st.fragment
def cell_4_2():
  with st.container(border=True):
    with st.container(horizontal=True, horizontal_alignment="distribute", vertical_alignment="center"):
      with st.container(height=80, border=False, vertical_alignment="center"):
        st.markdown("### POI Data Quality Score Distribution (0-5)")
      if st.button(
        ":material/refresh:", type="tertiary", key=f"refresh_button_cell_4_2", help="Refresh poi_data_quality_score_distribution_(0-5) data"
      ):
        execute_query.clear(query_4_2())

    try:
      with st.spinner("Executing query", show_time=True):
        df = session.create_async_job(
          execute_query(query_4_2())
        ).result("pandas")

      if any(df.columns.duplicated()):
        new_names = []
        name_indexes = {}
        for name in df.columns:
          name_index = name_indexes.get(name, 0) + 1
          name_indexes[name] = name_index
          new_names.append(f"{name}_{name_index}" if name_index > 1 else name)
        df.columns = new_names

      # Prepare data for bar chart
      if len(df) > 0:
        df = df.groupby(
          by="DATA_QUALITY_SCORE",
          sort=False
        ).agg(
          col1=("TOTAL_POIS", "sum")
        ).rename(columns={
          "col1": "TOTAL_POIS (sum)"
        }).reset_index()


        datetime_primary_column = None
        if pd.api.types.is_datetime64_dtype(df["DATA_QUALITY_SCORE"]):
          datetime_primary_column = df["DATA_QUALITY_SCORE"]
        elif df["DATA_QUALITY_SCORE"].dtype == "object" and isinstance(df["DATA_QUALITY_SCORE"].get(df["DATA_QUALITY_SCORE"].first_valid_index()), dt.date):
          datetime_primary_column = pd.to_datetime(df["DATA_QUALITY_SCORE"], errors="coerce")
        if datetime_primary_column is not None and (datetime_primary_column.max() - datetime_primary_column.min()).days > len(df) * 2:
          # Use string type for sparse date range
          df["DATA_QUALITY_SCORE"] = df["DATA_QUALITY_SCORE"].astype("string")

        st.bar_chart(
          df.set_index("DATA_QUALITY_SCORE"),
          sort=True,
          use_container_width=True,
          height=400,
          stack=False,
        )
      else:
        st.warning("No data available")
    except Exception as e:
      st.error(f"Error: {str(e)}")

# Row 4: 2 Cells
col4_1, col4_2 = st.columns(2)
with col4_1:
  cell_4_1()
with col4_2:
  cell_4_2()


# Footer
st.markdown("---")
st.markdown(
  "*Dashboard loaded: {}*".format(dt.datetime.now().strftime("%Y-%m-%d %H:%M:%S"))
)

# ---- DOWNLOAD SECTION ----
st.markdown("### Download Data")

# Load main POI data for download
@st.cache_data(ttl="23h50m")
def get_download_data():
    df = session.sql("""
        SELECT * FROM POI_PROJECT.CUR_POI.CUR_POI_PROCESSED
    """).to_pandas()
    return df

if st.button("Load Data for Download"):
    download_df = get_download_data()
    csv = download_df.to_csv(index=False)
    st.download_button(
        label="Download Full POI Data as CSV",
        data=csv,
        file_name="eagle_project_poi_data.csv",
        mime="text/csv"
    )

# Footer  ← your existing footer stays here
st.markdown("---")

"""
NYC Traffic Accidents 2020 — Interactive Dashboard Prototype
Uses synthetic data to demonstrate the planned R Shiny application layout.
"""

import streamlit as st
import pandas as pd
import numpy as np
import plotly.express as px
import plotly.graph_objects as go
from plotly.subplots import make_subplots
import folium
from streamlit_folium import st_folium

# ── Page config ────────────────────────────────────────────────────────────────
st.set_page_config(
    page_title="NYC Accident Dashboard",
    page_icon="🚨",
    layout="wide",
    initial_sidebar_state="expanded",
)

# ── Custom CSS ─────────────────────────────────────────────────────────────────
st.markdown("""
<style>
.dashboard-header {
  background: linear-gradient(90deg, #161b22 0%, #1a1a2e 100%);
  border-bottom: 2px solid #e74c3c;
  padding: 18px 28px 14px;
  margin: -1rem -1rem 1.5rem;
  display: flex;
  align-items: center;
  gap: 16px;
}
.dashboard-header h1 {
  margin: 0;
  font-size: 1.55rem;
  font-weight: 700;
  color: #e6edf3;
}
.header-badge {
  background: #e74c3c;
  color: white;
  font-size: 0.68rem;
  font-weight: 700;
  letter-spacing: 0.12em;
  text-transform: uppercase;
  padding: 3px 10px;
  border-radius: 20px;
}
.kpi-card {
  border-radius: 10px;
  padding: 20px 22px;
  margin-bottom: 6px;
  position: relative;
  overflow: hidden;
}
.kpi-card .kpi-icon {
  position: absolute;
  right: 16px; top: 50%;
  transform: translateY(-50%);
  font-size: 2.8rem;
  opacity: 0.18;
}
.kpi-card .kpi-label {
  font-size: 0.72rem;
  font-weight: 600;
  letter-spacing: 0.12em;
  text-transform: uppercase;
  color: rgba(255,255,255,0.8);
  margin-bottom: 6px;
}
.kpi-card .kpi-value {
  font-size: 2.1rem;
  font-weight: 700;
  color: #fff;
  line-height: 1;
}
.kpi-card .kpi-sub {
  font-size: 0.75rem;
  color: rgba(255,255,255,0.65);
  margin-top: 4px;
}
.kpi-red    { background: linear-gradient(135deg,#c0392b,#e74c3c); }
.kpi-orange { background: linear-gradient(135deg,#d35400,#e67e22); }
.kpi-purple { background: linear-gradient(135deg,#7d3c98,#9b59b6); }
.kpi-blue   { background: linear-gradient(135deg,#1a5276,#2980b9); }
.section-title {
  font-size: 0.72rem;
  font-weight: 700;
  letter-spacing: 0.15em;
  text-transform: uppercase;
  color: #8b949e;
  border-bottom: 1px solid #30363d;
  padding-bottom: 6px;
  margin-bottom: 12px;
}
.risk-badge {
  text-align: center;
  border-radius: 10px;
  padding: 14px;
  margin-top: 10px;
  font-size: 1.1rem;
  font-weight: 700;
  letter-spacing: 0.08em;
}
.risk-low    { background: rgba(39,174,96,0.2);  border: 1px solid #27ae60; color: #27ae60; }
.risk-medium { background: rgba(243,156,18,0.2); border: 1px solid #f39c12; color: #f39c12; }
.risk-high   { background: rgba(192,57,43,0.2);  border: 1px solid #c0392b; color: #c0392b; }
div[data-baseweb="tab-list"] { border-bottom: 2px solid #30363d !important; }
button[data-baseweb="tab"] {
  font-size: 0.8rem !important;
  font-weight: 600 !important;
  letter-spacing: 0.06em !important;
  text-transform: uppercase !important;
  color: #8b949e !important;
}
button[data-baseweb="tab"][aria-selected="true"] { color: #e74c3c !important; }
</style>
""", unsafe_allow_html=True)


# ══════════════════════════════════════════════════════════════════════════════
# HELPERS
# ══════════════════════════════════════════════════════════════════════════════
# Base layout — applied via a separate update_layout call to avoid key conflicts
BASE = dict(
    paper_bgcolor="#161b22",
    plot_bgcolor="#161b22",
    font=dict(color="#e6edf3", family="Inter, sans-serif", size=12),
    legend=dict(bgcolor="rgba(0,0,0,0)", bordercolor="#30363d", borderwidth=1),
)

def bl(fig, **kwargs):
    """Apply base layout then chart-specific overrides, then style axes."""
    fig.update_layout(**BASE)
    if kwargs:
        fig.update_layout(**kwargs)
    fig.update_xaxes(gridcolor="#21262d", zerolinecolor="#30363d", color="#8b949e")
    fig.update_yaxes(gridcolor="#21262d", zerolinecolor="#30363d", color="#8b949e")
    return fig


def hex_rgba(hex_color, alpha=1.0):
    """Convert '#rrggbb' to 'rgba(r,g,b,alpha)' — Plotly 6.x compatible."""
    h = hex_color.lstrip("#")
    r, g, b = int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)
    return f"rgba({r},{g},{b},{alpha})"


# ══════════════════════════════════════════════════════════════════════════════
# SYNTHETIC DATA
# ══════════════════════════════════════════════════════════════════════════════
@st.cache_data
def make_data(n=8_000):
    rng = np.random.default_rng(42)
    boroughs   = ["Manhattan", "Brooklyn", "Queens", "Bronx", "Staten Island"]
    boro_w     = [0.22, 0.30, 0.24, 0.18, 0.06]
    severities = ["Property Damage Only", "Injury", "Severe Injury", "Fatal"]
    sev_w      = [0.60, 0.30, 0.08, 0.02]
    factors    = ["Distraction", "Speed", "Impairment", "Traffic Violation",
                  "Following Too Closely", "Visibility", "Driver Condition", "Other"]
    fac_w      = [0.35, 0.18, 0.12, 0.13, 0.08, 0.05, 0.05, 0.04]
    vehicles   = ["Sedan", "SUV/Wagon", "Taxi/Livery", "Truck/Van/Bus",
                  "Motorcycle", "Bicycle/E-Bike"]
    veh_w      = [0.38, 0.24, 0.14, 0.10, 0.09, 0.05]
    months     = list(range(1, 13))
    days       = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

    boro_bounds = {
        "Manhattan":     (40.70, 40.88, -74.02, -73.91),
        "Brooklyn":      (40.57, 40.74, -74.04, -73.85),
        "Queens":        (40.54, 40.80, -73.96, -73.70),
        "Bronx":         (40.79, 40.92, -73.93, -73.75),
        "Staten Island": (40.49, 40.65, -74.26, -74.05),
    }

    borough  = rng.choice(boroughs, size=n, p=boro_w)
    hour     = rng.integers(0, 24, size=n)
    dow_num  = rng.integers(0, 7, size=n)
    month    = rng.choice(months, size=n)
    severity = rng.choice(severities, size=n, p=sev_w)
    factor   = rng.choice(factors, size=n, p=fac_w)
    vehicle  = rng.choice(vehicles, size=n, p=veh_w)

    lat = np.array([rng.uniform(boro_bounds[b][0], boro_bounds[b][1]) for b in borough])
    lon = np.array([rng.uniform(boro_bounds[b][2], boro_bounds[b][3]) for b in borough])

    any_injury = severity != "Property Damage Only"
    injured = np.where(severity == "Property Damage Only", 0,
              np.where(severity == "Injury",        rng.integers(1, 3, size=n),
              np.where(severity == "Severe Injury", rng.integers(2, 6, size=n),
                                                    rng.integers(1, 3, size=n))))
    killed = np.where(severity == "Fatal", rng.integers(1, 3, size=n), 0)

    df = pd.DataFrame({
        "BOROUGH":    borough,
        "HOUR":       hour,
        "DOW_NUM":    dow_num,
        "DOW":        [days[d] for d in dow_num],
        "MONTH":      month,
        "SEVERITY":   severity,
        "FACTOR":     factor,
        "VEHICLE":    vehicle,
        "LATITUDE":   lat,
        "LONGITUDE":  lon,
        "INJURED":    injured,
        "KILLED":     killed,
        "ANY_INJURY": any_injury,
    })
    df["IS_WEEKEND"]  = df["DOW"].isin(["Sat", "Sun"])
    df["IS_RUSH"]     = df["HOUR"].isin([7, 8, 9, 16, 17, 18, 19])
    return df


df_full = make_data()

SEVERITY_COLORS = {
    "Property Damage Only": "#5d6d7e",
    "Injury":               "#f39c12",
    "Severe Injury":        "#e67e22",
    "Fatal":                "#e74c3c",
}
BOROUGH_COLORS = {
    "Manhattan":     "#3498db",
    "Brooklyn":      "#e74c3c",
    "Queens":        "#27ae60",
    "Bronx":         "#f39c12",
    "Staten Island": "#9b59b6",
}
FACTOR_COLORS = {
    "Distraction":          "#e74c3c",
    "Speed":                "#e67e22",
    "Impairment":           "#9b59b6",
    "Traffic Violation":    "#3498db",
    "Following Too Closely":"#f39c12",
    "Visibility":           "#1abc9c",
    "Driver Condition":     "#e91e63",
    "Other":                "#5d6d7e",
}


# ══════════════════════════════════════════════════════════════════════════════
# HEADER
# ══════════════════════════════════════════════════════════════════════════════
st.markdown("""
<div class="dashboard-header">
  <div><span style="font-size:1.6rem">🚨</span></div>
  <div>
    <h1>NYC Traffic Accidents <span style="color:#e74c3c">2020</span></h1>
    <div style="color:#8b949e;font-size:0.78rem;margin-top:2px">
      NYPD Motor Vehicle Collisions &nbsp;·&nbsp; Interactive Analytics Dashboard
    </div>
  </div>
  <div style="margin-left:auto">
    <span class="header-badge">Prototype</span>
  </div>
</div>
""", unsafe_allow_html=True)


# ══════════════════════════════════════════════════════════════════════════════
# SIDEBAR
# ══════════════════════════════════════════════════════════════════════════════
with st.sidebar:
    st.markdown("**BOROUGH**")
    boroughs_all = sorted(df_full["BOROUGH"].unique())
    sel_boroughs = st.multiselect("Borough", boroughs_all, default=boroughs_all,
                                  label_visibility="collapsed")

    st.markdown("**SEVERITY**")
    sev_all = ["Property Damage Only", "Injury", "Severe Injury", "Fatal"]
    sel_severity = st.multiselect("Severity", sev_all, default=sev_all,
                                  label_visibility="collapsed")

    st.markdown("**MONTH RANGE**")
    sel_months = st.slider("Month", 1, 12, (1, 12), label_visibility="collapsed")

    st.markdown("**TIME OF DAY**")
    time_options = ["All", "Morning (6–11)", "Afternoon (12–17)", "Evening (18–22)", "Night (23–5)"]
    sel_time = st.selectbox("Time", time_options, label_visibility="collapsed")

    st.markdown("---")
    if st.button("↺  Reset Filters", use_container_width=True):
        st.rerun()

# ── Apply filters ──────────────────────────────────────────────────────────────
df = df_full.copy()
if sel_boroughs:
    df = df[df["BOROUGH"].isin(sel_boroughs)]
if sel_severity:
    df = df[df["SEVERITY"].isin(sel_severity)]
df = df[df["MONTH"].between(sel_months[0], sel_months[1])]
time_map = {
    "Morning (6–11)":    [6, 7, 8, 9, 10, 11],
    "Afternoon (12–17)": [12, 13, 14, 15, 16, 17],
    "Evening (18–22)":   [18, 19, 20, 21, 22],
    "Night (23–5)":      [23, 0, 1, 2, 3, 4, 5],
}
if sel_time != "All":
    df = df[df["HOUR"].isin(time_map[sel_time])]

crash_count = len(df)
st.sidebar.markdown(f"""
<div style="background:#21262d;border:1px solid #30363d;border-radius:8px;
            padding:12px 14px;margin-top:4px;text-align:center">
  <div style="font-size:0.65rem;text-transform:uppercase;letter-spacing:.12em;color:#8b949e">
    MATCHING CRASHES
  </div>
  <div style="font-size:1.7rem;font-weight:700;color:#e74c3c">
    {crash_count:,}
  </div>
</div>
""", unsafe_allow_html=True)


# ══════════════════════════════════════════════════════════════════════════════
# TABS
# ══════════════════════════════════════════════════════════════════════════════
tab1, tab2, tab3, tab4, tab5 = st.tabs([
    "📊  Overview",
    "🗺️  Map",
    "⏱️  Time Analysis",
    "⚠️  Causes & Vehicles",
    "🤖  Predictive Model",
])


# ─────────────────────────────────────────────────────────────────────────────
# TAB 1 — OVERVIEW
# ─────────────────────────────────────────────────────────────────────────────
with tab1:
    k1, k2, k3, k4 = st.columns(4)
    total_crashes = len(df)
    total_injured = int(df["INJURED"].sum())
    total_killed  = int(df["KILLED"].sum())
    injury_rate   = df["ANY_INJURY"].mean() * 100

    with k1:
        st.markdown(f"""<div class="kpi-card kpi-red">
          <div class="kpi-label">Total Crashes</div>
          <div class="kpi-value">{total_crashes:,}</div>
          <div class="kpi-sub">Collision records</div>
          <div class="kpi-icon">🚗</div></div>""", unsafe_allow_html=True)
    with k2:
        st.markdown(f"""<div class="kpi-card kpi-orange">
          <div class="kpi-label">Persons Injured</div>
          <div class="kpi-value">{total_injured:,}</div>
          <div class="kpi-sub">Across all boroughs</div>
          <div class="kpi-icon">🚑</div></div>""", unsafe_allow_html=True)
    with k3:
        st.markdown(f"""<div class="kpi-card kpi-purple">
          <div class="kpi-label">Fatalities</div>
          <div class="kpi-value">{total_killed:,}</div>
          <div class="kpi-sub">Deaths recorded</div>
          <div class="kpi-icon">⚠️</div></div>""", unsafe_allow_html=True)
    with k4:
        st.markdown(f"""<div class="kpi-card kpi-blue">
          <div class="kpi-label">Injury Rate</div>
          <div class="kpi-value">{injury_rate:.1f}%</div>
          <div class="kpi-sub">Crashes with casualties</div>
          <div class="kpi-icon">📊</div></div>""", unsafe_allow_html=True)

    st.markdown("<br>", unsafe_allow_html=True)
    col_a, col_b = st.columns([3, 2])

    with col_a:
        st.markdown('<div class="section-title">Borough Comparison</div>', unsafe_allow_html=True)
        boro_df = (df.groupby("BOROUGH")
                   .agg(Crashes=("BOROUGH", "count"),
                        Injured=("INJURED", "sum"),
                        Killed=("KILLED", "sum"))
                   .reset_index()
                   .sort_values("Crashes", ascending=True))
        fig = go.Figure()
        for col, color, name in [
            ("Crashes", "#3498db", "Crashes"),
            ("Injured", "#e67e22", "Injured"),
            ("Killed",  "#e74c3c", "Fatalities"),
        ]:
            fig.add_trace(go.Bar(
                y=boro_df["BOROUGH"], x=boro_df[col],
                name=name, orientation="h",
                marker_color=color, marker_line_width=0,
            ))
        bl(fig, barmode="group", height=300,
           title="Crashes, Injuries & Fatalities by Borough",
           margin=dict(l=10, r=10, t=40, b=10))
        fig.update_yaxes(tickfont=dict(size=11))
        st.plotly_chart(fig, use_container_width=True)

    with col_b:
        st.markdown('<div class="section-title">Victim Type Breakdown</div>', unsafe_allow_html=True)
        ped = total_injured * 0.18
        cyc = total_injured * 0.12
        mot = total_injured * 0.70
        fig2 = go.Figure(go.Pie(
            labels=["Motorists", "Pedestrians", "Cyclists"],
            values=[mot, ped, cyc],
            hole=0.6,
            marker=dict(colors=["#3498db", "#e74c3c", "#27ae60"],
                        line=dict(color="#161b22", width=2)),
            textinfo="label+percent",
            textfont=dict(size=11),
        ))
        fig2.add_annotation(text=f"<b>{total_injured:,}</b><br><span style='font-size:10px'>total</span>",
                            x=0.5, y=0.5, showarrow=False,
                            font=dict(size=15, color="#e6edf3"))
        bl(fig2, showlegend=True, title="Injured by Victim Type",
           height=300, margin=dict(l=0, r=0, t=36, b=0))
        st.plotly_chart(fig2, use_container_width=True)

    st.markdown('<div class="section-title">Monthly Crash Trend by Severity</div>', unsafe_allow_html=True)
    month_sev = (df.groupby(["MONTH", "SEVERITY"])
                 .size().reset_index(name="n")
                 .pivot(index="MONTH", columns="SEVERITY", values="n").fillna(0))
    mo_labels = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"]
    month_sev.index = [mo_labels[m - 1] for m in month_sev.index]
    fig3 = go.Figure()
    for sev in ["Property Damage Only", "Injury", "Severe Injury", "Fatal"]:
        if sev in month_sev.columns:
            fig3.add_trace(go.Scatter(
                x=month_sev.index, y=month_sev[sev],
                name=sev, stackgroup="one",
                fillcolor=hex_rgba(SEVERITY_COLORS[sev], 0.67),
                line=dict(color=SEVERITY_COLORS[sev], width=1.5),
            ))
    bl(fig3, title="Monthly Distribution by Severity", height=260,
       showlegend=True,
       legend=dict(orientation="h", y=-0.15, bgcolor="rgba(0,0,0,0)"),
       margin=dict(l=10, r=10, t=40, b=40))
    st.plotly_chart(fig3, use_container_width=True)


# ─────────────────────────────────────────────────────────────────────────────
# TAB 2 — MAP
# ─────────────────────────────────────────────────────────────────────────────
with tab2:
    map_col, ctrl_col = st.columns([4, 1])

    with ctrl_col:
        st.markdown('<div class="section-title">CONTROLS</div>', unsafe_allow_html=True)
        map_mode   = st.radio("Layer", ["Heatmap", "Markers", "Borough View"],
                              label_visibility="collapsed")
        inj_filter = st.selectbox("Overlay", ["All Crashes", "Pedestrian Involved",
                                               "Cyclist Involved", "Fatal Only"])
        hour_range = st.slider("Hour", 0, 23, (0, 23))

    with map_col:
        st.markdown('<div class="section-title">INTERACTIVE CRASH MAP — NEW YORK CITY</div>',
                    unsafe_allow_html=True)
        map_df = df[(df["HOUR"] >= hour_range[0]) & (df["HOUR"] <= hour_range[1])].copy()
        if inj_filter == "Fatal Only":
            map_df = map_df[map_df["KILLED"] > 0]
        elif inj_filter == "Cyclist Involved":
            map_df = map_df[map_df["VEHICLE"] == "Bicycle/E-Bike"]
        elif inj_filter == "Pedestrian Involved":
            map_df = map_df[map_df["SEVERITY"].isin(["Injury", "Severe Injury", "Fatal"])].sample(
                frac=0.3, random_state=1)
        map_df = map_df.head(3000)

        m = folium.Map(location=[40.730, -73.935], zoom_start=11,
                       tiles="CartoDB dark_matter")

        if map_mode == "Heatmap":
            from folium.plugins import HeatMap
            heat_data = map_df[["LATITUDE", "LONGITUDE"]].dropna().values.tolist()
            HeatMap(heat_data, radius=10, blur=15, min_opacity=0.4,
                    gradient={0.2: "blue", 0.5: "lime", 0.8: "orange", 1.0: "red"}).add_to(m)

        elif map_mode == "Markers":
            from folium.plugins import MarkerCluster
            mc = MarkerCluster().add_to(m)
            sev_colors = {"Property Damage Only": "gray", "Injury": "orange",
                          "Severe Injury": "darkred", "Fatal": "red"}
            for _, row in map_df.head(600).iterrows():
                color = sev_colors.get(row["SEVERITY"], "gray")
                folium.CircleMarker(
                    location=[row["LATITUDE"], row["LONGITUDE"]],
                    radius=5, color=color, fill=True,
                    fill_color=color, fill_opacity=0.7,
                    popup=folium.Popup(
                        f"<b>Borough:</b> {row['BOROUGH']}<br>"
                        f"<b>Hour:</b> {row['HOUR']}:00<br>"
                        f"<b>Severity:</b> {row['SEVERITY']}<br>"
                        f"<b>Factor:</b> {row['FACTOR']}<br>"
                        f"<b>Vehicle:</b> {row['VEHICLE']}",
                        max_width=220,
                    ),
                ).add_to(mc)

        else:  # Borough View
            boro_centroids = {
                "Manhattan":     (40.790, -73.960),
                "Brooklyn":      (40.650, -73.950),
                "Queens":        (40.680, -73.820),
                "Bronx":         (40.850, -73.870),
                "Staten Island": (40.580, -74.150),
            }
            boro_counts = map_df.groupby("BOROUGH").size().reset_index(name="count")
            max_count = boro_counts["count"].max()
            for _, row in boro_counts.iterrows():
                if row["BOROUGH"] in boro_centroids:
                    lat, lon = boro_centroids[row["BOROUGH"]]
                    radius = 15 + 35 * (row["count"] / max_count)
                    folium.CircleMarker(
                        location=[lat, lon], radius=radius,
                        color=BOROUGH_COLORS.get(row["BOROUGH"], "#888"),
                        fill=True, fill_opacity=0.5,
                        tooltip=f"{row['BOROUGH']}: {row['count']:,} crashes",
                    ).add_to(m)

        st_folium(m, height=540, width=None, returned_objects=[])

    mc1, mc2 = st.columns(2)
    with mc1:
        st.markdown('<div class="section-title">TOP CRASH STREETS</div>', unsafe_allow_html=True)
        streets = pd.DataFrame({
            "Street":  ["Atlantic Ave", "Broadway", "Queens Blvd",
                        "Grand Concourse", "Flatbush Ave"],
            "Crashes": [312, 289, 261, 247, 234],
            "Injured": [78, 91, 65, 82, 71],
        })
        st.dataframe(streets, hide_index=True, use_container_width=True,
                     column_config={"Crashes": st.column_config.ProgressColumn(
                         "Crashes", format="%d", min_value=0, max_value=350)})

    with mc2:
        st.markdown('<div class="section-title">CRASHES BY HOUR (FILTERED)</div>',
                    unsafe_allow_html=True)
        hour_df = map_df.groupby("HOUR").size().reset_index(name="n")
        fig_h = px.bar(hour_df, x="HOUR", y="n", color_discrete_sequence=["#e74c3c"])
        bl(fig_h, height=200, margin=dict(l=0, r=0, t=10, b=0))
        fig_h.update_xaxes(title_text="Hour")
        fig_h.update_yaxes(title_text="Crashes")
        st.plotly_chart(fig_h, use_container_width=True)


# ─────────────────────────────────────────────────────────────────────────────
# TAB 3 — TIME ANALYSIS
# ─────────────────────────────────────────────────────────────────────────────
with tab3:
    st.markdown('<div class="section-title">WHEN DO ACCIDENTS HAPPEN? — Hour × Day of Week</div>',
                unsafe_allow_html=True)

    heat = (df.groupby(["DOW_NUM", "HOUR"])
            .size().reset_index(name="crashes"))
    heat_pivot = heat.pivot(index="DOW_NUM", columns="HOUR", values="crashes").fillna(0)
    day_labels = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

    fig_hm = go.Figure(go.Heatmap(
        z=heat_pivot.values,
        x=[f"{h:02d}:00" for h in heat_pivot.columns],
        y=[day_labels[i] for i in heat_pivot.index],
        colorscale="Viridis",
        hoverongaps=False,
        hovertemplate="<b>%{y} %{x}</b><br>Crashes: %{z}<extra></extra>",
    ))
    fig_hm.add_vrect(x0="07:00", x1="09:00", fillcolor="rgba(231,76,60,0.12)", line_width=0)
    fig_hm.add_vrect(x0="16:00", x1="19:00", fillcolor="rgba(231,76,60,0.12)", line_width=0)
    fig_hm.add_annotation(x="08:00", y=7.5, text="AM Rush", showarrow=False,
                           font=dict(size=10, color="#e74c3c"), yref="y")
    fig_hm.add_annotation(x="17:00", y=7.5, text="PM Rush", showarrow=False,
                           font=dict(size=10, color="#e74c3c"), yref="y")
    bl(fig_hm, height=280, margin=dict(l=10, r=10, t=40, b=10))
    fig_hm.update_xaxes(tickangle=-45)
    st.plotly_chart(fig_hm, use_container_width=True)

    tc1, tc2 = st.columns(2)

    with tc1:
        st.markdown('<div class="section-title">DAY-OF-WEEK PATTERN</div>', unsafe_allow_html=True)
        dow_df = (df.groupby(["DOW_NUM", "DOW"])
                  .agg(Crashes=("BOROUGH", "count"), Injury_Rate=("ANY_INJURY", "mean"))
                  .reset_index()
                  .sort_values("DOW_NUM"))
        fig_dow = make_subplots(specs=[[{"secondary_y": True}]])
        fig_dow.add_trace(go.Bar(
            x=dow_df["DOW"], y=dow_df["Crashes"], name="Crashes",
            marker_color=[("#e74c3c" if d in ["Sat", "Sun"] else "#3498db") for d in dow_df["DOW"]],
            marker_line_width=0,
        ), secondary_y=False)
        fig_dow.add_trace(go.Scatter(
            x=dow_df["DOW"], y=dow_df["Injury_Rate"] * 100,
            name="Injury Rate %", mode="lines+markers",
            line=dict(color="#f39c12", width=2), marker=dict(size=7),
        ), secondary_y=True)
        bl(fig_dow, height=270, margin=dict(l=10, r=10, t=10, b=40),
           legend=dict(orientation="h", y=-0.25, bgcolor="rgba(0,0,0,0)"))
        fig_dow.update_yaxes(title_text="Crashes", secondary_y=False, color="#e6edf3")
        fig_dow.update_yaxes(title_text="Injury Rate %", secondary_y=True, color="#f39c12")
        st.plotly_chart(fig_dow, use_container_width=True)

    with tc2:
        st.markdown('<div class="section-title">TIME OF DAY BY VICTIM TYPE</div>',
                    unsafe_allow_html=True)
        tod_data = pd.DataFrame({
            "Time":        ["Morning", "Afternoon", "Evening", "Night"],
            "Motorists":   [45, 62, 55, 28],
            "Pedestrians": [18, 22, 30, 12],
            "Cyclists":    [10, 15, 8, 3],
        })
        fig_tod = go.Figure()
        total_arr = tod_data[["Motorists", "Pedestrians", "Cyclists"]].sum(axis=1)
        for col, color in [("Motorists", "#3498db"), ("Pedestrians", "#e74c3c"), ("Cyclists", "#27ae60")]:
            fig_tod.add_trace(go.Bar(
                name=col, x=tod_data["Time"],
                y=(tod_data[col] / total_arr * 100).round(1),
                marker_color=color, marker_line_width=0,
            ))
        bl(fig_tod, barmode="stack", height=270, margin=dict(l=10, r=10, t=10, b=40),
           legend=dict(orientation="h", y=-0.25, bgcolor="rgba(0,0,0,0)"))
        fig_tod.update_yaxes(title_text="% of Injured")
        st.plotly_chart(fig_tod, use_container_width=True)

    tc3, tc4 = st.columns(2)

    with tc3:
        st.markdown('<div class="section-title">MONTHLY SEASONALITY</div>', unsafe_allow_html=True)
        mo_df = df.groupby("MONTH").size().reset_index(name="n")
        mo_df["label"] = [mo_labels[m - 1] for m in mo_df["MONTH"]]
        fig_mo = go.Figure(go.Scatterpolar(
            r=mo_df["n"], theta=mo_df["label"],
            fill="toself",
            fillcolor="rgba(231,76,60,0.2)",
            line=dict(color="#e74c3c", width=2),
            marker=dict(size=6),
        ))
        bl(fig_mo, height=270, margin=dict(l=10, r=10, t=10, b=10))
        fig_mo.update_layout(polar=dict(
            bgcolor="#161b22",
            radialaxis=dict(gridcolor="#30363d", color="#8b949e"),
            angularaxis=dict(gridcolor="#30363d", color="#8b949e"),
        ))
        st.plotly_chart(fig_mo, use_container_width=True)

    with tc4:
        st.markdown('<div class="section-title">RUSH HOUR vs. OFF-PEAK (Injuries per Crash)</div>',
                    unsafe_allow_html=True)
        rush_df = df.copy()
        rush_df["Rush"] = rush_df["IS_RUSH"].map({True: "Rush Hour", False: "Off-Peak"})
        fig_rush = px.violin(rush_df, x="Rush", y="INJURED", color="Rush",
                             color_discrete_map={"Rush Hour": "#e74c3c", "Off-Peak": "#3498db"},
                             box=True, points=False)
        bl(fig_rush, height=270, showlegend=False, margin=dict(l=10, r=10, t=10, b=10))
        fig_rush.update_yaxes(title_text="Persons Injured")
        st.plotly_chart(fig_rush, use_container_width=True)


# ─────────────────────────────────────────────────────────────────────────────
# TAB 4 — CAUSES & VEHICLES
# ─────────────────────────────────────────────────────────────────────────────
with tab4:
    ca1, ca2 = st.columns([5, 3])

    with ca1:
        st.markdown('<div class="section-title">TOP CONTRIBUTING FACTORS</div>',
                    unsafe_allow_html=True)
        fac_df = (df.groupby("FACTOR")
                  .agg(Crashes=("FACTOR", "count"), InjuryRate=("ANY_INJURY", "mean"))
                  .reset_index()
                  .sort_values("Crashes", ascending=True))
        fig_fac = go.Figure()
        fig_fac.add_trace(go.Bar(
            y=fac_df["FACTOR"], x=fac_df["Crashes"],
            orientation="h",
            marker_color=[FACTOR_COLORS.get(f, "#888") for f in fac_df["FACTOR"]],
            marker_line_width=0,
            customdata=fac_df[["InjuryRate"]].values,
            hovertemplate="<b>%{y}</b><br>Crashes: %{x:,}<br>Injury Rate: %{customdata[0]:.1%}<extra></extra>",
        ))
        bl(fig_fac, height=320, title="Crashes by Contributing Factor",
           margin=dict(l=10, r=10, t=40, b=10))
        fig_fac.update_xaxes(title_text="Number of Crashes")
        fig_fac.update_yaxes(tickfont=dict(size=11))
        st.plotly_chart(fig_fac, use_container_width=True)

    with ca2:
        st.markdown('<div class="section-title">FACTOR CATEGORIES</div>', unsafe_allow_html=True)
        treemap_df = fac_df[["FACTOR", "Crashes"]].rename(
            columns={"FACTOR": "label", "Crashes": "value"})
        fig_tree = px.treemap(treemap_df, path=["label"], values="value",
                              color="value",
                              color_continuous_scale=["#21262d", "#c0392b", "#e74c3c"])
        fig_tree.update_traces(textinfo="label+value", textfont_size=11)
        bl(fig_tree, height=320, margin=dict(l=0, r=0, t=30, b=0),
           coloraxis_showscale=False)
        st.plotly_chart(fig_tree, use_container_width=True)

    ca3, ca4 = st.columns(2)

    with ca3:
        st.markdown('<div class="section-title">SEVERITY BY VEHICLE TYPE</div>',
                    unsafe_allow_html=True)
        veh_df = (df.groupby(["VEHICLE", "SEVERITY"])
                  .size().reset_index(name="n"))
        veh_total = veh_df.groupby("VEHICLE")["n"].transform("sum")
        veh_df["pct"] = veh_df["n"] / veh_total * 100
        veh_rank = (veh_df[veh_df["SEVERITY"].isin(["Fatal", "Severe Injury"])]
                    .groupby("VEHICLE")["pct"].sum()
                    .sort_values(ascending=False))
        fig_veh = go.Figure()
        for sev in ["Property Damage Only", "Injury", "Severe Injury", "Fatal"]:
            sub = veh_df[veh_df["SEVERITY"] == sev].set_index("VEHICLE")
            fig_veh.add_trace(go.Bar(
                name=sev,
                x=list(veh_rank.index),
                y=[sub.loc[v, "pct"] if v in sub.index else 0 for v in veh_rank.index],
                marker_color=SEVERITY_COLORS[sev], marker_line_width=0,
            ))
        bl(fig_veh, barmode="stack", height=300, margin=dict(l=10, r=10, t=10, b=60),
           legend=dict(orientation="h", y=-0.35, bgcolor="rgba(0,0,0,0)"))
        fig_veh.update_xaxes(tickangle=-20)
        fig_veh.update_yaxes(title_text="% of Crashes")
        st.plotly_chart(fig_veh, use_container_width=True)

    with ca4:
        st.markdown('<div class="section-title">VEHICLE × FACTOR CO-OCCURRENCE</div>',
                    unsafe_allow_html=True)
        co = (df.groupby(["VEHICLE", "FACTOR"])
              .size().reset_index(name="n")
              .pivot(index="FACTOR", columns="VEHICLE", values="n").fillna(0))
        fig_co = go.Figure(go.Heatmap(
            z=co.values, x=list(co.columns), y=list(co.index),
            colorscale=[[0, "#161b22"], [0.5, "#9b59b6"], [1.0, "#e74c3c"]],
            hoverongaps=False,
        ))
        bl(fig_co, height=300, margin=dict(l=10, r=10, t=10, b=10))
        fig_co.update_xaxes(tickangle=-30, tickfont=dict(size=10))
        fig_co.update_yaxes(tickfont=dict(size=10))
        st.plotly_chart(fig_co, use_container_width=True)

    st.markdown('<div class="section-title">PEDESTRIAN & CYCLIST VULNERABILITY BY BOROUGH</div>',
                unsafe_allow_html=True)
    ped_data = pd.DataFrame({
        "Borough":    ["Manhattan", "Brooklyn", "Queens", "Bronx", "Staten Island"],
        "Ped Rate":   [28.1, 19.4, 16.2, 22.8, 9.5],
        "Cyc Rate":   [12.3, 9.8, 7.1, 6.5, 4.2],
        "Total Rate": [41.2, 31.5, 25.0, 32.1, 14.8],
    })
    fig_vul = go.Figure()
    fig_vul.add_trace(go.Bar(name="Pedestrian", x=ped_data["Borough"],
                             y=ped_data["Ped Rate"],
                             marker_color="#e74c3c", marker_line_width=0))
    fig_vul.add_trace(go.Bar(name="Cyclist", x=ped_data["Borough"],
                             y=ped_data["Cyc Rate"],
                             marker_color="#27ae60", marker_line_width=0))
    fig_vul.add_trace(go.Scatter(name="Combined Rate", x=ped_data["Borough"],
                                 y=ped_data["Total Rate"], mode="lines+markers",
                                 line=dict(color="#f39c12", width=2),
                                 marker=dict(size=8)))
    bl(fig_vul, barmode="group", height=260, margin=dict(l=10, r=10, t=30, b=40),
       legend=dict(orientation="h", y=-0.25, bgcolor="rgba(0,0,0,0)"))
    fig_vul.update_yaxes(title_text="Injury Rate per 100 Crashes")
    fig_vul.add_annotation(
        text="Manhattan pedestrians are 3× more at risk than Staten Island",
        x=0.5, y=1.08, xref="paper", yref="paper",
        showarrow=False, font=dict(size=11, color="#8b949e"))
    st.plotly_chart(fig_vul, use_container_width=True)


# ─────────────────────────────────────────────────────────────────────────────
# TAB 5 — PREDICTIVE MODEL
# ─────────────────────────────────────────────────────────────────────────────
with tab5:
    st.markdown("""
    <div style="background:#161b22;border:1px solid #30363d;border-radius:10px;
                padding:18px 22px;margin-bottom:18px">
      <div style="font-size:0.7rem;font-weight:700;letter-spacing:.15em;
                  text-transform:uppercase;color:#8b949e;margin-bottom:8px">MODEL OVERVIEW</div>
      <div style="display:flex;gap:32px;flex-wrap:wrap">
        <div><div style="color:#8b949e;font-size:0.72rem;text-transform:uppercase">Target</div>
          <div style="color:#e6edf3;font-weight:600">Crash results in injury/fatality (binary)</div></div>
        <div><div style="color:#8b949e;font-size:0.72rem;text-transform:uppercase">Algorithm</div>
          <div style="color:#e6edf3;font-weight:600">Random Forest (5-fold CV, AUC-optimized)</div></div>
        <div><div style="color:#8b949e;font-size:0.72rem;text-transform:uppercase">AUC</div>
          <div style="color:#27ae60;font-weight:700;font-size:1.1rem">0.74</div></div>
        <div><div style="color:#8b949e;font-size:0.72rem;text-transform:uppercase">Accuracy</div>
          <div style="color:#27ae60;font-weight:700;font-size:1.1rem">71.2%</div></div>
        <div><div style="color:#8b949e;font-size:0.72rem;text-transform:uppercase">Features</div>
          <div style="color:#e6edf3;font-weight:600">Borough · Hour · Day · Factor · Vehicle · Rush Hour</div></div>
      </div>
    </div>
    """, unsafe_allow_html=True)

    pred_col, eval_col = st.columns([2, 3])

    with pred_col:
        st.markdown('<div class="section-title">LIVE CRASH RISK PREDICTOR</div>',
                    unsafe_allow_html=True)
        p_borough = st.selectbox("Borough",
                                 ["Manhattan", "Brooklyn", "Queens", "Bronx", "Staten Island"])
        p_hour    = st.slider("Hour of Day", 0, 23, 8)
        p_dow     = st.selectbox("Day of Week",
                                 ["Monday", "Tuesday", "Wednesday", "Thursday",
                                  "Friday", "Saturday", "Sunday"])
        p_factor  = st.selectbox("Contributing Factor",
                                 ["Distraction", "Speed", "Impairment", "Traffic Violation",
                                  "Following Too Closely", "Visibility", "Driver Condition", "Other"])
        p_vehicle = st.selectbox("Vehicle Type",
                                 ["Sedan", "SUV/Wagon", "Taxi/Livery",
                                  "Truck/Van/Bus", "Motorcycle", "Bicycle/E-Bike"])

        if st.button("🔍  Predict Injury Risk", use_container_width=True):
            base  = {"Manhattan": 0.45, "Brooklyn": 0.38, "Queens": 0.35,
                     "Bronx": 0.41, "Staten Island": 0.28}.get(p_borough, 0.35)
            f_add = {"Impairment": 0.18, "Speed": 0.14, "Distraction": 0.05,
                     "Traffic Violation": 0.08, "Following Too Closely": 0.04,
                     "Visibility": 0.10, "Driver Condition": 0.12, "Other": 0.0}.get(p_factor, 0)
            v_add = {"Motorcycle": 0.22, "Bicycle/E-Bike": 0.18, "Sedan": 0.0,
                     "SUV/Wagon": 0.02, "Taxi/Livery": 0.05, "Truck/Van/Bus": 0.08}.get(p_vehicle, 0)
            h_add = 0.06 if p_hour in range(7, 10) or p_hour in range(16, 20) else 0.0
            we_add = 0.03 if p_dow in ["Saturday", "Sunday"] else 0.0
            prob = float(np.clip(base + f_add + v_add + h_add + we_add +
                                 np.random.uniform(-0.03, 0.03), 0.05, 0.95))
            st.session_state["pred_prob"] = prob

        prob = st.session_state.get("pred_prob", None)
        if prob is not None:
            bar_color = "#27ae60" if prob < 0.3 else "#f39c12" if prob < 0.6 else "#e74c3c"
            fig_gauge = go.Figure(go.Indicator(
                mode="gauge+number",
                value=round(prob * 100, 1),
                title={"text": "Injury Probability (%)", "font": {"size": 13, "color": "#e6edf3"}},
                number={"suffix": "%", "font": {"size": 28, "color": "#e6edf3"}},
                gauge={
                    "axis": {"range": [0, 100], "tickcolor": "#8b949e",
                             "tickfont": {"color": "#8b949e"}},
                    "bar": {"color": bar_color},
                    "bgcolor": "#21262d",
                    "bordercolor": "#30363d",
                    "steps": [
                        {"range": [0, 30],   "color": "rgba(39,174,96,0.15)"},
                        {"range": [30, 60],  "color": "rgba(243,156,18,0.15)"},
                        {"range": [60, 100], "color": "rgba(231,76,60,0.15)"},
                    ],
                },
            ))
            fig_gauge.update_layout(
                paper_bgcolor="#161b22",
                font=dict(color="#e6edf3"),
                height=260,
                margin=dict(l=20, r=20, t=40, b=0),
            )
            st.plotly_chart(fig_gauge, use_container_width=True)

            level = ("LOW RISK" if prob < 0.3 else "MODERATE RISK" if prob < 0.6 else "HIGH RISK")
            css   = ("risk-low" if prob < 0.3 else "risk-medium" if prob < 0.6 else "risk-high")
            st.markdown(f'<div class="risk-badge {css}">{level}</div>', unsafe_allow_html=True)
        else:
            st.info("Configure inputs above and click **Predict** to see injury probability.")

    with eval_col:
        st.markdown('<div class="section-title">MODEL EVALUATION</div>', unsafe_allow_html=True)
        ev1, ev2 = st.tabs(["ROC Curve & Confusion Matrix",
                             "Variable Importance & Calibration"])

        with ev1:
            ev1a, ev1b = st.columns(2)
            with ev1a:
                fpr = np.linspace(0, 1, 100)
                tpr = np.clip(np.sort(fpr ** 0.45 + np.random.default_rng(7).normal(0, 0.01, 100)), 0, 1)
                auc = float(np.trapz(tpr, fpr))
                fig_roc = go.Figure()
                fig_roc.add_trace(go.Scatter(x=[0, 1], y=[0, 1], mode="lines",
                                             line=dict(dash="dash", color="#30363d"),
                                             name="Random (AUC=0.50)"))
                fig_roc.add_trace(go.Scatter(x=fpr, y=tpr, mode="lines",
                                             line=dict(color="#e74c3c", width=2.5),
                                             name=f"RF Model (AUC={auc:.2f})"))
                fig_roc.add_annotation(text=f"<b>AUC = {auc:.2f}</b>",
                                       x=0.75, y=0.25, showarrow=False,
                                       font=dict(size=14, color="#e74c3c"),
                                       bgcolor="#161b22", bordercolor="#e74c3c", borderwidth=1)
                bl(fig_roc, height=280, title="ROC Curve", margin=dict(l=10, r=10, t=40, b=10))
                fig_roc.update_xaxes(title_text="False Positive Rate")
                fig_roc.update_yaxes(title_text="True Positive Rate")
                st.plotly_chart(fig_roc, use_container_width=True)

            with ev1b:
                cm = np.array([[3812, 874], [1241, 2073]])
                fig_cm = go.Figure(go.Heatmap(
                    z=cm, x=["No Injury", "Injury"], y=["No Injury", "Injury"],
                    colorscale=[[0, "#161b22"], [1, "#e74c3c"]],
                    text=cm.astype(str), texttemplate="%{text}",
                    textfont=dict(size=18, color="white"),
                    showscale=False,
                ))
                bl(fig_cm, height=280, title="Confusion Matrix (Test Set)",
                   margin=dict(l=10, r=10, t=40, b=10))
                fig_cm.update_xaxes(title_text="Predicted")
                fig_cm.update_yaxes(title_text="Actual")
                st.plotly_chart(fig_cm, use_container_width=True)

        with ev2:
            ev2a, ev2b = st.columns(2)
            with ev2a:
                imp_df = pd.DataFrame({
                    "Feature": ["Factor Category", "Vehicle Type", "Hour", "Borough",
                                "N Vehicles", "Rush Hour", "Day of Week", "Month",
                                "Is Weekend", "Time Period"],
                    "Importance": [38.2, 22.1, 14.5, 10.3, 5.8, 4.1, 2.7, 1.4, 0.6, 0.3],
                }).sort_values("Importance")
                fig_imp = px.bar(imp_df, x="Importance", y="Feature", orientation="h",
                                 color="Importance",
                                 color_continuous_scale=["#21262d", "#3498db", "#e74c3c"])
                fig_imp.update_traces(marker_line_width=0)
                bl(fig_imp, height=280, title="Variable Importance (%)",
                   coloraxis_showscale=False, margin=dict(l=10, r=10, t=40, b=10))
                fig_imp.update_xaxes(title_text="Mean Decrease in Gini")
                st.plotly_chart(fig_imp, use_container_width=True)

            with ev2b:
                pred_bins   = [0.10, 0.20, 0.30, 0.40, 0.50, 0.60, 0.70, 0.80, 0.90]
                actual_bins = [0.12, 0.19, 0.31, 0.38, 0.52, 0.59, 0.68, 0.81, 0.88]
                fig_cal = go.Figure()
                fig_cal.add_trace(go.Scatter(x=[0, 1], y=[0, 1], mode="lines",
                                             line=dict(dash="dash", color="#30363d"),
                                             name="Perfect calibration"))
                fig_cal.add_trace(go.Scatter(x=pred_bins, y=actual_bins,
                                             mode="lines+markers",
                                             line=dict(color="#27ae60", width=2.5),
                                             marker=dict(size=8),
                                             name="RF Model"))
                bl(fig_cal, height=280, title="Calibration Plot",
                   margin=dict(l=10, r=10, t=40, b=10))
                fig_cal.update_xaxes(title_text="Mean Predicted Probability")
                fig_cal.update_yaxes(title_text="Fraction of Positives")
                st.plotly_chart(fig_cal, use_container_width=True)


# ── Footer ─────────────────────────────────────────────────────────────────────
st.markdown("---")
st.markdown("""
<div style="text-align:center;color:#8b949e;font-size:0.75rem;padding:8px 0">
  NYC Traffic Accidents Dashboard &nbsp;·&nbsp; Data Analytics with R — Group Project &nbsp;·&nbsp;
  <span style="color:#e74c3c">Prototype</span> — Synthetic data for visualization purposes only
</div>
""", unsafe_allow_html=True)

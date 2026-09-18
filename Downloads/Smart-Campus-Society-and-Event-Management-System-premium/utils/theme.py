"""Shared premium visual theme for the Smart Campus app.

Streamlit doesn't give us full control over markup, so the "premium" look
is delivered via one consistent CSS injection (fonts, palette, card
styling, status pills, buttons) used identically on every page.
"""

import streamlit as st

PRIMARY = "#5B5FEF"       # indigo
PRIMARY_DARK = "#3F3FD1"
ACCENT = "#22C39A"        # teal accent
WARN = "#F5A623"
DANGER = "#E5484D"

_CSS = f"""
<style>
@import url('https://fonts.googleapis.com/css2?family=Manrope:wght@400;500;600;700;800&family=Sora:wght@600;700;800&display=swap');

html, body, [class*="css"] {{
    font-family: 'Manrope', sans-serif;
}}

#MainMenu {{visibility: hidden;}}
footer {{visibility: hidden;}}
header[data-testid="stHeader"] {{background: transparent;}}

.block-container {{
    padding-top: 2rem;
    padding-bottom: 3rem;
    max-width: 1150px;
}}

h1, h2, h3 {{
    font-family: 'Sora', sans-serif !important;
    letter-spacing: -0.02em;
}}

/* Hero / brand header */
.sc-hero {{
    background: linear-gradient(120deg, {PRIMARY} 0%, {PRIMARY_DARK} 55%, #2A2A6E 100%);
    border-radius: 20px;
    padding: 2.4rem 2.2rem;
    color: white;
    margin-bottom: 1.6rem;
    box-shadow: 0 12px 30px -12px rgba(91,95,239,0.55);
}}
.sc-hero h1 {{
    color: white !important;
    font-size: 2.1rem;
    margin-bottom: 0.35rem;
}}
.sc-hero p {{
    color: rgba(255,255,255,0.88);
    font-size: 1.02rem;
    margin-bottom: 0;
}}

/* Section badge above titles */
.sc-eyebrow {{
    display: inline-block;
    background: rgba(91,95,239,0.12);
    color: {PRIMARY_DARK};
    font-weight: 700;
    font-size: 0.72rem;
    letter-spacing: 0.08em;
    text-transform: uppercase;
    padding: 0.28rem 0.7rem;
    border-radius: 999px;
    margin-bottom: 0.5rem;
}}

/* Status pills */
.sc-pill {{
    display: inline-block;
    padding: 0.22rem 0.7rem;
    border-radius: 999px;
    font-size: 0.75rem;
    font-weight: 700;
    letter-spacing: 0.02em;
}}
.sc-pill-approved, .sc-pill-active, .sc-pill-paid, .sc-pill-attended {{
    background: rgba(34,195,154,0.15); color: #128A6C;
}}
.sc-pill-pending {{
    background: rgba(245,166,35,0.16); color: #B67509;
}}
.sc-pill-rejected, .sc-pill-cancelled, .sc-pill-failed {{
    background: rgba(229,72,77,0.14); color: #C82E33;
}}
.sc-pill-confirmed, .sc-pill-unpaid {{
    background: rgba(91,95,239,0.14); color: {PRIMARY_DARK};
}}
.sc-pill-conflict {{
    background: rgba(229,72,77,0.14); color: #C82E33;
    border: 1px solid rgba(229,72,77,0.35);
}}

/* Cards */
div[data-testid="stContainer"] > div[data-testid="stVerticalBlockBorderWrapper"] {{
    border-radius: 16px !important;
    border: 1px solid rgba(49,51,63,0.09) !important;
    box-shadow: 0 2px 10px -6px rgba(20,20,43,0.12);
}}

/* Buttons */
.stButton > button, .stFormSubmitButton > button {{
    border-radius: 10px;
    font-weight: 700;
    border: none;
}}
.stButton > button[kind="primary"], .stFormSubmitButton > button[kind="primary"] {{
    background: linear-gradient(120deg, {PRIMARY} 0%, {PRIMARY_DARK} 100%);
}}

/* Metrics */
div[data-testid="stMetric"] {{
    background: rgba(91,95,239,0.05);
    border-radius: 14px;
    padding: 0.8rem 1rem 0.6rem 1rem;
    border: 1px solid rgba(91,95,239,0.10);
}}

/* Sidebar */
section[data-testid="stSidebar"] {{
    background: #14142B;
}}
section[data-testid="stSidebar"] * {{
    color: #EDEDF7 !important;
}}
section[data-testid="stSidebar"] .stButton > button {{
    background: rgba(255,255,255,0.08);
    color: #EDEDF7 !important;
    border: 1px solid rgba(255,255,255,0.14);
}}

/* Tabs */
button[data-baseweb="tab"] {{
    font-weight: 700;
}}
</style>
"""


def inject(hide_sidebar_nav: bool = True) -> None:
    """Inject the shared premium CSS. Call once near the top of every page."""
    st.markdown(_CSS, unsafe_allow_html=True)
    if hide_sidebar_nav:
        st.markdown(
            """<style>[data-testid="stSidebarNav"] {display: none;}</style>""",
            unsafe_allow_html=True,
        )


def hero(title: str, subtitle: str, emoji: str = "🎓") -> None:
    st.markdown(
        f"""<div class="sc-hero"><h1>{emoji} {title}</h1><p>{subtitle}</p></div>""",
        unsafe_allow_html=True,
    )


def eyebrow(text: str) -> None:
    st.markdown(f'<span class="sc-eyebrow">{text}</span>', unsafe_allow_html=True)


def pill(label: str, kind: str) -> str:
    """Return HTML for a small status pill. `kind` maps to a CSS class suffix
    (e.g. 'approved', 'pending', 'rejected', 'paid', 'failed', 'conflict')."""
    kind = (kind or "").lower().strip()
    return f'<span class="sc-pill sc-pill-{kind}">{label}</span>'

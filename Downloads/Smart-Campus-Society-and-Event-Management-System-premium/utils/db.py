import os
from typing import Optional
import streamlit as st
from supabase import create_client, Client
from dotenv import load_dotenv

load_dotenv()

SUPABASE_URL = os.environ.get("SUPABASE_URL")
SUPABASE_KEY = os.environ.get("SUPABASE_KEY")


def get_supabase() -> Client:
    """Return a Supabase client scoped to THIS user's browser session.

    IMPORTANT: this is intentionally NOT @st.cache_resource. cache_resource
    is a process-wide singleton in Streamlit -- every visitor's browser tab
    would share one client object, which means one student's logged-in
    session (and their auth.uid() used by Row Level Security) could leak
    into another visitor's requests. Each session gets its own client,
    stored in st.session_state, so auth state never crosses users.
    """
    if not SUPABASE_URL or not SUPABASE_KEY:
        st.error("Supabase credentials not found. Please check your .env file / secrets.")
        st.stop()

    if "supabase_client" not in st.session_state:
        st.session_state.supabase_client = create_client(SUPABASE_URL, SUPABASE_KEY)

    return st.session_state.supabase_client


def get_profile(supabase: Client, user_id: str) -> Optional[dict]:
    """Fetch the caller's own profile row. Returns None if not found."""
    res = supabase.table("profiles").select("*").eq("id", user_id).execute()
    return res.data[0] if res.data else None


def require_role(role: str):
    """Guard a page: ensure the logged-in user's profile role matches.

    Returns (user_id, supabase, profile) on success, otherwise stops the
    page with an appropriate message.
    """
    if "user" not in st.session_state or st.session_state.user is None:
        st.warning("Please log in from the main page.")
        st.stop()

    supabase = get_supabase()
    profile = get_profile(supabase, st.session_state.user.id)

    if not profile:
        st.error("No profile found for this account.")
        st.stop()

    if profile.get("role") != role:
        st.error(f"Unauthorized: {role.replace('_', ' ').title()} access required.")
        st.stop()

    return st.session_state.user.id, supabase, profile


def sign_out(supabase: Client) -> None:
    try:
        supabase.auth.sign_out()
    except Exception:
        pass
    for key in ("user", "role", "supabase_client"):
        st.session_state.pop(key, None)

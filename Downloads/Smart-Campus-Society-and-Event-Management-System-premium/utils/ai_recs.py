import os
import datetime
import google.generativeai as genai
from utils.db import get_supabase

MODEL_NAME = "gemini-1.5-flash"


def _configure():
    api_key = os.environ.get("GEMINI_API_KEY")
    if not api_key:
        return None
    genai.configure(api_key=api_key)
    return api_key


def get_recommendations(user_id: str) -> str:
    if not _configure():
        return "⚠️ Gemini API key is not configured in the environment variables."

    supabase = get_supabase()

    try:
        prof_res = supabase.table("profiles").select("*").eq("id", user_id).execute()
        if not prof_res.data:
            return "Could not load your profile."
        profile = prof_res.data[0]

        regs_res = (
            supabase.table("registrations")
            .select("registration_status, events(title, category)")
            .eq("student_id", user_id)
            .execute()
        )
        past_events = []
        if regs_res.data:
            for r in regs_res.data:
                e = r.get("events")
                if e and r.get("registration_status") != "cancelled":
                    past_events.append(f"{e.get('title', 'Untitled')} ({e.get('category', 'General')})")

        today = datetime.date.today().isoformat()
        avail_res = (
            supabase.table("events")
            .select("title, category, description, date, venue")
            .eq("status", "approved")
            .gte("date", today)
            .execute()
        )
        if not avail_res.data:
            return "There are no upcoming approved events available to recommend right now."

        prompt = f"""
        You are an AI assistant for a smart campus event platform.
        Student Name: {profile.get('name', 'Student')}
        Department: {profile.get('department') or 'Not specified'}
        Interests: {profile.get('interests') or 'Not specified'}

        Past Events Attended/Registered:
        {', '.join(past_events) if past_events else 'None yet.'}

        Upcoming Approved Events on Campus:
        """
        for count, e in enumerate(avail_res.data, 1):
            desc = (e.get("description") or "")[:100]
            prompt += (
                f"{count}. {e.get('title', 'Untitled')} ({e.get('category', 'General')}) "
                f"on {e.get('date', 'TBD')} @ {e.get('venue', 'TBD')}. Details: {desc}\n"
            )

        prompt += """
        Based strictly on the student's background and past events attended, pick 2-3 most
        relevant events from the 'Upcoming Approved Events' list above (use their exact titles).
        Format the response in engaging markdown with a short reason under each pick.
        Be enthusiastic, clear, and brief. Start directly with the recommendations, no preamble.
        """

        model = genai.GenerativeModel(MODEL_NAME)
        response = model.generate_content(prompt)
        return response.text or "No recommendations were generated. Please try again."

    except Exception as e:
        return f"⚠️ AI recommendation engine hit an error: {str(e)}"

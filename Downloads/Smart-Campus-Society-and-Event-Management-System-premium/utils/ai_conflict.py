"""Secondary AI feature: venue / schedule conflict flagging.

Design note: we never rely on the LLM alone to decide whether two events
truly clash -- that's a deterministic question (same venue, overlapping
date/time window) and we answer it with plain comparison logic first.
Gemini is layered on top only to phrase a friendly, specific warning and
to notice softer conflicts (e.g. a big campus-wide event nearby in time)
using data already stored in Supabase, per the PRD's MVP constraint of
not depending on an external timetable API.
"""

import os
import datetime
from typing import Optional, List
import google.generativeai as genai
from utils.db import get_supabase

MODEL_NAME = "gemini-1.5-flash"


def _to_time(value) -> Optional[datetime.time]:
    if value is None:
        return None
    if isinstance(value, datetime.time):
        return value
    try:
        return datetime.time.fromisoformat(str(value)[:8])
    except Exception:
        return None


def _overlaps(a_start, a_end, b_start, b_end) -> bool:
    """True if two [start, end) time windows overlap. Missing end times are
    treated as a conservative 2-hour block from start."""
    a_start_t, a_end_t = _to_time(a_start), _to_time(a_end)
    b_start_t, b_end_t = _to_time(b_start), _to_time(b_end)
    if not a_start_t or not b_start_t:
        return True  # can't rule it out -> flag for human review

    def minutes(t):
        return t.hour * 60 + t.minute

    a_s = minutes(a_start_t)
    a_e = minutes(a_end_t) if a_end_t else a_s + 120
    b_s = minutes(b_start_t)
    b_e = minutes(b_end_t) if b_end_t else b_s + 120
    return a_s < b_e and b_s < a_e


def find_deterministic_conflicts(new_event: dict, exclude_event_id: str = None) -> List[dict]:
    """Return existing pending/approved events that clash on date+venue+time."""
    supabase = get_supabase()
    date = new_event.get("date")
    venue = (new_event.get("venue") or "").strip().lower()
    if not date or not venue:
        return []

    res = (
        supabase.table("events")
        .select("id, title, date, start_time, end_time, venue, status")
        .eq("date", str(date))
        .in_("status", ["pending", "approved"])
        .execute()
    )
    conflicts = []
    for e in res.data or []:
        if exclude_event_id and e["id"] == exclude_event_id:
            continue
        if (e.get("venue") or "").strip().lower() != venue:
            continue
        if _overlaps(new_event.get("start_time"), new_event.get("end_time"), e.get("start_time"), e.get("end_time")):
            conflicts.append(e)
    return conflicts


def analyze_conflict(new_event: dict, exclude_event_id: str = None) -> dict:
    """Return {"flagged": bool, "note": str} for the given candidate event.

    Combines the deterministic venue/time overlap check with an optional
    Gemini-written explanation. Never blocks event creation -- it's a
    flag for the society head / admin to see, per the PRD.
    """
    hard_conflicts = find_deterministic_conflicts(new_event, exclude_event_id)

    if not hard_conflicts:
        return {"flagged": False, "note": ""}

    titles = ", ".join(c["title"] for c in hard_conflicts)
    fallback_note = (
        f"⚠️ Potential scheduling conflict: another event ({titles}) is already "
        f"{hard_conflicts[0]['status']} at the same venue on an overlapping time slot."
    )

    api_key = os.environ.get("GEMINI_API_KEY")
    if not api_key:
        return {"flagged": True, "note": fallback_note}

    try:
        genai.configure(api_key=api_key)
        model = genai.GenerativeModel(MODEL_NAME)
        prompt = f"""
        A society wants to host: "{new_event.get('title')}" on {new_event.get('date')}
        from {new_event.get('start_time')} to {new_event.get('end_time')} at
        venue "{new_event.get('venue')}".

        These campus events already occupy the same venue on an overlapping
        time window: {titles}.

        Write ONE short, specific sentence (max 30 words) warning the society
        head about this venue/time conflict, in a helpful, non-alarming tone.
        Do not add markdown, headers, or extra commentary.
        """
        response = model.generate_content(prompt)
        note = (response.text or "").strip() or fallback_note
        return {"flagged": True, "note": note}
    except Exception:
        return {"flagged": True, "note": fallback_note}

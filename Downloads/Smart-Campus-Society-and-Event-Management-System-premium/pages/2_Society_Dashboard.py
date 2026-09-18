import datetime
import streamlit as st
from utils.db import require_role, sign_out
from utils import theme
from utils.storage import upload_image
from utils.ai_conflict import analyze_conflict

st.set_page_config(page_title="Society Dashboard", page_icon="🏢", layout="wide")
theme.inject(hide_sidebar_nav=True)

user_id, supabase, profile = require_role("society_head")

with st.sidebar:
    st.markdown(f"### 👋 {profile.get('name', 'Society Head')}")
    st.caption(profile.get("email", ""))
    if st.button("Log Out", type="primary", use_container_width=True):
        sign_out(supabase)
        st.switch_page("app.py")

theme.hero("Society Dashboard", "Manage your society profile, create events, and track attendance.", "🏢")

soc_res = supabase.table("societies").select("*").eq("head_id", user_id).execute()
society = soc_res.data[0] if soc_res.data else None

# ---------------------------------------------------------------------
# No society yet -> onboarding form
# ---------------------------------------------------------------------
if not society:
    st.info("You haven't set up your society profile yet. Submit your details for Admin approval.")
    with st.form("create_society_form"):
        soc_name = st.text_input("Society Name*")
        soc_desc = st.text_area("Description")
        soc_dept = st.text_input("Department (Optional)")
        col1, col2 = st.columns(2)
        contact_email = col1.text_input("Contact Email (Optional)")
        contact_phone = col2.text_input("Contact Phone (Optional)")
        logo_file = st.file_uploader("Society Logo (Optional)", type=["png", "jpg", "jpeg", "webp"])
        submitted = st.form_submit_button("Submit for Admin Approval", type="primary")

    if submitted:
        if not soc_name:
            st.error("Society name is required.")
        else:
            logo_url = None
            try:
                logo_url = upload_image(supabase, "logos", logo_file)
            except Exception as e:
                st.warning(f"Logo upload skipped (storage error: {e}).")

            supabase.table("societies").insert({
                "name": soc_name, "description": soc_desc, "department": soc_dept,
                "head_id": user_id, "status": "pending",
                "contact_email": contact_email or None, "contact_phone": contact_phone or None,
                "logo_url": logo_url,
            }).execute()
            st.success("Society profile submitted successfully! It is now pending review.")
            st.rerun()

else:
    header_l, header_r = st.columns([1, 5])
    with header_l:
        if society.get("logo_url"):
            st.image(society["logo_url"], width=80)
    with header_r:
        st.subheader(f"✨ {society.get('name')}")
        st.write(society.get("description", ""))

    status = society.get("status", "pending")

    if status == "pending":
        st.markdown(theme.pill("Pending Admin Approval", "pending"), unsafe_allow_html=True)
        st.warning("Your society profile is pending Admin approval. Event creation unlocks once approved.")
    elif status == "rejected":
        st.markdown(theme.pill("Rejected", "rejected"), unsafe_allow_html=True)
        st.error("Your society profile request has been rejected by the Administration.")
    else:
        st.markdown(theme.pill("Active", "active"), unsafe_allow_html=True)
        st.divider()

        tab_events, tab_create, tab_scan, tab_profile = st.tabs(
            ["📊 My Events & Stats", "➕ Create New Event", "📷 Scan QR Attendance", "🏢 Society Profile"]
        )

        # -----------------------------------------------------------------
        # My events & stats
        # -----------------------------------------------------------------
        with tab_events:
            events_res = supabase.table("events").select("*").eq("society_id", society["id"]).order("date", desc=True).execute()
            today = datetime.date.today()

            if events_res.data:
                upcoming = [e for e in events_res.data if e.get("date") and str(e["date"]) >= str(today)]
                past = [e for e in events_res.data if e.get("date") and str(e["date"]) < str(today)]

                st.caption(f"{len(upcoming)} upcoming · {len(past)} past")

                for event in events_res.data:
                    regs_res = supabase.table("registrations").select("id, registration_status").eq("event_id", event["id"]).execute()
                    active_regs = [r for r in (regs_res.data or []) if r["registration_status"] != "cancelled"]
                    total_regs = len(active_regs)
                    attended = len([r for r in active_regs if r["registration_status"] == "attended"])

                    status_kind = event["status"]
                    label = f"{event['title']} — {event['date']}"
                    with st.expander(label):
                        st.markdown(theme.pill(event["status"].title(), status_kind), unsafe_allow_html=True)
                        c1, c2, c3 = st.columns(3)
                        c1.metric("Registrations", total_regs)
                        c2.metric("Attended", attended)
                        c3.metric("Capacity", event.get("capacity") or "Unlimited")

                        st.write(f"**Venue:** {event['venue']} | **Time:** {event['start_time']}")
                        st.write(f"**Registration deadline:** {event.get('registration_deadline') or 'None'}")
                        st.write(f"**Description:** {event['description']}")
                        if event.get("poster_url"):
                            st.image(event["poster_url"], width=220)
            else:
                st.info("You have not created any events yet.")

        # -----------------------------------------------------------------
        # Create event
        # -----------------------------------------------------------------
        with tab_create:
            with st.form("create_event_form"):
                st.write("Submit a new event for Admin approval:")
                title = st.text_input("Event Title*")
                desc = st.text_area("Description")

                cats_res = supabase.table("event_categories").select("name").order("name").execute()
                cat_list = [c["name"] for c in cats_res.data] if cats_res.data else ["General"]
                category = st.selectbox("Category*", cat_list)
                event_type = st.selectbox("Event Type*", ["in_person", "online", "hybrid"], format_func=lambda t: t.replace("_", " ").title())

                col1, col2 = st.columns(2)
                date = col1.date_input("Event Date*", min_value=datetime.date.today())
                time_start = col1.time_input("Start Time*")
                time_end = col2.time_input("End Time")
                venue = col2.text_input("Venue*")

                col3, col4 = st.columns(2)
                capacity = col3.number_input("Capacity (0 for unlimited)", min_value=0, value=100)
                deadline_date = col4.date_input("Registration Deadline*", value=date, min_value=datetime.date.today())

                col5, col6 = st.columns(2)
                is_paid = col5.checkbox("Is a Paid Event?")
                fee = col6.number_input("Fee Amount (if paid)", min_value=0.0, value=0.0)

                poster_file = st.file_uploader("Event Poster (Optional)", type=["png", "jpg", "jpeg", "webp"])

                submitted_evt = st.form_submit_button("Submit Event", type="primary")

            if submitted_evt:
                if not (title and date and venue):
                    st.error("Please fill all required (*) fields.")
                elif time_end and time_end <= time_start:
                    st.error("End time must be after the start time.")
                else:
                    poster_url = None
                    try:
                        poster_url = upload_image(supabase, "posters", poster_file)
                    except Exception as e:
                        st.warning(f"Poster upload skipped (storage error: {e}).")

                    candidate = {
                        "date": str(date), "start_time": str(time_start),
                        "end_time": str(time_end) if time_end else None, "venue": venue,
                    }
                    conflict = analyze_conflict(candidate)

                    supabase.table("events").insert({
                        "society_id": society["id"], "title": title, "description": desc,
                        "category": category, "event_type": event_type,
                        "date": str(date), "start_time": str(time_start),
                        "end_time": str(time_end) if time_end else None,
                        "venue": venue, "capacity": capacity if capacity > 0 else None,
                        "is_paid": is_paid, "fee": fee if is_paid else 0.0,
                        "registration_deadline": datetime.datetime.combine(deadline_date, datetime.time(23, 59)).isoformat(),
                        "status": "pending", "poster_url": poster_url,
                        "conflict_flag": conflict["flagged"], "conflict_note": conflict["note"],
                    }).execute()

                    st.success("Event submitted successfully! It is now pending Admin approval.")
                    if conflict["flagged"]:
                        st.warning(f"Heads up — a possible scheduling conflict was detected: {conflict['note']}")

        # -----------------------------------------------------------------
        # Scan QR attendance
        # -----------------------------------------------------------------
        with tab_scan:
            st.write("Scan a student's QR code (or manually enter the token) to mark attendance.")
            token_input = st.text_input("QR Token", placeholder="e.g. 5d5a2b1f-...")

            if st.button("Validate & Mark Attendance", type="primary"):
                if not token_input:
                    st.error("Please enter a token.")
                else:
                    reg = supabase.table("registrations").select("*, events(society_id, title)").eq("qr_token", token_input.strip()).execute()
                    if not reg.data:
                        st.error("❌ Invalid QR Token. Registration not found.")
                    else:
                        r_data = reg.data[0]
                        if (r_data.get("events") or {}).get("society_id") != society["id"]:
                            st.error("❌ This QR token is for an event hosted by a different society.")
                        elif r_data["registration_status"] == "cancelled":
                            st.error("❌ This registration was cancelled by the student.")
                        else:
                            att_check = supabase.table("attendance").select("id").eq("registration_id", r_data["id"]).execute()
                            if att_check.data:
                                st.warning("⚠️ Duplicate Scan! This student has already been marked as attended.")
                            else:
                                supabase.table("attendance").insert({"registration_id": r_data["id"]}).execute()
                                supabase.table("registrations").update({"registration_status": "attended"}).eq("id", r_data["id"]).execute()
                                st.success(f"✅ Attendance recorded for {(r_data.get('events') or {}).get('title', 'event')}!")

        # -----------------------------------------------------------------
        # Society profile editor
        # -----------------------------------------------------------------
        with tab_profile:
            with st.form("edit_society_form"):
                edit_desc = st.text_area("Description", value=society.get("description", ""))
                edit_dept = st.text_input("Department", value=society.get("department") or "")
                c1, c2 = st.columns(2)
                edit_email = c1.text_input("Contact Email", value=society.get("contact_email") or "")
                edit_phone = c2.text_input("Contact Phone", value=society.get("contact_phone") or "")
                new_logo = st.file_uploader("Update Logo", type=["png", "jpg", "jpeg", "webp"])
                save_profile = st.form_submit_button("Save Changes", type="primary")

            if save_profile:
                update_payload = {
                    "description": edit_desc, "department": edit_dept,
                    "contact_email": edit_email or None, "contact_phone": edit_phone or None,
                }
                if new_logo is not None:
                    try:
                        update_payload["logo_url"] = upload_image(supabase, "logos", new_logo)
                    except Exception as e:
                        st.warning(f"Logo upload skipped (storage error: {e}).")
                supabase.table("societies").update(update_payload).eq("id", society["id"]).execute()
                st.success("Society profile updated.")
                st.rerun()

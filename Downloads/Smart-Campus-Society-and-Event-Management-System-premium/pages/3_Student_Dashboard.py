import datetime
import uuid
import streamlit as st
from utils.db import require_role, sign_out
from utils.qr_ops import get_qr_base64
from utils.ai_recs import get_recommendations
from utils import theme

st.set_page_config(page_title="Student Dashboard", page_icon="🎓", layout="wide")
theme.inject(hide_sidebar_nav=True)

user_id, supabase, profile = require_role("student")

with st.sidebar:
    st.markdown(f"### 👋 {profile.get('name', 'Student')}")
    st.caption(profile.get("email", ""))
    with st.expander("Edit profile"):
        with st.form("edit_profile_form"):
            dept = st.text_input("Department", value=profile.get("department") or "")
            interests = st.text_input("Interests (comma separated)", value=profile.get("interests") or "")
            if st.form_submit_button("Save", use_container_width=True):
                supabase.table("profiles").update({"department": dept, "interests": interests}).eq("id", user_id).execute()
                st.success("Profile updated.")
                st.rerun()
    if st.button("Log Out", type="primary", use_container_width=True):
        sign_out(supabase)
        st.switch_page("app.py")

theme.hero("Student Dashboard", "Discover verified events, manage registrations, and get AI picks made for you.", "🎓")

now = datetime.datetime.now()
today = now.date()

regs_call = supabase.table("registrations").select("*").eq("student_id", user_id).execute()
my_regs_by_event = {r["event_id"]: r for r in (regs_call.data or [])}

tab1, tab2, tab3 = st.tabs(["🔎 Discover Events", "🎟️ My Registrations", "✨ AI Recommendations"])

# ---------------------------------------------------------------------
# Discover events
# ---------------------------------------------------------------------
with tab1:
    st.subheader("Discover Campus Events")

    fc1, fc2, fc3, fc4 = st.columns([2, 1, 1, 1])
    search_q = fc1.text_input("Search by title, society, or category...", "")
    cats_res = supabase.table("event_categories").select("name").order("name").execute()
    cat_options = ["All"] + ([c["name"] for c in cats_res.data] if cats_res.data else [])
    cat_filter = fc2.selectbox("Category", cat_options)
    fee_filter = fc3.selectbox("Fee", ["All", "Free", "Paid"])
    type_filter = fc4.selectbox("Type", ["All", "In Person", "Online", "Hybrid"])

    events_res = (
        supabase.table("events").select("*, societies(name, department)")
        .eq("status", "approved").gte("date", str(today)).order("date").execute()
    )

    shown = 0
    if events_res.data:
        for event in events_res.data:
            society = event.get("societies") or {}
            society_name = society.get("name", "Unknown Society")

            q = search_q.lower().strip()
            if q and q not in event["title"].lower() and q not in society_name.lower() and q not in (event.get("category") or "").lower():
                continue
            if cat_filter != "All" and event.get("category") != cat_filter:
                continue
            if fee_filter == "Free" and event.get("is_paid"):
                continue
            if fee_filter == "Paid" and not event.get("is_paid"):
                continue
            if type_filter != "All" and event.get("event_type", "in_person") != type_filter.lower().replace(" ", "_"):
                continue

            shown += 1
            cap_res = supabase.table("registrations").select("registration_status").eq("event_id", event["id"]).execute()
            active_count = len([r for r in (cap_res.data or []) if r["registration_status"] != "cancelled"])
            capacity = event.get("capacity")
            spots_left = (capacity - active_count) if capacity else None

            deadline = event.get("registration_deadline")
            deadline_passed = bool(deadline) and datetime.datetime.fromisoformat(deadline.replace("Z", "+00:00")).replace(tzinfo=None) < now

            existing = my_regs_by_event.get(event["id"])
            is_active_reg = existing and existing["registration_status"] != "cancelled"

            with st.container(border=True):
                has_poster = bool(event.get("poster_url"))
                if has_poster:
                    poster_col, text_col = st.columns([1, 4])
                    poster_col.image(event["poster_url"], use_container_width=True)
                else:
                    text_col = st.container()

                with text_col:
                    row1, row2 = st.columns([3, 1])
                    with row1:
                        st.markdown(f"### {event['title']}")
                        st.markdown(f"**By:** {society_name} | **Category:** {event['category']} | **Type:** {event.get('event_type', 'in_person').replace('_', ' ').title()}")
                        st.markdown(f"📅 {event['date']} at {event['start_time']} | 📍 {event['venue']}")
                        fee_label = f"${event.get('fee', 0)}" if event.get("is_paid") else "Free"
                        spots_label = spots_left if spots_left is not None else "Unlimited"
                        st.markdown(f"**Fee:** {fee_label} | **Spots left:** {spots_label} | **Deadline:** {deadline[:10] if deadline else 'None'}")
                        st.write(event.get("description") or "")

                    with row2:
                        st.markdown("<br>", unsafe_allow_html=True)
                        if is_active_reg:
                            label = "Attended" if existing["registration_status"] == "attended" else "Registered"
                            st.markdown(theme.pill(f"✅ {label}", existing["registration_status"]), unsafe_allow_html=True)
                        elif deadline_passed:
                            st.markdown(theme.pill("Registration Closed", "rejected"), unsafe_allow_html=True)
                        elif capacity and active_count >= capacity:
                            st.markdown(theme.pill("Sold Out", "rejected"), unsafe_allow_html=True)
                        else:
                            with st.popover("Register Now"):
                                st.write(f"Confirm registration for **{event['title']}**")
                                if event.get("is_paid"):
                                    st.info(f"💳 This event costs ${event.get('fee', 0)} (simulated payment).")
                                    st.text_input("Card Number", "4242 4242 4242 4242", type="password", key=f"card_{event['id']}")
                                    pc1, pc2 = st.columns(2)
                                    pay_ok = pc1.button("Pay & Confirm", key=f"pay_{event['id']}", type="primary", use_container_width=True)
                                    pay_fail = pc2.button("Simulate Decline", key=f"fail_{event['id']}", use_container_width=True)
                                    if pay_fail:
                                        st.error("❌ Payment declined (simulated). Please try again.")
                                    if pay_ok:
                                        payment_status = "paid"
                                    else:
                                        payment_status = None
                                else:
                                    confirm = st.button("Confirm Registration", key=f"confirm_{event['id']}", type="primary", use_container_width=True)
                                    payment_status = "unpaid" if confirm else None

                                if payment_status:
                                    qr_token = str(uuid.uuid4())
                                    cancelled_row = existing  # a previously-cancelled row for this student+event
                                    if cancelled_row:
                                        supabase.table("registrations").update({
                                            "registration_status": "confirmed",
                                            "payment_status": payment_status,
                                            "qr_token": qr_token,
                                        }).eq("id", cancelled_row["id"]).execute()
                                    else:
                                        supabase.table("registrations").insert({
                                            "event_id": event["id"], "student_id": user_id,
                                            "payment_status": payment_status, "registration_status": "confirmed",
                                            "qr_token": qr_token,
                                        }).execute()
                                    st.success("🎉 Registration Successful!")
                                    st.rerun()

    if shown == 0:
        st.info("No events match your filters right now.")

# ---------------------------------------------------------------------
# My registrations
# ---------------------------------------------------------------------
with tab2:
    st.subheader("My Registrations & QR Codes")
    my_regs = supabase.table("registrations").select("*, events(*)").eq("student_id", user_id).order("registered_at", desc=True).execute()

    if my_regs.data:
        for r in my_regs.data:
            e = r.get("events")
            if not e:
                continue

            with st.container(border=True):
                c1, c2 = st.columns([3, 1])
                with c1:
                    st.markdown(f"**{e['title']}**")
                    st.markdown(theme.pill(r["registration_status"].title(), r["registration_status"]), unsafe_allow_html=True)
                    st.write(f"📅 {e['date']} | 📍 {e['venue']}")
                    st.write(f"Payment: {r['payment_status'].title()}")
                    st.caption(f"Registration ID: REG-{r['id'][:8].upper()}")

                    if r["registration_status"] == "confirmed":
                        is_past = str(e.get("date", "")) < str(today)
                        if not is_past and st.button("Cancel Registration", key=f"cancel_{r['id']}"):
                            supabase.table("registrations").update({"registration_status": "cancelled"}).eq("id", r["id"]).execute()
                            st.warning("Registration cancelled.")
                            st.rerun()

                with c2:
                    if r["registration_status"] != "cancelled":
                        qr_b64 = get_qr_base64(r["qr_token"])
                        st.markdown(f'<img src="{qr_b64}" width="150">', unsafe_allow_html=True)
                        st.caption("Show this at the venue entrance.")
    else:
        st.info("You haven't registered for any events yet.")

# ---------------------------------------------------------------------
# AI recommendations
# ---------------------------------------------------------------------
with tab3:
    st.subheader("✨ AI Recommended Events for You")
    st.caption("Gemini looks at your department, interests, and past events to suggest what's next.")
    if st.button("Generate Recommendations", type="primary"):
        with st.spinner("Analyzing your profile and scanning campus events..."):
            recs = get_recommendations(user_id)
            st.markdown(recs)

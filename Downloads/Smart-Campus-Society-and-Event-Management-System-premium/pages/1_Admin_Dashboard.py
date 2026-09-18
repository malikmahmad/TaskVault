import streamlit as st
import pandas as pd
from utils.db import require_role, sign_out
from utils import theme
from utils.ai_conflict import analyze_conflict

st.set_page_config(page_title="Admin Dashboard", page_icon="⚙️", layout="wide")
theme.inject(hide_sidebar_nav=True)

user_id, supabase, profile = require_role("admin")

with st.sidebar:
    st.markdown(f"### 👋 {profile.get('name', 'Admin')}")
    st.caption(profile.get("email", ""))
    if st.button("Log Out", type="primary", use_container_width=True):
        sign_out(supabase)
        st.switch_page("app.py")

theme.hero("Admin Control Center", "Manage societies, verify events, and monitor the whole platform.", "⚙️")

tab_overview, tab_soc_approvals, tab_evt_approvals, tab_browse = st.tabs(
    ["📊 Overview", "🏢 Pending Societies", "✔️ Pending Events", "🗂️ Browse Everything"]
)

# ---------------------------------------------------------------------
# Overview
# ---------------------------------------------------------------------
with tab_overview:
    stu_res = supabase.table("profiles").select("id", count="exact").eq("role", "student").execute()
    soc_res = supabase.table("societies").select("id", count="exact").execute()
    evt_res = supabase.table("events").select("id", count="exact").execute()
    pending_evt_res = supabase.table("events").select("id", count="exact").eq("status", "pending").execute()
    reg_total = supabase.table("registrations").select("id", count="exact").execute()
    att_total = supabase.table("attendance").select("id", count="exact").execute()

    c1, c2, c3, c4, c5, c6 = st.columns(6)
    c1.metric("Students", stu_res.count or 0)
    c2.metric("Societies", soc_res.count or 0)
    c3.metric("Events", evt_res.count or 0)
    c4.metric("Pending Events", pending_evt_res.count or 0)
    c5.metric("Registrations", reg_total.count or 0)
    c6.metric("Attendance", att_total.count or 0)

    st.divider()
    col_left, col_right = st.columns(2)

    with col_left:
        st.subheader("Event Categories")
        all_events = supabase.table("events").select("category").execute()
        if all_events.data:
            df = pd.DataFrame(all_events.data)
            st.bar_chart(df["category"].value_counts())
        else:
            st.info("No events yet.")

    with col_right:
        st.subheader("Event Status Mix")
        status_events = supabase.table("events").select("status").execute()
        if status_events.data:
            df2 = pd.DataFrame(status_events.data)
            st.bar_chart(df2["status"].value_counts())
        else:
            st.info("No events yet.")

# ---------------------------------------------------------------------
# Pending societies
# ---------------------------------------------------------------------
with tab_soc_approvals:
    st.subheader("Pending Society Registrations")
    pending_soc = supabase.table("societies").select("*, profiles(name, email)").eq("status", "pending").order("created_at").execute()

    if pending_soc.data:
        for soc in pending_soc.data:
            head = soc.get("profiles") or {}
            with st.container(border=True):
                colA, colB = st.columns([4, 1])
                with colA:
                    st.markdown(f"### {soc['name']}")
                    st.markdown(f"**Requested by:** {head.get('name', 'Unknown')} ({head.get('email', 'n/a')})  \n**Department:** {soc.get('department') or 'N/A'}")
                    st.write(soc.get("description") or "No description provided.")
                with colB:
                    st.markdown("<br>", unsafe_allow_html=True)
                    if st.button("✅ Approve", key=f"app_soc_{soc['id']}", use_container_width=True):
                        supabase.table("societies").update({"status": "active"}).eq("id", soc["id"]).execute()
                        st.success("Society Approved!")
                        st.rerun()
                    if st.button("❌ Reject", key=f"rej_soc_{soc['id']}", use_container_width=True):
                        supabase.table("societies").update({"status": "rejected"}).eq("id", soc["id"]).execute()
                        st.error("Society Rejected.")
                        st.rerun()
    else:
        st.info("No pending societies to review at the moment.")

# ---------------------------------------------------------------------
# Pending events (with conflict flagging)
# ---------------------------------------------------------------------
with tab_evt_approvals:
    st.subheader("Pending Events")
    pending_res = supabase.table("events").select("*, societies(name)").eq("status", "pending").order("created_at").execute()

    if pending_res.data:
        for event in pending_res.data:
            society_name = (event.get("societies") or {}).get("name", "Unknown Society")
            with st.container(border=True):
                colA, colB = st.columns([4, 1])
                with colA:
                    st.markdown(f"### {event['title']}")
                    st.markdown(
                        f"**Hosted by:** {society_name} | **Category:** {event['category']} | **Type:** {event.get('event_type', 'in_person').replace('_', ' ').title()}"
                    )
                    st.markdown(f"**Date:** {event['date']} at {event['start_time']} | **Venue:** {event['venue']}")
                    st.markdown(
                        f"**Capacity:** {event.get('capacity') or 'Unlimited'} | "
                        f"**Fee:** {'$' + str(event.get('fee', 0)) if event.get('is_paid') else 'Free'} | "
                        f"**Deadline:** {event.get('registration_deadline') or 'None set'}"
                    )
                    st.write(event.get("description") or "No description provided.")

                    conflict = analyze_conflict(event, exclude_event_id=event["id"])
                    if conflict["flagged"]:
                        st.markdown(theme.pill("Scheduling Conflict", "conflict"), unsafe_allow_html=True)
                        st.warning(conflict["note"])

                with colB:
                    st.markdown("<br>", unsafe_allow_html=True)
                    if st.button("✅ Approve Event", key=f"app_evt_{event['id']}", use_container_width=True):
                        supabase.table("events").update({"status": "approved"}).eq("id", event["id"]).execute()
                        st.success("Event Approved!")
                        st.rerun()
                    if st.button("❌ Reject", key=f"rej_evt_{event['id']}", use_container_width=True):
                        supabase.table("events").update({"status": "rejected"}).eq("id", event["id"]).execute()
                        st.error("Event Rejected.")
                        st.rerun()
    else:
        st.info("No pending events to review at the moment.")

# ---------------------------------------------------------------------
# Browse everything
# ---------------------------------------------------------------------
with tab_browse:
    sub_soc, sub_stu, sub_evt, sub_reg = st.tabs(["Societies", "Students", "Events", "Registrations & Attendance"])

    with sub_soc:
        socs = supabase.table("societies").select("*, profiles(name, email)").order("created_at", desc=True).execute()
        if socs.data:
            rows = [{
                "Name": s["name"],
                "Status": s["status"],
                "Department": s.get("department") or "-",
                "Head": (s.get("profiles") or {}).get("name", "-"),
                "Head Email": (s.get("profiles") or {}).get("email", "-"),
            } for s in socs.data]
            st.dataframe(pd.DataFrame(rows), use_container_width=True, hide_index=True)
        else:
            st.info("No societies yet.")

    with sub_stu:
        students = supabase.table("profiles").select("*").eq("role", "student").order("created_at", desc=True).execute()
        if students.data:
            rows = [{
                "Name": s["name"], "Email": s.get("email"),
                "Department": s.get("department") or "-",
                "Interests": s.get("interests") or "-",
            } for s in students.data]
            st.dataframe(pd.DataFrame(rows), use_container_width=True, hide_index=True)
        else:
            st.info("No students yet.")

    with sub_evt:
        events = supabase.table("events").select("*, societies(name)").order("created_at", desc=True).execute()
        if events.data:
            rows = [{
                "Title": e["title"], "Society": (e.get("societies") or {}).get("name", "-"),
                "Status": e["status"], "Category": e["category"], "Date": e["date"],
                "Venue": e["venue"], "Capacity": e.get("capacity") or "Unlimited",
                "Paid": "Yes" if e.get("is_paid") else "No",
            } for e in events.data]
            st.dataframe(pd.DataFrame(rows), use_container_width=True, hide_index=True)
        else:
            st.info("No events yet.")

    with sub_reg:
        regs = supabase.table("registrations").select("*, events(title), profiles(name, email)").order("registered_at", desc=True).execute()
        if regs.data:
            rows = [{
                "Event": (r.get("events") or {}).get("title", "-"),
                "Student": (r.get("profiles") or {}).get("name", "-"),
                "Status": r["registration_status"], "Payment": r["payment_status"],
                "Registered At": r.get("registered_at"),
            } for r in regs.data]
            st.dataframe(pd.DataFrame(rows), use_container_width=True, hide_index=True)
        else:
            st.info("No registrations yet.")

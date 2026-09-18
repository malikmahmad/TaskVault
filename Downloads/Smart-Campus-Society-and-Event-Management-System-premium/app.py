import streamlit as st
from utils.db import get_supabase, get_profile, sign_out
from utils import theme

st.set_page_config(
    page_title="Smart Campus Events",
    page_icon="🎓",
    layout="centered",
    initial_sidebar_state="collapsed",
)

theme.inject(hide_sidebar_nav=True)


def route_to_dashboard(role: str) -> None:
    if role == "admin":
        st.switch_page("pages/1_Admin_Dashboard.py")
    elif role == "society_head":
        st.switch_page("pages/2_Society_Dashboard.py")
    else:
        st.switch_page("pages/3_Student_Dashboard.py")


def main():
    supabase = get_supabase()

    if "user" not in st.session_state:
        st.session_state.user = None

    if st.session_state.user is not None:
        profile = get_profile(supabase, st.session_state.user.id)
        if profile:
            st.session_state.role = profile.get("role", "student")
            route_to_dashboard(st.session_state.role)
            return
        else:
            st.error("Could not find a profile for this account.")
            if st.button("Log out"):
                sign_out(supabase)
                st.rerun()
            return

    theme.hero(
        "Smart Campus Society & Event Management",
        "One verified place to discover, register for, and attend every society event on campus.",
    )

    tabs = st.tabs(["🔐 Log In", "✨ Sign Up", "🔑 Forgot Password"])

    with tabs[0]:
        with st.form("login_form"):
            email = st.text_input("Email")
            password = st.text_input("Password", type="password")
            submitted = st.form_submit_button("Log In", type="primary", use_container_width=True)

        if submitted:
            if not email or not password:
                st.error("Please enter both email and password.")
            else:
                try:
                    res = supabase.auth.sign_in_with_password({"email": email, "password": password})
                    st.session_state.user = res.user
                    st.success("Successfully logged in!")
                    st.rerun()
                except Exception as e:
                    st.error(f"Login failed: {e}")

    with tabs[1]:
        st.caption(
            "New accounts are created as **Student** or **Society Head**. "
            "Admin access is granted manually by the platform owner for security."
        )
        with st.form("signup_form"):
            new_name = st.text_input("Full Name")
            new_email = st.text_input("Email", key="signup_email")
            new_password = st.text_input("Password", type="password", key="signup_password")
            role = st.selectbox("I am a...", ["student", "society_head"], format_func=lambda r: "Student" if r == "student" else "Society Head")
            department = st.text_input("Department (optional)")
            submitted_signup = st.form_submit_button("Create Account", type="primary", use_container_width=True)

        if submitted_signup:
            if not new_name or not new_email or not new_password:
                st.error("Please fill in your name, email, and password.")
            else:
                try:
                    res = supabase.auth.sign_up({
                        "email": new_email,
                        "password": new_password,
                        "options": {"data": {"name": new_name, "role": role}},
                    })

                    if getattr(res, "user", None):
                        # Upsert to make sure name/department land correctly even
                        # though the DB trigger already created the base row.
                        supabase.table("profiles").upsert({
                            "id": res.user.id,
                            "email": new_email,
                            "name": new_name,
                            "role": role,
                            "department": department or None,
                        }).execute()

                    st.success("Account created! Check your email to confirm, then log in.")
                except Exception as e:
                    st.error(f"Registration failed: {e}")

    with tabs[2]:
        st.caption("We'll email you a link to reset your password.")
        with st.form("reset_form"):
            reset_email = st.text_input("Account email", key="reset_email")
            reset_submitted = st.form_submit_button("Send Reset Link", use_container_width=True)

        if reset_submitted:
            if not reset_email:
                st.error("Please enter your account email.")
            else:
                try:
                    supabase.auth.reset_password_email(reset_email)
                    st.success("If that email is registered, a reset link is on its way.")
                except Exception as e:
                    st.error(f"Could not send reset email: {e}")

    st.divider()
    c1, c2, c3 = st.columns(3)
    c1.markdown("**✅ Verified events**\n\nOnly admin-approved events go public.")
    c2.markdown("**🎫 Instant QR tickets**\n\nOne tap registration, one scan check-in.")
    c3.markdown("**✨ AI recommendations**\n\nGemini suggests events matched to you.")


if __name__ == "__main__":
    main()

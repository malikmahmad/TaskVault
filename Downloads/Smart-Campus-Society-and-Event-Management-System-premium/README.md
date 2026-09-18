# 🎓 Smart Campus Society & Event Management System

**Hackathon MVP — v2.0 (Premium / Security-hardened build)**

A centralized digital platform where university societies manage events and students discover,
register for, and attend verified campus events from one place — no more scattered WhatsApp
groups and social pages.

## ✨ Core Features
- **🏢 Role-based dashboards** for Students, Society Heads, and Admins.
- **✅ Two-stage verification**: Admin approves both new societies and every event before it goes public.
- **🎫 Smart registration**: live capacity limits, registration deadlines, free & simulated-paid flows (pay / decline), duplicate-registration protection, and self-service cancellation.
- **📷 QR attendance**: unique, single-use QR tokens scanned at the door; registration status flips to *Attended* automatically.
- **🖼️ Posters & logos**: society heads upload an event poster and a society logo (Supabase Storage).
- **🤖 AI event recommendations** — Gemini 1.5 Flash reads a student's department, interests, and past events to suggest 2–3 upcoming events.
- **⚠️ AI venue/schedule conflict flagging** — a deterministic venue+time overlap check (always correct) layered with a Gemini-written explanation, shown to the society head at creation time and to the admin at approval time.
- **🔒 Row Level Security** on every table, so the rules in the PRD ("students can't touch other students' registrations," "society heads can't touch other societies' events") are enforced by the database itself — not just by app code.

## 🛠 Tech Stack
- **Frontend & app engine:** Python 3 & Streamlit
- **Backend:** Supabase (PostgreSQL + Auth + Storage), fully row-level-secured
- **AI:** Google Gemini API
- **Utilities:** `qrcode`, `python-dotenv`, `pandas`

## 🚀 Local Installation

**1. Clone and install:**
```bash
git clone <your-fork-url>
cd Smart-Campus-Society-and-Event-Management-System
pip install -r requirements.txt
```

**2. Environment:**
Copy `.env.example` to `.env` and fill in your keys:
```env
SUPABASE_URL="your_supabase_project_url"
SUPABASE_KEY="your_supabase_anon_key"
GEMINI_API_KEY="your_gemini_api_key"
```

**3. Database:**
Run the entire `supabase_schema.sql` file in your Supabase project's SQL Editor. It creates all
tables, indexes, RLS policies, anti-tamper triggers, storage buckets, and seed categories.

**4. Create your first Admin.**
For security, **nobody can self-register as Admin** — the signup form only offers Student /
Society Head. Sign up normally as a student with the account you want to use for Admin, then in
the Supabase SQL Editor run:
```sql
update profiles set role = 'admin' where email = 'you@example.com';
```

**5. Run it:**
```bash
python -m streamlit run app.py
```

## 💡 Demo Script
1. Log in as **Society Head** → create a society → wait for admin approval.
2. Log in as **Admin** → approve the society → approve its first event (watch for a conflict
   warning if you deliberately double-book a venue/time).
3. Log in as **Student** → browse/search/filter events → register (try both a free and a paid
   event, and try the "Simulate Decline" button on a paid one) → view your QR code.
4. Log back in as **Society Head** → *Scan QR Attendance* → paste the token → attendance is
   recorded and the registration flips to *Attended*.
5. Scan the same token again → see the duplicate-scan guard.
6. As the student, open **AI Recommendations** to see Gemini's picks.

## 🔐 What changed from v1.0 (security & correctness audit)
- Closed the self-signup-as-admin hole.
- Added Row Level Security + anti-tamper triggers on every table (role/status columns can no
  longer be edited directly by a normal user, even via a crafted API call).
- Fixed a cross-user session leak: the Supabase client was previously cached globally
  (`@st.cache_resource`), so every visitor shared one authenticated session. It's now scoped per
  browser session.
- Fixed a crash on any paid event (`event.fee` → `event['fee']`).
- Added a unique constraint so a student can't double-register for the same event.
- Registration status now actually transitions to `attended` on scan, and cancellation is
  supported (`confirmed → cancelled → re-register` cleanly re-uses the same row).
- Added registration deadlines, event posters, society logos/contact info, event type, search
  filters (category / fee / type), and admin "browse everything" tables — all called for in the
  PRD but missing from v1.0.
- Added the AI venue/schedule conflict resolver (optional PRD feature).
- Added password reset.

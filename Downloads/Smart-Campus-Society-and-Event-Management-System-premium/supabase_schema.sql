-- =====================================================================
-- Smart Campus Society & Event Management System
-- Database schema v2 — adds Row Level Security, anti-tamper triggers,
-- missing PRD fields, storage buckets, and integrity constraints.
--
-- Safe to run on a fresh Supabase project. Run the whole file once in
-- the Supabase SQL Editor.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. TABLES
-- ---------------------------------------------------------------------

create table if not exists profiles (
  id uuid references auth.users(id) on delete cascade primary key,
  name text not null,
  email text,
  role text check (role in ('student', 'society_head', 'admin')) default 'student',
  department text,
  interests text,                    -- comma separated, simple TEXT for MVP
  created_at timestamptz default timezone('utc'::text, now())
);

create table if not exists societies (
  id uuid default gen_random_uuid() primary key,
  name text not null,
  description text,
  department text,
  head_id uuid references profiles(id) on delete set null,
  logo_url text,
  contact_email text,
  contact_phone text,
  status text check (status in ('pending', 'active', 'rejected')) default 'pending',
  created_at timestamptz default timezone('utc'::text, now())
);

create table if not exists event_categories (
  id uuid default gen_random_uuid() primary key,
  name text not null unique
);

create table if not exists events (
  id uuid default gen_random_uuid() primary key,
  society_id uuid references societies(id) on delete cascade,
  title text not null,
  description text,
  category text,
  event_type text check (event_type in ('in_person', 'online', 'hybrid')) default 'in_person',
  date date not null,
  start_time time not null,
  end_time time,
  venue text,
  capacity integer,
  fee numeric default 0,
  is_paid boolean default false,
  registration_deadline timestamptz,
  status text check (status in ('pending', 'approved', 'rejected')) default 'pending',
  poster_url text,
  conflict_flag boolean default false,
  conflict_note text,
  created_at timestamptz default timezone('utc'::text, now())
);

create table if not exists registrations (
  id uuid default gen_random_uuid() primary key,
  event_id uuid references events(id) on delete cascade,
  student_id uuid references profiles(id) on delete cascade,
  payment_status text check (payment_status in ('unpaid', 'pending', 'paid', 'failed')) default 'unpaid',
  registration_status text check (registration_status in ('confirmed', 'cancelled', 'attended')) default 'confirmed',
  qr_token text unique,
  registered_at timestamptz default timezone('utc'::text, now()),
  constraint uniq_student_event unique (event_id, student_id)
);

create table if not exists attendance (
  id uuid default gen_random_uuid() primary key,
  registration_id uuid references registrations(id) on delete cascade unique,
  status text default 'attended',
  scanned_at timestamptz default timezone('utc'::text, now())
);

create index if not exists idx_events_status on events(status);
create index if not exists idx_events_society on events(society_id);
create index if not exists idx_registrations_event on registrations(event_id);
create index if not exists idx_registrations_student on registrations(student_id);

insert into event_categories (name) values
  ('Technology'), ('Science'), ('Arts'), ('Sports'),
  ('Business'), ('Cultural'), ('Career'), ('Academic'),
  ('Social'), ('Competition'), ('Workshop'), ('General')
on conflict (name) do nothing;

-- ---------------------------------------------------------------------
-- 2. NEW-USER TRIGGER
-- Only 'student' and 'society_head' can be granted at signup — 'admin'
-- is intentionally excluded here. Promote a trusted user to admin
-- manually afterwards (see bottom of this file).
-- ---------------------------------------------------------------------

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
declare
  requested_role text;
begin
  requested_role := coalesce(new.raw_user_meta_data->>'role', 'student');
  if requested_role not in ('student', 'society_head') then
    requested_role := 'student';
  end if;

  insert into public.profiles (id, email, name, role)
  values (new.id, new.email, coalesce(new.raw_user_meta_data->>'name', 'New User'), requested_role)
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- ---------------------------------------------------------------------
-- 3. SECURITY-DEFINER HELPER FUNCTIONS
-- These read `profiles`/`societies` with elevated rights so RLS
-- policies elsewhere can call them without recursive-policy issues.
-- ---------------------------------------------------------------------

create or replace function public.current_role()
returns text
language sql security definer set search_path = public stable
as $$
  select role from public.profiles where id = auth.uid();
$$;

create or replace function public.is_admin()
returns boolean
language sql security definer set search_path = public stable
as $$
  select coalesce((select role = 'admin' from public.profiles where id = auth.uid()), false);
$$;

create or replace function public.owns_society(soc_id uuid)
returns boolean
language sql security definer set search_path = public stable
as $$
  select exists(select 1 from public.societies where id = soc_id and head_id = auth.uid());
$$;

create or replace function public.owns_event(evt_id uuid)
returns boolean
language sql security definer set search_path = public stable
as $$
  select exists(
    select 1 from public.events e
    join public.societies s on s.id = e.society_id
    where e.id = evt_id and s.head_id = auth.uid()
  );
$$;

create or replace function public.owns_registration_event(reg_id uuid)
returns boolean
language sql security definer set search_path = public stable
as $$
  select exists(
    select 1 from public.registrations r
    join public.events e on e.id = r.event_id
    join public.societies s on s.id = e.society_id
    where r.id = reg_id and s.head_id = auth.uid()
  );
$$;

-- ---------------------------------------------------------------------
-- 4. ANTI-TAMPER TRIGGERS
-- Prevent a normal user from writing privileged columns directly
-- (role, event/society approval status) even though they have INSERT/
-- UPDATE rights on their own rows.
-- ---------------------------------------------------------------------

create or replace function public.protect_role_column()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.role is distinct from old.role and not public.is_admin() then
    new.role := old.role;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_protect_role on profiles;
create trigger trg_protect_role
  before update on profiles
  for each row execute procedure public.protect_role_column();

create or replace function public.enforce_society_status()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if TG_OP = 'INSERT' then
    if not public.is_admin() then
      new.status := 'pending';
    end if;
  elsif TG_OP = 'UPDATE' then
    if new.status is distinct from old.status and not public.is_admin() then
      new.status := old.status;
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_enforce_society_status on societies;
create trigger trg_enforce_society_status
  before insert or update on societies
  for each row execute procedure public.enforce_society_status();

create or replace function public.enforce_event_status()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if TG_OP = 'INSERT' then
    if not public.is_admin() then
      new.status := 'pending';
    end if;
  elsif TG_OP = 'UPDATE' then
    if new.status is distinct from old.status and not public.is_admin() then
      new.status := old.status;
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_enforce_event_status on events;
create trigger trg_enforce_event_status
  before insert or update on events
  for each row execute procedure public.enforce_event_status();

-- ---------------------------------------------------------------------
-- 5. ROW LEVEL SECURITY
-- ---------------------------------------------------------------------

alter table profiles enable row level security;
alter table societies enable row level security;
alter table event_categories enable row level security;
alter table events enable row level security;
alter table registrations enable row level security;
alter table attendance enable row level security;

-- profiles: users see/edit their own row; admins see everyone
drop policy if exists "profiles_select" on profiles;
create policy "profiles_select" on profiles for select
  using (id = auth.uid() or public.is_admin());

drop policy if exists "profiles_insert" on profiles;
create policy "profiles_insert" on profiles for insert
  with check (id = auth.uid());

drop policy if exists "profiles_update" on profiles;
create policy "profiles_update" on profiles for update
  using (id = auth.uid() or public.is_admin());

-- event_categories: public read, admin write
drop policy if exists "categories_select" on event_categories;
create policy "categories_select" on event_categories for select using (true);

drop policy if exists "categories_write" on event_categories;
create policy "categories_write" on event_categories for all
  using (public.is_admin()) with check (public.is_admin());

-- societies: active ones are public; owners/admins see their own regardless of status
drop policy if exists "societies_select" on societies;
create policy "societies_select" on societies for select
  using (status = 'active' or head_id = auth.uid() or public.is_admin());

drop policy if exists "societies_insert" on societies;
create policy "societies_insert" on societies for insert
  with check (head_id = auth.uid() and public.current_role() = 'society_head');

drop policy if exists "societies_update" on societies;
create policy "societies_update" on societies for update
  using (head_id = auth.uid() or public.is_admin());

-- events: approved ones are public; owning society head + admin see all statuses
drop policy if exists "events_select" on events;
create policy "events_select" on events for select
  using (status = 'approved' or public.owns_society(society_id) or public.is_admin());

drop policy if exists "events_insert" on events;
create policy "events_insert" on events for insert
  with check (public.owns_society(society_id));

drop policy if exists "events_update" on events;
create policy "events_update" on events for update
  using (public.owns_society(society_id) or public.is_admin());

-- registrations: student sees/creates their own; society head sees regs for
-- their events (for the scan/roster view); admin sees all
drop policy if exists "registrations_select" on registrations;
create policy "registrations_select" on registrations for select
  using (
    student_id = auth.uid()
    or public.owns_event(event_id)
    or public.is_admin()
  );

drop policy if exists "registrations_insert" on registrations;
create policy "registrations_insert" on registrations for insert
  with check (student_id = auth.uid());

drop policy if exists "registrations_update" on registrations;
create policy "registrations_update" on registrations for update
  using (
    student_id = auth.uid()            -- student cancelling their own reg
    or public.owns_event(event_id)     -- society head marking attended
    or public.is_admin()
  );

-- attendance: visible/writable by the hosting society head + admin only
drop policy if exists "attendance_select" on attendance;
create policy "attendance_select" on attendance for select
  using (public.owns_registration_event(registration_id) or public.is_admin());

drop policy if exists "attendance_insert" on attendance;
create policy "attendance_insert" on attendance for insert
  with check (public.owns_registration_event(registration_id) or public.is_admin());

-- ---------------------------------------------------------------------
-- 6. STORAGE BUCKETS (event posters & society logos)
-- ---------------------------------------------------------------------

insert into storage.buckets (id, name, public)
values ('posters', 'posters', true)
on conflict (id) do nothing;

insert into storage.buckets (id, name, public)
values ('logos', 'logos', true)
on conflict (id) do nothing;

drop policy if exists "public_read_posters" on storage.objects;
create policy "public_read_posters" on storage.objects for select
  using (bucket_id = 'posters');

drop policy if exists "authenticated_upload_posters" on storage.objects;
create policy "authenticated_upload_posters" on storage.objects for insert
  with check (bucket_id = 'posters' and auth.role() = 'authenticated');

drop policy if exists "public_read_logos" on storage.objects;
create policy "public_read_logos" on storage.objects for select
  using (bucket_id = 'logos');

drop policy if exists "authenticated_upload_logos" on storage.objects;
create policy "authenticated_upload_logos" on storage.objects for insert
  with check (bucket_id = 'logos' and auth.role() = 'authenticated');

-- ---------------------------------------------------------------------
-- 7. PROMOTING YOUR FIRST ADMIN
-- Sign up normally as a student, then run this once with your email:
--
--   update profiles set role = 'admin' where email = 'you@example.com';
--
-- (The protect_role_column trigger only blocks role changes made
--  through the app's own client session, not trusted SQL-editor runs
--  authenticated as the Supabase project owner.)
-- ---------------------------------------------------------------------

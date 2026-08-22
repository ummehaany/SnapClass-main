-- SnapClass AI Attendance — database schema
--
-- This creates exactly the tables/columns/relationships that the existing
-- application code in src/database/db.py already expects. Nothing here
-- changes app behavior or architecture — it just makes the tables the
-- code has always assumed exist.
--
-- HOW TO RUN:
--   Supabase dashboard -> your project -> SQL Editor -> New query
--   -> paste this whole file -> Run.
-- Safe to re-run: uses IF NOT EXISTS / DROP POLICY-free design, but if
-- tables already exist with different columns this will NOT alter them —
-- run it once on a fresh project.

-- ── teachers ─────────────────────────────────────────────────────────────
-- Used by: check_teacher_exists, create_teacher, teacher_login
create table if not exists public.teachers (
    teacher_id  bigint generated always as identity primary key,
    username    text not null unique,
    password    text not null,      -- bcrypt hash, written by src/database/db.py:hash_pass
    name        text not null,
    created_at  timestamptz not null default now()
);

-- ── students ─────────────────────────────────────────────────────────────
-- Used by: get_all_students, create_student
-- face_embedding: 128-value list from dlib (src/pipelines/face_pipeline.py)
-- voice_embedding: 256-value list from resemblyzer (src/pipelines/voice_pipeline.py), optional
create table if not exists public.students (
    student_id      bigint generated always as identity primary key,
    name            text not null,
    face_embedding  jsonb,
    voice_embedding jsonb,
    created_at      timestamptz not null default now()
);

-- ── subjects ─────────────────────────────────────────────────────────────
-- Used by: create_subject, get_teacher_subjects
-- subject_code is the human-shareable code used for QR/join links (dialog_share_subject.py, auto_enroll)
create table if not exists public.subjects (
    subject_id    bigint generated always as identity primary key,
    subject_code  text not null unique,
    name          text not null,
    section       text not null,
    teacher_id    bigint not null references public.teachers(teacher_id) on delete cascade,
    created_at    timestamptz not null default now()
);

create index if not exists idx_subjects_teacher_id on public.subjects(teacher_id);

-- ── subject_students (enrollment join table) ────────────────────────────
-- Used by: enroll_student_to_subject, unenroll_student_to_subject,
--          get_student_subjects, and embedded selects like
--          subjects(*, subject_students(count)) / subject_students(*, subjects(*))
create table if not exists public.subject_students (
    id          bigint generated always as identity primary key,
    student_id  bigint not null references public.students(student_id) on delete cascade,
    subject_id  bigint not null references public.subjects(subject_id) on delete cascade,
    created_at  timestamptz not null default now(),
    unique (student_id, subject_id)
);

create index if not exists idx_subject_students_student_id on public.subject_students(student_id);
create index if not exists idx_subject_students_subject_id on public.subject_students(subject_id);

-- ── attendance_logs ──────────────────────────────────────────────────────
-- Used by: create_attendance, get_student_attendance, get_attendance_for_teacher,
--          and embedded selects like subjects(*, attendance_logs(timestamp)),
--          attendance_logs(*, subjects!inner(*))
create table if not exists public.attendance_logs (
    id          bigint generated always as identity primary key,
    student_id  bigint not null references public.students(student_id) on delete cascade,
    subject_id  bigint not null references public.subjects(subject_id) on delete cascade,
    "timestamp" timestamptz not null default now(),
    is_present  boolean not null default false
);

create index if not exists idx_attendance_logs_student_id on public.attendance_logs(student_id);
create index if not exists idx_attendance_logs_subject_id on public.attendance_logs(subject_id);

-- ── Row Level Security ───────────────────────────────────────────────────
-- The app does NOT use Supabase Auth (auth.uid()) — it does its own
-- username/bcrypt login against the teachers table and talks to Postgres
-- directly via the anon/API key. So RLS is left OFF here, matching how the
-- existing code has always queried these tables (no auth headers, no
-- policies referenced anywhere in db.py). This is fine for local
-- development but means anyone with your API key can read/write all rows —
-- do not point a public/production deployment at this schema without adding
-- real RLS policies first.
alter table public.teachers          disable row level security;
alter table public.students          disable row level security;
alter table public.subjects          disable row level security;
alter table public.subject_students  disable row level security;
alter table public.attendance_logs   disable row level security;

-- Force PostgREST to pick up the new tables/relationships immediately
-- instead of waiting for its next automatic schema cache refresh.
notify pgrst, 'reload schema';

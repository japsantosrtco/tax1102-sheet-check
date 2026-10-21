-- Run ONCE in the SQL editor of a new, dedicated Supabase project.
-- No answer key belongs in this table, its policies, or Storage.
begin;
create table public.scans (
  id bigint generated always as identity primary key,
  scan_id uuid not null unique, -- Stable browser-generated ID makes retries idempotent.
  created_at timestamptz not null default now(),
  exam text not null check (exam = 'TX1102MT2627'),
  version_code text not null check (version_code in ('Q7K4', 'R2M8')),
  section text not null check (section ~ '^[0-9?]{2}$'),
  student_no text not null check (student_no ~ '^[0-9?]{10}$'),
  answers text not null check (answers ~ '^[ABCD*-]{70}$'),
  flags jsonb not null default '[]' check (jsonb_typeof(flags) = 'array'),
  key_loaded boolean not null,
  score int check (score between 0 and 70),
  theory_score int check (theory_score between 0 and 40),
  problem_score int check (problem_score between 0 and 30),
  mode text not null check (mode in ('student','professor')),
  device_id text not null check (device_id ~ '^[0-9a-f-]{36}$'),
  app_version text not null check (char_length(app_version) <= 32),
  image_path text not null,
  constraint scoring_consistent check (
    (not key_loaded and score is null and theory_score is null and problem_score is null)
    or (key_loaded and score is not null and theory_score is not null
      and problem_score is not null and score = theory_score + problem_score)
  ),
  constraint image_matches_scan check (
    image_path = exam || '/' || device_id || '/' || scan_id::text || '.jpg'
  )
);
alter table public.scans enable row level security;
revoke all on public.scans from anon, authenticated;
-- SELECT has no policy, so an anon SELECT returns [] and never exposes rows.
grant select, insert on public.scans to anon;
grant usage on sequence public.scans_id_seq to anon;
create policy "scanner insert only" on public.scans for insert to anon
  with check (exam = 'TX1102MT2627' and char_length(answers) = 70);
-- No SELECT, UPDATE or DELETE policies, and no authenticated-user access.
create index scans_section_student_created_idx
  on public.scans (section, student_no, created_at desc);

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('sheets', 'sheets', false, 1048576, array['image/jpeg']);
create policy "scanner images insert only" on storage.objects for insert to anon
  with check (
    bucket_id = 'sheets'
    and name ~ '^TX1102MT2627/[0-9a-f-]{36}/[0-9a-f-]{36}\.jpg$'
  );
-- No Storage SELECT, UPDATE, DELETE policy; uploads always use x-upsert:false.
commit;

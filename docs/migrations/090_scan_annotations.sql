-- =============================================================================
-- 090_scan_annotations.sql  (검토용 초안 — 대표 승인 후 공유 Supabase에 적용)
-- -----------------------------------------------------------------------------
-- 목적: 질문방 "스캔 펜 첨삭"을 저장할 scan_annotations 테이블 + RLS + 전용 버킷.
-- 정렬 기준: 앱 SupabaseScanAnnotationsRepository 가 기대하는 컬럼/경로
--   - 컬럼: mentor_student_room_id, author_id, author_role, annotation_json,
--           scan_image_path, preview_path, has_annotations, created_at
--   - 스토리지 경로: {roomId}/{stamp}-original.jpg, {roomId}/{stamp}-preview.png
-- RLS 본보기: connection_notes(002_p0 / 085) — room 당사자(학생·멘토)만 접근.
-- 적용처: 웹 SQL 소스 정본에도 동일 번호(090)로 보관 권장.
-- 멱등성: create ... if not exists / drop policy if exists / on conflict 사용.
-- =============================================================================

-- 1) 테이블 -------------------------------------------------------------------
create table if not exists public.scan_annotations (
  id uuid primary key default gen_random_uuid(),
  mentor_student_room_id uuid not null
    references public.mentor_student_rooms (id) on delete cascade,
  author_id uuid not null references public.users (id) on delete cascade,
  author_role text not null check (author_role in ('student', 'mentor')),
  annotation_json text not null default '{}',
  scan_image_path text not null,
  preview_path text,
  has_annotations boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_sa_msr
  on public.scan_annotations (mentor_student_room_id, created_at desc);

drop trigger if exists trg_sa_set_updated on public.scan_annotations;
create trigger trg_sa_set_updated
  before update on public.scan_annotations
  for each row execute function public.set_updated_at();

-- 2) 테이블 RLS — 방 당사자만 select/insert/update --------------------------
alter table public.scan_annotations enable row level security;

drop policy if exists "sa_select" on public.scan_annotations;
create policy "sa_select" on public.scan_annotations
  for select to authenticated
  using (
    exists (
      select 1 from public.mentor_student_rooms r
      where r.id = scan_annotations.mentor_student_room_id
        and ((select auth.uid()) in (r.student_id, r.mentor_id))
    )
  );

drop policy if exists "sa_insert" on public.scan_annotations;
create policy "sa_insert" on public.scan_annotations
  for insert to authenticated
  with check (
    author_id = (select auth.uid())
    and exists (
      select 1 from public.mentor_student_rooms r
      where r.id = mentor_student_room_id
        and ((select auth.uid()) in (r.student_id, r.mentor_id))
    )
  );

drop policy if exists "sa_update" on public.scan_annotations;
create policy "sa_update" on public.scan_annotations
  for update to authenticated
  using (
    exists (
      select 1 from public.mentor_student_rooms r
      where r.id = scan_annotations.mentor_student_room_id
        and ((select auth.uid()) in (r.student_id, r.mentor_id))
    )
  )
  with check (
    exists (
      select 1 from public.mentor_student_rooms r
      where r.id = mentor_student_room_id
        and ((select auth.uid()) in (r.student_id, r.mentor_id))
    )
  );

-- 3) 전용 비공개 버킷 ----------------------------------------------------------
--    스캔 이미지는 학생 필체/개인정보가 담길 수 있어 반드시 비공개(public=false).
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'scan-annotations',
  'scan-annotations',
  false,
  20971520,  -- 20MB
  array['image/jpeg', 'image/png', 'image/webp']::text[]
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = coalesce(excluded.file_size_limit, storage.buckets.file_size_limit),
  allowed_mime_types = coalesce(excluded.allowed_mime_types, storage.buckets.allowed_mime_types);

-- 4) 경로(첫 세그먼트=roomId) → 방 당사자 검사 헬퍼 ---------------------------
create or replace function public.scan_room_uuid_from_path(p_name text)
returns uuid
language sql
immutable
as $$
  select nullif(split_part(p_name, '/', 1), '')::uuid;
$$;

create or replace function public.user_can_access_scan_path(p_name text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.mentor_student_rooms r
    where r.id = public.scan_room_uuid_from_path(p_name)
      and ((select auth.uid()) in (r.student_id, r.mentor_id))
  );
$$;

-- 5) storage.objects RLS — scan-annotations 버킷의 방 당사자만 ----------------
drop policy if exists "sa_storage_read" on storage.objects;
create policy "sa_storage_read"
  on storage.objects for select to authenticated
  using (
    bucket_id = 'scan-annotations'
    and public.user_can_access_scan_path(name)
  );

drop policy if exists "sa_storage_insert" on storage.objects;
create policy "sa_storage_insert"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'scan-annotations'
    and public.user_can_access_scan_path(name)
  );

-- 앱이 upsert(덮어쓰기)로 재업로드할 수 있어 update 정책도 둔다.
drop policy if exists "sa_storage_update" on storage.objects;
create policy "sa_storage_update"
  on storage.objects for update to authenticated
  using (
    bucket_id = 'scan-annotations'
    and public.user_can_access_scan_path(name)
  );

-- =============================================================================
-- 검증용 (Supabase SQL Editor에서 적용 후 확인)
-- -- 테이블 컬럼
-- select column_name, data_type from information_schema.columns
--   where table_schema='public' and table_name='scan_annotations' order by ordinal_position;
-- -- 버킷
-- select id, public, file_size_limit from storage.buckets where id='scan-annotations';
-- -- 정책
-- select policyname, cmd from pg_policies where tablename='scan_annotations';
-- select policyname, cmd from pg_policies
--   where schemaname='storage' and tablename='objects' and policyname like 'sa_%';
-- =============================================================================

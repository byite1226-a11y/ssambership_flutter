-- =============================================================================
-- 093_mentor_withdrawals.sql  (검토용 초안 — 대표 승인 후 적용)
-- -----------------------------------------------------------------------------
-- 목적: 멘토 "출금 요청"을 저장할 withdrawals 테이블 + RLS. (REALDATA_GAPS_DESIGN 3-3)
--   - 앱 SupabaseSettlementsRepository 가 mentor_id·amount_cash·status·created_at 를
--     read/insert 한다. DB에 테이블이 없어 정산/출금 화면이 에러 → 본 테이블로 해소.
--
-- 범위(1차): "요청 접수"까지만 기록한다. 실제 송금(은행/PG)·정산 차감은 별도 운영 절차.
--   - 멘토: 본인 출금만 조회 + 본인 명의 'requested' 요청만 생성.
--   - 상태 변경(approved/paid/rejected/canceled)은 관리자만.
--
-- ⚠️ 정책 미결(finance 결정 필요): 웹은 custom_order_settlement_items 를 에스크로
--    지급 RPC(055)에서 'paid'로 바꾸며 멘토에게 자동 지급한다. 즉 웹은 "자동 지급" 모델이라
--    앱의 "출금 요청" 모델과 결제 경로가 다르다. 실제 송금을 withdrawals 로 일원화할지,
--    아니면 웹 자동지급을 정본으로 둘지는 finance-settlement 가 확정해야 한다. 그 전까지
--    본 테이블은 "요청 로그"로만 쓰고 실제 송금/차감은 연결하지 않는다(돈 사고 방지).
--
-- 멱등성: create ... if not exists / drop policy if exists.
-- 적용처: 웹 SQL 정본에도 동일 번호(093)로 보관.
-- 선행: set_updated_at() 함수, public.users(role) 존재.
-- =============================================================================

-- 1) 테이블 -------------------------------------------------------------------
create table if not exists public.withdrawals (
  id uuid primary key default gen_random_uuid(),
  mentor_id uuid not null references public.users (id) on delete restrict,
  amount_cash integer not null check (amount_cash > 0),
  status text not null default 'requested'
    check (status in ('requested', 'approved', 'paid', 'rejected', 'canceled')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_withdrawals_mentor
  on public.withdrawals (mentor_id, created_at desc);

drop trigger if exists trg_withdrawals_set_updated on public.withdrawals;
create trigger trg_withdrawals_set_updated
  before update on public.withdrawals
  for each row execute function public.set_updated_at();

-- 2) RLS — 멘토 본인 조회/요청, 상태 변경은 관리자 ---------------------------
alter table public.withdrawals enable row level security;

-- 조회: 본인 출금 또는 관리자.
drop policy if exists "wd_select_own_or_admin" on public.withdrawals;
create policy "wd_select_own_or_admin" on public.withdrawals
  for select to authenticated
  using (
    mentor_id = (select auth.uid())
    or exists (
      select 1 from public.users u
      where u.id = (select auth.uid()) and u.role = 'admin'
    )
  );

-- 생성: 본인 명의로 'requested' 상태만(금액 양수는 컬럼 제약이 보장).
drop policy if exists "wd_insert_own_requested" on public.withdrawals;
create policy "wd_insert_own_requested" on public.withdrawals
  for insert to authenticated
  with check (
    mentor_id = (select auth.uid())
    and status = 'requested'
  );

-- 상태 변경(승인·지급·반려·취소): 관리자만.
drop policy if exists "wd_update_admin" on public.withdrawals;
create policy "wd_update_admin" on public.withdrawals
  for update to authenticated
  using (
    exists (
      select 1 from public.users u
      where u.id = (select auth.uid()) and u.role = 'admin'
    )
  )
  with check (
    exists (
      select 1 from public.users u
      where u.id = (select auth.uid()) and u.role = 'admin'
    )
  );

comment on table public.withdrawals is
  'Mentor payout/withdrawal requests. Phase 1 = request log only; real transfer is a separate ops step. Mentor inserts own requested rows; admin changes status.';

-- =============================================================================
-- 검증용 (Supabase SQL Editor에서 적용 후 확인)
-- select column_name, data_type from information_schema.columns
--   where table_schema='public' and table_name='withdrawals' order by ordinal_position;
-- select policyname, cmd from pg_policies where tablename='withdrawals';
-- =============================================================================

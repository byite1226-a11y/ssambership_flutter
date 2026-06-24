-- =============================================================================
-- 091_individual_question_student_wrappers.sql  (검토용 초안 — 대표 승인 후 적용)
-- -----------------------------------------------------------------------------
-- 목적: 개별질문 "지급(정산)·환불"을 앱(authenticated)에서 안전하게 호출하기 위한
--       학생 본인용 래퍼 RPC 2종을 신설한다. (REALDATA_GAPS_DESIGN.md 3-1)
--
-- 배경(돈 직결):
--   - 앱은 release_individual_question / refund_individual_question 를 호출하지만,
--     공유 DB의 실제 함수는 release_individual_question_payout / refund_individual_question_hold
--     이고 둘 다 `service_role`(서버) 전용이라 앱에서 호출 자체가 거부된다(070 파일 grant).
--   - 코어 함수는 "호출자가 누구인지" 검증하지 않는다(서버를 신뢰). 그래서 코어 함수를
--     authenticated 에 그냥 열어주면 남의 질문을 정산/환불시키는 권한상승이 생긴다.
--
-- 설계(권한상승·노동탈취 차단):
--   - 본 래퍼는 security definer 로, 호출자 auth.uid() 가 그 질문의 student_id 인지 검증한 뒤
--     기존 코어 함수를 내부 호출한다(돈 계산 로직은 절대 복제하지 않음 → 정합성 유지).
--   - 정산(release): 작성 학생만. 상태=answered 요구는 코어가 이미 강제.
--   - 환불(refund): 작성 학생만 + 답변 전(open/assigned/claimed)만. answered/released 면 거부
--     (코어는 answered 환불을 막지 않으므로 여기서 반드시 막아 멘토 노동 탈취를 차단).
--   - 코어 결과 ok=false 면 예외를 던져 앱 try/catch 가 실패를 정확히 보여주게 한다
--     (코어는 검증 실패 시 쓰기 전에 일찍 return 하므로 부분 기록 없이 안전하게 롤백).
--
-- 멱등성: create or replace / 코어의 already_released·already_refunded 가드 재사용.
-- 적용처: 웹 SQL 정본에도 동일 번호(091)로 보관.
-- 선행: 070_individual_question_schema_escrow.sql (코어 함수·복합타입 존재해야 함).
-- =============================================================================

-- 1) 정산(지급) — 학생 본인 확인 후 코어 payout 호출 -------------------------
create or replace function public.release_individual_question(
  p_question_id uuid
)
returns public.individual_question_escrow_result
language plpgsql
security definer
set search_path = public
as $function$
declare
  v_uid uuid := auth.uid();
  v_question public.individual_questions%rowtype;
  v_result public.individual_question_escrow_result;
begin
  if v_uid is null then
    raise exception 'NOT_AUTHENTICATED' using errcode = 'P0001';
  end if;

  if p_question_id is null then
    raise exception 'question_id is required' using errcode = 'P0001';
  end if;

  select * into v_question
  from public.individual_questions
  where id = p_question_id;

  if not found then
    raise exception 'NOT_FOUND' using errcode = 'P0001';
  end if;

  -- 지급 확정은 질문을 등록한 학생 본인만 가능(권한상승 차단).
  if v_question.student_id <> v_uid then
    raise exception 'NOT_AUTHORIZED' using errcode = 'P0001';
  end if;

  -- 코어가 status=answered, 중복지급/환불 충돌을 모두 검증·처리한다.
  v_result := public.release_individual_question_payout(p_question_id);

  if not v_result.ok then
    raise exception '%', coalesce(v_result.message, v_result.code, 'release_failed')
      using errcode = 'P0001';
  end if;

  return v_result;
end;
$function$;

-- 2) 환불 — 학생 본인 + 답변 전 상태만 허용 후 코어 refund 호출 -------------
create or replace function public.refund_individual_question(
  p_question_id uuid
)
returns public.individual_question_escrow_result
language plpgsql
security definer
set search_path = public
as $function$
declare
  v_uid uuid := auth.uid();
  v_question public.individual_questions%rowtype;
  v_result public.individual_question_escrow_result;
begin
  if v_uid is null then
    raise exception 'NOT_AUTHENTICATED' using errcode = 'P0001';
  end if;

  if p_question_id is null then
    raise exception 'question_id is required' using errcode = 'P0001';
  end if;

  select * into v_question
  from public.individual_questions
  where id = p_question_id;

  if not found then
    raise exception 'NOT_FOUND' using errcode = 'P0001';
  end if;

  -- 환불은 질문을 등록한 학생 본인만 가능.
  if v_question.student_id <> v_uid then
    raise exception 'NOT_AUTHORIZED' using errcode = 'P0001';
  end if;

  -- 핵심 가드: 답변 완료(answered)·정산 완료(released) 후에는 환불 불가.
  -- (코어는 answered 환불을 막지 않으므로 여기서 차단 → 멘토 노동 탈취 방지.)
  if v_question.status in ('answered', 'released') then
    raise exception '답변 후에는 환불할 수 없어요. 답변을 확인하고 정산해 주세요.'
      using errcode = 'P0001';
  end if;

  -- open/assigned/claimed → 환불, refunded → 코어가 already_refunded(ok=true)로 멱등 처리.
  v_result := public.refund_individual_question_hold(p_question_id);

  if not v_result.ok then
    raise exception '%', coalesce(v_result.message, v_result.code, 'refund_failed')
      using errcode = 'P0001';
  end if;

  return v_result;
end;
$function$;

-- 3) 권한 — authenticated(앱)에게만 실행 허용. 코어 service_role 함수는 그대로 둔다.
revoke all on function public.release_individual_question(uuid) from public, anon;
grant execute on function public.release_individual_question(uuid) to authenticated, service_role;

revoke all on function public.refund_individual_question(uuid) from public, anon;
grant execute on function public.refund_individual_question(uuid) to authenticated, service_role;

comment on function public.release_individual_question(uuid) is
  'Q1 student-facing payout. Verifies caller is the asking student, then delegates to release_individual_question_payout (service_role core). Raises on failure.';
comment on function public.refund_individual_question(uuid) is
  'Q1 student-facing refund. Verifies caller is the asking student AND status is pre-answer (open/assigned/claimed), then delegates to refund_individual_question_hold. Blocks answered/released to prevent mentor-work theft.';

-- =============================================================================
-- 검증용 (Supabase SQL Editor에서 적용 후 확인)
-- -- 함수·권한
-- select p.proname, pg_get_function_identity_arguments(p.oid) as args
--   from pg_proc p join pg_namespace n on n.oid=p.pronamespace
--   where n.nspname='public'
--     and p.proname in ('release_individual_question','refund_individual_question');
-- -- authenticated 에게 execute 권한이 있는지
-- select proname,
--        has_function_privilege('authenticated', oid, 'execute') as auth_can_exec
--   from pg_proc
--   where proname in ('release_individual_question','refund_individual_question');
-- =============================================================================

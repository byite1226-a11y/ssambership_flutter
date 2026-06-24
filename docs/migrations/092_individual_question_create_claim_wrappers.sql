-- =============================================================================
-- 092_individual_question_create_claim_wrappers.sql  (검토용 초안 — 대표 승인 후 적용)
-- -----------------------------------------------------------------------------
-- 목적: 개별질문 "등록(예치)·수령(가져가기)"을 앱(authenticated)에서 안전하게 호출하기
--       위한 인증 래퍼 RPC 2종을 신설한다. (091의 지급·환불과 같은 뿌리 문제)
--
-- 배경(돈 직결):
--   - 등록 create_individual_question_with_hold / 수령 claim_individual_question 은
--     둘 다 service_role 전용(070 파일 grant)이라 앱에서 호출이 거부된다.
--   - 게다가 앱이 보내던 파라미터(p_amount_cents 등)와 코어 시그니처(p_price_cents,
--     p_student_id, p_idempotency_key …)가 불일치해 함수 해석조차 실패한다.
--   - 즉 091(지급·환불)만 적용해도 학생이 질문을 "등록"하는 것부터 막혀 유료 흐름이
--     끝까지 동작하지 않는다. 본 092가 그 앞단(등록·수령)을 인증 래퍼로 연결한다.
--
-- 설계(권한상승·명의도용 차단):
--   - security definer 래퍼가 호출자 auth.uid() 를 student_id/mentor_id 로 "강제"한다.
--     클라이언트가 보내는 남의 id 를 신뢰하지 않는다.
--   - 등록: 학생 본인 명의로만 등록·예치. 지정질문 가격은 mentor 가격표에서 서버가 직접
--     조회(앱 표시가와 동일 소스). 멱등성 키로 재시도 시 이중 예치(이중 과금)를 막는다.
--   - 수령: 멘토 본인만. 코어가 승인멘토 여부·선착순(claimed_mentor_id is null)을 원자적 검증.
--   - 돈 계산·원장 기록은 절대 복제하지 않고 기존 검증된 코어 함수를 내부 호출.
--   - 코어 ok=false 면 예외를 던져 앱이 실패를 정확히 표시(insufficient_cash 등).
--
-- ⚠️ 가격 기본값 주의(finance 검토 필요):
--   - 지정질문에서 멘토 가격표 행이 없으면 800000센트(=8,000캐시)를 기본으로 쓴다.
--     이는 앱/웹이 현재 미설정 멘토에 8,000을 표시·청구하는 동작과 일치시키기 위함이다.
--     기본값을 거부로 바꿀지 여부는 finance-pricing 확정 후 조정.
--
-- 멱등성: create or replace. 등록은 create_idempotency_key 로 코어가 already_exists 멱등 처리.
-- 적용처: 웹 SQL 정본에도 동일 번호(092)로 보관.
-- 선행: 070_individual_question_schema_escrow.sql (코어 함수·복합타입 존재해야 함).
-- =============================================================================

-- 1) 등록(예치) — 학생 본인 강제 + 가격/멱등성 처리 후 코어 호출 -------------
create or replace function public.create_individual_question_as_student(
  p_question_type text,
  p_title text,
  p_body text,
  p_amount_cents int default null,
  p_designated_mentor_id uuid default null,
  p_idempotency_key text default null
)
returns public.individual_question_escrow_result
language plpgsql
security definer
set search_path = public
as $function$
declare
  v_uid uuid := auth.uid();
  v_type text := lower(trim(coalesce(p_question_type, '')));
  v_price_cents int;
  v_idem text;
  v_result public.individual_question_escrow_result;
begin
  if v_uid is null then
    raise exception 'NOT_AUTHENTICATED' using errcode = 'P0001';
  end if;

  if v_type not in ('open', 'direct') then
    raise exception 'INVALID_TYPE' using errcode = 'P0001';
  end if;

  -- 가격: 공개질문은 학생이 입력한 금액, 지정질문은 멘토 가격표(서버 조회).
  if v_type = 'open' then
    v_price_cents := p_amount_cents;
  else
    if p_designated_mentor_id is null then
      raise exception 'MENTOR_REQUIRED' using errcode = 'P0001';
    end if;
    -- 미설정 멘토는 8,000캐시(=800000센트) 기본 — 앱 표시가와 동일(위 주의 참고).
    select coalesce(amount_cents, 800000)
      into v_price_cents
    from public.mentor_individual_question_pricing
    where mentor_id = p_designated_mentor_id;
    if v_price_cents is null then
      v_price_cents := 800000;
    end if;
  end if;

  -- 멱등성 키: 앱이 주면 사용(재시도 시 이중 예치 방지), 없으면 서버 생성.
  v_idem := coalesce(nullif(trim(coalesce(p_idempotency_key, '')), ''),
                     gen_random_uuid()::text);

  -- 호출자 본인(v_uid)을 student_id 로 강제 → 남의 명의 등록 불가.
  v_result := public.create_individual_question_with_hold(
    v_uid,
    v_type,
    p_designated_mentor_id,
    null,            -- p_subject
    null,            -- p_topic
    p_title,
    p_body,
    v_price_cents,
    v_idem
  );

  if not v_result.ok then
    raise exception '%', coalesce(v_result.message, v_result.code, 'create_failed')
      using errcode = 'P0001';
  end if;

  return v_result;
end;
$function$;

-- 2) 수령(공개질문 가져가기) — 멘토 본인 강제 후 코어 호출 -------------------
create or replace function public.claim_individual_question_as_mentor(
  p_question_id uuid
)
returns public.individual_question_escrow_result
language plpgsql
security definer
set search_path = public
as $function$
declare
  v_uid uuid := auth.uid();
  v_result public.individual_question_escrow_result;
begin
  if v_uid is null then
    raise exception 'NOT_AUTHENTICATED' using errcode = 'P0001';
  end if;

  if p_question_id is null then
    raise exception 'question_id is required' using errcode = 'P0001';
  end if;

  -- 호출자 본인(v_uid)을 mentor_id 로 강제. 코어가 승인멘토·선착순을 원자적 검증.
  v_result := public.claim_individual_question(p_question_id, v_uid);

  if not v_result.ok then
    raise exception '%', coalesce(v_result.message, v_result.code, 'claim_failed')
      using errcode = 'P0001';
  end if;

  return v_result;
end;
$function$;

-- 3) 권한 — authenticated(앱)에게만. 코어 service_role 함수는 그대로 둔다.
revoke all on function public.create_individual_question_as_student(text, text, text, int, uuid, text) from public, anon;
grant execute on function public.create_individual_question_as_student(text, text, text, int, uuid, text) to authenticated, service_role;

revoke all on function public.claim_individual_question_as_mentor(uuid) from public, anon;
grant execute on function public.claim_individual_question_as_mentor(uuid) to authenticated, service_role;

comment on function public.create_individual_question_as_student(text, text, text, int, uuid, text) is
  'Q1 student-facing create+hold. Forces student_id = auth.uid(), looks up direct price server-side, then delegates to create_individual_question_with_hold (service_role core).';
comment on function public.claim_individual_question_as_mentor(uuid) is
  'Q1 mentor-facing open-question claim. Forces mentor_id = auth.uid(), then delegates to claim_individual_question (service_role core).';

-- =============================================================================
-- 검증용 (Supabase SQL Editor에서 적용 후 확인)
-- -- 함수·권한
-- select proname,
--        has_function_privilege('authenticated', oid, 'execute') as auth_can_exec
--   from pg_proc
--   where proname in ('create_individual_question_as_student',
--                     'claim_individual_question_as_mentor');
-- =============================================================================

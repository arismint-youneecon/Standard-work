-- 2026-11-07 마이그레이션: 접속코드 이름만으로 발급, 라인 자동 지정
alter table access_codes alter column employee_no set default '';
alter table access_codes alter column employee_no drop not null;
alter table workers alter column employee_no set default '';
alter table workers alter column employee_no drop not null;

-- 최초 접속: 접속코드 → 작업자 등록 (익명 세션 uid에 바인딩)
create or replace function redeem_access_code(p_code text)
returns json language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
  v_ac  access_codes%rowtype;
begin
  if v_uid is null then
    return json_build_object('ok', false, 'error', 'no_session');
  end if;
  if exists (select 1 from workers where id = v_uid) then
    return json_build_object('ok', true, 'already', true);
  end if;
  select * into v_ac from access_codes
   where code = upper(trim(p_code)) for update;
  if not found then
    return json_build_object('ok', false, 'error', 'invalid_code');
  end if;
  if v_ac.used_by is not null then
    return json_build_object('ok', false, 'error', 'code_used');
  end if;
  if v_ac.expires_at < now() then
    return json_build_object('ok', false, 'error', 'code_expired');
  end if;
  insert into workers (id, employee_no, name, line_id)
  values (v_uid, coalesce(v_ac.employee_no, ''), v_ac.name, v_ac.line_id);
  update access_codes set used_by = v_uid, used_at = now() where code = v_ac.code;
  return json_build_object('ok', true, 'name', v_ac.name, 'employee_no', v_ac.employee_no);
end $$;

-- QR 스캔: 세션 12시간 연장 + 설비 정보 반환 + 진입 로그
create or replace function register_scan(p_equipment_code text)
returns json language plpgsql security definer set search_path = public as $$
declare
  v_uid   uuid := auth.uid();
  v_w     workers%rowtype;
  v_eq    record;
  v_hours interval;
begin
  select * into v_w from workers where id = v_uid;
  if not found then
    return json_build_object('ok', false, 'error', 'not_registered');
  end if;
  if v_w.blocked then
    return json_build_object('ok', false, 'error', 'blocked');
  end if;
  select e.id, e.code, e.name, e.process_name, l.name as line_name, l.id as line_id
    into v_eq
    from equipment e join lines l on l.id = e.line_id
   where e.code = p_equipment_code and e.active;
  if not found then
    return json_build_object('ok', false, 'error', 'unknown_equipment');
  end if;
  select make_interval(hours => coalesce(nullif(value, '')::int, 12)) into v_hours
    from app_settings where key = 'session_hours';
  v_hours := coalesce(v_hours, interval '12 hours');
  update workers
     set scan_valid_until = now() + v_hours,
         last_equipment_id = v_eq.id,
         line_id = coalesce(line_id, v_eq.line_id)   -- 라인 미지정 작업자는 첫 스캔 설비의 라인으로 자동 지정
   where id = v_uid;
  insert into view_logs (worker_id, equipment_id, section) values (v_uid, v_eq.id, null);
  return json_build_object(
    'ok', true,
    'equipment', json_build_object('id', v_eq.id, 'code', v_eq.code, 'name', v_eq.name,
                                   'process_name', v_eq.process_name, 'line_name', v_eq.line_name),
    'valid_until', now() + v_hours,
    'worker', json_build_object('name', v_w.name, 'employee_no', v_w.employee_no)
  );
end $$;

-- 접속코드 발급 (편집자: 담당 라인만)
create or replace function issue_access_code(p_employee_no text, p_name text, p_line uuid default null, p_days int default 7)
returns json language plpgsql security definer set search_path = public as $$
declare v_code text;
begin
  if p_name is null or trim(p_name) = '' then return json_build_object('ok', false, 'error', 'name_required'); end if;
  if p_line is null then
    if not is_editor() then return json_build_object('ok', false, 'error', 'forbidden'); end if;
  elsif not can_edit_line(p_line) then
    return json_build_object('ok', false, 'error', 'forbidden');
  end if;
  -- 헷갈리는 글자(0,O,1,I) 제외한 8자리
  loop
    v_code := upper(substr(translate(encode(gen_random_bytes(8), 'hex'), '01', 'XY'), 1, 8));
    exit when not exists (select 1 from access_codes where code = v_code);
  end loop;
  insert into access_codes (code, employee_no, name, line_id, expires_at, created_by)
  values (v_code, coalesce(trim(p_employee_no), ''), trim(p_name), p_line, now() + make_interval(days => p_days), auth.uid());
  return json_build_object('ok', true, 'code', v_code);
end $$;

-- 접속코드: 담당 라인 편집자만 열람 (발급은 RPC)
drop policy if exists access_codes_read on access_codes;
create policy access_codes_read on access_codes for select using (can_edit_line(line_id) or (line_id is null and is_editor()));
drop policy if exists access_codes_del on access_codes;
create policy access_codes_del on access_codes for delete using (can_edit_line(line_id) or (line_id is null and is_editor()));

-- 작업자 목록: 담당 라인 편집자 열람/차단
drop policy if exists workers_read on workers;
create policy workers_read on workers for select using (can_edit_line(line_id) or (line_id is null and is_editor()) or id = auth.uid());
drop policy if exists workers_edit on workers;
create policy workers_edit on workers for update using (can_edit_line(line_id) or (line_id is null and is_editor())) with check (can_edit_line(line_id) or (line_id is null and is_editor()));


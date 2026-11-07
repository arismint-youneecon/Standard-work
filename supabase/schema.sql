-- =====================================================================
--  QR 표준작업 앱 — Supabase 스키마 (v1, 파일럿)
--  Supabase 대시보드 > SQL Editor 에 전체 붙여넣고 Run 하면 됩니다.
--  (다시 실행해도 안전하도록 IF NOT EXISTS / OR REPLACE 사용)
-- =====================================================================

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------
-- 1. 조직 구조: 공장 > 라인 > 설비(공정)
-- ---------------------------------------------------------------------
create table if not exists plants (
  id         uuid primary key default gen_random_uuid(),
  name       text not null,
  created_at timestamptz not null default now()
);

create table if not exists lines (
  id         uuid primary key default gen_random_uuid(),
  plant_id   uuid not null references plants(id) on delete cascade,
  code       text not null,              -- 예: L01
  name       text not null,              -- 예: 시트 프레임 1라인
  sort       int  not null default 0,
  active     boolean not null default true,
  created_at timestamptz not null default now(),
  unique (plant_id, code)
);

create table if not exists equipment (
  id           uuid primary key default gen_random_uuid(),
  line_id      uuid not null references lines(id) on delete cascade,
  code         text not null unique,     -- QR코드에 들어가는 값. 예: L01-OP10
  name         text not null,            -- 설비명. 예: 스폿용접기 #3
  process_name text,                     -- 공정명. 예: OP10 스폿용접
  sort         int  not null default 0,
  active       boolean not null default true,
  created_at   timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- 2. 편집자(컨트롤타워 사용자) — Supabase Auth(이메일/비번) 계정에 연결
--    role: admin(전체) / line_manager(담당 라인 등록·수정·게시)
--          / author(담당 라인 초안 작성만, 게시 불가)
-- ---------------------------------------------------------------------
create table if not exists profiles (
  id         uuid primary key references auth.users(id) on delete cascade,
  name       text not null,
  role       text not null check (role in ('admin','line_manager','author')),
  active     boolean not null default true,
  created_at timestamptz not null default now()
);

-- 삭제 권한: 공장·라인·설비 삭제는 admin 이어도 이 플래그가 있어야 가능 (관리자가 부여)
alter table profiles add column if not exists can_delete boolean not null default false;

create table if not exists profile_lines (  -- 편집자가 담당하는 라인
  profile_id uuid references profiles(id) on delete cascade,
  line_id    uuid references lines(id) on delete cascade,
  primary key (profile_id, line_id)
);

-- ---------------------------------------------------------------------
-- 3. 작업자 — Supabase "익명 로그인" 세션에 연결 (이메일/비번 없음)
--    최초 1회 접속코드 입력 → workers 행 생성 → 이후 QR 스캔마다 12시간 연장
-- ---------------------------------------------------------------------
create table if not exists access_codes (
  code        text primary key,           -- 관리자가 발급 (예: 8자리)
  employee_no text not null,
  name        text not null,
  line_id     uuid references lines(id) on delete set null,
  expires_at  timestamptz not null default now() + interval '7 days',
  used_by     uuid,                        -- auth.uid() of worker
  used_at     timestamptz,
  created_by  uuid references profiles(id),
  created_at  timestamptz not null default now()
);

create table if not exists workers (
  id                uuid primary key,      -- = auth.uid() (익명 세션)
  employee_no       text not null,
  name              text not null,
  line_id           uuid references lines(id) on delete set null,
  scan_valid_until  timestamptz not null default now() + interval '12 hours',
  last_equipment_id uuid references equipment(id) on delete set null,
  blocked           boolean not null default false,
  created_at        timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- 4. 표준 콘텐츠 — 설비 × 섹션 × 버전
--    section: sop(표준작업) / inspection(자주검사) / safety(안전)
--             / quality(품질) / abnormal(이상발생 조치)
--    status : draft(초안) → published(게시) → archived(이전 버전)
-- ---------------------------------------------------------------------
create table if not exists standards (
  id           uuid primary key default gen_random_uuid(),
  equipment_id uuid not null references equipment(id) on delete cascade,
  section      text not null check (section in ('sop','inspection','safety','quality','abnormal')),
  version      int  not null default 1,
  status       text not null default 'draft' check (status in ('draft','published','archived')),
  content      jsonb not null default '{}'::jsonb,
  change_note  text,                        -- 개정 사유
  created_by   uuid references profiles(id),
  created_at   timestamptz not null default now(),
  updated_by   uuid references profiles(id),
  updated_at   timestamptz not null default now(),
  published_by uuid references profiles(id),
  published_at timestamptz
);
-- 번역본: { "en": {...content와 같은 구조, 문자열만 번역...}, "vi": {...}, "__hash": "원문 해시" }
alter table standards add column if not exists translations jsonb not null default '{}'::jsonb;
-- 설비·섹션당 게시본 1개, 초안 1개만
create unique index if not exists standards_one_published
  on standards(equipment_id, section) where status = 'published';
create unique index if not exists standards_one_draft
  on standards(equipment_id, section) where status = 'draft';
create index if not exists standards_eq_idx on standards(equipment_id, section, status);

-- ---------------------------------------------------------------------
-- 5. 로그
-- ---------------------------------------------------------------------
create table if not exists view_logs (
  id           bigserial primary key,
  worker_id    uuid references workers(id) on delete set null,
  equipment_id uuid references equipment(id) on delete set null,
  section      text,                       -- null = QR 스캔(진입)
  viewed_at    timestamptz not null default now()
);
create index if not exists view_logs_eq_idx on view_logs(equipment_id, viewed_at desc);

create table if not exists audit_log (
  id           bigserial primary key,
  actor        uuid,                       -- auth.uid()
  action       text not null,              -- insert/update/delete/publish
  target_table text not null,
  target_id    text,
  detail       jsonb,
  at           timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- 5-1. 앱 설정 · 화면 문구 (컨트롤타워에서 수정 → 작업자 앱이 켜질 때마다 읽음)
-- ---------------------------------------------------------------------
create table if not exists app_settings (
  key        text primary key,            -- app_name / plant_name / session_hours
  value      text not null,
  updated_at timestamptz not null default now(),
  updated_by uuid
);
insert into app_settings (key, value) values
  ('app_name', '표준작업 가이드'), ('plant_name', 'FORVIA 대구공장'), ('session_hours', '12')
on conflict (key) do nothing;

create table if not exists app_texts (   -- 기본 문구(worker/i18n.js)를 덮어쓰는 값만 저장
  key        text not null,              -- i18n 키 (tab_safety, steps, ...)
  lang       text not null,              -- ko, en, zh, ja, vi, uz, ru, ne, kk, bn, fr
  text       text not null,
  updated_at timestamptz not null default now(),
  updated_by uuid,
  primary key (key, lang)
);

-- ---------------------------------------------------------------------
-- 6. 권한 헬퍼 함수
-- ---------------------------------------------------------------------
create or replace function is_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from profiles p where p.id = auth.uid() and p.role = 'admin' and p.active);
$$;

create or replace function is_editor() returns boolean   -- 컨트롤타워 로그인 가능자
language sql stable security definer set search_path = public as $$
  select exists (select 1 from profiles p where p.id = auth.uid() and p.active);
$$;

create or replace function can_delete() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from profiles p where p.id = auth.uid() and p.active and p.can_delete);
$$;

create or replace function can_edit_line(p_line uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select is_admin() or exists (
    select 1 from profiles p join profile_lines pl on pl.profile_id = p.id
    where p.id = auth.uid() and p.active and pl.line_id = p_line
  );
$$;

create or replace function can_publish_line(p_line uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select is_admin() or exists (
    select 1 from profiles p join profile_lines pl on pl.profile_id = p.id
    where p.id = auth.uid() and p.active and p.role = 'line_manager' and pl.line_id = p_line
  );
$$;

create or replace function is_active_worker() returns boolean  -- 12시간 이내 QR 스캔한 작업자
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from workers w
    where w.id = auth.uid() and not w.blocked and w.scan_valid_until > now()
  );
$$;

-- ---------------------------------------------------------------------
-- 7. 작업자용 RPC
-- ---------------------------------------------------------------------
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
  values (v_uid, v_ac.employee_no, v_ac.name, v_ac.line_id);
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
         last_equipment_id = v_eq.id
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

-- 내 세션 상태 조회 (앱 재실행 시)
create or replace function my_worker_status()
returns json language plpgsql security definer set search_path = public as $$
declare v_w workers%rowtype; v_eq record;
begin
  select * into v_w from workers where id = auth.uid();
  if not found then return json_build_object('registered', false); end if;
  select e.id, e.code, e.name, e.process_name, l.name as line_name into v_eq
    from equipment e join lines l on l.id = e.line_id where e.id = v_w.last_equipment_id;
  return json_build_object(
    'registered', true, 'name', v_w.name, 'employee_no', v_w.employee_no,
    'valid', (v_w.scan_valid_until > now() and not v_w.blocked),
    'valid_until', v_w.scan_valid_until,
    'equipment', case when v_eq.id is null then null else json_build_object(
      'id', v_eq.id, 'code', v_eq.code, 'name', v_eq.name,
      'process_name', v_eq.process_name, 'line_name', v_eq.line_name) end
  );
end $$;

-- 섹션 열람 로그
create or replace function log_view(p_equipment_id uuid, p_section text)
returns void language sql security definer set search_path = public as $$
  insert into view_logs (worker_id, equipment_id, section)
  select auth.uid(), p_equipment_id, p_section where is_active_worker();
$$;

-- ---------------------------------------------------------------------
-- 8. 편집자용 RPC: 게시 (초안 → 게시, 기존 게시본 → 보관)
-- ---------------------------------------------------------------------
create or replace function publish_standard(p_draft_id uuid, p_note text default null)
returns json language plpgsql security definer set search_path = public as $$
declare v_d standards%rowtype; v_line uuid; v_ver int;
begin
  select * into v_d from standards where id = p_draft_id and status = 'draft';
  if not found then return json_build_object('ok', false, 'error', 'no_draft'); end if;
  select line_id into v_line from equipment where id = v_d.equipment_id;
  if not can_publish_line(v_line) then
    return json_build_object('ok', false, 'error', 'forbidden');
  end if;
  select coalesce(max(version), 0) + 1 into v_ver
    from standards where equipment_id = v_d.equipment_id and section = v_d.section
     and status <> 'draft';
  update standards set status = 'archived'
   where equipment_id = v_d.equipment_id and section = v_d.section and status = 'published';
  update standards
     set status = 'published', version = v_ver, published_by = auth.uid(),
         published_at = now(), change_note = coalesce(p_note, change_note)
   where id = p_draft_id;
  insert into audit_log (actor, action, target_table, target_id, detail)
  values (auth.uid(), 'publish', 'standards', p_draft_id::text,
          json_build_object('equipment_id', v_d.equipment_id, 'section', v_d.section, 'version', v_ver));
  return json_build_object('ok', true, 'version', v_ver);
end $$;

-- 접속코드 발급 (편집자: 담당 라인만)
create or replace function issue_access_code(p_employee_no text, p_name text, p_line uuid, p_days int default 7)
returns json language plpgsql security definer set search_path = public as $$
declare v_code text;
begin
  if not can_edit_line(p_line) then return json_build_object('ok', false, 'error', 'forbidden'); end if;
  -- 헷갈리는 글자(0,O,1,I) 제외한 8자리
  loop
    v_code := upper(substr(translate(encode(gen_random_bytes(8), 'hex'), '01', 'XY'), 1, 8));
    exit when not exists (select 1 from access_codes where code = v_code);
  end loop;
  insert into access_codes (code, employee_no, name, line_id, expires_at, created_by)
  values (v_code, p_employee_no, p_name, p_line, now() + make_interval(days => p_days), auth.uid());
  return json_build_object('ok', true, 'code', v_code);
end $$;

-- 삭제 (삭제 권한자만, 코드 재입력 확인). 하위 항목은 cascade 로 함께 삭제됨
create or replace function delete_target(p_kind text, p_id uuid, p_confirm text)
returns json language plpgsql security definer set search_path = public as $$
declare v_code text; v_detail json;
begin
  if not can_delete() then return json_build_object('ok', false, 'error', 'forbidden'); end if;
  if p_kind = 'plant' then
    select name into v_code from plants where id = p_id;
    if v_code is null then return json_build_object('ok', false, 'error', 'not_found'); end if;
    if v_code <> p_confirm then return json_build_object('ok', false, 'error', 'confirm_mismatch'); end if;
    select json_build_object('plant', v_code, 'lines', count(distinct l.id), 'equipment', count(distinct e.id))
      into v_detail from lines l left join equipment e on e.line_id = l.id where l.plant_id = p_id;
    insert into audit_log (actor, action, target_table, target_id, detail) values (auth.uid(), 'delete', 'plants', p_id::text, v_detail);
    delete from plants where id = p_id;
  elsif p_kind = 'line' then
    select code into v_code from lines where id = p_id;
    if v_code is null then return json_build_object('ok', false, 'error', 'not_found'); end if;
    if v_code <> p_confirm then return json_build_object('ok', false, 'error', 'confirm_mismatch'); end if;
    select json_build_object('line', v_code, 'equipment', count(e.id), 'standards', (select count(*) from standards s join equipment e2 on e2.id = s.equipment_id where e2.line_id = p_id))
      into v_detail from equipment e where e.line_id = p_id;
    insert into audit_log (actor, action, target_table, target_id, detail) values (auth.uid(), 'delete', 'lines', p_id::text, v_detail);
    delete from lines where id = p_id;
  elsif p_kind = 'equipment' then
    select code into v_code from equipment where id = p_id;
    if v_code is null then return json_build_object('ok', false, 'error', 'not_found'); end if;
    if v_code <> p_confirm then return json_build_object('ok', false, 'error', 'confirm_mismatch'); end if;
    select json_build_object('equipment', v_code, 'standards', count(*)) into v_detail from standards where equipment_id = p_id;
    insert into audit_log (actor, action, target_table, target_id, detail) values (auth.uid(), 'delete', 'equipment', p_id::text, v_detail);
    delete from equipment where id = p_id;
  else
    return json_build_object('ok', false, 'error', 'bad_kind');
  end if;
  return json_build_object('ok', true, 'deleted', v_detail);
end $$;

-- 삭제 대상의 하위 항목 수 미리보기
create or replace function delete_preview(p_kind text, p_id uuid)
returns json language sql stable security definer set search_path = public as $$
  select case p_kind
    when 'plant' then (select json_build_object('lines', count(distinct l.id), 'equipment', count(distinct e.id), 'standards', count(distinct s.id))
                        from lines l left join equipment e on e.line_id = l.id left join standards s on s.equipment_id = e.id where l.plant_id = p_id)
    when 'line' then (select json_build_object('equipment', count(distinct e.id), 'standards', count(distinct s.id))
                        from equipment e left join standards s on s.equipment_id = e.id where e.line_id = p_id)
    else (select json_build_object('standards', count(*)) from standards where equipment_id = p_id) end;
$$;

-- 대시보드: 라인별 열람 현황 (담당 라인만)
create or replace function line_view_stats(p_since timestamptz)
returns table (line_id uuid, line_code text, line_name text, equipment_count bigint, workers_registered bigint,
               workers_viewed bigint, scans bigint, views bigint, v_safety bigint, v_sop bigint, v_inspection bigint,
               v_quality bigint, v_abnormal bigint, last_viewed_at timestamptz)
language sql stable security definer set search_path = public as $$
  select l.id, l.code, l.name,
         (select count(*) from equipment e where e.line_id = l.id and e.active),
         (select count(*) from workers w where w.line_id = l.id and not w.blocked),
         (select count(distinct v.worker_id) from view_logs v join equipment e on e.id = v.equipment_id where e.line_id = l.id and v.viewed_at >= p_since),
         (select count(*) from view_logs v join equipment e on e.id = v.equipment_id where e.line_id = l.id and v.viewed_at >= p_since and v.section is null),
         (select count(*) from view_logs v join equipment e on e.id = v.equipment_id where e.line_id = l.id and v.viewed_at >= p_since and v.section is not null),
         (select count(*) from view_logs v join equipment e on e.id = v.equipment_id where e.line_id = l.id and v.viewed_at >= p_since and v.section = 'safety'),
         (select count(*) from view_logs v join equipment e on e.id = v.equipment_id where e.line_id = l.id and v.viewed_at >= p_since and v.section = 'sop'),
         (select count(*) from view_logs v join equipment e on e.id = v.equipment_id where e.line_id = l.id and v.viewed_at >= p_since and v.section = 'inspection'),
         (select count(*) from view_logs v join equipment e on e.id = v.equipment_id where e.line_id = l.id and v.viewed_at >= p_since and v.section = 'quality'),
         (select count(*) from view_logs v join equipment e on e.id = v.equipment_id where e.line_id = l.id and v.viewed_at >= p_since and v.section = 'abnormal'),
         (select max(v.viewed_at) from view_logs v join equipment e on e.id = v.equipment_id where e.line_id = l.id)
  from lines l where l.active and can_edit_line(l.id) order by l.sort, l.code;
$$;

-- 대시보드: 한 라인의 설비별 열람 현황
create or replace function equipment_view_stats(p_line uuid, p_since timestamptz)
returns table (equipment_id uuid, code text, name text, process_name text, published_sections bigint,
               workers_viewed bigint, scans bigint, views bigint, last_viewed_at timestamptz)
language sql stable security definer set search_path = public as $$
  select e.id, e.code, e.name, e.process_name,
         (select count(*) from standards s where s.equipment_id = e.id and s.status = 'published'),
         (select count(distinct v.worker_id) from view_logs v where v.equipment_id = e.id and v.viewed_at >= p_since),
         (select count(*) from view_logs v where v.equipment_id = e.id and v.viewed_at >= p_since and v.section is null),
         (select count(*) from view_logs v where v.equipment_id = e.id and v.viewed_at >= p_since and v.section is not null),
         (select max(v.viewed_at) from view_logs v where v.equipment_id = e.id)
  from equipment e where e.line_id = p_line and e.active and can_edit_line(p_line) order by e.sort, e.code;
$$;

-- 대시보드: 한 라인에서 기간 내 열람 기록이 없는 작업자
create or replace function line_unviewed_workers(p_line uuid, p_since timestamptz)
returns table (employee_no text, name text, last_viewed_at timestamptz)
language sql stable security definer set search_path = public as $$
  select w.employee_no, w.name, (select max(v.viewed_at) from view_logs v where v.worker_id = w.id)
  from workers w where w.line_id = p_line and not w.blocked and can_edit_line(p_line)
    and not exists (select 1 from view_logs v where v.worker_id = w.id and v.viewed_at >= p_since)
  order by w.employee_no;
$$;

-- 대시보드: 일별 추이 (p_line 이 null 이면 담당 라인 전체)
create or replace function daily_view_counts(p_since timestamptz, p_line uuid default null)
returns table (day date, scans bigint, views bigint)
language sql stable security definer set search_path = public as $$
  select d::date,
         coalesce((select count(*) from view_logs v join equipment e on e.id = v.equipment_id
                    where v.section is null and v.viewed_at >= d and v.viewed_at < d + interval '1 day'
                      and (p_line is null or e.line_id = p_line) and can_edit_line(e.line_id)), 0),
         coalesce((select count(*) from view_logs v join equipment e on e.id = v.equipment_id
                    where v.section is not null and v.viewed_at >= d and v.viewed_at < d + interval '1 day'
                      and (p_line is null or e.line_id = p_line) and can_edit_line(e.line_id)), 0)
  from generate_series(date_trunc('day', p_since), date_trunc('day', now()), interval '1 day') d
  order by 1;
$$;

-- ---------------------------------------------------------------------
-- 9. 감사 로그 트리거
-- ---------------------------------------------------------------------
create or replace function audit_trigger() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into audit_log (actor, action, target_table, target_id, detail)
  values (auth.uid(), lower(TG_OP), TG_TABLE_NAME,
          coalesce((case when TG_OP = 'DELETE' then old.id else new.id end)::text, ''),
          case when TG_OP = 'DELETE' then to_jsonb(old) else to_jsonb(new) end);
  return coalesce(new, old);
end $$;

drop trigger if exists audit_standards on standards;
create trigger audit_standards after insert or update or delete on standards
  for each row execute function audit_trigger();
drop trigger if exists audit_equipment on equipment;
create trigger audit_equipment after insert or update or delete on equipment
  for each row execute function audit_trigger();
drop trigger if exists audit_lines on lines;
create trigger audit_lines after insert or update or delete on lines
  for each row execute function audit_trigger();

create or replace function touch_updated() returns trigger language plpgsql as $$
begin new.updated_at := now(); new.updated_by := auth.uid(); return new; end $$;
drop trigger if exists standards_touch on standards;
create trigger standards_touch before update on standards
  for each row execute function touch_updated();

-- ---------------------------------------------------------------------
-- 10. RLS (행 단위 보안)
-- ---------------------------------------------------------------------
alter table plants        enable row level security;
alter table lines         enable row level security;
alter table equipment     enable row level security;
alter table profiles      enable row level security;
alter table profile_lines enable row level security;
alter table access_codes  enable row level security;
alter table workers       enable row level security;
alter table standards     enable row level security;
alter table view_logs     enable row level security;
alter table audit_log     enable row level security;
alter table app_settings  enable row level security;
alter table app_texts     enable row level security;

-- 설정·문구: 로그인(익명 포함)한 모든 사용자 열람, admin 만 수정
drop policy if exists app_settings_read on app_settings;
create policy app_settings_read on app_settings for select using (auth.uid() is not null);
drop policy if exists app_settings_admin on app_settings;
create policy app_settings_admin on app_settings for all using (is_admin()) with check (is_admin());
drop policy if exists app_texts_read on app_texts;
create policy app_texts_read on app_texts for select using (auth.uid() is not null);
drop policy if exists app_texts_admin on app_texts;
create policy app_texts_admin on app_texts for all using (is_admin()) with check (is_admin());

-- 조직 구조: 편집자 전체 열람 / 작업자(유효세션) 열람 / admin 만 변경 (라인·설비는 담당자도)
drop policy if exists plants_read on plants;
create policy plants_read on plants for select using (is_editor() or is_active_worker());
drop policy if exists plants_admin on plants;
drop policy if exists plants_ins on plants;
create policy plants_ins on plants for insert with check (is_admin());
drop policy if exists plants_upd on plants;
create policy plants_upd on plants for update using (is_admin()) with check (is_admin());

drop policy if exists lines_read on lines;
create policy lines_read on lines for select using (is_editor() or is_active_worker());
drop policy if exists lines_admin on lines;
drop policy if exists lines_ins on lines;
create policy lines_ins on lines for insert with check (is_admin());
drop policy if exists lines_upd on lines;
create policy lines_upd on lines for update using (is_admin()) with check (is_admin());

drop policy if exists equipment_read on equipment;
create policy equipment_read on equipment for select using (is_editor() or is_active_worker());
drop policy if exists equipment_edit on equipment;
drop policy if exists equipment_ins on equipment;
create policy equipment_ins on equipment for insert with check (can_edit_line(line_id));
drop policy if exists equipment_upd on equipment;
create policy equipment_upd on equipment for update using (can_edit_line(line_id)) with check (can_edit_line(line_id));
-- 삭제는 delete_target() RPC 로만 (삭제 권한자 + 코드 재입력)

-- 편집자 프로필: 본인 열람, admin 전체
drop policy if exists profiles_self on profiles;
create policy profiles_self on profiles for select using (id = auth.uid() or is_admin());
drop policy if exists profiles_admin on profiles;
create policy profiles_admin on profiles for all using (is_admin()) with check (is_admin());
drop policy if exists profile_lines_read on profile_lines;
create policy profile_lines_read on profile_lines for select using (profile_id = auth.uid() or is_admin());
drop policy if exists profile_lines_admin on profile_lines;
create policy profile_lines_admin on profile_lines for all using (is_admin()) with check (is_admin());

-- 접속코드: 담당 라인 편집자만 열람 (발급은 RPC)
drop policy if exists access_codes_read on access_codes;
create policy access_codes_read on access_codes for select using (can_edit_line(line_id));
drop policy if exists access_codes_del on access_codes;
create policy access_codes_del on access_codes for delete using (can_edit_line(line_id));

-- 작업자 목록: 담당 라인 편집자 열람/차단
drop policy if exists workers_read on workers;
create policy workers_read on workers for select using (can_edit_line(line_id) or id = auth.uid());
drop policy if exists workers_edit on workers;
create policy workers_edit on workers for update using (can_edit_line(line_id)) with check (can_edit_line(line_id));

-- 표준: 작업자는 게시본만 / 편집자는 담당 라인 전체
drop policy if exists standards_worker_read on standards;
create policy standards_worker_read on standards for select
  using (status = 'published' and is_active_worker());
drop policy if exists standards_editor_read on standards;
create policy standards_editor_read on standards for select using (is_editor());
drop policy if exists standards_editor_write on standards;
create policy standards_editor_write on standards for insert
  with check (status = 'draft' and can_edit_line((select line_id from equipment where id = equipment_id)));
drop policy if exists standards_editor_update on standards;
create policy standards_editor_update on standards for update
  using (status = 'draft' and can_edit_line((select line_id from equipment where id = equipment_id)))
  with check (status = 'draft' and can_edit_line((select line_id from equipment where id = equipment_id)));
drop policy if exists standards_editor_delete on standards;
create policy standards_editor_delete on standards for delete
  using (status = 'draft' and can_edit_line((select line_id from equipment where id = equipment_id)));

-- 로그: 편집자 열람 (작성은 RPC/트리거)
drop policy if exists view_logs_read on view_logs;
create policy view_logs_read on view_logs for select
  using (can_edit_line((select line_id from equipment where id = equipment_id)));
drop policy if exists audit_log_read on audit_log;
create policy audit_log_read on audit_log for select using (is_admin());

-- ---------------------------------------------------------------------
-- 11. 파일 저장소 (bucket: media, 비공개)
--     업로드: 편집자 / 열람: 편집자 + 유효세션 작업자 (서명 URL)
-- ---------------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit)
values ('media', 'media', false, null)
on conflict (id) do nothing;

drop policy if exists media_read on storage.objects;
create policy media_read on storage.objects for select
  using (bucket_id = 'media' and (is_editor() or is_active_worker()));
drop policy if exists media_write on storage.objects;
create policy media_write on storage.objects for insert
  with check (bucket_id = 'media' and is_editor());
drop policy if exists media_update on storage.objects;
create policy media_update on storage.objects for update
  using (bucket_id = 'media' and is_editor());
drop policy if exists media_delete on storage.objects;
create policy media_delete on storage.objects for delete
  using (bucket_id = 'media' and is_editor());

-- ---------------------------------------------------------------------
-- 12. 관리자 열람용 뷰 (설비별 게시 현황)
-- ---------------------------------------------------------------------
create or replace view v_equipment_status with (security_invoker = true) as
select e.id as equipment_id, e.code, e.name, e.process_name, l.id as line_id, l.name as line_name,
       count(*) filter (where s.status = 'published') as published_sections,
       count(*) filter (where s.status = 'draft')     as draft_sections,
       max(s.published_at) as last_published_at
from equipment e
join lines l on l.id = e.line_id
left join standards s on s.equipment_id = e.id
group by e.id, l.id;

-- 대시보드 매트릭스용: 표준별 요약 (번역 언어 수 포함, 본문은 제외)
create or replace view v_standard_overview with (security_invoker = true) as
select s.id, s.equipment_id, s.section, s.status, s.version, s.updated_at, s.published_at, s.change_note,
       (select count(*) from jsonb_object_keys(s.translations) k where k not like '\_\_%') as lang_count
from standards s where s.status in ('published','draft');

-- =====================================================================
-- 설치 후 1회: 첫 관리자 등록
--  (Authentication > Users 에서 본인 이메일 계정을 만든 뒤 아래 실행)
--
--  insert into profiles (id, name, role)
--  select id, '서성목', 'admin' from auth.users where email = '본인이메일@forvia.com';
-- =====================================================================

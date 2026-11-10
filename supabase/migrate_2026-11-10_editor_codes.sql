-- 2026-11-10 마이그레이션: 편집자(관리자) 코드 로그인
-- 이미 schema.sql 을 실행한 DB에 1회 실행. 기존 데이터·이메일 로그인은 그대로 유지됩니다.

-- 2-1. 편집자 코드 로그인 (2026-11-10)
--   편집자(관리자·라인 책임자·작성자)는 이메일 없이 "8자리 코드"로 로그인합니다.
--   코드를 입력한 휴대폰(익명 세션)이 editor_devices 에 등록되고, 그 기기의 권한은 연결된 프로필을 따릅니다.
--   기존 이메일 로그인 계정(profiles.id = auth 계정 id)도 그대로 동작합니다.
-- ---------------------------------------------------------------------
do $$ declare c text; begin
  for c in select conname from pg_constraint
           where conrelid = 'public.profiles'::regclass and contype = 'f' and confrelid = 'auth.users'::regclass loop
    execute format('alter table profiles drop constraint %I', c);
  end loop;
end $$;
alter table profiles alter column id set default gen_random_uuid();

create table if not exists editor_devices (   -- 코드로 로그인한 휴대폰
  uid          uuid primary key,              -- = auth.uid() (익명 세션)
  profile_id   uuid not null references profiles(id) on delete cascade,
  created_at   timestamptz not null default now(),
  last_seen_at timestamptz not null default now()
);
create index if not exists editor_devices_profile_idx on editor_devices(profile_id);

create table if not exists editor_codes (     -- 편집자 접속코드 (휴대폰 등록용)
  code       text primary key,
  profile_id uuid not null references profiles(id) on delete cascade,
  max_uses   int  not null default 2,          -- 사파리 + 홈 화면 앱
  use_count  int  not null default 0,
  expires_at timestamptz not null default now() + interval '7 days',
  created_by uuid,
  created_at timestamptz not null default now()
);

-- 지금 접속한 사람의 편집자 프로필 id (이메일 계정이면 계정 id, 코드 로그인 기기면 연결된 프로필)
create or replace function my_profile_id() returns uuid
language sql stable security definer set search_path = public as $$
  select coalesce(
    (select p.id from profiles p where p.id = auth.uid()),
    (select d.profile_id from editor_devices d where d.uid = auth.uid())
  );
$$;

create or replace function is_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from profiles p where p.id = my_profile_id() and p.role = 'admin' and p.active);
$$;

create or replace function is_editor() returns boolean   -- 컨트롤타워 로그인 가능자
language sql stable security definer set search_path = public as $$
  select exists (select 1 from profiles p where p.id = my_profile_id() and p.active);
$$;

create or replace function can_delete() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from profiles p where p.id = my_profile_id() and p.active and p.can_delete);
$$;

create or replace function can_edit_line(p_line uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select is_admin() or exists (
    select 1 from profiles p join profile_lines pl on pl.profile_id = p.id
    where p.id = my_profile_id() and p.active and pl.line_id = p_line
  );
$$;

create or replace function can_publish_line(p_line uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select is_admin() or exists (
    select 1 from profiles p join profile_lines pl on pl.profile_id = p.id
    where p.id = my_profile_id() and p.active and p.role = 'line_manager' and pl.line_id = p_line
  );
$$;

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
     set status = 'published', version = v_ver, published_by = my_profile_id(),
         published_at = now(), change_note = coalesce(p_note, change_note)
   where id = p_draft_id;
  insert into audit_log (actor, action, target_table, target_id, detail)
  values (my_profile_id(), 'publish', 'standards', p_draft_id::text,
          json_build_object('equipment_id', v_d.equipment_id, 'section', v_d.section, 'version', v_ver));
  return json_build_object('ok', true, 'version', v_ver);
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
  values (v_code, coalesce(trim(p_employee_no), ''), trim(p_name), p_line, now() + make_interval(days => p_days), my_profile_id());
  return json_build_object('ok', true, 'code', v_code);
end $$;

-- ---- 편집자 코드 로그인 RPC ----------------------------------------
-- 코드 생성 (작업자·편집자 코드 전체에서 중복 없음, 헷갈리는 0/1 제외)
create or replace function new_access_code() returns text
language plpgsql security definer set search_path = public as $$
declare v text;
begin
  loop
    v := upper(substr(translate(encode(gen_random_bytes(8), 'hex'), '01', 'XY'), 1, 8));
    exit when not exists (select 1 from access_codes where code = v)
          and not exists (select 1 from editor_codes where code = v);
  end loop;
  return v;
end $$;

-- 편집자 추가 + 코드 발급 (관리자만)
create or replace function create_editor(p_name text, p_role text, p_lines uuid[] default '{}', p_can_delete boolean default false, p_days int default 7)
returns json language plpgsql security definer set search_path = public as $$
declare v_id uuid; v_code text;
begin
  if not is_admin() then return json_build_object('ok', false, 'error', 'forbidden'); end if;
  if p_name is null or trim(p_name) = '' then return json_build_object('ok', false, 'error', 'name_required'); end if;
  if p_role not in ('admin','line_manager','author') then return json_build_object('ok', false, 'error', 'bad_role'); end if;
  insert into profiles (name, role, can_delete) values (trim(p_name), p_role, coalesce(p_can_delete, false)) returning id into v_id;
  insert into profile_lines (profile_id, line_id) select v_id, l from unnest(coalesce(p_lines, '{}')) l on conflict do nothing;
  v_code := new_access_code();
  insert into editor_codes (code, profile_id, expires_at, created_by) values (v_code, v_id, now() + make_interval(days => p_days), my_profile_id());
  insert into audit_log (actor, action, target_table, target_id, detail)
  values (my_profile_id(), 'create_editor', 'profiles', v_id::text, json_build_object('name', trim(p_name), 'role', p_role));
  return json_build_object('ok', true, 'profile_id', v_id, 'code', v_code);
end $$;

-- 코드 재발급 (관리자만) — 이전에 발급한 코드는 무효
create or replace function issue_editor_code(p_profile uuid, p_days int default 7)
returns json language plpgsql security definer set search_path = public as $$
declare v_code text;
begin
  if not is_admin() then return json_build_object('ok', false, 'error', 'forbidden'); end if;
  if not exists (select 1 from profiles where id = p_profile) then return json_build_object('ok', false, 'error', 'not_found'); end if;
  delete from editor_codes where profile_id = p_profile;
  v_code := new_access_code();
  insert into editor_codes (code, profile_id, expires_at, created_by) values (v_code, p_profile, now() + make_interval(days => p_days), my_profile_id());
  return json_build_object('ok', true, 'code', v_code);
end $$;

-- 코드 입력 → 이 휴대폰을 편집자 기기로 등록
create or replace function redeem_editor_code(p_code text)
returns json language plpgsql security definer set search_path = public as $$
declare v_uid uuid := auth.uid(); v_c editor_codes%rowtype; v_p profiles%rowtype;
begin
  if v_uid is null then return json_build_object('ok', false, 'error', 'no_session'); end if;
  select * into v_c from editor_codes where code = upper(trim(p_code)) for update;
  if not found then return json_build_object('ok', false, 'error', 'invalid_code'); end if;
  if v_c.expires_at < now() then return json_build_object('ok', false, 'error', 'code_expired'); end if;
  select * into v_p from profiles where id = v_c.profile_id;
  if not v_p.active then return json_build_object('ok', false, 'error', 'inactive'); end if;
  if exists (select 1 from editor_devices where uid = v_uid and profile_id = v_c.profile_id) then
    return json_build_object('ok', true, 'already', true, 'name', v_p.name, 'role', v_p.role);
  end if;
  if v_c.use_count >= v_c.max_uses then return json_build_object('ok', false, 'error', 'code_used'); end if;
  insert into editor_devices (uid, profile_id) values (v_uid, v_c.profile_id)
    on conflict (uid) do update set profile_id = excluded.profile_id, created_at = now(), last_seen_at = now();
  update editor_codes set use_count = use_count + 1 where code = v_c.code;
  insert into audit_log (actor, action, target_table, target_id, detail)
  values (v_c.profile_id, 'device_login', 'editor_devices', v_uid::text, json_build_object('code', v_c.code));
  return json_build_object('ok', true, 'name', v_p.name, 'role', v_p.role);
end $$;

-- 내 편집자 프로필 (없으면 null)
create or replace function my_profile()
returns json language plpgsql security definer set search_path = public as $$
declare v_id uuid := my_profile_id(); v json;
begin
  if v_id is null then return null; end if;
  update editor_devices set last_seen_at = now() where uid = auth.uid();
  select row_to_json(p) into v from profiles p where p.id = v_id;
  return v;
end $$;

-- 이 사람의 휴대폰 로그인을 모두 해제 (관리자만)
create or replace function revoke_editor_devices(p_profile uuid)
returns json language plpgsql security definer set search_path = public as $$
declare n int;
begin
  if not is_admin() then return json_build_object('ok', false, 'error', 'forbidden'); end if;
  delete from editor_devices where profile_id = p_profile;
  get diagnostics n = row_count;
  delete from editor_codes where profile_id = p_profile;
  insert into audit_log (actor, action, target_table, target_id, detail)
  values (my_profile_id(), 'revoke_devices', 'editor_devices', p_profile::text, json_build_object('devices', n));
  return json_build_object('ok', true, 'devices', n);
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
    insert into audit_log (actor, action, target_table, target_id, detail) values (my_profile_id(), 'delete', 'plants', p_id::text, v_detail);
    delete from plants where id = p_id;
  elsif p_kind = 'line' then
    select code into v_code from lines where id = p_id;
    if v_code is null then return json_build_object('ok', false, 'error', 'not_found'); end if;
    if v_code <> p_confirm then return json_build_object('ok', false, 'error', 'confirm_mismatch'); end if;
    select json_build_object('line', v_code, 'equipment', count(e.id), 'standards', (select count(*) from standards s join equipment e2 on e2.id = s.equipment_id where e2.line_id = p_id))
      into v_detail from equipment e where e.line_id = p_id;
    insert into audit_log (actor, action, target_table, target_id, detail) values (my_profile_id(), 'delete', 'lines', p_id::text, v_detail);
    delete from lines where id = p_id;
  elsif p_kind = 'equipment' then
    select code into v_code from equipment where id = p_id;
    if v_code is null then return json_build_object('ok', false, 'error', 'not_found'); end if;
    if v_code <> p_confirm then return json_build_object('ok', false, 'error', 'confirm_mismatch'); end if;
    select json_build_object('equipment', v_code, 'standards', count(*)) into v_detail from standards where equipment_id = p_id;
    insert into audit_log (actor, action, target_table, target_id, detail) values (my_profile_id(), 'delete', 'equipment', p_id::text, v_detail);
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

create or replace function audit_trigger() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into audit_log (actor, action, target_table, target_id, detail)
  values (coalesce(my_profile_id(), auth.uid()), lower(TG_OP), TG_TABLE_NAME,
          coalesce((case when TG_OP = 'DELETE' then old.id else new.id end)::text, ''),
          case when TG_OP = 'DELETE' then to_jsonb(old) else to_jsonb(new) end);
  return coalesce(new, old);
end $$;

create or replace function touch_updated() returns trigger language plpgsql as $$
begin new.updated_at := now(); new.updated_by := my_profile_id(); return new; end $$;
alter table editor_devices enable row level security;
alter table editor_codes   enable row level security;
-- 편집자 기기·코드: 관리자 열람 (본인 기기는 본인도). 변경은 RPC 로만
drop policy if exists editor_devices_read on editor_devices;
create policy editor_devices_read on editor_devices for select using (is_admin() or uid = auth.uid());
drop policy if exists editor_codes_read on editor_codes;
create policy editor_codes_read on editor_codes for select using (is_admin());

drop policy if exists profiles_self on profiles;
create policy profiles_self on profiles for select using (id = my_profile_id() or is_admin());
drop policy if exists profile_lines_read on profile_lines;
create policy profile_lines_read on profile_lines for select using (profile_id = my_profile_id() or is_admin());

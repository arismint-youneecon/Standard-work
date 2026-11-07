// =====================================================================
//  컨트롤타워 데모용 가짜 Supabase 클라이언트 (admin/?demo=1)
//  - DB 없이 샘플 데이터로 모든 화면을 눌러 볼 수 있음. 저장은 메모리에만 (새로고침하면 초기화)
//  - 실제 운영에는 사용되지 않음
// =====================================================================
(() => {
  const ME = 'u-admin', L1 = 'line-gpf', L2 = 'line-l02';
  const E = ['eq-op10','eq-op20','eq-op30','eq-op40'];
  const now = Date.now(), ago = (h) => new Date(now - h*3.6e6).toISOString();
  const sop = { full_video:{ title:'OP30 전체 작업 (1분 40초)', path:'GPF-OP30/sop/full.mp4' }, videos:[],
    steps:[ {text:'좌측 공급대에서 브라켓 A를 집어 지그 1번 핀에 끼운다.', key_point:'핀 2개가 모두 홀에 들어갔는지 손으로 눌러 확인', image_path:'GPF-OP30/sop/step1.jpg'},
            {text:'우측 공급대에서 브라켓 B를 지그 2번 위치에 올린다.'},
            {text:'양손 기동 버튼을 동시에 눌러 용접을 시작한다.', key_point:'클램프 완전 하강 확인 후 버튼'},
            {text:'용접 완료 램프 점등 후 제품을 꺼내 우측 트레이에 놓는다.', key_point:'너깃 3개 위치 육안 확인'} ],
    notes:'사이클 타임 42초. 제품 투입 전 전극 팁 오염 여부 확인.' };
  const safety = { ppe:[{name:'보안경',icon:'🥽'},{name:'용접 장갑',icon:'🧤'},{name:'안전화',icon:'🥾'},{name:'귀마개',icon:'🎧'}],
    hazards:['용접 스패터 비산 — 화상 위험','클램프 하강 시 협착 위험','전극 팁 고온(200℃ 이상)'],
    rules:['양손 기동 버튼 외 다른 방법으로 기동 금지','클램프 하강 중 지그 내부에 손 넣지 않기','전극 팁 교체는 전원 차단 후 보전 담당만'] };
  const inspection = { items:[ {name:'용접 너깃 외관', interval:'시작 시 1개 / 2시간마다 1개', method:'육안', ok:{desc:'너깃 지름 5mm 이상, 균일한 원형'}, nok:{desc:'핀홀, 과용입, 위치 이탈'}, nok_action:'즉시 라인 정지 → 직전 2시간 생산품 격리 → 반장 호출'} ] };
  const quality = { points:[{text:'브라켓 A/B 방향 — 각인 "UP"이 위로', spec:'각인 육안 확인'}], defects:[{name:'너깃 미형성', cause:'전극 팁 마모', action:'NOK 박스, 보전 호출'}] };
  const abnormal = { cases:[{symptom:'용접 불량 2개 연속 발생', stop_line:true, action:'1. 라인 정지\n2. NOK 격리\n3. 반장 호출', contact:'반장'}], contacts:[{role:'반장',name:'박반장',phone:'010-0000-0000'}] };
  const std = (id, eq, section, status, version, content, extra={}) => ({ id, equipment_id:eq, section, status, version, content, translations: extra.translations||{}, change_note: extra.note||'', created_by:ME, created_at: ago(72), updated_at: extra.updated||ago(48), updated_by:ME, published_by: status==='published'?ME:null, published_at: status==='published'?ago(24):null });

  const DB = {
    plants:[{id:'p1', name:'대구공장'}],
    lines:[{id:L1, plant_id:'p1', code:'GPF', name:'GPF 라인', sort:1, active:true}, {id:L2, plant_id:'p1', code:'L02', name:'시트프레임 2라인', sort:2, active:true}],
    equipment:[
      {id:E[0], line_id:L1, code:'GPF-OP10', name:'프레스 #1', process_name:'OP10 블랭킹', sort:10, active:true},
      {id:E[1], line_id:L1, code:'GPF-OP20', name:'벤딩기 #2', process_name:'OP20 벤딩', sort:20, active:true},
      {id:E[2], line_id:L1, code:'GPF-OP30', name:'스폿용접기 #3', process_name:'OP30 브라켓 용접', sort:30, active:true},
      {id:E[3], line_id:L1, code:'GPF-OP40', name:'너트런너 #1', process_name:'OP40 볼트 체결', sort:40, active:true},
    ],
    profiles:[ {id:ME, name:'서성목', role:'admin', active:true, can_delete:true, created_at:ago(200)}, {id:'u-mgr', name:'김책임', role:'line_manager', active:true, created_at:ago(100)}, {id:'u-auth', name:'이작성', role:'author', active:true, created_at:ago(50)} ],
    profile_lines:[ {profile_id:'u-mgr', line_id:L1}, {profile_id:'u-auth', line_id:L1} ],
    access_codes:[ {code:'K7M2P9XQ', employee_no:'24031', name:'김작업', line_id:L1, expires_at:ago(-120), used_by:'w1', used_at:ago(30), created_by:ME, created_at:ago(40)},
                   {code:'B4N8R2TY', employee_no:'24052', name:'응우옌 반 안', line_id:L1, expires_at:ago(-150), used_by:null, used_at:null, created_by:ME, created_at:ago(5)} ],
    workers:[ {id:'w1', employee_no:'24031', name:'김작업', line_id:L1, scan_valid_until:ago(-9), last_equipment_id:E[2], blocked:false, created_at:ago(30)},
              {id:'w2', employee_no:'23118', name:'라제시', line_id:L1, scan_valid_until:ago(3), last_equipment_id:E[1], blocked:false, created_at:ago(80)},
              {id:'w3', employee_no:'24052', name:'응우옌 반 안', line_id:L1, scan_valid_until:ago(300), last_equipment_id:null, blocked:false, created_at:ago(300)} ],
    standards:[
      std('s1', E[2], 'safety', 'published', 1, safety, {translations:{en:{}, vi:{}}}),
      std('s2', E[2], 'sop', 'published', 2, sop, {note:'급소 문구 보완', translations:{en:{},vi:{},zh:{},ja:{},uz:{},ru:{},ne:{},kk:{},bn:{},fr:{}}}),
      std('s2a', E[2], 'sop', 'archived', 1, sop, {note:'최초 게시'}),
      std('s3', E[2], 'inspection', 'published', 1, inspection),
      std('s4', E[2], 'quality', 'published', 1, quality),
      std('s5', E[2], 'abnormal', 'draft', 1, abnormal, {updated: ago(2)}),
      std('s6', E[1], 'safety', 'published', 1, safety),
      std('s7', E[1], 'sop', 'draft', 1, {steps:[{text:'소재를 벤딩 다이에 올린다.'}]}),
    ],
    view_logs:[ ...Array.from({length:40}, (_,i) => ({id:100+i, worker_id: i%3?'w1':'w2', equipment_id: E[(i%3)+1], section: ['safety','sop','inspection',null,'quality','abnormal','sop'][i%7], viewed_at: ago(2 + i*3.7)})), {id:1, worker_id:'w1', equipment_id:E[2], section:null, viewed_at:ago(3)}, {id:2, worker_id:'w1', equipment_id:E[2], section:'safety', viewed_at:ago(2.9)}, {id:3, worker_id:'w1', equipment_id:E[2], section:'sop', viewed_at:ago(2.8)}, {id:4, worker_id:'w2', equipment_id:E[1], section:null, viewed_at:ago(20)}, {id:5, worker_id:'w2', equipment_id:E[1], section:'safety', viewed_at:ago(19.9)} ],
    audit_log:[ {id:1, actor:ME, action:'publish', target_table:'standards', target_id:'s2', detail:{section:'sop', version:2}, at:ago(24)}, {id:2, actor:'u-auth', action:'update', target_table:'standards', target_id:'s5', detail:{section:'abnormal'}, at:ago(2)} ],
    app_settings:[ {key:'app_name', value:'표준작업 가이드'}, {key:'plant_name', value:'FORVIA 대구공장'}, {key:'session_hours', value:'12'} ],
    app_texts:[],
    v_equipment_status:null,   // 아래에서 계산
  };
  const statusView = () => DB.equipment.map(e => { const l = DB.lines.find(x=>x.id===e.line_id); const ss = DB.standards.filter(s=>s.equipment_id===e.id);
    return { equipment_id:e.id, code:e.code, name:e.name, process_name:e.process_name, line_id:l.id, line_name:l.name, published_sections: ss.filter(s=>s.status==='published').length, draft_sections: ss.filter(s=>s.status==='draft').length, last_published_at: ss.filter(s=>s.published_at).map(s=>s.published_at).sort().pop()||null }; });
  const uid = () => 'id-' + Math.random().toString(36).slice(2,8);

  function from(table){
    let op='select', payload=null, filters=[], single=false, head=false, orders=[], lim=null;
    const q = {
      select(cols, opts){ if(opts?.head) head=true; return q; },
      insert(p){ op='insert'; payload=p; return q; }, update(p){ op='update'; payload=p; return q; }, upsert(p){ op='upsert'; payload=p; return q; }, delete(){ op='delete'; return q; },
      eq(k,v){ filters.push(r=>r[k]===v); return q; }, is(k,v){ filters.push(r=>r[k]==v); return q; }, gte(k,v){ filters.push(r=>r[k]>=v); return q; }, match(m){ filters.push(r=>Object.entries(m).every(([k,v])=>r[k]===v)); return q; },
      order(k,o){ orders.push([k, o?.ascending===false?-1:1]); return q; }, limit(n){ lim=n; return q; }, single(){ single=true; return q; }, maybeSingle(){ single=true; return q; },
      then(res){
        const rows = table==='v_equipment_status' ? statusView() : table==='v_standard_overview' ? DB.standards.filter(x=>x.status==='published'||x.status==='draft').map(x=>({id:x.id, equipment_id:x.equipment_id, section:x.section, status:x.status, version:x.version, updated_at:x.updated_at, published_at:x.published_at, change_note:x.change_note, lang_count:Object.keys(x.translations||{}).filter(k=>!k.startsWith('__')).length})) : (DB[table]||[]);
        const hit = r => filters.every(f=>f(r));
        let out;
        if(op==='select'){ out = rows.filter(hit).map(r=>({...r}));
          orders.forEach(([k,d]) => out.sort((a,b)=>(a[k]>b[k]?1:a[k]<b[k]?-1:0)*d)); if(lim) out = out.slice(0,lim);
          if(table==='view_logs') out.forEach(r => { r.workers = DB.workers.find(w=>w.id===r.worker_id)||null; const e=DB.equipment.find(x=>x.id===r.equipment_id); r.equipment = e?{code:e.code,name:e.name,line_id:e.line_id}:null; }); }
        if(op==='insert'){ out = (Array.isArray(payload)?payload:[payload]).map(p => { const r = {id:uid(), status:'draft', version:1, active:true, created_at:new Date().toISOString(), updated_at:new Date().toISOString(), translations:{}, ...p}; DB[table].push(r); return r; }); }
        if(op==='update'){ out=[]; DB[table].forEach(r => { if(hit(r)){ Object.assign(r, payload, {updated_at:new Date().toISOString()}); out.push({...r}); } }); }
        if(op==='upsert'){ (Array.isArray(payload)?payload:[payload]).forEach(p => { const i = DB[table].findIndex(r => r.key===p.key && (p.lang===undefined || r.lang===p.lang)); i>=0 ? Object.assign(DB[table][i], p) : DB[table].push({...p}); }); out=[]; }
        if(op==='delete'){ out=[]; DB[table] = DB[table].filter(r=>!hit(r)); }
        res({ data: single ? (out[0]||null) : out, error:null, count: head ? out.length : null });
      }
    };
    return q;
  }
  const rpc = async (name, a) => {
    if(name==='publish_standard'){ const d = DB.standards.find(s=>s.id===a.p_draft_id); if(!d) return {data:{ok:false,error:'no_draft'}};
      const v = Math.max(0, ...DB.standards.filter(s=>s.equipment_id===d.equipment_id&&s.section===d.section&&s.status!=='draft').map(s=>s.version)) + 1;
      DB.standards.forEach(s => { if(s.equipment_id===d.equipment_id&&s.section===d.section&&s.status==='published') s.status='archived'; });
      Object.assign(d, {status:'published', version:v, published_at:new Date().toISOString(), published_by:ME, change_note:a.p_note||d.change_note}); return {data:{ok:true,version:v}}; }
    if(name==='issue_access_code'){ const code = Math.random().toString(36).slice(2,10).toUpperCase().replace(/[01OI]/g,'X'); DB.access_codes.unshift({code, employee_no:a.p_employee_no, name:a.p_name, line_id:a.p_line, expires_at:ago(-24*a.p_days), used_by:null, created_by:ME, created_at:new Date().toISOString()}); return {data:{ok:true,code}}; }
    if(name==='line_view_stats'){ const since=a.p_since; return {data: DB.lines.filter(l=>l.active).map(l => { const eqs=DB.equipment.filter(e=>e.line_id===l.id&&e.active); const vl=DB.view_logs.filter(v=>v.viewed_at>=since&&eqs.some(e=>e.id===v.equipment_id)); const ws=DB.workers.filter(w=>w.line_id===l.id&&!w.blocked);
      const c=sec=>vl.filter(v=>v.section===sec).length; return { line_id:l.id, line_code:l.code, line_name:l.name, equipment_count:eqs.length, workers_registered:ws.length, workers_viewed:new Set(vl.map(v=>v.worker_id)).size, scans:c(null), views:vl.filter(v=>v.section).length, v_safety:c('safety'), v_sop:c('sop'), v_inspection:c('inspection'), v_quality:c('quality'), v_abnormal:c('abnormal'), last_viewed_at: DB.view_logs.filter(v=>eqs.some(e=>e.id===v.equipment_id)).map(v=>v.viewed_at).sort().pop()||null }; })}; }
    if(name==='equipment_view_stats'){ return {data: DB.equipment.filter(e=>e.line_id===a.p_line&&e.active).map(e => { const vl=DB.view_logs.filter(v=>v.equipment_id===e.id&&v.viewed_at>=a.p_since); return { equipment_id:e.id, code:e.code, name:e.name, process_name:e.process_name, published_sections:DB.standards.filter(s=>s.equipment_id===e.id&&s.status==='published').length, workers_viewed:new Set(vl.map(v=>v.worker_id)).size, scans:vl.filter(v=>!v.section).length, views:vl.filter(v=>v.section).length, last_viewed_at:DB.view_logs.filter(v=>v.equipment_id===e.id).map(v=>v.viewed_at).sort().pop()||null }; })}; }
    if(name==='line_unviewed_workers'){ return {data: DB.workers.filter(w=>w.line_id===a.p_line&&!w.blocked&&!DB.view_logs.some(v=>v.worker_id===w.id&&v.viewed_at>=a.p_since)).map(w=>({employee_no:w.employee_no, name:w.name, last_viewed_at:DB.view_logs.filter(v=>v.worker_id===w.id).map(v=>v.viewed_at).sort().pop()||null}))}; }
    if(name==='daily_view_counts'){ const since=new Date(a.p_since); since.setHours(0,0,0,0); const out=[]; for(let d=new Date(since); d<=new Date(); d.setDate(d.getDate()+1)){ const ds=d.toISOString().slice(0,10); const vl=DB.view_logs.filter(v=>v.viewed_at.slice(0,10)===ds && (!a.p_line || DB.equipment.find(e=>e.id===v.equipment_id)?.line_id===a.p_line)); out.push({day:ds, scans:vl.filter(v=>!v.section).length, views:vl.filter(v=>v.section).length}); } return {data:out}; }
    if(name==='delete_preview'){ const k=a.p_kind, id=a.p_id; const eqs = k==='plant' ? DB.equipment.filter(e=>DB.lines.some(l=>l.plant_id===id&&l.id===e.line_id)) : k==='line' ? DB.equipment.filter(e=>e.line_id===id) : DB.equipment.filter(e=>e.id===id);
      const st = DB.standards.filter(s=>eqs.some(e=>e.id===s.equipment_id)).length; return {data: k==='plant' ? {lines: DB.lines.filter(l=>l.plant_id===id).length, equipment:eqs.length, standards:st} : k==='line' ? {equipment:eqs.length, standards:st} : {standards:st}}; }
    if(name==='delete_target'){ const k=a.p_kind, id=a.p_id; const row = (k==='plant'?DB.plants:k==='line'?DB.lines:DB.equipment).find(r=>r.id===id); if(!row) return {data:{ok:false,error:'not_found'}};
      if((k==='plant'?row.name:row.code)!==a.p_confirm) return {data:{ok:false,error:'confirm_mismatch'}};
      if(k==='plant'){ const ls = DB.lines.filter(l=>l.plant_id===id).map(l=>l.id); DB.equipment = DB.equipment.filter(e=>!ls.includes(e.line_id)); DB.lines = DB.lines.filter(l=>l.plant_id!==id); DB.plants = DB.plants.filter(p=>p.id!==id); }
      if(k==='line'){ DB.equipment = DB.equipment.filter(e=>e.line_id!==id); DB.lines = DB.lines.filter(l=>l.id!==id); }
      if(k==='equipment'){ DB.equipment = DB.equipment.filter(e=>e.id!==id); }
      DB.standards = DB.standards.filter(s=>DB.equipment.some(e=>e.id===s.equipment_id));
      DB.audit_log.unshift({id:uid(), actor:ME, action:'delete', target_table:k+'s', target_id:id, detail:{code:a.p_confirm}, at:new Date().toISOString()}); return {data:{ok:true}}; }
    return {data:{ok:true}};
  };
  window.DEMO_MOCK = { createClient: () => ({
    auth: { getSession: async()=>({data:{session:{}}}), getUser: async()=>({data:{user:{id:ME}}}), signInWithPassword: async()=>({error:null}), signOut: async()=>{}, signUp: async()=>({data:{user:{id:uid()}},error:null}) },
    from, rpc,
    functions: { invoke: async (name, {body}) => { await new Promise(r=>setTimeout(r,800));
      if(body.mode==='texts'){ return {data:{ok:true, done:['en','vi'], failed:{}}}; }
      const d = DB.standards.find(s=>s.id===body.draft_id); if(d){ d.translations = Object.fromEntries(['en','zh','ja','vi','uz','ru','ne','kk','bn','fr'].map(l=>[l,{}])); d.translations.__at = new Date().toISOString(); d.translations.__hash = 'demo'; }
      return {data:{ok:true, done:['en','zh','ja','vi','uz','ru','ne','kk','bn','fr'], failed:{}, strings:9}}; } },
    storage: { from: () => ({ upload: async()=>{ await new Promise(r=>setTimeout(r,600)); return {error:null}; }, createSignedUrl: async(path)=>({data:{signedUrl:'data:image/svg+xml;utf8,'+encodeURIComponent(`<svg xmlns="http://www.w3.org/2000/svg" width="160" height="120"><rect width="100%" height="100%" fill="#334155"/><text x="50%" y="50%" fill="#fff" font-size="12" text-anchor="middle" dominant-baseline="middle">${path.split('/').pop()}</text></svg>`)}}) }) },
  })};
})();

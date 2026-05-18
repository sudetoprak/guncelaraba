let ws=null, wsOk=false, curSpd=128;

function connectWS() {
  const cid=document.getElementById('carIdInput')?.value.trim()||'car001';
  const token=TokenStorage.get()||'guest';
  if (MOCK_MODE) {
    wsOk=true; setConn(true,cid);
    addLog('system','Simülasyon modu aktif');
    toast('Araçla bağlantı kuruldu! (Sim)','success'); return;
  }
  try { ws=new WebSocket(`${WS_BASE}/ws/control/${cid}?token=${token}`); }
  catch(e) { toast('WS başlatılamadı: '+e.message,'error'); return; }
  document.getElementById('statusText').textContent='Bağlanıyor...';
  ws.onopen=()=>{ wsOk=true; setConn(true,cid); addLog('system','Bağlandı: '+cid); toast('Araçla bağlantı kuruldu!','success'); };
  ws.onmessage=e=>{ try { const d=JSON.parse(e.data); if(d.type==='ack'){ const lc=document.getElementById('lastCmd'); if(lc) lc.textContent=`Son: ${cmdLbl(d.command)} (${d.latency_ms}ms)`; } } catch{} };
  ws.onclose=e=>{ wsOk=false; setConn(false); if(e.code!==1000){addLog('warn','Bağlantı kesildi. 3s sonra...'); setTimeout(()=>{if(!wsOk)connectWS();},3000);} };
  ws.onerror=()=>{ toast('WebSocket hatası','error'); };
}
function disconnectWS() {
  if(ws){ws.close(1000);ws=null;} wsOk=false; setConn(false); toast('Bağlantı kesildi.','info');
}
function setConn(ok,cid='') {
  const panel=document.getElementById('joystickPanel');
  const conn=document.getElementById('ctrlConnect');
  if (ok) {
    panel&&(panel.classList.add('show'),panel.style.display='block');
    conn&&(conn.style.display='none');
    const st=document.getElementById('statusText'); if(st) st.textContent='Bağlı: '+cid;
    document.querySelectorAll('.sdot').forEach(d=>d.classList.add('connected'));
    const js=document.getElementById('joyStatus'); if(js) js.textContent='Bağlı';
  } else {
    panel&&(panel.classList.remove('show'),panel.style.display='none');
    conn&&(conn.style.display='block');
    const st=document.getElementById('statusText'); if(st) st.textContent='Bağlantı Yok';
    document.querySelectorAll('.sdot').forEach(d=>d.classList.remove('connected'));
  }
}
function snd(cmd,x=0,y=0) {
  if (!wsOk) return;
  document.querySelectorAll('.db').forEach(b=>b.classList.remove('pressing'));
  const map={forward:'.up',backward:'.down',left:'.left',right:'.right',stop:'.stop-b'};
  const sel=map[cmd]; if(sel){ const b=document.querySelector('.dpad '+sel); if(b) b.classList.add('pressing'); }
  const lc=document.getElementById('lastCmd'); if(lc) lc.textContent='Son: '+cmdLbl(cmd);
  if (MOCK_MODE) { addLog(cmd,`${cmdLbl(cmd)} — %${Math.round(curSpd/255*100)}`); return; }
  if (!ws||ws.readyState!==WebSocket.OPEN) return;
  try { ws.send(JSON.stringify({command:cmd,x:parseFloat(x),y:parseFloat(y),speed:curSpd})); } catch{}
}
function setSpeed(btn,val) {
  curSpd=val;
  document.querySelectorAll('.sb').forEach(b=>b.classList.remove('active'));
  if(btn) btn.classList.add('active');
}
const cColors={forward:'#a78bfa',backward:'#f87171',left:'#60a5fa',right:'#34d399',stop:'#fbbf24',system:'#6b7280',warn:'#fb923c'};
function cmdLbl(c){return{forward:'▲ İleri',backward:'▼ Geri',left:'◀ Sol',right:'▶ Sağ',stop:'⏹ Dur',system:'SYS',warn:'WARN'}[c]||c;}
function addLog(type,msg) {
  const el=document.getElementById('cmdLog'); if(!el) return;
  const t=new Date().toLocaleTimeString('tr-TR',{hour:'2-digit',minute:'2-digit',second:'2-digit'});
  el.innerHTML+=`<div class="log-e"><span style="color:${cColors.system}">[${t}]</span> <span class="lc" style="color:${cColors[type]||'#9ca3af'}">${cmdLbl(type)}</span> <span style="color:var(--txt3)">${msg&&msg!==cmdLbl(type)?'— '+msg:''}</span></div>`;
  el.scrollTop=el.scrollHeight;
  const es=el.querySelectorAll('.log-e'); if(es.length>30) es[0].remove();
}

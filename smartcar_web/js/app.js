const PAGES=['home','products','detail','cart','checkout','orders','auth','profile'];

function showPage(name) {
  PAGES.forEach(p=>{ const el=document.getElementById('page-'+p); el&&el.classList.toggle('active',p===name); });
  document.querySelectorAll('.nl[data-page]').forEach(l=>l.classList.toggle('active',l.dataset.page===name));
  document.getElementById('navLinks')?.classList.remove('open');
  document.getElementById('hamburger')?.classList.remove('open');
  window.scrollTo({top:0,behavior:'smooth'});
  switch(name){
    case 'home':     loadFeatured(); break;
    case 'products': loadAllProducts(); break;
    case 'cart':     loadCart(); break;
    case 'checkout': loadCheckout(); break;
    case 'orders':   loadOrders(); break;
    case 'profile':  loadProfile(); break;
  }
  setTimeout(observeReveal,100);
}

function goFeatures() {
  if (!document.getElementById('page-home').classList.contains('active')) showPage('home');
  setTimeout(()=>{ document.getElementById('features-section')?.scrollIntoView({behavior:'smooth',block:'start'}); },200);
}

function toggleMenu() {
  document.getElementById('navLinks')?.classList.toggle('open');
  document.getElementById('hamburger')?.classList.toggle('open');
}

function toast(msg,type='info') {
  const c=document.getElementById('toastContainer');
  const el=document.createElement('div');
  el.className=`toast ${type}`; el.textContent=msg;
  c.appendChild(el);
  setTimeout(()=>el.remove(),3200);
}

async function loadProfile() {
  const el=document.getElementById('profileContent'); if(!el) return;
  const user=UserStorage.get();
  if (!user) {
    el.innerHTML=`<div style="text-align:center;padding:4rem"><h3 style="margin-bottom:1rem">Giriş Yapmanız Gerekiyor</h3><button class="btn-glow" onclick="showPage('auth')">Giriş Yap</button></div>`;
    return;
  }
  const init=user.full_name?user.full_name.split(' ').map(n=>n[0]).join('').slice(0,2).toUpperCase():'?';
  el.innerHTML=`<div class="prof-grid">
    <div class="prof-side">
      <div class="prof-avatar">${init}</div>
      <div class="prof-name">${user.full_name||user.username}</div>
      <div class="prof-email">${user.email}</div>
      <div class="prof-menu">
        <a href="#" class="on" onclick="return false">Profilim</a>
        <a href="#" onclick="showPage('orders');return false">Siparişlerim</a>
      </div>
      <button class="logout-btn" onclick="logout()">Çıkış Yap</button>
    </div>
    <div class="prof-main">
      <h3>Hesap Bilgileri</h3>
      <div class="det-specs">
        <div class="srow"><span class="sk">Ad Soyad</span><span class="sv">${user.full_name||'—'}</span></div>
        <div class="srow"><span class="sk">Kullanıcı Adı</span><span class="sv">${user.username||'—'}</span></div>
        <div class="srow"><span class="sk">E-posta</span><span class="sv">${user.email}</span></div>
        <div class="srow"><span class="sk">Telefon</span><span class="sv">${user.phone||'—'}</span></div>
        <div class="srow"><span class="sk">Rol</span><span class="sv">${user.role==='admin'?'Yönetici':'Kullanıcı'}</span></div>
        <div class="srow"><span class="sk">Üyelik</span><span class="sv">${user.created_at?new Date(user.created_at).toLocaleDateString('tr-TR'):'—'}</span></div>
      </div>
      <div style="display:flex;gap:0.75rem;margin-top:1.5rem;flex-wrap:wrap">
        <button class="btn-outline" onclick="showPage('orders')">Siparişlerim</button>
      </div>
    </div>
  </div>`;
}

// Scroll reveal (called from effects.js too)
function observeReveal() {
  document.querySelectorAll('[data-reveal]:not(.revealed)').forEach(el=>{
    const rect=el.getBoundingClientRect();
    if (rect.top < window.innerHeight * 0.9) el.classList.add('revealed');
  });
}
window.addEventListener('scroll',()=>{observeReveal();},{ passive:true });

// Init
document.addEventListener('DOMContentLoaded',()=>{
  const user=UserStorage.get();
  if (user) updateNav(user);
  updateCartBadge();
  loadFeatured();
  setTimeout(observeReveal, 300);
  window.addEventListener('storage',e=>{ if(e.key==='ptCart') updateCartBadge(); });
});

/* ─── UYGULAMA DURUMU ─────────────────────────────────────────── */
let currentPage = 'dashboard';
let currentUser = null;
let adminLiveWS = null;
let logsPollInterval = null;
const liveSeenKeys = new Set();
const _productCache = {};

// Backend origin — api.js'deki SERVER_BASE ile eşleşmeli
window.BACKEND_ORIGIN = 'http://100.114.176.17:8000';

/* ─── YARDIMCI FONKSİYONLAR ──────────────────────────────────── */

function toast(msg, type = 'default') {
  const el = document.createElement('div');
  el.className = `toast ${type}`;
  el.textContent = msg;
  document.getElementById('toast-container').appendChild(el);
  setTimeout(() => el.remove(), 3500);
}

function showModal(title, bodyHTML, onSubmit = null) {
  document.getElementById('modal-title').textContent = title;
  document.getElementById('modal-body').innerHTML = bodyHTML;
  document.getElementById('modal-overlay').classList.remove('hidden');
  if (onSubmit) {
    const form = document.querySelector('#modal-body form');
    if (form) form.addEventListener('submit', async (e) => { e.preventDefault(); await onSubmit(); });
  }
}

function hideModal() {
  document.getElementById('modal-overlay').classList.add('hidden');
}

function loading() {
  return `<div class="loading"><div class="spinner"></div> Yükleniyor...</div>`;
}

function empty(msg = 'Kayıt bulunamadı', icon = '📭') {
  return `<div class="empty-state"><span class="empty-icon">${icon}</span><p>${msg}</p></div>`;
}

function fmt(date) {
  if (!date) return '-';
  return new Date(date).toLocaleString('tr-TR', { day: '2-digit', month: '2-digit', year: 'numeric', hour: '2-digit', minute: '2-digit' });
}

function fmtMoney(n) {
  return (n || 0).toLocaleString('tr-TR', { minimumFractionDigits: 2, maximumFractionDigits: 2 }) + ' ₺';
}

function badge(text, cls) {
  return `<span class="badge badge-${cls}">${text}</span>`;
}

function roleBadge(role) {
  return badge(role === 'admin' ? 'Admin' : 'Kullanıcı', role);
}

function statusBadge(status) {
  const map = { pending: 'Bekliyor', paid: 'Ödendi', shipped: 'Kargoda',
                delivered: 'Teslim Edildi', cancelled: 'İptal' };
  return badge(map[status] || status, status);
}

function activeBadge(active) {
  return active ? badge('Aktif', 'active') : badge('Pasif', 'inactive');
}

const CMD_COLORS = {
  forward:  '#22c55e',
  backward: '#ef4444',
  left:     '#3b82f6',
  right:    '#f59e0b',
  stop:     '#6b7280',
};

const CAT_LABELS = { Araba: 'Araba', Aksesuar: 'Aksesuar' };
function normalizeCategory(cat) {
  const value = (cat || '').trim();
  const map = { araba: 'Araba', aksesuar: 'Aksesuar' };
  return map[value.toLowerCase()] || value;
}
function catLabel(cat) { return CAT_LABELS[normalizeCategory(cat)] || cat || '-'; }

function cmdBadge(cmd) {
  const color = CMD_COLORS[cmd] || '#6b7280';
  return `<span class="badge" style="background:${color}20;color:${color};border:1px solid ${color}40;font-weight:700">${cmd}</span>`;
}

/* ─── SAYFA GEÇİŞİ ───────────────────────────────────────────── */

function navigate(page) {
  const visiblePages = ['dashboard', 'users', 'orders', 'products'];
  if (!visiblePages.includes(page)) {
    page = 'dashboard';
    if (location.hash && location.hash !== '#dashboard') location.hash = '#dashboard';
  }

  if (currentPage === 'logs' && page !== 'logs') {
    stopAdminLiveWS();
    stopLogsPolling();
  }
  currentPage = page;

  document.querySelectorAll('.nav-item').forEach(el => {
    el.classList.toggle('active', el.dataset.page === page);
  });

  const titles = {
    dashboard: 'Dashboard', users: 'Kullanıcılar', orders: 'Siparişler',
    products: 'Ürünler',
  };
  document.getElementById('page-title').textContent = titles[page] || page;
  document.getElementById('topbar-actions').innerHTML = '';
  document.getElementById('content').innerHTML = loading();

  switch (page) {
    case 'dashboard': renderDashboard(); break;
    case 'users':     renderUsers();     break;
    case 'orders':    renderOrders();    break;
    case 'products':  renderProducts();  break;
  }
}

/* ─── AUTH ────────────────────────────────────────────────────── */

async function init() {
  const token = localStorage.getItem('sc_token');
  if (token) {
    try {
      currentUser = JSON.parse(localStorage.getItem('sc_user') || 'null') || await API.me();
      if (currentUser.role !== 'admin') throw new Error('Yetkisiz');
      showApp();
    } catch {
      localStorage.removeItem('sc_token');
      localStorage.removeItem('sc_user');
      showLogin();
    }
  } else {
    showLogin();
  }
}

function showLogin() {
  document.getElementById('login-screen').classList.remove('hidden');
  document.getElementById('app').classList.add('hidden');
}

function showApp() {
  document.getElementById('login-screen').classList.add('hidden');
  document.getElementById('app').classList.remove('hidden');
  document.getElementById('sidebar-user').innerHTML =
    `<strong>${currentUser.username}</strong>${currentUser.email}`;
  const hash = location.hash.replace('#', '') || 'dashboard';
  navigate(hash);
}

/* ─── SEKME GEÇİŞİ ───────────────────────────────────────────── */
document.querySelectorAll('.tab-btn').forEach(btn => {
  btn.addEventListener('click', () => {
    document.querySelectorAll('.tab-btn').forEach(b => b.classList.remove('active'));
    btn.classList.add('active');
    const tab = btn.dataset.tab;
    document.getElementById('tab-login').classList.toggle('hidden', tab !== 'login');
    document.getElementById('tab-register').classList.toggle('hidden', tab !== 'register');
  });
});

/* ─── KAYIT FORMU ─────────────────────────────────────────────── */
document.getElementById('register-form').addEventListener('submit', async (e) => {
  e.preventDefault();
  const btn = document.getElementById('register-btn');
  const err = document.getElementById('register-error');
  const suc = document.getElementById('register-success');
  err.classList.add('hidden'); suc.classList.add('hidden');
  btn.disabled = true; btn.textContent = 'Oluşturuluyor...';
  try {
    await API.adminRegister({
      full_name: document.getElementById('reg-fullname').value,
      username:  document.getElementById('reg-username').value,
      email:     document.getElementById('reg-email').value,
      password:  document.getElementById('reg-password').value,
      phone:     document.getElementById('reg-phone').value || undefined,
    });
    suc.textContent = 'Admin hesabı oluşturuldu! Şimdi giriş yapabilirsiniz.';
    suc.classList.remove('hidden');
    document.getElementById('register-form').reset();
    setTimeout(() => document.querySelector('[data-tab="login"]').click(), 2000);
  } catch (ex) {
    err.textContent = ex.message; err.classList.remove('hidden');
  } finally {
    btn.disabled = false; btn.textContent = 'Hesap Oluştur';
  }
});

/* ─── GİRİŞ FORMU ────────────────────────────────────────────── */
document.getElementById('login-form').addEventListener('submit', async (e) => {
  e.preventDefault();
  const btn = document.getElementById('login-btn');
  const err = document.getElementById('login-error');
  err.classList.add('hidden'); btn.disabled = true; btn.textContent = 'Giriş yapılıyor...';
  try {
    const { access_token, refresh_token } = await API.login(
      document.getElementById('login-email').value,
      document.getElementById('login-password').value,
    );
    localStorage.setItem('sc_token', access_token);
    if (refresh_token) localStorage.setItem('sc_refresh_token', refresh_token);
    currentUser = await API.me();
    if (currentUser.role !== 'admin') throw new Error('Bu hesabın admin yetkisi yok.');
    localStorage.setItem('sc_user', JSON.stringify(currentUser));
    showApp();
  } catch (ex) {
    err.textContent = ex.message; err.classList.remove('hidden');
  } finally {
    btn.disabled = false; btn.textContent = 'Giriş Yap';
  }
});

document.getElementById('logout-btn').addEventListener('click', () => {
  localStorage.removeItem('sc_token');
  localStorage.removeItem('sc_refresh_token');
  localStorage.removeItem('sc_user');
  currentUser = null; showLogin();
});

document.getElementById('modal-close-btn').addEventListener('click', hideModal);
document.getElementById('modal-overlay').addEventListener('click', (e) => {
  if (e.target === document.getElementById('modal-overlay')) hideModal();
});

window.addEventListener('hashchange', () => {
  const page = location.hash.replace('#', '') || 'dashboard';
  if (page !== currentPage) navigate(page);
});

/* ─── DASHBOARD ───────────────────────────────────────────────── */

function drawBarChart(canvasId, labels, values, color, unit) {
  const canvas = document.getElementById(canvasId);
  if (!canvas) return;
  const ctx = canvas.getContext('2d');
  const W = canvas.width, H = canvas.height;
  const pad = { top: 20, right: 12, bottom: 36, left: 56 };
  const cW = W - pad.left - pad.right;
  const cH = H - pad.top - pad.bottom;
  const max = Math.max(...values, 1);

  ctx.clearRect(0, 0, W, H);

  for (let i = 0; i <= 4; i++) {
    const y = pad.top + cH - (i / 4) * cH;
    ctx.strokeStyle = '#e2e8f0'; ctx.lineWidth = 1;
    ctx.beginPath(); ctx.moveTo(pad.left, y); ctx.lineTo(W - pad.right, y); ctx.stroke();
    const val = max * i / 4;
    const lbl = unit === '\u20ba'
      ? (val >= 1000 ? (val/1000).toFixed(1) + 'K' : val.toFixed(0)) + '\u20ba'
      : Math.round(val).toString();
    ctx.fillStyle = '#94a3b8'; ctx.font = '10px system-ui'; ctx.textAlign = 'right';
    ctx.fillText(lbl, pad.left - 4, y + 3);
  }

  const gap = cW / labels.length;
  const barW = Math.max(Math.floor(gap * 0.55), 8);
  labels.forEach((lbl, i) => {
    const bH = (values[i] / max) * cH;
    const x = pad.left + i * gap + (gap - barW) / 2;
    const y = pad.top + cH - bH;
    const grad = ctx.createLinearGradient(0, y, 0, y + bH);
    grad.addColorStop(0, color);
    grad.addColorStop(1, color + '55');
    ctx.fillStyle = grad;
    ctx.beginPath();
    if (ctx.roundRect) ctx.roundRect(x, y, barW, bH, [3, 3, 0, 0]);
    else ctx.rect(x, y, barW, bH);
    ctx.fill();
    if (values[i] > 0) {
      ctx.fillStyle = '#475569'; ctx.font = 'bold 9px system-ui'; ctx.textAlign = 'center';
      const v = unit === '\u20ba'
        ? (values[i] >= 1000 ? (values[i]/1000).toFixed(1)+'K' : values[i].toFixed(0))
        : values[i].toString();
      ctx.fillText(v, x + barW / 2, y - 4);
    }
    ctx.fillStyle = '#64748b'; ctx.font = '10px system-ui'; ctx.textAlign = 'center';
    ctx.fillText(lbl, x + barW / 2, H - 8);
  });
}

async function renderDashboard() {
  try {
    const [d, charts, recentRes, lowStockRes] = await Promise.all([
      API.dashboard(),
      API.charts(),
      API.recentOrders(),
      API.lowStock(),
    ]);

    const users = d?.users || {}, orders = d?.orders || {}, revenue = d?.revenue || {};
    const products = d?.products || {};
    const byStatus = orders?.by_status || {};
    const recentOrders = recentRes?.orders || [];
    const lowStockItems = lowStockRes?.products || [];
    const revChart = charts?.revenue_chart || [];
    const ordChart = charts?.orders_chart || [];

    document.getElementById('content').innerHTML = `
      <div class="stats-grid">
        <div class="stat-card blue"><span class="stat-label">Toplam Kullan\u0131c\u0131</span><span class="stat-value">${users.total ?? 0}</span><span class="stat-sub">Aktif: ${users.active ?? 0} \u00b7 Bug\u00fcn +${users.new_today ?? 0}</span></div>
        <div class="stat-card green"><span class="stat-label">Toplam Sipari\u015f</span><span class="stat-value">${orders.total ?? 0}</span><span class="stat-sub">Bekleyen: ${byStatus.pending ?? 0} \u00b7 Bug\u00fcn: ${orders.today ?? 0}</span></div>
        <div class="stat-card yellow"><span class="stat-label">Toplam Gelir</span><span class="stat-value">${fmtMoney(revenue.total)}</span><span class="stat-sub">Bug\u00fcn: ${fmtMoney(revenue.today)}</span></div>
        <div class="stat-card"><span class="stat-label">\u00dcr\u00fcnler</span><span class="stat-value">${products.active ?? 0}</span><span class="stat-sub">D\u00fc\u015f\u00fck stok: ${products.low_stock ?? 0}</span></div>
      </div>

      <div class="section-grid" style="margin-top:20px">
        <div class="card">
          <div class="card-header"><span class="card-title">\ud83d\udcc8 G\u00fcnl\u00fck Gelir (Son 30 G\u00fcn)</span></div>
          <canvas id="revenue-chart" width="700" height="190" style="width:100%;display:block"></canvas>
        </div>
        <div class="card">
          <div class="card-header"><span class="card-title">\ud83d\udce6 Sipari\u015f Say\u0131s\u0131 (Son 30 G\u00fcn)</span></div>
          <canvas id="orders-chart" width="700" height="190" style="width:100%;display:block"></canvas>
        </div>
      </div>

      <div class="section-grid" style="margin-top:20px">
        <div class="card">
          <div class="card-header"><span class="card-title">\ud83e\uddfe Son Sipari\u015fler</span></div>
          ${recentOrders.length === 0
            ? `<p style="color:var(--text-muted);font-size:13px;padding:8px 0">Hen\u00fcz sipari\u015f yok.</p>`
            : `<table style="width:100%">
                <thead><tr><th>ID</th><th>Toplam</th><th>Durum</th><th>Tarih</th></tr></thead>
                <tbody>${recentOrders.map(o => `
                <tr>
                  <td><code style="font-size:11px">${o.id.slice(-8)}</code></td>
                  <td><strong>${fmtMoney(o.total)}</strong></td>
                  <td>${statusBadge(o.status)}</td>
                  <td style="font-size:12px;color:var(--text-muted)">${fmt(o.created_at)}</td>
                </tr>`).join('')}</tbody>
              </table>`}
        </div>
        <div class="card">
          <div class="card-header"><span class="card-title">\u26a0\ufe0f D\u00fc\u015f\u00fck Stok (\u226410)</span></div>
          ${lowStockItems.length === 0
            ? `<p style="color:var(--text-muted);font-size:13px;padding:8px 0">D\u00fc\u015f\u00fck stoklu \u00fcr\u00fcn yok \ud83c\udf89</p>`
            : `<table style="width:100%">
                <thead><tr><th>\u00dcr\u00fcn</th><th>Stok</th></tr></thead>
                <tbody>${lowStockItems.map(p => `
                <tr>
                  <td>${p.name?.tr || p.name}</td>
                  <td><span style="color:${p.stock<=3?'var(--danger)':'var(--warning)'};font-weight:700">${p.stock}</span></td>
                </tr>`).join('')}</tbody>
              </table>`}
        </div>
      </div>`;

    requestAnimationFrame(() => {
      drawBarChart('revenue-chart', revChart.map(r => r.date), revChart.map(r => r.total), '#22c55e', '\u20ba');
      drawBarChart('orders-chart',  ordChart.map(r => r.date), ordChart.map(r => r.count), '#3b82f6', '');
    });

  } catch (ex) {
    document.getElementById('content').innerHTML = `<div class="alert alert-danger">Dashboard y\u00fcklenemedi: ${ex.message}</div>`;
  }
}

/* ─── KULLANICILAR ────────────────────────────────────────────── */

let usersPage = 1;
const usersLimit = 20;

async function renderUsers(page = 1) {
  usersPage = page;
  const searchVal = document.getElementById('user-search')?.value || '';
  const roleVal = document.getElementById('user-role-filter')?.value || '';

  document.getElementById('topbar-actions').innerHTML =
    `<button class="btn btn-outline btn-sm" onclick="openCreateAdmin()" style="margin-right:8px">+ Admin Ekle</button>` +
    `<button class="btn btn-primary btn-sm" onclick="openCreateUser()">+ Yeni Kullanıcı Ekle</button>`;

  try {
    const params = { page, limit: usersLimit };
    if (searchVal) params.search = searchVal;
    if (roleVal) params.role = roleVal;
    const { users, total } = await API.getUsers(params);
    const totalPages = Math.ceil(total / usersLimit);

    document.getElementById('content').innerHTML = `
      <div class="card">
        <div class="filters">
          <div class="form-group"><input type="text" id="user-search" placeholder="Ad, email, kullanıcı ara..." value="${searchVal}" /></div>
          <div class="form-group">
            <select id="user-role-filter">
              <option value="">Tüm Roller</option>
              <option value="admin" ${roleVal==='admin'?'selected':''}>Admin</option>
              <option value="user" ${roleVal==='user'?'selected':''}>Kullanıcı</option>
            </select>
          </div>
          <button class="btn btn-primary btn-sm" id="user-search-btn">Ara</button>
        </div>
        <div class="table-wrapper">
          <table>
            <thead><tr><th>Kullanıcı</th><th>E-posta</th><th>Rol</th><th>Kayıt Tarihi</th><th>İşlem</th></tr></thead>
            <tbody>
              ${users.length === 0 ? `<tr><td colspan="5">${empty()}</td></tr>` : users.map(u => `
              <tr>
                <td><strong>${u.username}</strong><br><small style="color:var(--text-muted)">${u.full_name || ''}</small></td>
                <td>${u.email}</td>
                <td>${roleBadge(u.role)}</td>
                <td>${fmt(u.created_at)}</td>
                <td>
                  <button class="btn btn-outline btn-sm" onclick="openEditUser('${u.id}')">Düzenle</button>
                  <button class="btn btn-danger btn-sm" style="margin-left:4px" onclick="confirmDeleteUser('${u.id}','${u.username}')">Sil</button>
                </td>
              </tr>`).join('')}
            </tbody>
          </table>
        </div>
        <div class="pagination">
          <span class="pagination-info">Toplam ${total} kullanıcı — Sayfa ${page}/${totalPages || 1}</span>
          <div class="pagination-btns">
            <button class="btn btn-outline btn-sm" ${page<=1?'disabled':''} onclick="renderUsers(${page-1})">← Önceki</button>
            <button class="btn btn-outline btn-sm" ${page>=totalPages?'disabled':''} onclick="renderUsers(${page+1})">Sonraki →</button>
          </div>
        </div>
      </div>`;

    document.getElementById('user-search-btn').addEventListener('click', () => renderUsers(1));
    document.getElementById('user-search').addEventListener('keydown', e => { if (e.key==='Enter') renderUsers(1); });
  } catch (ex) {
    document.getElementById('content').innerHTML = `<div class="alert alert-danger">Kullanıcılar yüklenemedi: ${ex.message}</div>`;
  }
}

function openCreateAdmin() {
  showModal('Yeni Admin Ekle', `
    <form id="create-admin-form">
      <div class="form-group"><label>Ad Soyad *</label><input type="text" id="ca-fullname" required /></div>
      <div class="form-group"><label>Kullanıcı Adı *</label><input type="text" id="ca-username" required /></div>
      <div class="form-group"><label>E-posta *</label><input type="email" id="ca-email" required /></div>
      <div class="form-group"><label>Şifre *</label><input type="password" id="ca-password" required minlength="6" /></div>
      <div class="form-group"><label>Telefon</label><input type="text" id="ca-phone" /></div>
      <div class="modal-footer">
        <button type="button" class="btn btn-outline" onclick="hideModal()">İptal</button>
        <button type="submit" class="btn btn-primary">Admin Oluştur</button>
      </div>
    </form>`);
  document.getElementById('create-admin-form').addEventListener('submit', async (e) => {
    e.preventDefault();
    const btn = e.target.querySelector('[type="submit"]');
    btn.disabled = true; btn.textContent = 'Oluşturuluyor...';
    try {
      await API.createUser({ full_name: document.getElementById('ca-fullname').value, username: document.getElementById('ca-username').value, email: document.getElementById('ca-email').value, password: document.getElementById('ca-password').value, phone: document.getElementById('ca-phone').value || undefined, role: 'admin' });
      hideModal(); toast('Admin hesabı oluşturuldu', 'success'); renderUsers(usersPage);
    } catch (ex) { toast(ex.message, 'error'); btn.disabled = false; btn.textContent = 'Admin Oluştur'; }
  });
}

function openCreateUser() {
  showModal('Yeni Kullanıcı Ekle', `
    <form id="create-user-form">
      <div class="form-group"><label>Ad Soyad *</label><input type="text" id="cu-fullname" required /></div>
      <div class="form-group"><label>Kullanıcı Adı *</label><input type="text" id="cu-username" required /></div>
      <div class="form-group"><label>E-posta *</label><input type="email" id="cu-email" required /></div>
      <div class="form-group"><label>Şifre *</label><input type="password" id="cu-password" required minlength="6" /></div>
      <div class="form-group"><label>Telefon</label><input type="text" id="cu-phone" /></div>
      <div class="form-group"><label>Rol</label><select id="cu-role"><option value="user">Kullanıcı</option><option value="admin">Admin</option></select></div>
      <div class="modal-footer">
        <button type="button" class="btn btn-outline" onclick="hideModal()">İptal</button>
        <button type="submit" class="btn btn-primary">Oluştur</button>
      </div>
    </form>`);
  document.getElementById('create-user-form').addEventListener('submit', async (e) => {
    e.preventDefault();
    const btn = e.target.querySelector('[type="submit"]');
    btn.disabled = true; btn.textContent = 'Oluşturuluyor...';
    try {
      await API.createUser({ full_name: document.getElementById('cu-fullname').value, username: document.getElementById('cu-username').value, email: document.getElementById('cu-email').value, password: document.getElementById('cu-password').value, phone: document.getElementById('cu-phone').value || undefined, role: document.getElementById('cu-role').value });
      hideModal(); toast('Kullanıcı oluşturuldu', 'success'); renderUsers(usersPage);
    } catch (ex) { toast(ex.message, 'error'); btn.disabled = false; btn.textContent = 'Oluştur'; }
  });
}

async function openEditUser(id) {
  try {
    const u = await API.getUser(id);
    showModal('Kullanıcı Düzenle', `
      <form id="edit-user-form">
        <div class="form-group"><label>Kullanıcı Adı</label><input type="text" value="${u.username}" disabled /></div>
        <div class="form-group"><label>Ad Soyad</label><input type="text" id="eu-fullname" value="${u.full_name || ''}" /></div>
        <div class="form-group"><label>Rol</label><select id="eu-role"><option value="user" ${u.role==='user'?'selected':''}>Kullanıcı</option><option value="admin" ${u.role==='admin'?'selected':''}>Admin</option></select></div>
        <div class="form-group"><label>Durum</label><select id="eu-active"><option value="true" ${u.is_active?'selected':''}>Aktif</option><option value="false" ${!u.is_active?'selected':''}>Pasif</option></select></div>
        <div class="form-group" style="background:#f8fafc;border-radius:8px;padding:12px">
          <small style="color:var(--text-muted)">Sipariş sayısı: <strong>${u.stats?.order_count ?? '-'}</strong> &nbsp;|&nbsp; Toplam harcama: <strong>${fmtMoney(u.stats?.total_spent)}</strong></small>
        </div>
        <div class="modal-footer">
          <button type="button" class="btn btn-outline" onclick="hideModal()">İptal</button>
          <button type="submit" class="btn btn-primary">Kaydet</button>
        </div>
      </form>`);
    document.getElementById('edit-user-form').addEventListener('submit', async (e) => {
      e.preventDefault();
      try {
        await API.updateUser(id, { role: document.getElementById('eu-role').value, is_active: document.getElementById('eu-active').value === 'true', full_name: document.getElementById('eu-fullname').value || undefined });
        hideModal(); toast('Kullanıcı güncellendi', 'success'); renderUsers(usersPage);
      } catch (ex) { toast(ex.message, 'error'); }
    });
  } catch (ex) { toast(ex.message, 'error'); }
}

function confirmDeleteUser(id, username) {
  showModal('Kullanıcıyı Sil', `
    <p><strong>${username}</strong> adlı kullanıcıyı kalıcı olarak silmek istediğinize emin misiniz?</p>
    <p style="margin-top:8px;color:var(--text-muted);font-size:13px">Bu işlem geri alınamaz.</p>
    <div class="modal-footer">
      <button class="btn btn-outline" onclick="hideModal()">İptal</button>
      <button class="btn btn-danger" onclick="deleteUser('${id}')">Kalıcı Sil</button>
    </div>`);
}

async function deleteUser(id) {
  try { await API.deleteUser(id); hideModal(); toast('Kullanıcı silindi', 'success'); renderUsers(usersPage); }
  catch (ex) { toast(ex.message, 'error'); }
}

/* ─── SİPARİŞLER ─────────────────────────────────────────────── */

let ordersPage = 1;
const ordersLimit = 20;

async function renderOrders(page = 1) {
  ordersPage = page;
  const statusVal = document.getElementById('order-status-filter')?.value || '';
  try {
    const params = { page, limit: ordersLimit };
    if (statusVal) params.status = statusVal;
    const { orders, total } = await API.getOrders(params);
    const totalPages = Math.ceil(total / ordersLimit);

    document.getElementById('content').innerHTML = `
      <div class="card">
        <div class="filters">
          <div class="form-group">
            <select id="order-status-filter">
              <option value="">Tüm Durumlar</option>
              <option value="pending" ${statusVal==='pending'?'selected':''}>Bekliyor</option>
              <option value="paid" ${statusVal==='paid'?'selected':''}>Ödendi</option>
              <option value="shipped" ${statusVal==='shipped'?'selected':''}>Kargoda</option>
              <option value="delivered" ${statusVal==='delivered'?'selected':''}>Teslim Edildi</option>
              <option value="cancelled" ${statusVal==='cancelled'?'selected':''}>İptal</option>
            </select>
          </div>
          <button class="btn btn-primary btn-sm" id="order-filter-btn">Filtrele</button>
        </div>
        <div class="table-wrapper">
          <table>
            <thead><tr><th>Sipariş ID</th><th>Kullanıcı</th><th>Toplam</th><th>Durum</th><th>Tarih</th><th>İşlem</th></tr></thead>
            <tbody>
              ${orders.length === 0 ? `<tr><td colspan="6">${empty('Sipariş bulunamadı', '📦')}</td></tr>` : orders.map(o => `
              <tr>
                <td><code style="font-size:11px">${o.id.slice(-8)}</code></td>
                <td>${o.user ? `<strong>${o.user.username}</strong><br><small style="color:var(--text-muted)">${o.user.email}</small>` : `<code style="font-size:11px">${o.user_id.slice(-8)}</code>`}</td>
                <td><strong>${fmtMoney(o.total)}</strong></td>
                <td>${statusBadge(o.status)}</td>
                <td>${fmt(o.created_at)}</td>
                <td>
                  <button class="btn btn-outline btn-sm" onclick="openOrderDetail('${o.id}')">Detay</button>
                  <button class="btn btn-primary btn-sm" style="margin-left:4px" onclick="openUpdateOrderStatus('${o.id}','${o.status}')">Durum</button>
                </td>
              </tr>`).join('')}
            </tbody>
          </table>
        </div>
        <div class="pagination">
          <span class="pagination-info">Toplam ${total} sipariş — Sayfa ${page}/${totalPages || 1}</span>
          <div class="pagination-btns">
            <button class="btn btn-outline btn-sm" ${page<=1?'disabled':''} onclick="renderOrders(${page-1})">← Önceki</button>
            <button class="btn btn-outline btn-sm" ${page>=totalPages?'disabled':''} onclick="renderOrders(${page+1})">Sonraki →</button>
          </div>
        </div>
      </div>`;
    document.getElementById('order-filter-btn').addEventListener('click', () => renderOrders(1));
  } catch (ex) {
    document.getElementById('content').innerHTML = `<div class="alert alert-danger">Siparişler yüklenemedi: ${ex.message}</div>`;
  }
}

async function openOrderDetail(id) {
  try {
    const o = await API.getOrder(id);
    showModal(`Sipariş Detayı`, `
      <div style="margin-bottom:12px"><small style="color:var(--text-muted)">Sipariş ID</small><div><code>${o.id}</code></div></div>
      ${o.user ? `<div style="margin-bottom:12px"><small style="color:var(--text-muted)">Kullanıcı</small><div><strong>${o.user.username}</strong> (${o.user.email})</div></div>` : ''}
      <div style="margin-bottom:12px"><small style="color:var(--text-muted)">Durum</small><div>${statusBadge(o.status)}</div></div>
      <div style="margin-bottom:12px">
        <small style="color:var(--text-muted)">Ürünler</small>
        <table style="width:100%;margin-top:6px">
          <thead><tr><th>Ürün</th><th>Adet</th><th>Fiyat</th></tr></thead>
          <tbody>${(o.items||[]).map(item => `<tr><td>${typeof item.name === 'object' ? item.name.tr : item.name}</td><td>${item.quantity}</td><td>${fmtMoney(item.price * item.quantity)}</td></tr>`).join('')}</tbody>
        </table>
      </div>
      <div style="text-align:right;font-size:16px;font-weight:700">Toplam: ${fmtMoney(o.total)}</div>
      <div class="modal-footer">
        <button class="btn btn-outline" onclick="hideModal()">Kapat</button>
        <button class="btn btn-primary" onclick="hideModal();openUpdateOrderStatus('${o.id}','${o.status}')">Durumu Güncelle</button>
      </div>`);
  } catch (ex) { toast(ex.message, 'error'); }
}

function openUpdateOrderStatus(id, currentStatus) {
  const statuses = ['pending', 'paid', 'shipped', 'delivered', 'cancelled'];
  const labels = { pending:'Bekliyor', paid:'Ödendi', shipped:'Kargoda', delivered:'Teslim Edildi', cancelled:'İptal' };
  showModal('Sipariş Durumunu Güncelle', `
    <form id="order-status-form">
      <div class="form-group"><label>Yeni Durum</label>
        <select id="new-order-status">${statuses.map(s => `<option value="${s}" ${s===currentStatus?'selected':''}>${labels[s]}</option>`).join('')}</select>
      </div>
      <div class="modal-footer">
        <button type="button" class="btn btn-outline" onclick="hideModal()">İptal</button>
        <button type="submit" class="btn btn-primary">Güncelle</button>
      </div>
    </form>`);
  document.getElementById('order-status-form').addEventListener('submit', async (e) => {
    e.preventDefault();
    try {
      await API.updateOrderStatus(id, document.getElementById('new-order-status').value);
      hideModal(); toast('Sipariş durumu güncellendi', 'success'); renderOrders(ordersPage);
    } catch (ex) { toast(ex.message, 'error'); }
  });
}

/* ─── ÜRÜNLER ─────────────────────────────────────────────────── */

let productsPage = 1;
const productsLimit = 20;
let _pendingProductImages = [];
let _isUploadingProductImage = false;

async function renderProducts(page = 1) {
  productsPage = page;
  document.getElementById('topbar-actions').innerHTML = `<button class="btn btn-primary" onclick="openAddProduct()">+ Ürün Ekle</button>`;

  const lowStock = document.getElementById('low-stock-filter')?.checked || false;
  const showInactive = document.getElementById('inactive-filter')?.checked || false;

  try {
    const params = { page, limit: productsLimit };
    if (lowStock) params.low_stock_only = true;
    if (showInactive) params.include_inactive = true;

    const { products, total } = await API.getAdminProducts(params);
    const totalPages = Math.ceil(total / productsLimit);

    products.forEach(p => { _productCache[p.id] = p; });

    document.getElementById('content').innerHTML = `
      <div class="card">
        <div class="filters" style="align-items:center">
          <label style="display:flex;align-items:center;gap:6px;cursor:pointer"><input type="checkbox" id="low-stock-filter" ${lowStock?'checked':''} onchange="renderProducts(1)" /> Düşük Stok</label>
          <label style="display:flex;align-items:center;gap:6px;cursor:pointer"><input type="checkbox" id="inactive-filter" ${showInactive?'checked':''} onchange="renderProducts(1)" /> Pasifleri Göster</label>
        </div>
        <div class="table-wrapper">
          <table>
            <thead><tr><th>Ürün</th><th>Fiyat</th><th>Stok</th><th>Kategori</th><th>Durum</th><th>İşlem</th></tr></thead>
            <tbody>
              ${products.length === 0 ? `<tr><td colspan="6">${empty('Ürün bulunamadı', '🛒')}</td></tr>` : products.map(p => {
                const nameTR = p.name?.tr || p.name || '-';
                const nameEN = p.name?.en || '';
                const imgUrl = p.images && p.images[0] ? resolveProductImageUrl(p.images[0]) : '';
                return `<tr>
                  <td style="display:flex;align-items:center;gap:10px;min-width:200px">
                    ${imgUrl
                      ? `<img src="${imgUrl}" alt="${nameTR}" onerror="this.style.display='none'" style="width:44px;height:44px;object-fit:cover;border-radius:6px;border:1px solid var(--border);flex-shrink:0">`
                      : `<div style="width:44px;height:44px;border-radius:6px;background:var(--border);flex-shrink:0;display:flex;align-items:center;justify-content:center;font-size:18px">📦</div>`}
                    <div>
                      <strong>${nameTR}</strong>
                      ${nameEN ? `<br><small style="color:var(--text-muted)">${nameEN}</small>` : ''}
                      <div style="margin-top:2px">${(p.tags||[]).map(t => `<span class="tag">${t}</span>`).join('')}</div>
                    </div>
                  </td>
                  <td>${fmtMoney(p.price)}</td>
                  <td><span style="color:${p.stock<=5?'var(--danger)':p.stock<=20?'var(--warning)':'inherit'};font-weight:600">${p.stock}</span></td>
                  <td>${catLabel(p.category)}</td>
                  <td>${p.is_active ? badge('Aktif','active') : badge('Pasif','inactive')}</td>
                  <td>
                    <button class="btn btn-outline btn-sm" onclick="openEditProduct('${p.id}')">Düzenle</button>
                    <button class="btn btn-danger btn-sm" style="margin-left:4px" onclick="confirmDeleteProduct('${p.id}','${nameTR.replace(/'/g,'')}')">Sil</button>
                  </td>
                </tr>`;}).join('')}
            </tbody>
          </table>
        </div>
        <div class="pagination">
          <span class="pagination-info">Toplam ${total} ürün — Sayfa ${page}/${totalPages || 1}</span>
          <div class="pagination-btns">
            <button class="btn btn-outline btn-sm" ${page<=1?'disabled':''} onclick="renderProducts(${page-1})">← Önceki</button>
            <button class="btn btn-outline btn-sm" ${page>=totalPages?'disabled':''} onclick="renderProducts(${page+1})">Sonraki →</button>
          </div>
        </div>
      </div>`;
  } catch (ex) {
    document.getElementById('content').innerHTML = `<div class="alert alert-danger">Ürünler yüklenemedi: ${ex.message}</div>`;
  }
}

function productFormHTML(p = null) {
  const v = p || {};
  return `
    <div id="product-form">
      <div class="form-row">
        <div class="form-group"><label>Ürün Adı (TR)</label><input type="text" id="pf-name-tr" value="${v.name?.tr || ''}" required /></div>
        <div class="form-group"><label>Ürün Adı (EN)</label><input type="text" id="pf-name-en" value="${v.name?.en || ''}" required /></div>
      </div>
      <div class="form-group"><label>Açıklama (TR)</label><textarea id="pf-desc-tr">${v.description?.tr || ''}</textarea></div>
      <div class="form-group"><label>Açıklama (EN)</label><textarea id="pf-desc-en">${v.description?.en || ''}</textarea></div>
      <div class="form-row">
        <div class="form-group"><label>Fiyat (₺)</label><input type="number" id="pf-price" value="${v.price || ''}" min="0" step="0.01" required /></div>
        <div class="form-group"><label>Stok</label><input type="number" id="pf-stock" value="${v.stock ?? ''}" min="0" required /></div>
      </div>
      <div class="form-row">
        <div class="form-group"><label>Kategori</label><select id="pf-category" required>
          <option value="Araba" ${normalizeCategory(v.category) === 'Araba' ? 'selected' : ''}>Araba</option>
          <option value="Aksesuar" ${normalizeCategory(v.category) === 'Aksesuar' ? 'selected' : ''}>Aksesuar</option>
        </select></div>
        <div class="form-group"><label>Etiketler (virgülle)</label><input type="text" id="pf-tags" value="${(v.tags || []).join(', ')}" /></div>
      </div>
      <div class="form-group">
        <label>Görsel Yükle</label>
        <div style="display:flex;align-items:center;gap:8px;flex-wrap:wrap">
          <input type="file" id="pf-image-file" accept="image/*" />
          <button type="button" class="btn btn-outline btn-sm" id="pf-upload-btn">Yükle</button>
          <span id="pf-upload-status" style="font-size:12px;color:var(--text-muted)"></span>
        </div>
        <div id="pf-image-preview" style="margin-top:8px;display:flex;gap:8px;flex-wrap:wrap"></div>
      </div>
      ${p ? `<div class="form-group"><label>Durum</label><select id="pf-active"><option value="true" ${p.is_active?'selected':''}>Aktif</option><option value="false" ${!p.is_active?'selected':''}>Pasif</option></select></div>` : ''}
      <div class="modal-footer">
        <button type="button" class="btn btn-outline" onclick="hideModal()">İptal</button>
        <button type="button" class="btn btn-primary" id="pf-submit-btn">${p ? 'Güncelle' : 'Ekle'}</button>
      </div>
    </div>`;
}

// FIX 1: window.BACKEND_ORIGIN kullanıyor — artık dosyanın başında set edildi
function resolveProductImageUrl(url) {
  if (!url) return '';
  if (url.startsWith('http')) return url;
  if (url.startsWith('/')) return window.BACKEND_ORIGIN + url;
  return url;
}

async function ensureAdminSession() {
  const me = await API.me();
  currentUser = me;
  localStorage.setItem('sc_user', JSON.stringify(me));
  if (me.role !== 'admin') {
    throw new Error('Bu hesabin admin yetkisi yok.');
  }
  return me;
}

function renderProductImagePreview() {
  const preview = document.getElementById('pf-image-preview');
  if (!preview) return;

  preview.innerHTML = _pendingProductImages.map((url, index) => `
    <div style="position:relative;display:inline-flex">
      <img src="${url}" style="width:80px;height:80px;object-fit:cover;border-radius:8px;border:1px solid var(--border)" />
      <button
        type="button"
        class="btn btn-danger btn-sm"
        onclick="removePendingProductImage(${index})"
        style="position:absolute;top:-6px;right:-6px;min-width:24px;height:24px;padding:0;border-radius:999px;line-height:1"
      >×</button>
    </div>
  `).join('');
}

function removePendingProductImage(index) {
  _pendingProductImages.splice(index, 1);
  renderProductImagePreview();
}

function bindUploadBtn(existingUrls = []) {
  return bindProductUploadFlow(existingUrls);
}

function getProductFormData(isEdit = false) {
  return getFixedProductFormData(isEdit);
}

function syncPendingProductImages(existingUrls = []) {
  _pendingProductImages = existingUrls.map(resolveProductImageUrl).filter(Boolean);
  renderProductImagePreview();
}

function bindProductUploadFlow(existingUrls = []) {
  syncPendingProductImages(existingUrls);

  const uploadBtn = document.getElementById('pf-upload-btn');
  if (!uploadBtn) return;
  uploadBtn.type = 'button';

  uploadBtn.onclick = async (event) => {
    event.preventDefault();
    event.stopPropagation();
    event.stopImmediatePropagation();

    const fileInput = document.getElementById('pf-image-file');
    const status = document.getElementById('pf-upload-status');
    const file = fileInput?.files?.[0];

    if (!file) {
      status.textContent = 'Önce bir dosya seçin.';
      status.style.color = 'var(--danger)';
      return;
    }

    _isUploadingProductImage = true;
    uploadBtn.disabled = true;
    status.textContent = 'Yükleniyor...';
    status.style.color = 'var(--text-muted)';

    try {
      const result = await API.uploadImage(file);
      const fullUrl = resolveProductImageUrl(result.url);

      // FIX 2: includes kontrolü kaldırıldı — her yüklenen resim listeye eklenir
      _pendingProductImages.push(fullUrl);

      renderProductImagePreview();
      status.textContent = 'Yüklendi!';
      status.style.color = 'var(--success)';
      fileInput.value = '';
    } catch (ex) {
      status.textContent = 'Hata: ' + ex.message;
      status.style.color = 'var(--danger)';
    } finally {
      _isUploadingProductImage = false;
      uploadBtn.disabled = false;
    }
  };
}

function getFixedProductFormData(isEdit = false) {
  const data = {
    name: {
      tr: document.getElementById('pf-name-tr').value,
      en: document.getElementById('pf-name-en').value,
    },
    description: {
      tr: document.getElementById('pf-desc-tr').value,
      en: document.getElementById('pf-desc-en').value,
    },
    price: parseFloat(document.getElementById('pf-price').value),
    stock: parseInt(document.getElementById('pf-stock').value, 10),
    category: normalizeCategory(document.getElementById('pf-category').value),
    tags: document.getElementById('pf-tags').value.split(',').map(t => t.trim()).filter(Boolean),
    images: [..._pendingProductImages],
  };

  if (isEdit) {
    data.is_active = document.getElementById('pf-active').value === 'true';
  }

  return data;
}

async function submitProductForm(mode, productId = null) {
  const btn = document.getElementById('pf-submit-btn');
  if (!btn) return;

  if (_isUploadingProductImage) {
    toast('Görsel yüklemesi bitmeden kaydedemezsiniz.', 'error');
    return;
  }

  btn.disabled = true;
  btn.textContent = mode === 'edit' ? 'Güncelleniyor...' : 'Ekleniyor...';

  try {
    await ensureAdminSession();

    // Dosya seçilmiş ama Yükle'ye basılmamışsa otomatik yükle
    const fileInput = document.getElementById('pf-image-file');
    if (fileInput && fileInput.files && fileInput.files[0]) {
      btn.textContent = 'Resim yükleniyor...';
      const result = await API.uploadImage(fileInput.files[0]);
      const fullUrl = resolveProductImageUrl(result.url);
      _pendingProductImages.push(fullUrl);
      renderProductImagePreview();
      fileInput.value = '';
      btn.textContent = mode === 'edit' ? 'Güncelleniyor...' : 'Ekleniyor...';
    }

    const payload = getFixedProductFormData(mode === 'edit');

    if (mode === 'edit') {
      await API.updateProduct(productId, payload);
      toast('Ürün güncellendi', 'success');
    } else {
      await API.createProduct(payload);
      toast('Ürün eklendi', 'success');
    }

    hideModal();
    renderProducts(productsPage);
  } catch (ex) {
    toast(ex.message, 'error');
    btn.disabled = false;
    btn.textContent = mode === 'edit' ? 'Güncelle' : 'Ekle';
  }
}

function openAddProduct() {
  // FIX 3: Her açılışta sıfırla
  _pendingProductImages = [];
  _isUploadingProductImage = false;
  showModal('Yeni Ürün Ekle', productFormHTML());
  bindProductUploadFlow([]);
  const submitBtn = document.getElementById('pf-submit-btn');
  if (submitBtn) {
    submitBtn.onclick = () => submitProductForm('create');
  }
}

function openEditProduct(productId) {
  const p = _productCache[productId];
  // FIX 3: Her açılışta sıfırla
  _pendingProductImages = [];
  _isUploadingProductImage = false;
  if (!p) { toast('Ürün bulunamadı', 'error'); return; }
  showModal('Ürün Düzenle', productFormHTML(p));
  bindProductUploadFlow(p.images || []);
  const submitBtn = document.getElementById('pf-submit-btn');
  if (submitBtn) {
    submitBtn.onclick = () => submitProductForm('edit', p.id);
  }
}

function confirmDeleteProduct(id, name) {
  showModal('Ürünü Sil', `
    <p><strong>${name}</strong> adlı ürünü silmek istediğinize emin misiniz?</p>
    <p style="margin-top:8px;color:var(--text-muted);font-size:13px">Ürün pasife alınır, kalıcı silinmez.</p>
    <div class="modal-footer">
      <button class="btn btn-outline" onclick="hideModal()">İptal</button>
      <button class="btn btn-danger" onclick="deleteProduct('${id}')">Sil</button>
    </div>`);
}

async function deleteProduct(id) {
  try { await API.deleteProduct(id); hideModal(); toast('Ürün silindi', 'success'); renderProducts(productsPage); }
  catch (ex) { toast(ex.message, 'error'); }
}

/* ─── KOMUT LOGLARI ────────────────────────────────────────────── */

let logsPage = 1;
const logsLimit = 50;

function startAdminLiveWS() {
  if (adminLiveWS && adminLiveWS.readyState === WebSocket.OPEN) return;
  const token = localStorage.getItem('sc_token');
  if (!token) return;
  const wsOrigin = window.BACKEND_ORIGIN.replace(/^http/i, 'ws');
  adminLiveWS = new WebSocket(`${wsOrigin}/api/v1/ws/admin/live?token=${encodeURIComponent(token)}`);
  adminLiveWS.onopen = () => {
    const dot = document.getElementById('live-dot'), lbl = document.getElementById('live-label');
    if (dot) dot.style.background = '#22c55e';
    if (lbl) lbl.textContent = 'Canlı';
    adminLiveWS._pingInterval = setInterval(() => { if (adminLiveWS.readyState === WebSocket.OPEN) adminLiveWS.send('ping'); }, 30000);
  };
  adminLiveWS.onmessage = (e) => {
    try { const msg = JSON.parse(e.data); if (msg.type === 'live_command') prependLiveRow(msg); } catch {}
  };
  adminLiveWS.onclose = () => {
    clearInterval(adminLiveWS?._pingInterval);
    const dot = document.getElementById('live-dot'), lbl = document.getElementById('live-label');
    if (dot) dot.style.background = '#ef4444'; if (lbl) lbl.textContent = 'Bağlantı kesildi';
  };
  adminLiveWS.onerror = () => {
    const dot = document.getElementById('live-dot'), lbl = document.getElementById('live-label');
    if (dot) dot.style.background = '#f59e0b'; if (lbl) lbl.textContent = 'Hata';
  };
}

function stopAdminLiveWS() {
  if (adminLiveWS) { clearInterval(adminLiveWS._pingInterval); adminLiveWS.close(); adminLiveWS = null; }
}

function makeLiveKey(msg) {
  return [
    msg.id || '',
    msg.timestamp || '',
    msg.car_id || '',
    msg.command || '',
    msg.username || '',
    msg.speed ?? '',
  ].join('|');
}

function prependLiveRow(msg) {
  const key = makeLiveKey(msg);
  if (liveSeenKeys.has(key)) return;
  liveSeenKeys.add(key);

  const tbody = document.getElementById('live-log-tbody');
  if (!tbody) return;
  if (tbody.rows.length === 1 && tbody.rows[0].cells.length === 1) tbody.innerHTML = '';
  while (tbody.rows.length >= 100) tbody.deleteRow(tbody.rows.length - 1);
  const tr = document.createElement('tr');
  tr.innerHTML = `
    <td>${cmdBadge(msg.command)}</td>
    <td><strong>${msg.username || '?'}</strong></td>
    <td>${msg.car_id}</td>
    <td>${msg.speed ?? '-'}</td>
    <td>${(msg.x_axis ?? 0).toFixed(2)}</td>
    <td>${(msg.y_axis ?? 0).toFixed(2)}</td>
    <td>${msg.latency_ms != null ? msg.latency_ms + ' ms' : '-'}</td>
    <td><span style="color:${msg.car_reached ? '#22c55e' : '#ef4444'}">${msg.car_reached ? '✓' : '✗'}</span></td>
    <td>${fmt(msg.timestamp)}</td>`;
  tbody.insertBefore(tr, tbody.firstChild);
  const counter = document.getElementById('live-count');
  if (counter) counter.textContent = parseInt(counter.textContent || '0') + 1;
}

async function pollLatestLogs() {
  if (currentPage !== 'logs') return;
  try {
    const { logs } = await API.getLogs({ page: 1, limit: 20, hours: 168 });
    logs.slice().reverse().forEach((log) => {
      prependLiveRow({
        id: log.id,
        username: log.username || (log.user_id ? log.user_id.slice(-8) : '?'),
        car_id: log.car_id,
        command: log.command,
        speed: log.speed,
        x_axis: log.x_axis ?? 0,
        y_axis: log.y_axis ?? 0,
        latency_ms: log.latency_ms,
        car_reached: log.car_reached ?? true,
        timestamp: log.timestamp,
      });
    });
  } catch {}
}

function startLogsPolling() {
  stopLogsPolling();
  pollLatestLogs();
  logsPollInterval = setInterval(pollLatestLogs, 2000);
}

function stopLogsPolling() {
  if (logsPollInterval) {
    clearInterval(logsPollInterval);
    logsPollInterval = null;
  }
}

async function renderLogs(page = 1) {
  logsPage = page;
  const cmdFilter = document.getElementById('log-cmd-filter')?.value || '';
  try {
    const params = { page, limit: logsLimit, hours: 168 };
    if (cmdFilter) params.command = cmdFilter;
    const { logs, total } = await API.getLogs(params);
    const totalPages = Math.ceil(total / logsLimit);
    liveSeenKeys.clear();
    logs.forEach((log) => liveSeenKeys.add(makeLiveKey(log)));

    document.getElementById('content').innerHTML = `
      <div class="card" style="margin-bottom:20px">
        <div class="card-header" style="display:flex;align-items:center;gap:10px">
          <span class="card-title">Canlı Komut Akışı</span>
          <span id="live-dot" style="display:inline-block;width:10px;height:10px;border-radius:50%;background:#6b7280;margin-left:4px"></span>
          <span id="live-label" style="font-size:12px;color:var(--text-muted)">Bağlanıyor...</span>
          <span style="margin-left:auto;font-size:12px;color:var(--text-muted)">Bu oturumda: <strong id="live-count">0</strong> komut</span>
        </div>
        <div class="table-wrapper" style="max-height:280px;overflow-y:auto">
          <table>
            <thead><tr><th>Komut</th><th>Kullanıcı</th><th>Araba</th><th>Hız</th><th>X</th><th>Y</th><th>Gecikme</th><th>Ulaştı</th><th>Zaman</th></tr></thead>
            <tbody id="live-log-tbody">
              <tr><td colspan="9" style="text-align:center;color:var(--text-muted);padding:20px">Joystick'ten komut bekleniyor...</td></tr>
            </tbody>
          </table>
        </div>
      </div>
      <div class="card">
        <div class="card-header"><span class="card-title">Geçmiş Loglar (Son 7 Gün)</span></div>
        <div class="filters">
          <div class="form-group">
            <select id="log-cmd-filter">
              <option value="">Tüm Komutlar</option>
              ${['forward','backward','left','right','stop','drift'].map(c => `<option value="${c}" ${cmdFilter===c?'selected':''}>${c}</option>`).join('')}
            </select>
          </div>
          <button class="btn btn-primary btn-sm" id="log-filter-btn">Filtrele</button>
        </div>
        <div class="table-wrapper">
          <table>
            <thead><tr><th>Komut</th><th>Kullanıcı</th><th>Hız</th><th>X</th><th>Y</th><th>Gecikme</th><th>Zaman</th></tr></thead>
            <tbody>
              ${logs.length === 0 ? `<tr><td colspan="7">${empty('Log bulunamadı', '📋')}</td></tr>` : logs.map(l => `
              <tr>
                <td>${cmdBadge(l.command)}</td>
                <td><code style="font-size:11px">${l.username || l.user_id?.slice(-8) || '-'}</code></td>
                <td>${l.speed ?? '-'}</td>
                <td>${l.x_axis?.toFixed(2) ?? '-'}</td>
                <td>${l.y_axis?.toFixed(2) ?? '-'}</td>
                <td>${l.latency_ms != null ? l.latency_ms + ' ms' : '-'}</td>
                <td>${fmt(l.timestamp)}</td>
              </tr>`).join('')}
            </tbody>
          </table>
        </div>
        <div class="pagination">
          <span class="pagination-info">Son 7 günde ${total} komut — Sayfa ${page}/${totalPages || 1}</span>
          <div class="pagination-btns">
            <button class="btn btn-outline btn-sm" ${page<=1?'disabled':''} onclick="renderLogs(${page-1})">← Önceki</button>
            <button class="btn btn-outline btn-sm" ${page>=totalPages?'disabled':''} onclick="renderLogs(${page+1})">Sonraki →</button>
          </div>
        </div>
      </div>`;

    document.getElementById('log-filter-btn').addEventListener('click', () => renderLogs(1));
    startAdminLiveWS();
    startLogsPolling();
  } catch (ex) {
    document.getElementById('content').innerHTML = `<div class="alert alert-danger">Loglar yüklenemedi: ${ex.message}</div>`;
  }
}

/* ─── BAĞLI ARABALAR ──────────────────────────────────────────── */

async function renderCars() {
  try {
    const data = await API.getConnectedCars();
    document.getElementById('content').innerHTML = `
      <div class="stats-grid" style="max-width:400px">
        <div class="stat-card green"><span class="stat-label">Bağlı Araba</span><span class="stat-value">${data.count}</span><span class="stat-sub">Anlık WebSocket bağlantısı</span></div>
      </div>
      <div class="card" style="max-width:600px">
        <div class="card-header"><span class="card-title">Araba Listesi</span><button class="btn btn-outline btn-sm" onclick="renderCars()">Yenile</button></div>
        ${data.count === 0 ? empty('Şu an bağlı araba yok', '🚗') : `
        <div class="table-wrapper">
          <table>
            <thead><tr><th>Araba ID</th><th>Controller Sayısı</th></tr></thead>
            <tbody>${data.car_ids.map(id => `<tr><td><code>${id}</code></td><td>${data.controller_counts?.[id] ?? 0}</td></tr>`).join('')}</tbody>
          </table>
        </div>`}
      </div>`;
  } catch (ex) {
    document.getElementById('content').innerHTML = `<div class="alert alert-danger">Arabalar yüklenemedi: ${ex.message}</div>`;
  }
}

/* ─── BAŞLAT ──────────────────────────────────────────────────── */
init();

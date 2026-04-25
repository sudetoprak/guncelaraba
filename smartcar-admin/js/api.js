/* ─── API MODÜLÜ ─────────────────────────────────────────────── */

// Backend URL: SC_BACKEND_ORIGIN ile override edilebilir,
// aksi hâlde tarayıcının hostname'ine göre otomatik belirlenir.
window.BACKEND_ORIGIN = window.SC_BACKEND_ORIGIN
  || (['localhost', '127.0.0.1'].includes(window.location.hostname)
      ? 'http://localhost:8000'
      : `http://${window.location.hostname}:8000`);

const BASE = window.BACKEND_ORIGIN + '/api/v1';

function getToken() { return localStorage.getItem('sc_token'); }
function getRefreshToken() { return localStorage.getItem('sc_refresh_token'); }

function doLogout() {
  localStorage.removeItem('sc_token');
  localStorage.removeItem('sc_refresh_token');
  localStorage.removeItem('sc_user');
  location.reload();
}

async function tryRefresh() {
  const rt = getRefreshToken();
  if (!rt) return false;
  try {
    const res = await fetch(BASE + '/auth/refresh', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ refresh_token: rt }),
    });
    if (!res.ok) return false;
    const data = await res.json();
    localStorage.setItem('sc_token', data.access_token);
    if (data.refresh_token) localStorage.setItem('sc_refresh_token', data.refresh_token);
    return true;
  } catch {
    return false;
  }
}

async function apiFetch(path, options = {}) {
  const doRequest = () => {
    const token = getToken();
    const headers = { 'Content-Type': 'application/json', ...(options.headers || {}) };
    if (token) headers['Authorization'] = `Bearer ${token}`;
    return fetch(BASE + path, { ...options, headers });
  };

  let res = await doRequest();

  if (res.status === 401) {
    const refreshed = await tryRefresh();
    if (!refreshed) { doLogout(); throw new Error('Oturum süresi doldu'); }
    res = await doRequest();
    if (res.status === 401) { doLogout(); throw new Error('Oturum süresi doldu'); }
  }

  const data = await res.json().catch(() => ({}));
  if (!res.ok) throw new Error(data.detail || `HTTP ${res.status}`);
  return data;
}

async function apiUpload(path, file) {
  if (!getToken() && !getRefreshToken()) { doLogout(); throw new Error('Oturum bulunamadı'); }

  const doRequest = () => {
    const formData = new FormData();
    formData.append('file', file);
    return fetch(BASE + path, {
      method: 'POST',
      headers: { 'Authorization': `Bearer ${getToken()}` },
      body: formData,
    });
  };

  let res;
  try { res = await doRequest(); }
  catch { throw new Error('Sunucuya bağlanılamadı. Sunucunun çalıştığından emin olun.'); }

  if (res.status === 401) {
    const refreshed = await tryRefresh();
    if (!refreshed) { doLogout(); throw new Error('Oturum süresi doldu'); }
    try { res = await doRequest(); }
    catch { throw new Error('Sunucuya bağlanılamadı.'); }
    if (res.status === 401) { doLogout(); throw new Error('Oturum süresi doldu'); }
  }

  const data = await res.json().catch(() => ({}));
  if (!res.ok) throw new Error(data.detail || `HTTP ${res.status}`);
  return data;
}

const API = {
  // Auth
  login: (email, password) =>
    apiFetch('/auth/login', {
      method: 'POST',
      body: JSON.stringify({ email, password }),
    }),

  adminRegister: (data) =>
    apiFetch('/auth/admin-register', {
      method: 'POST',
      body: JSON.stringify(data),
    }),

  me: () => apiFetch('/auth/me'),

  // Admin - Dashboard
  dashboard:    () => apiFetch('/admin/dashboard'),
  charts:       () => apiFetch('/admin/charts'),
  recentOrders: () => apiFetch('/admin/recent-orders'),
  lowStock:     () => apiFetch('/admin/low-stock'),

  // Admin - Kullanıcılar
  getUsers:   (params = {}) => apiFetch('/admin/users?' + new URLSearchParams(params)),
  getUser:    (id)          => apiFetch(`/admin/users/${id}`),
  createUser: (data)        => apiFetch('/admin/users', { method: 'POST', body: JSON.stringify(data) }),
  updateUser: (id, data)    => apiFetch(`/admin/users/${id}`, { method: 'PATCH', body: JSON.stringify(data) }),
  deleteUser: (id)          => apiFetch(`/admin/users/${id}`, { method: 'DELETE' }),

  // Admin - Siparişler
  getOrders:         (params = {}) => apiFetch('/admin/orders?' + new URLSearchParams(params)),
  getOrder:          (id)          => apiFetch(`/admin/orders/${id}`),
  updateOrderStatus: (id, status)  => apiFetch(`/admin/orders/${id}/status`, {
    method: 'PATCH', body: JSON.stringify({ status }),
  }),

  // Admin - Ürünler
  getAdminProducts: (params = {}) => apiFetch('/admin/products?' + new URLSearchParams(params)),
  createProduct:    (data)        => apiFetch('/products', { method: 'POST', body: JSON.stringify(data) }),
  updateProduct:    (id, data)    => apiFetch(`/products/${id}`, { method: 'PUT', body: JSON.stringify(data) }),
  deleteProduct:    (id)          => apiFetch(`/products/${id}`, { method: 'DELETE' }),
  uploadImage:      (file)        => apiUpload('/products/upload-image', file),

  // Bağlı arabalar
  getConnectedCars: () => apiFetch('/admin/cars/connected'),
};
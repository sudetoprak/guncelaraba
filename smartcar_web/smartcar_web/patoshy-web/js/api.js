async function apiReq(endpoint, opts={}) {
  const token = TokenStorage.get();
  const headers = {'Content-Type':'application/json',...opts.headers};
  if (token) headers['Authorization'] = `Bearer ${token}`;
  try {
    const res = await fetch(API_BASE + endpoint, {
      mode: 'cors',
      credentials: 'omit',
      ...opts,
      headers
    });
    if (res.status === 401) { TokenStorage.clear(); updateNav(null); showPage('auth'); throw new Error('Oturum süresi doldu.'); }
    if (!res.ok) { const e = await res.json().catch(()=>({})); throw new Error(e.detail||`Hata: ${res.status}`); }
    if (res.status === 204) return null;
    return res.json();
  } catch(err) {
    if (err.name === 'TypeError' || err.message.toLowerCase().includes('fetch') || err.message.toLowerCase().includes('network')) {
      throw new Error('Sunucuya bağlanılamadı. (CORS veya ağ hatası)');
    }
    throw err;
  }
}

const delay = ms => new Promise(r => setTimeout(r, ms));

function normalizeApiCategory(cat) {
  const value = (cat || '').trim();
  const map = {araba:'Araba',aksesuar:'Aksesuar'};
  return map[value.toLowerCase()] || value;
}

const api = {
  async login(email, password) {
    if (MOCK_MODE) {
      await delay(600);
      const user = {id:'u001',email,username:email.split('@')[0],full_name:'Demo Kullanıcı',role:'user',phone:null,language:'tr',address:null,created_at:new Date().toISOString()};
      return {access_token:'mock_'+Date.now(),refresh_token:'mock_r',user};
    }
    const d = await apiReq('/auth/login',{method:'POST',body:JSON.stringify({email,password})});
    const user = await apiReq('/auth/me',{headers:{Authorization:`Bearer ${d.access_token}`}});
    return {...d,user};
  },
  async register(payload) {
    if (MOCK_MODE) {
      await delay(800);
      const user = {id:'u_'+Date.now(),email:payload.email,username:payload.username,full_name:payload.full_name,role:'user',phone:payload.phone||null,language:'tr',address:null,created_at:new Date().toISOString()};
      return {access_token:'mock_'+Date.now(),refresh_token:'mock_r',user};
    }
    const d = await apiReq('/auth/register',{method:'POST',body:JSON.stringify(payload)});
    const user = await apiReq('/auth/me',{headers:{Authorization:`Bearer ${d.access_token}`}});
    return {...d,user};
  },
  async getProducts(params={}) {
    if (MOCK_MODE) {
      await delay(350);
      let p = [...MOCK_PRODUCTS];
      if (params.category) p = p.filter(x => normalizeApiCategory(x.category) === normalizeApiCategory(params.category));
      if (params.search) { const q=params.search.toLowerCase(); p = p.filter(x => x.name.tr.toLowerCase().includes(q)||x.description.tr.toLowerCase().includes(q)); }
      return p;
    }
    return apiReq('/products?' + new URLSearchParams(params));
  },
  async getProduct(id) {
    if (MOCK_MODE) { await delay(250); return MOCK_PRODUCTS.find(p=>p.id===id)||null; }
    return apiReq(`/products/${id}`);
  },
  async getCart() {
    if (MOCK_MODE) {
      await delay(250);
      const items = CartStorage.get();
      let total=0;
      const enriched = items.map(i=>{
        const p=MOCK_PRODUCTS.find(x=>x.id===i.product_id);
        if(!p) return null;
        const sub=p.price*i.quantity; total+=sub;
        return {product_id:i.product_id,name:p.name,price:p.price,quantity:i.quantity,subtotal:sub,image:fixImageUrl(p.images[0])};
      }).filter(Boolean);
      return {items:enriched,total};
    }
    return apiReq('/cart/');
  },
  async addToCart(product_id, quantity=1) {
    if (MOCK_MODE) {
      await delay(150);
      const items=CartStorage.get();
      const ex=items.find(i=>i.product_id===product_id);
      if(ex) ex.quantity+=quantity; else items.push({product_id,quantity});
      CartStorage.set(items);
      return {message:'Sepete eklendi'};
    }
    return apiReq('/cart/add',{method:'POST',body:JSON.stringify({product_id,quantity})});
  },
  async removeFromCart(product_id) {
    if (MOCK_MODE) {
      await delay(150);
      CartStorage.set(CartStorage.get().filter(i=>i.product_id!==product_id));
      return {message:'Kaldırıldı'};
    }
    return apiReq(`/cart/remove/${product_id}`,{method:'DELETE'});
  },
  async clearCart() {
    if (MOCK_MODE) { CartStorage.clear(); return {message:'Temizlendi'}; }
    return apiReq('/cart/clear',{method:'DELETE'});
  },
  async createOrder(payload) {
    if (MOCK_MODE) {
      await delay(700);
      const cart=CartStorage.get();
      const items=cart.map(c=>{
        const p=MOCK_PRODUCTS.find(x=>x.id===c.product_id);
        return p?{product_id:c.product_id,name:p.name,price:p.price,quantity:c.quantity,subtotal:p.price*c.quantity}:null;
      }).filter(Boolean);
      const total=items.reduce((s,i)=>s+i.subtotal,0);
      const order={id:'ord_'+Date.now(),items,total,status:'pending',shipping_address:payload.shipping_address,created_at:new Date().toISOString()};
      const orders=JSON.parse(localStorage.getItem('ptOrders')||'[]');
      orders.unshift(order);
      localStorage.setItem('ptOrders',JSON.stringify(orders));
      CartStorage.clear();
      return order;
    }
    return apiReq('/orders/',{method:'POST',body:JSON.stringify(payload)});
  },
  async getOrders() {
    if (MOCK_MODE) { await delay(350); return JSON.parse(localStorage.getItem('ptOrders')||'[]'); }
    return apiReq('/orders/');
  }
};

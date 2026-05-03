let allProds = [];
let activeCat = '';

const badgeMap = {araba:'pb-basic',aksesuar:'pb-aksesuar'};
const labelMap = {araba:'Araba',aksesuar:'Aksesuar'};

function normalizeProductCategory(cat) {
  const value = (cat || '').trim();
  const map = {araba:'Araba',aksesuar:'Aksesuar'};
  return map[value.toLowerCase()] || value;
}

function pcard(p, idx=0) {
  const name = typeof p.name==='object'?p.name.tr:p.name;
  const desc = typeof p.description==='object'?p.description.tr:p.description;
  const img = p.images&&p.images[0] ? fixImageUrl(p.images[0]) : 'img/basic.png';
  const category = normalizeProductCategory(p.category);
  const categoryKey = category.toLowerCase();
  const bc = badgeMap[categoryKey]||'pb-basic';
  const bl = labelMap[categoryKey]||category;
  const stock = p.stock>0 ? `<span class="pbadge-stock">● Stokta</span>` : `<span class="pbadge-stock out">● Tükendi</span>`;

  return `<div class="pcard" style="animation-delay:${idx*0.06}s" onclick="showDetail('${p.id}')">
    <div class="pcard-img">
      <div class="pcard-img-glow"></div>
      <img src="${img}" alt="${name}" loading="lazy" onerror="this.src='img/basic.png'" id="pimg-${p.id}">
      <span class="pbadge ${bc}">${bl}</span>
    </div>
    <div class="pcard-body">
      <div class="pcard-name">${name}</div>
      <div class="pcard-desc">${desc}</div>
      <div class="pcard-foot">
        <div class="pcard-price"><small>Fiyat</small>₺${Number(p.price).toLocaleString('tr-TR')}</div>
        <button class="add-btn" onclick="event.stopPropagation();addFromCard('${p.id}','${img}')" title="Sepete Ekle" ${p.stock===0?'disabled':''}>
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M6 2L3 6v14a2 2 0 002 2h14a2 2 0 002-2V6l-3-4z"/><line x1="3" y1="6" x2="21" y2="6"/><path d="M16 10a4 4 0 01-8 0"/></svg>
        </button>
      </div>
    </div>
  </div>`;
}

async function loadFeatured() {
  const el = document.getElementById('featuredProducts');
  if (!el) return;
  try {
    const prods = await api.getProducts({});
    allProds = prods;
    el.innerHTML = prods.slice(0,3).map((p,i)=>pcard(p,i)).join('');
    setTimeout(observeReveal, 50);
  } catch(err) {
    el.innerHTML = `<div style="grid-column:1/-1;text-align:center;padding:3rem;color:var(--txt3)">${err.message}</div>`;
  }
}

async function loadAllProducts() {
  const el = document.getElementById('allProducts');
  if (!el) return;
  el.innerHTML = '<div class="pskel"></div><div class="pskel"></div><div class="pskel"></div><div class="pskel"></div>';
  if (!allProds.length) allProds = await api.getProducts({}).catch(()=>[]);
  renderAllProducts();
}

function renderAllProducts() {
  const el = document.getElementById('allProducts');
  const emp = document.getElementById('productsEmpty');
  if (!el) return;
  const sort = document.getElementById('sortSelect')?.value||'';
  let prods = allProds.filter(p => !activeCat||normalizeProductCategory(p.category)===activeCat);
  if (sort==='price-asc') prods.sort((a,b)=>a.price-b.price);
  else if (sort==='price-desc') prods.sort((a,b)=>b.price-a.price);
  else if (sort==='name') prods.sort((a,b)=>(typeof a.name==='object'?a.name.tr:a.name).localeCompare(typeof b.name==='object'?b.name.tr:b.name,'tr'));
  if (!prods.length) { el.innerHTML=''; emp&&(emp.style.display='block'); return; }
  emp&&(emp.style.display='none');
  el.innerHTML = prods.map((p,i)=>pcard(p,i)).join('');
  setTimeout(observeReveal,50);
}

document.addEventListener('click', e=>{
  const ft = e.target.closest('.ft');
  if (!ft) return;
  document.querySelectorAll('.ft').forEach(t=>t.classList.remove('active'));
  ft.classList.add('active');
  activeCat = ft.dataset.cat;
  renderAllProducts();
});

async function showDetail(id) {
  showPage('detail');
  const el = document.getElementById('productDetail');
  el.innerHTML = `<div style="text-align:center;padding:6rem 0;color:var(--txt3)">
    <div style="font-size:2rem;animation:hex-spin 1s linear infinite;display:inline-block">⬡</div>
  </div>`;
  try {
    const p = await api.getProduct(id);
    if (!p) throw new Error('Ürün bulunamadı');
    const name = typeof p.name==='object'?p.name.tr:p.name;
    const desc = typeof p.description==='object'?p.description.tr:p.description;
    const images = (p.images&&p.images.length) ? p.images.map(fixImageUrl) : ['img/basic.png'];
    const img = images[0];
    const category = normalizeProductCategory(p.category);
    const categoryKey = category.toLowerCase();
    const bc = badgeMap[categoryKey]||'pb-basic';
    const bl = labelMap[categoryKey]||category;
    const specs = p.specs?.map(([k,v])=>`<div class="srow"><span class="sk">${k}</span><span class="sv">${v}</span></div>`).join('')||'';
    const stockBadge = p.stock>0
      ? `<span style="background:rgba(16,185,129,0.15);color:#34d399;border:1px solid rgba(16,185,129,0.3);padding:0.3rem 0.85rem;border-radius:20px;font-size:0.72rem;font-weight:700">● Stokta (${p.stock} adet)</span>`
      : `<span style="background:rgba(239,68,68,0.15);color:#f87171;border:1px solid rgba(239,68,68,0.3);padding:0.3rem 0.85rem;border-radius:20px;font-size:0.72rem;font-weight:700">Tükendi</span>`;

    // Birden fazla resim varsa küçük galeri thumbnail'leri oluştur
    const thumbs = images.length > 1
      ? `<div class="det-thumbs" style="display:flex;gap:0.5rem;flex-wrap:wrap;margin-top:0.75rem">
          ${images.map((src,i)=>`<img src="${src}" alt="${name} ${i+1}" loading="lazy"
            onerror="this.src='img/basic.png'"
            onclick="document.getElementById('detImg').src='${src}'"
            style="width:62px;height:62px;object-fit:cover;border-radius:10px;border:2px solid ${i===0?'var(--accent)':'rgba(255,255,255,0.1)'};cursor:pointer;transition:border-color .2s"
            onmouseover="this.style.borderColor='var(--accent)'" onmouseout="this.style.borderColor='${i===0?'var(--accent)':'rgba(255,255,255,0.1)'}'">`).join('')}
         </div>`
      : '';

    el.innerHTML = `
    <div style="margin-bottom:1.25rem;padding-top:0.5rem">
      <button class="btn-ghost" style="font-size:0.84rem;padding:0.45rem 1rem" onclick="showPage('products')">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" style="width:16px"><path d="M19 12H5M12 19l-7-7 7-7"/></svg>
        Ürünlere Dön
      </button>
    </div>
    <div class="detail-layout">
      <div class="det-gallery">
        <div class="det-main-img" id="detMainImg">
          <img src="${img}" alt="${name}" onerror="this.src='img/basic.png'" id="detImg">
        </div>
        ${thumbs}
        <div style="display:flex;gap:0.5rem;flex-wrap:wrap;margin-top:0.75rem">
          <span class="pbadge ${bc}" style="position:static">${bl}</span>
          ${stockBadge}
        </div>
      </div>
      <div class="det-info">
        <div class="det-cat">${bl} Serisi</div>
        <h1 class="det-name">${name}</h1>
        <div class="det-price"><small>Satış Fiyatı</small>₺${Number(p.price).toLocaleString('tr-TR')}</div>
        <p class="det-desc">${desc}</p>
        ${specs ? `<div class="det-specs"><h4>Teknik Özellikler</h4>${specs}</div>` : ''}
        <div class="qty-row">
          <span class="qty-l">Adet</span>
          <div class="qty-ctrl">
            <button class="qbtn" onclick="chQty(-1)">−</button>
            <span class="qnum" id="detQty">1</span>
            <button class="qbtn" onclick="chQty(1)">+</button>
          </div>
        </div>
        <div class="det-actions">
          <button class="btn-glow" style="flex:1" onclick="addFromDetail('${p.id}','${img}')" ${p.stock===0?'disabled':''}>
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M6 2L3 6v14a2 2 0 002 2h14a2 2 0 002-2V6l-3-4z"/><line x1="3" y1="6" x2="21" y2="6"/><path d="M16 10a4 4 0 01-8 0"/></svg>
            Sepete Ekle
          </button>
          <button class="btn-outline" onclick="addFromDetail('${p.id}','${img}',true)" ${p.stock===0?'disabled':''}>Hemen Al</button>
        </div>
      </div>
    </div>`;
  } catch(err) {
    el.innerHTML = `<div style="text-align:center;padding:6rem 0;color:var(--txt3)">${err.message}</div>`;
  }
}

function chQty(d) {
  const el=document.getElementById('detQty');
  if (!el) return;
  el.textContent = Math.max(1, Math.min(10, parseInt(el.textContent)+d));
}

async function addFromCard(id, img) {
  const srcEl = document.getElementById('pimg-'+id);
  try {
    await api.addToCart(id, 1);
    updateCartBadge();
    if (srcEl) flyToCart(srcEl, img);
    toast('Sepete eklendi!','success');
  } catch(err) { toast(err.message,'error'); }
}

async function addFromDetail(id, img, buyNow=false) {
  const qty = parseInt(document.getElementById('detQty')?.textContent||'1');
  const srcEl = document.getElementById('detImg');
  try {
    await api.addToCart(id, qty);
    updateCartBadge();
    if (srcEl && !buyNow) flyToCart(srcEl, img);
    if (buyNow) showPage('cart');
    else toast(`${qty} adet sepete eklendi!`,'success');
  } catch(err) { toast(err.message,'error'); }
}

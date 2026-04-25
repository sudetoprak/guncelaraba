async function updateCartBadge() {
  try {
    const c = await api.getCart();
    const n = c.items?c.items.reduce((s,i)=>s+i.quantity,0):0;
    const badge = document.getElementById('cartCount');
    if (badge) { badge.textContent=n; badge.style.display=n>0?'flex':'none'; }
  } catch {}
}

async function loadCart() {
  const el=document.getElementById('cartItems');
  const side=document.getElementById('cartSide');
  if (!el) return;
  el.innerHTML=`<div style="text-align:center;padding:4rem;color:var(--txt3)"><div style="font-size:2rem;animation:hex-spin 1s linear infinite;display:inline-block">⬡</div></div>`;
  try {
    const cart = await api.getCart();
    if (!cart.items||!cart.items.length) {
      el.innerHTML=`<div class="cart-empty-state"><div class="ei">🛒</div><h3>Sepetiniz Boş</h3><p style="color:var(--txt2);margin-bottom:1.5rem">Henüz ürün eklemediniz.</p><button class="btn-glow" onclick="showPage('products')">Alışverişe Başla</button></div>`;
      side&&(side.style.display='none'); return;
    }
    el.innerHTML = cart.items.map((item,i)=>{
      const name=typeof item.name==='object'?item.name.tr:item.name||'Ürün';
      const img=fixImageUrl(item.image||'img/basic.png');
      return `<div class="citem" style="animation-delay:${i*0.05}s" id="ci-${item.product_id}">
        <div class="citem-img"><img src="${img}" alt="${name}" onerror="this.src='img/basic.png'"></div>
        <div class="citem-info">
          <div class="citem-name">${name}</div>
          <div class="citem-px">₺${Number(item.price).toLocaleString('tr-TR')} / adet</div>
        </div>
        <div class="citem-actions">
          <div class="cqty">
            <button onclick="updCQty('${item.product_id}',${item.quantity-1})">−</button>
            <span>${item.quantity}</span>
            <button onclick="updCQty('${item.product_id}',${item.quantity+1})">+</button>
          </div>
          <div class="citem-sub">₺${Number(item.subtotal).toLocaleString('tr-TR')}</div>
          <button class="cremove" onclick="remCart('${item.product_id}')" title="Kaldır">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="3 6 5 6 21 6"/><path d="M19 6v14a2 2 0 01-2 2H7a2 2 0 01-2-2V6m3 0V4a1 1 0 011-1h4a1 1 0 011 1v2"/></svg>
          </button>
        </div>
      </div>`;
    }).join('');
    if (side) {
      side.style.display='block';
      const fmt=n=>'₺'+Number(n).toLocaleString('tr-TR');
      document.getElementById('cartSubtotal').textContent=fmt(cart.total);
      document.getElementById('cartTotal').textContent=fmt(cart.total);
    }
  } catch(err) {
    el.innerHTML=`<div style="text-align:center;padding:3rem;color:var(--txt3)">${err.message}</div>`;
  }
}

async function remCart(pid) {
  const el=document.getElementById('ci-'+pid);
  if (el) { el.style.transition='all 0.25s ease'; el.style.opacity='0'; el.style.transform='translateX(30px)'; }
  try {
    await api.removeFromCart(pid);
    setTimeout(()=>loadCart(),250);
    updateCartBadge();
    toast('Ürün sepetten kaldırıldı.','info');
  } catch(err) { toast(err.message,'error'); if(el){el.style.opacity='1';el.style.transform='none';} }
}

async function updCQty(pid, qty) {
  if (qty<=0) { remCart(pid); return; }
  if (qty>10) { toast('Maksimum adet: 10','error'); return; }
  try {
    await api.removeFromCart(pid);
    await api.addToCart(pid,qty);
    loadCart(); updateCartBadge();
  } catch(err) { toast(err.message,'error'); }
}

async function loadCheckout() {
  try {
    const cart=await api.getCart();
    if (!cart.items||!cart.items.length) { showPage('cart'); return; }
    const el=document.getElementById('checkoutItems');
    const tel=document.getElementById('checkoutTotal');
    if (el) el.innerHTML=cart.items.map(i=>{
      const name=typeof i.name==='object'?i.name.tr:i.name||'Ürün';
      return `<div class="co-item"><span>${name} × ${i.quantity}</span><span>₺${Number(i.subtotal).toLocaleString('tr-TR')}</span></div>`;
    }).join('');
    if (tel) tel.textContent='₺'+Number(cart.total).toLocaleString('tr-TR');
  } catch {}
}

async function placeOrder() {
  const street=document.getElementById('street')?.value.trim();
  const city=document.getElementById('city')?.value.trim();
  const country=document.getElementById('country')?.value.trim();
  const zip=document.getElementById('zip')?.value.trim();
  if (!street||!city||!country||!zip) { toast('Teslimat adresini eksiksiz doldurun.','error'); return; }
  const payment=document.querySelector('input[name="pay"]:checked')?.value||'credit_card';
  const btn=document.querySelector('#page-checkout .btn-glow.btn-xl');
  const orig=btn?.innerHTML;
  if (btn) { btn.innerHTML='<span style="opacity:0.7">İşleniyor...</span>'; btn.disabled=true; }
  try {
    const order=await api.createOrder({payment_method:payment,shipping_address:{street,city,country,zip}});
    updateCartBadge();
    toast('Siparişiniz alındı! 🎉','success');
    const total=order.total?'₺'+Number(order.total).toLocaleString('tr-TR'):'';
    document.getElementById('page-checkout').innerHTML=`
    <div style="min-height:60vh;display:flex;align-items:center;justify-content:center;padding:4rem 1.5rem">
      <div style="text-align:center;max-width:480px">
        <div style="font-size:5rem;margin-bottom:1.5rem">✅</div>
        <h2 style="font-size:1.8rem;font-weight:800;margin-bottom:0.75rem">Siparişiniz Alındı!</h2>
        <p style="color:var(--txt2);margin-bottom:0.5rem">Sipariş No: <strong style="font-family:'DM Mono',monospace;color:var(--pll)">${(order.id||'').slice(-10).toUpperCase()}</strong></p>
        ${total?`<p style="color:var(--txt2);margin-bottom:2.5rem">Toplam: <strong>${total}</strong></p>`:''}
        <div style="display:flex;gap:1rem;justify-content:center;flex-wrap:wrap">
          <button class="btn-glow" onclick="showPage('orders')">Siparişlerimi Gör</button>
          <button class="btn-outline" onclick="showPage('products')">Alışverişe Devam</button>
        </div>
      </div>
    </div>`;
  } catch(err) {
    toast(err.message,'error');
    if (btn) { btn.innerHTML=orig; btn.disabled=false; }
  }
}

async function loadOrders() {
  const el=document.getElementById('ordersList');
  if (!el) return;
  el.innerHTML=`<div style="text-align:center;padding:4rem;color:var(--txt3)"><div style="font-size:2rem;animation:hex-spin 1s linear infinite;display:inline-block">⬡</div></div>`;
  const user=UserStorage.get();
  if (!user) {
    el.innerHTML=`<div style="text-align:center;padding:4rem 2rem"><h3 style="margin-bottom:1rem">Giriş Yapmanız Gerekiyor</h3><button class="btn-glow" onclick="showPage('auth')">Giriş Yap</button></div>`;
    return;
  }
  try {
    const orders=await api.getOrders();
    if (!orders||!orders.length) {
      el.innerHTML=`<div style="text-align:center;padding:4rem 2rem"><div style="font-size:3.5rem;margin-bottom:1rem">📦</div><h3 style="margin-bottom:0.75rem">Henüz Siparişiniz Yok</h3><p style="color:var(--txt2);margin-bottom:1.5rem">İlk siparişinizi verin.</p><button class="btn-glow" onclick="showPage('products')">Ürünlere Bak</button></div>`;
      return;
    }
    const sl={pending:'s-pending',paid:'s-paid',shipped:'s-shipped',delivered:'s-delivered',cancelled:'s-cancelled'};
    const ll={pending:'Bekliyor',paid:'Ödendi',shipped:'Kargoda',delivered:'Teslim Edildi',cancelled:'İptal'};
    el.innerHTML=orders.map((o,i)=>{
      const items=o.items||[];
      const names=items.slice(0,2).map(it=>{const n=typeof it.name==='object'?it.name.tr:it.name; return `${n} × ${it.quantity}`;}).join(', ');
      const more=items.length>2?` +${items.length-2} ürün daha`:'';
      const date=o.created_at?new Date(o.created_at).toLocaleDateString('tr-TR'):'—';
      const s=o.status||'pending';
      return `<div class="ocard" style="animation-delay:${i*0.05}s">
        <div class="ocard-hd">
          <div><div class="oid">Sipariş #${(o.id||'').slice(-10).toUpperCase()}</div><div class="odate">${date}</div></div>
          <span class="ostatus ${sl[s]||''}">${ll[s]||s}</span>
        </div>
        <div class="oitems">${names}${more}</div>
        <div class="ototal">₺${Number(o.total||0).toLocaleString('tr-TR')}</div>
      </div>`;
    }).join('');
  } catch(err) {
    el.innerHTML=`<div style="text-align:center;padding:3rem;color:var(--txt3)">${err.message}</div>`;
  }
}

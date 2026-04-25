// ══ LOADER ══
const loaderFill = document.getElementById('loaderFill');
const loaderPct = document.getElementById('loaderPct');
const loaderCanvas = document.getElementById('loaderCanvas');
if (loaderCanvas) {
  const ctx = loaderCanvas.getContext('2d');
  loaderCanvas.width = window.innerWidth;
  loaderCanvas.height = window.innerHeight;
  const stars = Array.from({length:80},() => ({
    x: Math.random()*loaderCanvas.width, y:Math.random()*loaderCanvas.height,
    r: Math.random()*1.5+0.3, a:Math.random(), da:Math.random()*0.02+0.005
  }));
  function drawLoader() {
    ctx.clearRect(0,0,loaderCanvas.width,loaderCanvas.height);
    stars.forEach(s => {
      s.a += s.da; if (s.a>1||s.a<0) s.da*=-1;
      ctx.beginPath(); ctx.arc(s.x,s.y,s.r,0,Math.PI*2);
      ctx.fillStyle = `rgba(167,139,250,${s.a*0.6})`; ctx.fill();
    });
    if (!document.getElementById('loader').classList.contains('gone')) requestAnimationFrame(drawLoader);
  }
  drawLoader();
}
let pct = 0;
const loadInt = setInterval(() => {
  pct += Math.random() * 18 + 5;
  if (pct >= 100) { pct = 100; clearInterval(loadInt); setTimeout(hideLoader, 300); }
  loaderFill && (loaderFill.style.width = pct + '%');
  loaderPct && (loaderPct.textContent = Math.floor(pct) + '%');
}, 120);
function hideLoader() {
  const loader = document.getElementById('loader');
  loader && loader.classList.add('gone');
}

// ══ PARTICLE CANVAS ══
function initParticles(canvasId) {
  const canvas = document.getElementById(canvasId);
  if (!canvas) return;
  const ctx = canvas.getContext('2d');
  function resize() { canvas.width = canvas.offsetWidth; canvas.height = canvas.offsetHeight; }
  resize();
  window.addEventListener('resize', resize);

  const particles = Array.from({length: canvasId === 'particleCanvas' ? 60 : 30}, () => createParticle(canvas));
  function createParticle(cv) {
    return {
      x: Math.random()*cv.width, y: Math.random()*cv.height,
      vx: (Math.random()-0.5)*0.4, vy: (Math.random()-0.5)*0.4,
      r: Math.random()*2+0.5, a: Math.random()*0.5+0.1,
      color: Math.random() > 0.5 ? '139,92,246' : Math.random()>0.5 ? '168,85,247' : '236,72,153'
    };
  }

  let rafId;
  function draw() {
    ctx.clearRect(0,0,canvas.width,canvas.height);
    particles.forEach((p,i) => {
      p.x += p.vx; p.y += p.vy;
      if (p.x < 0) p.x = canvas.width; if (p.x > canvas.width) p.x = 0;
      if (p.y < 0) p.y = canvas.height; if (p.y > canvas.height) p.y = 0;
      ctx.beginPath(); ctx.arc(p.x,p.y,p.r,0,Math.PI*2);
      ctx.fillStyle = `rgba(${p.color},${p.a})`; ctx.fill();
      // Lines to nearby
      particles.slice(i+1).forEach(p2 => {
        const d = Math.hypot(p.x-p2.x,p.y-p2.y);
        if (d < 120) {
          ctx.beginPath(); ctx.moveTo(p.x,p.y); ctx.lineTo(p2.x,p2.y);
          ctx.strokeStyle = `rgba(139,92,246,${0.08*(1-d/120)})`; ctx.lineWidth=0.5; ctx.stroke();
        }
      });
    });
    rafId = requestAnimationFrame(draw);
  }
  draw();
  return () => cancelAnimationFrame(rafId);
}
setTimeout(() => { initParticles('particleCanvas'); initParticles('ctaCanvas'); initParticles('authCanvas'); }, 100);

// ══ PARALLAX ══
function handleParallax() {
  const el = document.querySelector('.parallax-hero');
  if (!el) return;
  const scrollY = window.scrollY;
  const speed = parseFloat(el.dataset.speed) || 0.3;
  el.style.transform = `translateY(${scrollY * speed}px)`;
}
window.addEventListener('scroll', handleParallax, { passive: true });

// ══ COUNTER ANIMATION ══
function animateCounters() {
  document.querySelectorAll('[data-count]').forEach(el => {
    if (el.dataset.animated) return;
    const rect = el.getBoundingClientRect();
    if (rect.top < window.innerHeight * 0.85) {
      el.dataset.animated = '1';
      const target = parseInt(el.dataset.count);
      let start = 0;
      const dur = 1800;
      const startTime = performance.now();
      function step(now) {
        const p = Math.min((now - startTime) / dur, 1);
        const ease = 1 - Math.pow(1 - p, 3);
        el.textContent = Math.floor(ease * target);
        if (p < 1) requestAnimationFrame(step);
        else el.textContent = target;
      }
      requestAnimationFrame(step);
    }
  });
}

// ══ SCROLL REVEAL ══
const revealObserver = new IntersectionObserver((entries) => {
  entries.forEach((entry, i) => {
    if (entry.isIntersecting) {
      setTimeout(() => entry.target.classList.add('revealed'), i * 80);
      revealObserver.unobserve(entry.target);
    }
  });
}, { threshold: 0.1 });

function observeReveal() {
  document.querySelectorAll('[data-reveal]:not(.revealed)').forEach(el => revealObserver.observe(el));
}
setTimeout(observeReveal, 100);
window.addEventListener('scroll', () => { animateCounters(); }, { passive: true });

// ══ NAVBAR SCROLL ══
window.addEventListener('scroll', () => {
  document.getElementById('navbar')?.classList.toggle('scrolled', window.scrollY > 30);
}, { passive: true });

// ══ FLY TO CART ANIMATION ══
function flyToCart(sourceEl, imgSrc) {
  const flyEl = document.getElementById('flyItem');
  const cartBtn = document.querySelector('.nav-icon.cart-btn, .nav-icon');
  if (!flyEl || !cartBtn || !sourceEl) return;

  const srcRect = sourceEl.getBoundingClientRect();
  const dstRect = cartBtn.getBoundingClientRect();

  flyEl.innerHTML = `<img src="${imgSrc}" alt="">`;
  flyEl.style.display = 'block';
  flyEl.style.left = (srcRect.left + srcRect.width/2 - 25) + 'px';
  flyEl.style.top  = (srcRect.top  + srcRect.height/2 - 25) + 'px';
  flyEl.style.opacity = '1';
  flyEl.style.transform = 'scale(1)';
  flyEl.style.transition = 'none';

  const destX = dstRect.left + dstRect.width/2 - 25;
  const destY = dstRect.top  + dstRect.height/2 - 25;

  requestAnimationFrame(() => {
    flyEl.style.transition = 'all 0.65s cubic-bezier(0.4,0,0.2,1)';
    flyEl.style.left = destX + 'px';
    flyEl.style.top  = destY + 'px';
    flyEl.style.transform = 'scale(0.2)';
    flyEl.style.opacity = '0.6';
  });

  setTimeout(() => {
    flyEl.style.display = 'none';
    // Cart badge bump animation
    const badge = document.getElementById('cartCount');
    if (badge) {
      badge.style.transform = 'scale(1.5)';
      badge.style.transition = 'transform 0.2s';
      setTimeout(() => badge.style.transform = 'scale(1)', 200);
    }
  }, 700);
}

function switchTab(t) {
  document.querySelectorAll('.at').forEach(x=>x.classList.remove('active'));
  document.querySelector(`.at[onclick="switchTab('${t}')"]`).classList.add('active');
  document.getElementById('loginForm').style.display = t==='login'?'flex':'none';
  document.getElementById('registerForm').style.display = t==='register'?'flex':'none';
  document.getElementById('loginError').classList.remove('show');
  document.getElementById('registerError').classList.remove('show');
}

async function handleLogin(e) {
  e.preventDefault();
  const btn=document.getElementById('loginBtn');
  const err=document.getElementById('loginError');
  err.classList.remove('show');
  btn.innerHTML='<span style="opacity:0.7">Giriş yapılıyor...</span>';
  btn.disabled=true;
  try {
    const {access_token,user} = await api.login(
      document.getElementById('loginEmail').value,
      document.getElementById('loginPassword').value
    );
    TokenStorage.set(access_token);
    UserStorage.set(user);
    updateNav(user);
    toast(`Hoş geldiniz, ${user.full_name}! 👋`,'success');
    showPage('home');
  } catch(ex) {
    err.textContent=ex.message; err.classList.add('show');
  } finally {
    btn.innerHTML='Giriş Yap'; btn.disabled=false;
  }
}

async function handleRegister(e) {
  e.preventDefault();
  const btn=document.getElementById('registerBtn');
  const err=document.getElementById('registerError');
  err.classList.remove('show');
  btn.innerHTML='<span style="opacity:0.7">Oluşturuluyor...</span>';
  btn.disabled=true;
  try {
    const payload = {
      email:document.getElementById('regEmail').value,
      username:document.getElementById('regUsername').value,
      password:document.getElementById('regPassword').value,
      full_name:document.getElementById('regFullName').value,
      phone:document.getElementById('regPhone').value||undefined,
      language:'tr'
    };
    const {access_token,user} = await api.register(payload);
    TokenStorage.set(access_token);
    UserStorage.set(user);
    updateNav(user);
    toast('Hesabınız oluşturuldu! 🎉','success');
    showPage('home');
  } catch(ex) {
    err.textContent=ex.message; err.classList.add('show');
  } finally {
    btn.innerHTML='Hesap Oluştur'; btn.disabled=false;
  }
}

function logout() {
  TokenStorage.clear();
  CartStorage.clear();
  updateNav(null);
  updateCartBadge();
  toast('Çıkış yapıldı.','info');
  showPage('home');
}

function updateNav(user) {
  const btn=document.getElementById('authBtn');
  if (user) {
    btn.textContent = user.username||user.email;
    btn.onclick = ()=>showPage('profile');
  } else {
    btn.textContent = 'Giriş Yap';
    btn.onclick = ()=>showPage('auth');
  }
}

function togglePw(id) {
  const i=document.getElementById(id);
  i.type = i.type==='password'?'text':'password';
}

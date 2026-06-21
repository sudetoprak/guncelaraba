# SmartCar / Patoshy

## Proje Özeti

SmartCar (Patoshy), e-ticaret altyapısı ile gerçek zamanlı araç kontrol sistemini bir araya getiren bütünleşik bir platformdur. Proje kapsamında mobil uygulama, web sitesi, admin paneli, FastAPI backend servisi, MongoDB veritabanı ve ESP32 tabanlı akıllı araç sistemi geliştirilmiştir.

Sistem sayesinde kullanıcılar ürünleri görüntüleyebilir, sipariş oluşturabilir, sipariş geçmişlerini takip edebilir ve aynı zamanda mobil uygulama üzerinden ESP32 tabanlı aracı kontrol edebilir. Yönetim paneli üzerinden ürün, kullanıcı ve sipariş yönetimi gerçekleştirilebilirken, araç komutları ve sistem kayıtları da takip edilebilmektedir.


## Çalıştırma Talimatları

### 1. Projeyi Bilgisayara İndirme

```bash
git clone <repo-url>
cd smartcar-project
---

# Proje Bileşenleri

## Backend (FastAPI)

Backend sistemi FastAPI frameworkü kullanılarak geliştirilmiştir.

### Özellikler

* JWT Authentication
* Access Token & Refresh Token
* Kullanıcı Yönetimi
* Admin Yönetimi
* Ürün Yönetimi
* Sepet Yönetimi
* Sipariş Yönetimi
* WebSocket Desteği
* Komut Loglama Sistemi
* Çok Dilli Ürün Yapısı
* Ürün Görseli Yükleme
* DDoS Koruma Mekanizması
* Redis Rate Limiting

---

## Mobil Uygulama (Flutter)

Mobil uygulama Flutter kullanılarak geliştirilmiştir.

### Özellikler

* Kullanıcı Kayıt
* Kullanıcı Giriş
* JWT Oturum Yönetimi
* Ürün Listeleme
* Ürün Detay Sayfası
* Sepet Yönetimi
* Sipariş Yönetimi
* Profil Yönetimi
* ESP32 Araç Kontrolü
* Joystick Kontrolü
* Drift Modu
* Hız Kontrolü
* ESP32 WebView Desteği

---

## Web Sitesi

Web sitesi kullanıcıların ürünleri inceleyebilmesi ve sipariş verebilmesi amacıyla geliştirilmiştir.

### Özellikler

* Ürün Listeleme
* Ürün Detayları
* Sepet İşlemleri
* Sipariş Oluşturma
* Kullanıcı Hesabı Yönetimi
* Kimlik Doğrulama

---

## Admin Panel

Admin paneli sistem yönetimi amacıyla geliştirilmiştir.

### Özellikler

* Dashboard
* Kullanıcı Yönetimi
* Ürün Yönetimi
* Sipariş Yönetimi
* Gelir İstatistikleri
* Düşük Stok Takibi
* Admin Başvuruları
* Komut Logları
* Araç Bağlantı Durumu Takibi

---

## Donanım Sistemi

Araç kontrol sistemi ESP32 tabanlı olarak geliştirilmiştir.

### Özellikler

* WiFi Access Point
* HTTP Komut Kontrolü
* İleri Hareket
* Geri Hareket
* Sağ Dönüş
* Sol Dönüş
* Dur Komutu
* Drift Modu
* PWM Hız Kontrolü
* L298N Motor Sürücü Desteği

---

# Kullanılan Teknolojiler

## Backend

* Python
* FastAPI
* MongoDB
* Redis
* JWT
* Pydantic
* WebSocket
* Docker
* Docker Compose

## Mobil

* Flutter
* Provider
* Dio
* flutter_secure_storage
* webview_flutter
* cached_network_image

## Donanım

* ESP32
* Arduino Framework
* L298N Motor Driver

---

# Proje Yapısı

```text
smartcar-project/
│
├── backend/
│   ├── app/
│   ├── uploads/
│   ├── Dockerfile
│   ├── requirements.txt
│   └── docker-compose.yml
│
├── mobile/
│   ├── lib/
│   ├── assets/
│   └── pubspec.yaml
│
├── web/
│
├── admin/
│
└── README.md
```

---

# Kurulum

## Backend Kurulumu

### 1. Projeyi Klonlayın

```bash
git clone <repo-url>
cd smartcar-project
```

### 2. Sanal Ortam Oluşturun

```bash
python -m venv venv
```

Windows:

```bash
venv\Scripts\activate
```

Linux / MacOS:

```bash
source venv/bin/activate
```

### 3. Gerekli Paketleri Kurun

```bash
pip install -r requirements.txt
```



###  Backend'i Başlatın

```bash
uvicorn app.main:app --reload
```

Backend varsayılan olarak:

```text
http://localhost:......
```

adresinde çalışacaktır.

Swagger:

```text
http://localhost:..../docs
```

---

# Flutter Kurulumu

### Paketleri Kur

```bash
flutter pub get
```

### Uygulamayı Çalıştır

```bash
flutter run
```

---

# Docker ile Çalıştırma

Docker Compose kullanarak tüm servisleri çalıştırabilirsiniz.

```bash
docker compose up -d
```

Bu komut:

* FastAPI Backend
* MongoDB
* Redis

servislerini başlatacaktır.

Servisleri durdurmak için:

```bash
docker compose down
```

---

# API Endpointleri

## Authentication

```text
POST /api/v1/auth/register
POST /api/v1/auth/login
POST /api/v1/auth/refresh
```

## Products

```text
GET /api/v1/products
POST /api/v1/products
PUT /api/v1/products/{id}
DELETE /api/v1/products/{id}
```

## Cart

```text
GET /api/v1/cart
POST /api/v1/cart/add
DELETE /api/v1/cart/remove
```

## Orders

```text
GET /api/v1/orders
POST /api/v1/orders
```

## Logs

```text
POST /api/v1/logs/command
GET /api/v1/logs
```

---

# Güvenlik Özellikleri

* JWT Authentication
* Access Token
* Refresh Token
* Role Based Authorization
* Password Hashing (bcrypt)
* DDoS Protection
* Redis Rate Limiting
* WebSocket Authentication

---

# Araç Kontrol Sistemi

Mobil uygulama üzerinden gönderilen komutlar ESP32 cihazına iletilmektedir.

### Desteklenen Komutlar

```text
forward
backward
left
right
stop
drift
```

Komutlar ESP32 tarafından işlenerek motor sürücü üzerinden araca uygulanmaktadır.

---

# Gelecek Çalışmalar

* Gerçek ödeme sistemi entegrasyonu
* Bulut tabanlı araç yönetimi
* Çoklu araç desteği
* Push bildirim sistemi
* Canlı kamera yayını
* Yapay zeka destekli sürüş analizi


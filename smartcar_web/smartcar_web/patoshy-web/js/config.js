const API_BASE    = 'http://100.114.176.17:8000/api/v1';
const SERVER_BASE = 'http://100.114.176.17:8000';
const WS_BASE     = 'ws://100.114.176.17:8000';
const MOCK_MODE   = false;

// Backend'den gelen göreli URL'leri (/uploads/...) tam URL'ye çevirir
function fixImageUrl(url) {
  if (!url) return 'img/basic.png';
  if (url.startsWith('/')) return SERVER_BASE + url;
  if (url.startsWith('http')) return url;
  return url; // yerel img/ dosyaları için değiştirme
}

const MOCK_PRODUCTS = [
  {
    id:'p001', category:'basic',
    name:{tr:'Patoshy Basic',en:'Patoshy Basic'},
    description:{
      tr:'WiFi kontrollü 4WD RC araç. ESP-32 tabanlı, mobil uygulama ve web kontrol desteği. L298N motor sürücüsü ve LiPo 7.4V pil dahildir. QR kod ile saniyeler içinde bağlanın.',
      en:'WiFi controlled 4WD RC car with ESP-32, mobile app and web control.'
    },
    price:899, currency:'TRY', stock:15,
    images:['img/basic.png'],
    tags:['esp32','wifi','mobil','4wd'],
    specs:[
      ['Mikrodenetleyici','ESP-32 (240 MHz Dual Core)'],
      ['Motor Sürücü','L298N (2A/kanal)'],
      ['Güç','LiPo 7.4V 2200mAh'],
      ['Bağlantı','WiFi 802.11 b/g/n 2.4GHz'],
      ['Kontrol','Mobil + Web (WebSocket)'],
      ['Sürüş','4WD DC Motor × 4'],
    ]
  },
  {
    id:'p002', category:'cam',
    name:{tr:'Patoshy Cam',en:'Patoshy Cam'},
    description:{
      tr:'HD kamera modüllü akıllı RC araç. Canlı MJPEG görüntü akışı, QR bağlantı, joystick kontrol ve tüm Basic özellikleri. Kamera açısı servo motor ile ayarlanabilir.',
      en:'Smart RC car with HD camera, live streaming and all Basic features.'
    },
    price:1299, currency:'TRY', stock:8,
    images:['img/kamerali.png'],
    tags:['esp32','kamera','hd','canli'],
    specs:[
      ['Mikrodenetleyici','ESP-32-CAM (240 MHz)'],
      ['Kamera','OV2640 2MP HD'],
      ['Görüntü','Canlı MJPEG akışı'],
      ['Motor Sürücü','L298N (2A/kanal)'],
      ['Güç','LiPo 7.4V 2200mAh'],
      ['Sürüş','4WD DC Motor × 4'],
    ]
  },
  {
    id:'p003', category:'pro',
    name:{tr:'Patoshy Pro',en:'Patoshy Pro'},
    description:{
      tr:'Sensör paketi ve yarı-otonom sürüş destekli profesyonel model. HC-SR04 ultrasonik sensörler, IR kızılötesi sensörler, HD kamera ve gelişmiş log sistemi.',
      en:'Professional model with sensor suite and semi-autonomous driving.'
    },
    price:1899, currency:'TRY', stock:5,
    images:['img/pro.png'],
    tags:['esp32','sensor','otonom','pro'],
    specs:[
      ['Mikrodenetleyici','ESP-32 (240 MHz Dual Core)'],
      ['Kamera','OV2640 2MP HD'],
      ['Sensörler','HC-SR04 × 2 + IR × 4'],
      ['Motor Sürücü','L298N (2A/kanal)'],
      ['Güç','LiPo 7.4V 3000mAh'],
      ['Mod','Manuel + Yarı-Otonom'],
    ]
  },
  {
    id:'p004', category:'aksesuar',
    name:{tr:'LiPo Pil 7.4V 3000mAh',en:'LiPo Battery 7.4V 3000mAh'},
    description:{
      tr:'Yüksek kapasiteli yedek LiPo pil. Tüm Patoshy modelleriyle uyumlu. Dengeli şarj devresi ve aşırı deşarj koruması dahildir.',
      en:'High capacity replacement LiPo battery for all Patoshy models.'
    },
    price:199, currency:'TRY', stock:30,
    images:['img/lipopil.png'],
    tags:['pil','aksesuar','lipo'],
    specs:[
      ['Voltaj','7.4V (2S LiPo)'],
      ['Kapasite','3000mAh'],
      ['Deşarj','25C sürekli'],
      ['Konektör','XT30'],
      ['Ağırlık','~185g'],
    ]
  },
  {
    id:'p005', category:'aksesuar',
    name:{tr:'HC-SR04 Ultrasonik Sensör',en:'HC-SR04 Ultrasonic Sensor'},
    description:{
      tr:'Engel algılama için ultrasonik mesafe sensörü. Patoshy Pro ile tam uyumlu. 2cm ile 400cm arasında ±3mm hassasiyetle mesafe ölçümü.',
      en:'Ultrasonic distance sensor for obstacle detection compatible with Patoshy Pro.'
    },
    price:49, currency:'TRY', stock:50,
    images:['img/sensor.png'],
    tags:['sensor','ultrasonik','aksesuar'],
    specs:[
      ['Mesafe','2cm – 400cm'],
      ['Hassasiyet','±3mm'],
      ['Voltaj','5V DC'],
      ['Frekans','40kHz'],
    ]
  },
  {
    id:'p006', category:'aksesuar',
    name:{tr:'ESP-32 Geliştirme Kartı',en:'ESP-32 Dev Board'},
    description:{
      tr:'Orijinal ESP-32 DevKit v1 geliştirme kartı. USB programlama, 38 pin çıkış ve dahili WiFi+Bluetooth. Patoshy projeleri için yedek ve geliştirme amaçlıdır.',
      en:'Original ESP-32 DevKit for Patoshy projects, development and replacement.'
    },
    price:129, currency:'TRY', stock:25,
    images:['img/esp32.png'],
    tags:['esp32','gelistirme','aksesuar'],
    specs:[
      ['İşlemci','Xtensa LX6 240MHz'],
      ['WiFi','802.11 b/g/n'],
      ['Bluetooth','v4.2 + BLE'],
      ['Flash','4MB'],
      ['Pin Sayısı','38'],
    ]
  },
  {
    id:'p007', category:'aksesuar',
    name:{tr:'Şarj Cihazı (LiPo Balancer)',en:'LiPo Balance Charger'},
    description:{
      tr:'Dengeli LiPo pil şarj cihazı. Tüm Patoshy pil paketleriyle uyumlu. Aşırı şarj ve termal koruma dahil. AC 100-240V evrensel giriş.',
      en:'Balanced LiPo charger compatible with all Patoshy battery packs.'
    },
    price:149, currency:'TRY', stock:20,
    images:['img/sarjaleti.png'],
    tags:['sarj','aksesuar','lipo'],
    specs:[
      ['Giriş','100-240V AC'],
      ['Çıkış','8.4V 2A'],
      ['Uyumlu Pil','2S LiPo'],
      ['Koruma','Aşırı şarj + termal'],
    ]
  },
  {
    id:'p008', category:'sensorlu',
    name:{tr:'Patoshy Sensörlü',en:'Patoshy Sensor Edition'},
    description:{
      tr:'Sensör paketi entegre edilmiş özel model. Ultrasonik ve IR sensörler ile donatılmış, tam otonom engel algılama için optimize edilmiş araç.',
      en:'Special sensor-equipped model with ultrasonic and IR for autonomous obstacle detection.'
    },
    price:1599, currency:'TRY', stock:6,
    images:['img/sensorlu.png'],
    tags:['sensor','otonom','akilli'],
    specs:[
      ['Mikrodenetleyici','ESP-32 (240 MHz)'],
      ['Sensörler','HC-SR04 × 4 + IR × 6'],
      ['Motor Sürücü','L298N dual'],
      ['Güç','LiPo 7.4V 2500mAh'],
      ['Mod','Manuel + Yarı-Otonom'],
    ]
  },
];

const CartStorage = {
  get(){try{return JSON.parse(localStorage.getItem('ptCart')||'[]')}catch{return[]}},
  set(v){localStorage.setItem('ptCart',JSON.stringify(v))},
  clear(){localStorage.removeItem('ptCart')}
};
const TokenStorage = {
  get(){return localStorage.getItem('ptToken')},
  set(v){localStorage.setItem('ptToken',v)},
  clear(){localStorage.removeItem('ptToken');localStorage.removeItem('ptUser')}
};
const UserStorage = {
  get(){try{return JSON.parse(localStorage.getItem('ptUser')||'null')}catch{return null}},
  set(v){localStorage.setItem('ptUser',JSON.stringify(v))}
};

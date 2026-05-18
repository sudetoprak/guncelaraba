#include <WiFi.h>
#include <HTTPClient.h>
#include <vector>

/* ================= WIFI ================= */
const char* ssid     = "Seyma";
const char* password = "seymappp";

/* ================= LOG API ================= */
const char* logServerUrl = "http://100.114.176.17:8000/api/v1/logs/command";

/* ================= MOTOR PINS ================= */
#define ENA 21
#define ENB 26
#define IN1 18
#define IN2 19
#define IN3 22
#define IN4 23

WiFiServer server(80);
int motorSpeed = 200;

/* ================= LOG STRUCT ================= */
struct LogEntry {
  String cmd;
  int spd;
  unsigned long ms;
};

std::vector<LogEntry> logs;

/* ================= LOG GÖNDER ================= */
void sendLogToServer(String cmd, int spd) {
  if (WiFi.status() == WL_CONNECTED) {
    HTTPClient http;
    http.begin(logServerUrl);
    http.addHeader("Content-Type", "application/json");

    String json =
      "{\"command\":\"" + cmd +
      "\",\"speed\":"   + String(spd) +
      ",\"time\":"      + String(millis()) + "}";

    int code = http.POST(json);
    Serial.print("LOG GONDERILDI: ");
    Serial.println(code);
    http.end();
  }
}

/* ================= LOG EKLE ================= */
void addLog(String cmd, int spd) {
  logs.push_back({cmd, spd, millis()});
  Serial.println("CMD: " + cmd);
  sendLogToServer(cmd, spd);
}

/* ================= MOTOR ================= */
void dur() {
  digitalWrite(IN1, LOW); digitalWrite(IN2, LOW);
  digitalWrite(IN3, LOW); digitalWrite(IN4, LOW);
  analogWrite(ENA, 0);    analogWrite(ENB, 0);
}

void ileri() {
  addLog("forward", motorSpeed);
  digitalWrite(IN1, HIGH); digitalWrite(IN2, LOW);
  digitalWrite(IN3, HIGH); digitalWrite(IN4, LOW);
  analogWrite(ENA, motorSpeed); analogWrite(ENB, motorSpeed);
}

void geri() {
  addLog("backward", motorSpeed);
  digitalWrite(IN1, LOW);  digitalWrite(IN2, HIGH);
  digitalWrite(IN3, LOW);  digitalWrite(IN4, HIGH);
  analogWrite(ENA, motorSpeed); analogWrite(ENB, motorSpeed);
}

void sag() {
  addLog("right", motorSpeed);
  digitalWrite(IN1, HIGH); digitalWrite(IN2, LOW);
  digitalWrite(IN3, LOW);  digitalWrite(IN4, HIGH);
  analogWrite(ENA, motorSpeed); analogWrite(ENB, motorSpeed);
}

void sol() {
  addLog("left", motorSpeed);
  digitalWrite(IN1, LOW);  digitalWrite(IN2, HIGH);
  digitalWrite(IN3, HIGH); digitalWrite(IN4, LOW);
  analogWrite(ENA, motorSpeed); analogWrite(ENB, motorSpeed);
}

void drift() {
  addLog("drift", 255);
  analogWrite(ENA, 255); analogWrite(ENB, 255);
  digitalWrite(IN1, HIGH); digitalWrite(IN2, LOW);
  digitalWrite(IN3, HIGH); digitalWrite(IN4, LOW); delay(400);
  digitalWrite(IN1, HIGH); digitalWrite(IN2, LOW);
  digitalWrite(IN3, LOW);  digitalWrite(IN4, HIGH); delay(700);
  digitalWrite(IN1, LOW);  digitalWrite(IN2, HIGH);
  digitalWrite(IN3, HIGH); digitalWrite(IN4, LOW);  delay(700);
  digitalWrite(IN1, HIGH); digitalWrite(IN2, LOW);
  digitalWrite(IN3, HIGH); digitalWrite(IN4, LOW);  delay(400);
  dur();
}

/* ================= HTML (Joystick UI) ================= */
const char* htmlPage = R"rawliteral(
<!DOCTYPE html>
<html lang='tr'>
<head>
<meta charset='UTF-8'>
<meta name='viewport' content='width=device-width, initial-scale=1.0'>
<title>SmartCar Kontrol</title>
<style>
*{box-sizing:border-box;margin:0;padding:0;}
body{font-family:Arial,sans-serif;text-align:center;background:#fff9f0;display:flex;flex-direction:column;justify-content:center;align-items:center;min-height:100vh;padding:20px;}
h1{color:#cc0000;margin-bottom:20px;font-size:24px;}
#joystick-container{position:relative;width:220px;height:220px;border:3px solid #cc0000;border-radius:50%;background:rgba(0,0,0,0.05);margin-bottom:30px;touch-action:none;user-select:none;}
#joystick{position:absolute;width:80px;height:80px;background:#ff3333;border-radius:50%;top:70px;left:70px;box-shadow:0 0 15px #ff9999;transition:box-shadow .1s;}
.buttons{display:flex;gap:12px;flex-wrap:wrap;justify-content:center;margin-bottom:16px;}
.btn{padding:14px 20px;font-size:16px;cursor:pointer;border-radius:12px;border:2px solid #cc0000;background:#fff;color:#cc0000;font-weight:bold;transition:all .15s;}
.btn:active{background:#cc0000;color:#fff;}
.stop-btn{background:#cc0000;color:#fff;font-size:20px;padding:16px 40px;border-radius:12px;border:none;cursor:pointer;margin-bottom:12px;}
.drift-btn{background:#fff;color:#000;border:2px solid #ff6600;font-size:18px;padding:14px 36px;border-radius:12px;cursor:pointer;margin-bottom:16px;transition:all .15s;}
.drift-btn.active{background:#ff6600;color:#fff;}
.speed-label{font-size:18px;color:#b30000;font-weight:bold;margin-bottom:8px;}
#status{font-size:13px;color:#64748b;margin-top:8px;min-height:18px;}
.log-link{margin-top:16px;font-size:15px;}
.log-link a{color:#cc0000;text-decoration:none;font-weight:bold;}
</style>
</head>
<body>
<h1>🚗 SmartCar Kontrol</h1>

<div id="joystick-container">
  <div id="joystick"></div>
</div>

<div class="buttons">
  <button class="btn" onclick="setSpeed(50)">🐢 50</button>
  <button class="btn" onclick="setSpeed(100)">100</button>
  <button class="btn" onclick="setSpeed(150)">⚡ 150</button>
  <button class="btn" onclick="setSpeed(200)">200</button>
  <button class="btn" onclick="setSpeed(250)">🚀 250</button>
</div>

<button class="stop-btn" onclick="send('stop')">⏹ DUR</button><br>
<button class="drift-btn" id="driftBtn" onclick="doDrift()">💨 DRIFT AT!</button>

<div class="speed-label">Hız: <span id="speedVal">200</span></div>
<div id="status">Joystick hazır</div>
<div class="log-link"><a href="/logs">📋 Logları Gör</a></div>

<script>
const joystick   = document.getElementById('joystick');
const container  = document.getElementById('joystick-container');
const driftBtn   = document.getElementById('driftBtn');
const statusEl   = document.getElementById('status');
const W  = container.offsetWidth;
const H  = container.offsetHeight;
const JW = joystick.offsetWidth;
const JH = joystick.offsetHeight;
const centerX = W / 2;
const centerY = H / 2;
const maxDist = W / 2 - JW / 2;

let lastDir = '';
let mouseActive = false;

container.addEventListener('touchstart', onMove, {passive: false});
container.addEventListener('touchmove',  onMove, {passive: false});
container.addEventListener('touchend',   onEnd);
container.addEventListener('mousedown',  e => { mouseActive = true; onMove({touches:[e]}); });
document.addEventListener('mouseup',     ()  => { mouseActive = false; onEnd(); });
document.addEventListener('mousemove',   e   => { if (mouseActive) onMove({touches:[e]}); });

function onMove(e) {
  e.preventDefault();
  const t    = e.touches[0];
  const rect = container.getBoundingClientRect();
  const dx   = t.clientX - rect.left  - centerX;
  const dy   = t.clientY - rect.top   - centerY;
  const dist = Math.min(Math.sqrt(dx*dx + dy*dy), maxDist);
  const angle = Math.atan2(dy, dx);

  joystick.style.left = (centerX + dist * Math.cos(angle) - JW/2) + 'px';
  joystick.style.top  = (centerY + dist * Math.sin(angle) - JH/2) + 'px';

  let dir = 'stop';
  if (dist > 20) {
    const deg = angle * (180 / Math.PI);
    if      (deg > -45  && deg <  45)  dir = 'right';
    else if (deg >=  45 && deg < 135)  dir = 'backward';
    else if (deg >= -135 && deg < -45) dir = 'forward';
    else                               dir = 'left';
  }

  if (dir !== lastDir) {
    lastDir = dir;
    send(dir);
  }
}

function onEnd() {
  joystick.style.left = (centerX - JW/2) + 'px';
  joystick.style.top  = (centerY - JH/2) + 'px';
  send('stop');
  lastDir = '';
}

function send(cmd) {
  statusEl.textContent = '→ ' + cmd;
  fetch('/control?cmd=' + cmd).catch(() => {
    statusEl.textContent = '⚠️ Bağlantı hatası';
  });
}

function setSpeed(val) {
  document.getElementById('speedVal').innerText = val;
  fetch('/speed?value=' + val).catch(() => {});
}

function doDrift() {
  driftBtn.classList.add('active');
  fetch('/drift')
    .then(() => setTimeout(() => driftBtn.classList.remove('active'), 2000))
    .catch(()  => driftBtn.classList.remove('active'));
}
</script>
</body>
</html>
)rawliteral";

/* ================= LOG SAYFASI ================= */
void sendLogsPage(WiFiClient& client) {
  String lastCmd    = logs.empty() ? "-" : logs.back().cmd;
  unsigned long totalMs = logs.empty() ? 0 : (millis() - logs.front().ms);

  auto cmdColor = [](const String& c) -> String {
    if (c == "forward")  return "#22c55e";
    if (c == "backward") return "#f59e0b";
    if (c == "left")     return "#3b82f6";
    if (c == "right")    return "#a855f7";
    if (c == "stop")     return "#ef4444";
    if (c == "drift")    return "#ff6600";
    return "#64748b";
  };

  String html = "<!DOCTYPE html><html><head><meta charset='UTF-8'>";
  html += "<meta name='viewport' content='width=device-width,initial-scale=1'>";
  html += "<meta http-equiv='refresh' content='3'>";
  html += "<style>";
  html += "*{box-sizing:border-box;margin:0;padding:0;}";
  html += "body{font-family:Arial,sans-serif;background:#fff9f0;padding:20px;}";
  html += ".header{display:flex;align-items:center;justify-content:space-between;margin-bottom:20px;}";
  html += ".title{color:#cc0000;font-size:18px;font-weight:500;}";
  html += ".live{display:flex;align-items:center;gap:6px;font-size:12px;color:#64748b;}";
  html += ".dot{width:8px;height:8px;background:#22c55e;border-radius:50%;display:inline-block;}";
  html += ".stats{display:grid;grid-template-columns:repeat(3,1fr);gap:10px;margin-bottom:20px;}";
  html += ".stat{background:#fff;border:1px solid #e2e8f0;border-radius:10px;padding:12px;}";
  html += ".stat-label{color:#94a3b8;font-size:11px;margin-bottom:4px;}";
  html += ".stat-val{color:#0f172a;font-size:20px;font-weight:500;}";
  html += ".card{background:#fff;border:1px solid #e2e8f0;border-radius:10px;overflow:hidden;}";
  html += ".card-head{padding:12px 16px;border-bottom:1px solid #e2e8f0;display:flex;justify-content:space-between;}";
  html += ".card-head span{color:#64748b;font-size:12px;}";
  html += ".row{display:flex;align-items:center;padding:12px 16px;border-bottom:1px solid #f1f5f9;gap:12px;}";
  html += ".row:last-child{border-bottom:none;}";
  html += ".row:nth-child(even){background:#fafafa;}";
  html += ".badge{padding:4px 10px;border-radius:6px;font-size:12px;font-weight:500;min-width:72px;text-align:center;}";
  html += ".info{flex:1;color:#0f172a;font-size:13px;}";
  html += ".time{color:#94a3b8;font-size:11px;}";
  html += ".back{display:block;text-align:center;margin-top:16px;color:#cc0000;text-decoration:none;font-size:13px;font-weight:500;}";
  html += "</style></head><body>";

  html += "<div class='header'>";
  html += "<div class='title'>🚗 SmartCar Logları</div>";
  html += "<div class='live'><span class='dot'></span>Canlı</div>";
  html += "</div>";

  html += "<div class='stats'>";
  html += "<div class='stat'><div class='stat-label'>Toplam Komut</div><div class='stat-val'>" + String(logs.size()) + "</div></div>";
  html += "<div class='stat'><div class='stat-label'>Son Komut</div><div class='stat-val' style='font-size:14px'>" + lastCmd + "</div></div>";
  html += "<div class='stat'><div class='stat-label'>Toplam Süre</div><div class='stat-val'>" + String(totalMs/1000) + "s</div></div>";
  html += "</div>";

  html += "<div class='card'>";
  html += "<div class='card-head'><span>Komut Geçmişi</span><span>3sn'de yenilenir</span></div>";

  if (logs.empty()) {
    html += "<div style='padding:20px;text-align:center;color:#94a3b8;font-size:13px;'>Henüz log yok.</div>";
  } else {
    for (int i = logs.size()-1; i >= 0; i--) {
      String col = cmdColor(logs[i].cmd);
      String bg  = col + "20";
      html += "<div class='row'>";
      html += "<span class='badge' style='background:" + bg + ";color:" + col + "'>" + logs[i].cmd + "</span>";
      html += "<div class='info'>Hız: " + String(logs[i].spd) + "</div>";
      html += "<div class='time'>" + String(logs[i].ms/1000) + "s</div>";
      html += "</div>";
    }
  }

  html += "</div>";
  html += "<a class='back' href='/'>← Joystick'e Dön</a>";
  html += "</body></html>";

  client.println("HTTP/1.1 200 OK");
  client.println("Content-Type: text/html; charset=utf-8");
  client.println("Connection: close");
  client.println();
  client.print(html);
  client.stop();
}

/* ================= HTTP HANDLER ================= */
void handleHttp(WiFiClient client) {
  String req = client.readStringUntil('\r');
  client.flush();

  if (req.indexOf("GET /logs") != -1) { sendLogsPage(client); return; }

  if      (req.indexOf("/control?cmd=forward")  != -1) ileri();
  else if (req.indexOf("/control?cmd=backward") != -1) geri();
  else if (req.indexOf("/control?cmd=left")     != -1) sol();
  else if (req.indexOf("/control?cmd=right")    != -1) sag();
  else if (req.indexOf("/control?cmd=stop")     != -1) { addLog("stop", 0); dur(); }
  else if (req.indexOf("/drift")                != -1) drift();
  else if (req.indexOf("/speed?value=")         != -1)
    motorSpeed = constrain(req.substring(req.indexOf("=")+1).toInt(), 50, 255);

  client.println("HTTP/1.1 200 OK");
  client.println("Content-Type: text/html; charset=utf-8");
  client.println("Connection: close");
  client.println();
  client.print(htmlPage);
  client.stop();
}

/* ================= WIFI CONNECT ================= */
void connectWiFi() {
  WiFi.begin(ssid, password);
  Serial.print("WiFi baglaniyor");
  while (WiFi.status() != WL_CONNECTED) {
    delay(500); Serial.print(".");
  }
  Serial.println("\nWiFi BAGLANDI!");
  Serial.print("IP: ");
  Serial.println(WiFi.localIP());
}

/* ================= SETUP ================= */
void setup() {
  Serial.begin(115200);
  pinMode(ENA,OUTPUT); pinMode(ENB,OUTPUT);
  pinMode(IN1,OUTPUT); pinMode(IN2,OUTPUT);
  pinMode(IN3,OUTPUT); pinMode(IN4,OUTPUT);
  dur();
  connectWiFi();
  server.begin();
  Serial.println("Server hazir");
}

/* ================= LOOP ================= */
void loop() {
  WiFiClient client = server.available();
  if (client) handleHttp(client);
}
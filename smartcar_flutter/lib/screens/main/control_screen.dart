import 'dart:async';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../services/api_client.dart';

const String _carId = 'car1';

// ESP32 AP modunda bu IP'de çalışır
const String _esp32BaseUrl = 'http://192.168.4.1';

class ControlScreen extends StatefulWidget {
  const ControlScreen({super.key});

  @override
  State<ControlScreen> createState() => _ControlScreenState();
}

class _ControlScreenState extends State<ControlScreen> {
  final _storage = const FlutterSecureStorage();
  final _espDio = Dio(BaseOptions(
    connectTimeout: const Duration(milliseconds: 800),
    receiveTimeout: const Duration(milliseconds: 800),
    sendTimeout: const Duration(milliseconds: 800),
  ));

  Timer? _pingTimer;
  bool _espConnected = false;
  String _statusMsg = 'ESP32 aranıyor...';
  String? _lastCmd;
  int? _lastLatency;
  bool _carReached = false;

  Offset _joystickOffset = Offset.zero;
  String _activeCmd = 'stop';
  int _speed = 200;

  static const double _padSize = 260;
  static const double _knobSize = 86;
  static const double _maxDist = (_padSize / 2) - (_knobSize / 2);

  @override
  void initState() {
    super.initState();
    _startPing();
  }

  @override
  void dispose() {
    _pingTimer?.cancel();
    _espDio.close();
    super.dispose();
  }

  // ESP32'nin erişilebilir olup olmadığını 3 saniyede bir kontrol et
  void _startPing() {
    _pingTimer = Timer.periodic(const Duration(seconds: 3), (_) => _ping());
    _ping();
  }

  Future<void> _ping() async {
    // ESP32'ye bağlantı kontrolü — /ping yoksa / dener
    bool ok = false;
    for (final path in ['/ping', '/']) {
      try {
        final resp = await _espDio.get('$_esp32BaseUrl$path');
        if (resp.statusCode != null) {
          ok = true;
          break;
        }
      } catch (_) {}
    }
    if (ok && !_espConnected) {
      setState(() {
        _espConnected = true;
        _statusMsg = 'ESP32 bağlı — hazır!';
      });
    } else if (!ok && _espConnected) {
      setState(() {
        _espConnected = false;
        _statusMsg = 'ESP32 bağlantısı kesildi (192.168.4.1)';
      });
    } else if (!ok) {
      setState(() => _statusMsg = 'ESP32 bekleniyor... (192.168.4.1)');
    }
  }

  // ESP32'ye komut gönder + backend'e logla
  Future<void> _send(String command) async {
    final sw = Stopwatch()..start();
    bool reached = false;

    // 1. ESP32'ye direkt gönder
    try {
      await _espDio.get('$_esp32BaseUrl/control?cmd=$command');
      reached = true;
    } catch (_) {
      // ESP32'ye ulaşılamadı — yine de log'la
    }

    sw.stop();
    final latency = sw.elapsedMilliseconds;

    setState(() {
      _lastCmd = command;
      _lastLatency = latency;
      _carReached = reached;
    });

    // 2. Backend'e log gönder (admin paneli için, fire-and-forget)
    _logToBackend(command, latency, reached);
  }

  Future<void> _logToBackend(String command, int latencyMs, bool carReached) async {
    try {
      final token = await _storage.read(key: 'access_token');
      if (token == null) return;
      await ApiClient().dio.post(
        '/logs/command',
        data: {
          'car_id':     _carId,
          'command':    command,
          'x':          _joystickOffset.dx / _maxDist,
          'y':          _joystickOffset.dy / _maxDist,
          'speed':      _speed,
          'latency_ms': latencyMs,
          'car_reached': carReached,
        },
      );
    } catch (_) {
      // Backend yoksa sessizce devam et
    }
  }

  void _onJoystickMove(Offset localPos) {
    final center = const Offset(_padSize / 2, _padSize / 2);
    final delta = localPos - center;
    final dist = delta.distance;
    final clampedDist = min(dist, _maxDist);
    final angle = atan2(delta.dy, delta.dx);
    final clamped = Offset(
      clampedDist * cos(angle),
      clampedDist * sin(angle),
    );

    String cmd = 'stop';
    if (dist > 20) {
      final deg = angle * 180 / pi;
      if (deg > -45 && deg < 45) cmd = 'right';
      else if (deg >= 45 && deg < 135) cmd = 'backward';
      else if (deg >= -135 && deg < -45) cmd = 'forward';
      else cmd = 'left';
    }

    setState(() => _joystickOffset = clamped);

    if (cmd != _activeCmd) {
      _activeCmd = cmd;
      _send(cmd);
    }
  }

  void _onJoystickEnd() {
    setState(() => _joystickOffset = Offset.zero);
    if (_activeCmd != 'stop') {
      _activeCmd = 'stop';
      _send('stop');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF9F0),
      body: SafeArea(
        child: Column(
          children: [
            _buildStatusBar(),
            const Spacer(),
            if (_lastCmd != null) ...[
              _buildCarStatus(),
              const SizedBox(height: 16),
            ],
            _buildJoystick(),
            const SizedBox(height: 28),
            _buildSpeedButtons(),
            const SizedBox(height: 20),
            _buildStopButton(),
            const SizedBox(height: 16),
            _buildDriftButton(),
            const SizedBox(height: 12),
            Text(
              'Hız: $_speed',
              style: const TextStyle(
                color: Color(0xFFB30000),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      color: Colors.white,
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _espConnected
                  ? const Color(0xFF22C55E)
                  : const Color(0xFFEF4444),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _statusMsg,
              style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            _esp32BaseUrl,
            style: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 11,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCarStatus() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      margin: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _carReached
              ? const Color(0xFF22C55E).withOpacity(0.4)
              : const Color(0xFFEF4444).withOpacity(0.4),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _carReached ? Icons.check_circle : Icons.cancel,
            size: 16,
            color: _carReached ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
          ),
          const SizedBox(width: 8),
          Text(
            'Son komut: $_lastCmd',
            style: const TextStyle(
                color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
          ),
          if (_lastLatency != null) ...[
            const SizedBox(width: 12),
            Text(
              '$_lastLatency ms',
              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildJoystick() {
    return GestureDetector(
      onPanStart: (d) => _onJoystickMove(d.localPosition),
      onPanUpdate: (d) => _onJoystickMove(d.localPosition),
      onPanEnd: (_) => _onJoystickEnd(),
      onPanCancel: _onJoystickEnd,
      child: Container(
        width: _padSize,
        height: _padSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black.withOpacity(0.05),
          border: Border.all(color: const Color(0xFFCC0000), width: 3),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Transform.translate(
              offset: _joystickOffset,
              child: Container(
                width: _knobSize,
                height: _knobSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFFF3333),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF9999).withOpacity(0.8),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpeedButtons() {
    final speeds = [50, 100, 150, 200, 250];
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: speeds.map((s) {
        final active = _speed == s;
        return GestureDetector(
          onTap: () => setState(() => _speed = s),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: active ? const Color(0xFFCC0000) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFCC0000), width: 2),
            ),
            child: Text(
              '$s',
              style: TextStyle(
                color: active ? Colors.white : const Color(0xFFCC0000),
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStopButton() {
    return GestureDetector(
      onTap: () {
        _activeCmd = 'stop';
        _send('stop');
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFCC0000),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          '⏹ DUR',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildDriftButton() {
    return GestureDetector(
      onTap: () => _send('drift'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFF6600), width: 2),
        ),
        child: const Text(
          '💨 DRIFT AT!',
          style: TextStyle(
            color: Color(0xFF000000),
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

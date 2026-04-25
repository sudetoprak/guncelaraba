import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';

class RegisterScreen extends StatefulWidget {
  final VoidCallback onGoLogin;
  const RegisterScreen({super.key, required this.onGoLogin});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _fullNameCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _loading = false;
  bool _showPass = false;

  Future<void> _register() async {
    final fullName = _fullNameCtrl.text.trim();
    final username = _usernameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final password = _passCtrl.text;
    final confirm = _confirmCtrl.text;

    if (fullName.isEmpty || username.isEmpty || email.isEmpty || password.isEmpty) {
      _showError('Tüm zorunlu alanları doldurun.');
      return;
    }
    if (username.length < 3) {
      _showError('Kullanıcı adı en az 3 karakter olmalı.');
      return;
    }
    if (password.length < 8) {
      _showError('Şifre en az 8 karakter olmalı.');
      return;
    }
    if (password != confirm) {
      _showError('Şifreler eşleşmiyor.');
      return;
    }

    setState(() => _loading = true);
    try {
      await context.read<AuthProvider>().register(
            email: email,
            username: username,
            password: password,
            fullName: fullName,
            phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
          );
    } on DioException catch (e) {
      final detail = e.response?.data;
      String msg = 'Kayıt başarısız.';
      if (detail is Map && detail['detail'] != null) {
        msg = detail['detail'].toString();
      } else if (detail is String && detail.isNotEmpty) {
        msg = detail;
      } else if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.connectionError) {
        msg = 'Sunucuya bağlanılamadı. İnternet bağlantınızı kontrol edin.';
      }
      if (mounted) _showError(msg);
    } catch (e) {
      if (mounted) _showError('Kayıt başarısız: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String msg) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Hata', style: TextStyle(color: Color(0xFFF1F5F9))),
        content: Text(msg, style: const TextStyle(color: Color(0xFF94A3B8))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tamam', style: TextStyle(color: Color(0xFF3B82F6))),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 20),
              const Text('🚗', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 8),
              const Text('SmartCar',
                  style: TextStyle(
                      fontSize: 28, fontWeight: FontWeight.w800,
                      color: Color(0xFFF1F5F9), letterSpacing: 1)),
              const SizedBox(height: 4),
              const Text('Yeni hesap oluştur',
                  style: TextStyle(fontSize: 15, color: Color(0xFF94A3B8))),
              const SizedBox(height: 32),
              _field('Ad Soyad *', _fullNameCtrl, 'Adınız Soyadınız'),
              _field('Kullanıcı Adı *', _usernameCtrl, 'kullanici_adi',
                  caps: TextCapitalization.none),
              _field('Email *', _emailCtrl, 'ornek@email.com',
                  keyboard: TextInputType.emailAddress, caps: TextCapitalization.none),
              _field('Telefon', _phoneCtrl, '+90 5XX XXX XX XX',
                  keyboard: TextInputType.phone),
              _label('Şifre *'),
              _passRow(),
              const SizedBox(height: 12),
              _field('Şifre Tekrar *', _confirmCtrl, 'Şifrenizi tekrar girin',
                  obscure: !_showPass),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _register,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3B82F6),
                    disabledBackgroundColor: const Color(0xFF3B82F6).withOpacity(0.6),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _loading
                      ? const SizedBox(
                          height: 20, width: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Kayıt Ol',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: widget.onGoLogin,
                child: RichText(
                  text: const TextSpan(
                    text: 'Zaten hesabın var mı? ',
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 15),
                    children: [
                      TextSpan(
                        text: 'Giriş Yap',
                        style: TextStyle(
                            color: Color(0xFF60A5FA), fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 6, top: 12),
          child: Text(text,
              style: const TextStyle(
                  color: Color(0xFFCBD5E1), fontSize: 13, fontWeight: FontWeight.w600)),
        ),
      );

  Widget _field(
    String label,
    TextEditingController ctrl,
    String hint, {
    TextInputType keyboard = TextInputType.text,
    TextCapitalization caps = TextCapitalization.words,
    bool obscure = false,
  }) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label(label),
          TextField(
            controller: ctrl,
            keyboardType: keyboard,
            textCapitalization: caps,
            obscureText: obscure,
            autocorrect: false,
            style: const TextStyle(color: Color(0xFFF1F5F9), fontSize: 15),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: Color(0xFF64748B)),
              filled: true,
              fillColor: const Color(0xFF1E293B),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF334155))),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF334155))),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF3B82F6))),
              contentPadding: const EdgeInsets.all(14),
            ),
          ),
        ],
      );

  Widget _passRow() => Row(
        children: [
          Expanded(
            child: TextField(
              controller: _passCtrl,
              obscureText: !_showPass,
              style: const TextStyle(color: Color(0xFFF1F5F9), fontSize: 15),
              decoration: InputDecoration(
                hintText: 'En az 8 karakter',
                hintStyle: const TextStyle(color: Color(0xFF64748B)),
                filled: true,
                fillColor: const Color(0xFF1E293B),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF334155))),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF334155))),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF3B82F6))),
                contentPadding: const EdgeInsets.all(14),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => setState(() => _showPass = !_showPass),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: Text(
                _showPass ? 'Gizle' : 'Göster',
                style: const TextStyle(
                    color: Color(0xFF60A5FA), fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      );

  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _usernameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }
}

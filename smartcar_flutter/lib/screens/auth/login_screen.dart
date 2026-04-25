import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback onGoRegister;
  const LoginScreen({super.key, required this.onGoRegister});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  bool _showPass = false;

  Future<void> _login() async {
    if (_emailCtrl.text.trim().isEmpty || _passCtrl.text.trim().isEmpty) {
      _showError('Email ve şifre zorunludur.');
      return;
    }
    setState(() => _loading = true);
    try {
      await context.read<AuthProvider>().login(_emailCtrl.text.trim(), _passCtrl.text);
    } catch (e) {
      _showError(_extractError(e));
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

  String _extractError(dynamic e) => e.toString().contains('detail')
      ? e.toString()
      : 'Giriş başarısız.';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 60),
              const Text('🚗', style: TextStyle(fontSize: 64)),
              const SizedBox(height: 8),
              const Text('SmartCar',
                  style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFF1F5F9),
                      letterSpacing: 1)),
              const SizedBox(height: 4),
              const Text('Hesabına giriş yap',
                  style: TextStyle(fontSize: 16, color: Color(0xFF94A3B8))),
              const SizedBox(height: 40),
              _label('Email'),
              _input(controller: _emailCtrl, hint: 'ornek@email.com',
                  keyboard: TextInputType.emailAddress),
              const SizedBox(height: 12),
              _label('Şifre'),
              _passField(),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _login,
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
                      : const Text('Giriş Yap',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
                              color: Colors.white)),
                ),
              ),
              const SizedBox(height: 20),
              Row(children: [
                Expanded(child: Divider(color: const Color(0xFF334155))),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text('veya', style: TextStyle(color: Color(0xFF64748B))),
                ),
                Expanded(child: Divider(color: const Color(0xFF334155))),
              ]),
              const SizedBox(height: 20),
              TextButton(
                onPressed: widget.onGoRegister,
                child: RichText(
                  text: const TextSpan(
                    text: "Hesabın yok mu? ",
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 15),
                    children: [
                      TextSpan(
                        text: 'Kayıt Ol',
                        style: TextStyle(
                            color: Color(0xFF60A5FA), fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(text,
              style: const TextStyle(
                  color: Color(0xFFCBD5E1), fontSize: 14, fontWeight: FontWeight.w600)),
        ),
      );

  Widget _input({
    required TextEditingController controller,
    required String hint,
    TextInputType keyboard = TextInputType.text,
    bool obscure = false,
  }) =>
      TextField(
        controller: controller,
        keyboardType: keyboard,
        obscureText: obscure,
        autocorrect: false,
        style: const TextStyle(color: Color(0xFFF1F5F9), fontSize: 16),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Color(0xFF64748B)),
          filled: true,
          fillColor: const Color(0xFF1E293B),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF334155)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF334155)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF3B82F6)),
          ),
          contentPadding: const EdgeInsets.all(14),
        ),
      );

  Widget _passField() => Row(
        children: [
          Expanded(
            child: TextField(
              controller: _passCtrl,
              obscureText: !_showPass,
              style: const TextStyle(color: Color(0xFFF1F5F9), fontSize: 16),
              decoration: InputDecoration(
                hintText: 'En az 8 karakter',
                hintStyle: const TextStyle(color: Color(0xFF64748B)),
                filled: true,
                fillColor: const Color(0xFF1E293B),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF334155)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF334155)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF3B82F6)),
                ),
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
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }
}

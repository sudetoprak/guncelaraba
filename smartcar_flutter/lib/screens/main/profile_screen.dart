import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    if (user == null) return const SizedBox();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      child: Column(
        children: [
          Column(
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF3B82F6),
                ),
                child: Center(
                  child: Text(
                    user.fullName.isNotEmpty
                        ? user.fullName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                        color: Colors.white, fontSize: 40, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(user.fullName,
                  style: const TextStyle(
                      color: Color(0xFFF1F5F9), fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text('@${user.username}',
                  style: const TextStyle(color: Color(0xFF64748B), fontSize: 15)),
              if (user.role == 'admin') ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7C3AED).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF7C3AED)),
                  ),
                  child: const Text('Admin',
                      style: TextStyle(
                          color: Color(0xFFA78BFA), fontSize: 12, fontWeight: FontWeight.w700)),
                ),
              ],
            ],
          ),
          const SizedBox(height: 32),
          _section('Hesap Bilgileri', [
            _InfoRow(icon: '✉️', label: 'Email', value: user.email),
            if (user.phone != null) _InfoRow(icon: '📱', label: 'Telefon', value: user.phone!),
            _InfoRow(icon: '📅', label: 'Kayıt Tarihi', value: _formatDate(user.createdAt)),
            _InfoRow(
                icon: '🌐',
                label: 'Dil',
                value: user.language == 'tr' ? 'Türkçe' : 'English'),
          ]),
          if (user.address != null) ...[
            const SizedBox(height: 16),
            _section('Adres', [
              _InfoRow(icon: '🏠', label: 'Sokak', value: user.address!.street),
              _InfoRow(icon: '🏙️', label: 'Şehir', value: user.address!.city),
              _InfoRow(icon: '🌍', label: 'Ülke', value: user.address!.country),
              _InfoRow(icon: '📮', label: 'Posta Kodu', value: user.address!.zip),
            ]),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _confirmLogout(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7F1D1D),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: const BorderSide(color: Color(0xFF991B1B))),
              ),
              child: const Text('Çıkış Yap',
                  style: TextStyle(
                      color: Color(0xFFFCA5A5), fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Çıkış Yap', style: TextStyle(color: Color(0xFFF1F5F9))),
        content: const Text('Hesabından çıkmak istediğinden emin misin?',
            style: TextStyle(color: Color(0xFF94A3B8))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal', style: TextStyle(color: Color(0xFF64748B))),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<AuthProvider>().logout();
            },
            child: const Text('Çıkış Yap', style: TextStyle(color: Color(0xFFF87171))),
          ),
        ],
      ),
    );
  }

  Widget _section(String title, List<Widget> rows) => Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title.toUpperCase(),
                style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1)),
            const SizedBox(height: 12),
            ...rows,
          ],
        ),
      );

  String _formatDate(String isoDate) {
    try {
      final dt = DateTime.parse(isoDate);
      return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
    } catch (_) {
      return isoDate;
    }
  }
}

class _InfoRow extends StatelessWidget {
  final String icon;
  final String label;
  final String value;

  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF334155))),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(icon, style: const TextStyle(fontSize: 18), textAlign: TextAlign.center),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(value,
                    style: const TextStyle(color: Color(0xFFF1F5F9), fontSize: 15)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

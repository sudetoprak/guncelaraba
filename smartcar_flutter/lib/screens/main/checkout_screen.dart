import 'package:flutter/material.dart';
import '../../providers/models/models.dart';
import '../../services/orders_service.dart';
import '../../services/cart_service.dart';

const _kPrimary     = Color(0xFF1E3A8A);
const _kPrimaryBg   = Color(0xFFEFF6FF);
const _kSuccess     = Color(0xFF10B981);
const _kDanger      = Color(0xFFEF4444);
const _kText        = Color(0xFF0F172A);
const _kTextSub     = Color(0xFF64748B);
const _kTextHint    = Color(0xFF94A3B8);
const _kBorder      = Color(0xFFE2E8F0);
const _kSurface     = Color(0xFFF8FAFC);

class CheckoutScreen extends StatefulWidget {
  final VoidCallback onBack;
  final VoidCallback onSuccess;

  const CheckoutScreen({super.key, required this.onBack, required this.onSuccess});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _streetCtrl  = TextEditingController();
  final _cityCtrl    = TextEditingController();
  final _countryCtrl = TextEditingController(text: 'Türkiye');
  final _zipCtrl     = TextEditingController();

  String _paymentMethod = 'cash_on_delivery';
  bool   _loading       = false;
  bool   _orderSuccess  = false;

  Cart?  _cart;
  bool   _cartLoading = true;

  final _orderService = OrdersService();
  final _cartService  = CartService();

  @override
  void initState() {
    super.initState();
    _fetchCart();
  }

  Future<void> _fetchCart() async {
    try {
      final cart = await _cartService.get();
      if (mounted) setState(() => _cart = cart);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _cartLoading = false);
    }
  }

  Future<void> _placeOrder() async {
    if (_streetCtrl.text.trim().isEmpty ||
        _cityCtrl.text.trim().isEmpty   ||
        _zipCtrl.text.trim().isEmpty) {
      _showError('Adres bilgilerini eksiksiz doldurun.');
      return;
    }
    setState(() => _loading = true);
    try {
      await _orderService.create(
        shippingAddress: Address(
          street:  _streetCtrl.text.trim(),
          city:    _cityCtrl.text.trim(),
          country: _countryCtrl.text.trim(),
          zip:     _zipCtrl.text.trim(),
        ),
        paymentMethod: _paymentMethod,
      );
      if (mounted) setState(() => _orderSuccess = true);
    } catch (e) {
      if (mounted) {
        final msg = e is Exception
            ? e.toString().replaceFirst('Exception: ', '')
            : 'Sipariş verilemedi.';
        _showError(msg);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600)),
      backgroundColor: _kDanger,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (_orderSuccess) return _buildSuccess();

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // ── Üst bar ────────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(4, 48, 16, 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: _kBorder)),
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: widget.onBack,
                  icon: const Icon(Icons.arrow_back_ios_new,
                      color: _kPrimary, size: 18),
                ),
                Container(
                  width: 34, height: 34,
                  decoration: BoxDecoration(
                      color: _kPrimaryBg,
                      borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.receipt_long_outlined,
                      color: _kPrimary, size: 18),
                ),
                const SizedBox(width: 10),
                const Text('Sipariş Özeti',
                    style: TextStyle(
                        color: _kText, fontSize: 17,
                        fontWeight: FontWeight.w800)),
              ],
            ),
          ),

          // ── İçerik ─────────────────────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Sepet özeti
                  _sectionTitle('Sipariş Detayı',
                      Icons.shopping_bag_outlined),
                  const SizedBox(height: 10),
                  _buildCartSummary(),

                  const SizedBox(height: 24),

                  // Teslimat adresi
                  _sectionTitle('Teslimat Adresi',
                      Icons.location_on_outlined),
                  const SizedBox(height: 10),
                  _field('Sokak / Mahalle *', _streetCtrl,
                      'Atatürk Cad. No:5 D:3'),
                  _field('Şehir *', _cityCtrl, 'İstanbul'),
                  _field('Ülke', _countryCtrl, 'Türkiye'),
                  _field('Posta Kodu *', _zipCtrl, '34000',
                      keyboard: TextInputType.number),

                  const SizedBox(height: 24),

                  // Ödeme yöntemi
                  _sectionTitle('Ödeme Yöntemi',
                      Icons.payment_outlined),
                  const SizedBox(height: 10),

                  ...[
                    ('cash_on_delivery', 'Kapıda Ödeme',
                        Icons.local_shipping_outlined,
                        'Teslimat sırasında ödeme yapın'),
                    ('credit_card', 'Kredi Kartı',
                        Icons.credit_card_outlined,
                        'Kredi / banka kartı ile öde'),
                    ('bank_transfer', 'Havale / EFT',
                        Icons.account_balance_outlined,
                        'Banka transferi ile öde'),
                  ].map((o) => _payOption(o.$1, o.$2, o.$3, o.$4)),

                  const SizedBox(height: 8),

                  // Kapıda ödeme notu
                  if (_paymentMethod == 'cash_on_delivery')
                    Container(
                      margin: const EdgeInsets.only(top: 8, bottom: 4),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline,
                              color: Color(0xFFD97706), size: 18),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Ürün teslim edildiğinde nakit veya kart ile ödeme yapabilirsiniz.',
                              style: TextStyle(
                                  color: Color(0xFF92400E),
                                  fontSize: 12,
                                  height: 1.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),

          // ── Alt buton ──────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: _kBorder)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Toplam satırı
                if (_cart != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Toplam Tutar',
                            style: TextStyle(
                                color: _kTextSub, fontSize: 14)),
                        Text('₺${_cart!.total.toStringAsFixed(0)}',
                            style: const TextStyle(
                                color: _kPrimary, fontSize: 22,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5)),
                      ],
                    ),
                  ),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _placeOrder,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kPrimary,
                      disabledBackgroundColor: _kPrimary.withAlpha(120),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: _loading
                        ? const SizedBox(
                            height: 20, width: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _paymentMethod == 'cash_on_delivery'
                                    ? Icons.local_shipping
                                    : Icons.check_circle_outline,
                                color: Colors.white, size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _paymentMethod == 'cash_on_delivery'
                                    ? 'Kapıda Öde & Onayla'
                                    : 'Siparişi Onayla',
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 16,
                                    fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Sipariş başarılı ekranı ─────────────────────────────────────────────────
  Widget _buildSuccess() => Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 100, height: 100,
                    decoration: const BoxDecoration(
                        color: Color(0xFFD1FAE5),
                        shape: BoxShape.circle),
                    child: const Icon(Icons.check_rounded,
                        color: _kSuccess, size: 54),
                  ),
                  const SizedBox(height: 24),
                  const Text('Siparişiniz Alındı!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: _kText, fontSize: 24,
                          fontWeight: FontWeight.w900)),
                  const SizedBox(height: 12),
                  Text(
                    _paymentMethod == 'cash_on_delivery'
                        ? 'Siparişiniz onaylandı.\nTeslimat sırasında ödeme yapabilirsiniz.'
                        : 'Siparişiniz başarıyla oluşturuldu.\nEn kısa sürede hazırlanacak.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: _kTextSub, fontSize: 15, height: 1.6),
                  ),
                  const SizedBox(height: 36),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: widget.onSuccess,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: const Text('Ana Sayfaya Dön',
                          style: TextStyle(
                              color: Colors.white, fontSize: 16,
                              fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

  // ── Sepet özet kartı ────────────────────────────────────────────────────────
  Widget _buildCartSummary() {
    if (_cartLoading) {
      return const Center(
          child: Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: CircularProgressIndicator(color: _kPrimary, strokeWidth: 2),
      ));
    }
    if (_cart == null || _cart!.items.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: _kSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _kBorder)),
        child: const Row(
          children: [
            Icon(Icons.warning_amber_outlined, color: _kTextHint, size: 18),
            SizedBox(width: 8),
            Text('Sepet bilgisi yüklenemedi.',
                style: TextStyle(color: _kTextSub, fontSize: 13)),
          ],
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
          color: _kSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _kBorder)),
      child: Column(
        children: [
          ..._cart!.items.asMap().entries.map((e) {
            final i    = e.key;
            final item = e.value;
            final last = i == _cart!.items.length - 1;
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.name.tr,
                                style: const TextStyle(
                                    color: _kText, fontSize: 13,
                                    fontWeight: FontWeight.w700)),
                            const SizedBox(height: 3),
                            Text('${item.quantity} adet',
                                style: const TextStyle(
                                    color: _kTextHint, fontSize: 12)),
                          ],
                        ),
                      ),
                      Text('₺${item.subtotal.toStringAsFixed(0)}',
                          style: const TextStyle(
                              color: _kPrimary, fontSize: 14,
                              fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
                if (!last)
                  const Divider(height: 1, color: _kBorder, indent: 14,
                      endIndent: 14),
              ],
            );
          }),
          const Divider(height: 1, color: _kBorder),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Toplam',
                    style: TextStyle(
                        color: _kText, fontSize: 14,
                        fontWeight: FontWeight.w700)),
                Text('₺${_cart!.total.toStringAsFixed(0)}',
                    style: const TextStyle(
                        color: _kPrimary, fontSize: 16,
                        fontWeight: FontWeight.w900)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Yardımcı widget'lar ─────────────────────────────────────────────────────
  Widget _sectionTitle(String title, IconData icon) => Row(
        children: [
          Icon(icon, color: _kPrimary, size: 18),
          const SizedBox(width: 8),
          Text(title,
              style: const TextStyle(
                  color: _kText, fontSize: 15, fontWeight: FontWeight.w800)),
        ],
      );

  Widget _field(
    String label,
    TextEditingController ctrl,
    String hint, {
    TextInputType keyboard = TextInputType.text,
  }) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 5),
            child: Text(label,
                style: const TextStyle(
                    color: _kTextSub, fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ),
          TextField(
            controller: ctrl,
            keyboardType: keyboard,
            style: const TextStyle(color: _kText, fontSize: 14),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: _kTextHint, fontSize: 13),
              filled: true,
              fillColor: _kSurface,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _kBorder)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _kBorder)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      const BorderSide(color: _kPrimary, width: 1.5)),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              isDense: true,
            ),
          ),
        ],
      );

  Widget _payOption(
          String id, String label, IconData icon, String subtitle) =>
      GestureDetector(
        onTap: () => setState(() => _paymentMethod = id),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: _paymentMethod == id ? _kPrimaryBg : _kSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _paymentMethod == id ? _kPrimary : _kBorder,
              width: _paymentMethod == id ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  color: _paymentMethod == id
                      ? _kPrimaryBg
                      : _kSurface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon,
                    size: 18,
                    color: _paymentMethod == id ? _kPrimary : _kTextHint),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: TextStyle(
                            color: _paymentMethod == id
                                ? _kText
                                : _kTextSub,
                            fontSize: 14,
                            fontWeight: FontWeight.w700)),
                    Text(subtitle,
                        style: const TextStyle(
                            color: _kTextHint, fontSize: 11)),
                  ],
                ),
              ),
              if (_paymentMethod == id)
                const Icon(Icons.check_circle_rounded,
                    color: _kPrimary, size: 20),
            ],
          ),
        ),
      );

  @override
  void dispose() {
    _streetCtrl.dispose();
    _cityCtrl.dispose();
    _countryCtrl.dispose();
    _zipCtrl.dispose();
    super.dispose();
  }
}

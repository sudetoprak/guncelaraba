import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../providers/models/models.dart';
import '../../services/products_service.dart';
import '../../services/cart_service.dart';

const _kPrimary    = Color(0xFF1E3A8A);
const _kPrimaryBg  = Color(0xFFEFF6FF);
const _kPrimaryBorder = Color(0xFFBFDBFE);
const _kGreenMid   = Color(0xFF10B981);
const _kSuccess    = Color(0xFF10B981);
const _kDanger     = Color(0xFFEF4444);
const _kWarning    = Color(0xFFF59E0B);
const _kText       = Color(0xFF0F172A);
const _kTextSub    = Color(0xFF64748B);
const _kTextHint   = Color(0xFF94A3B8);
const _kBorder     = Color(0xFFE2E8F0);
const _kSurface    = Color(0xFFF8FAFC);

Color _catColor(String cat) {
  switch (cat.toLowerCase()) {
    case 'araba':   return _kPrimary;
    case 'batarya': return _kGreenMid;
    case 'parca':   return const Color(0xFF2563EB);
    default:        return _kWarning;
  }
}

Color _catBg(String cat) {
  switch (cat.toLowerCase()) {
    case 'araba':   return _kPrimaryBg;
    case 'batarya': return const Color(0xFFD1FAE5);
    case 'parca':   return const Color(0xFFDBEAFE);
    default:        return const Color(0xFFFEF3C7);
  }
}

String _catLabel(String cat) {
  switch (cat.toLowerCase()) {
    case 'araba':   return 'Araba';
    case 'batarya': return 'Batarya';
    case 'parca':   return 'Parça';
    default:        return cat;
  }
}

class ProductDetailScreen extends StatefulWidget {
  final String productId;
  final VoidCallback onBack;
  final VoidCallback onCheckout;

  const ProductDetailScreen({
    super.key,
    required this.productId,
    required this.onBack,
    required this.onCheckout,
  });

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  final _productsService = ProductsService();
  final _cartService     = CartService();

  Product? _product;
  bool _loading       = true;
  bool _adding        = false;
  bool _orderLoading  = false;
  int  _qty           = 1;
  int  _imgIndex      = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final p = await _productsService.get(widget.productId);
      if (mounted) setState(() => _product = p);
    } catch (_) {
      if (mounted) _snack('Ürün yüklenemedi.', error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addToCart() async {
    if (_product == null) return;
    setState(() => _adding = true);
    try {
      await _cartService.add(_product!.id, _qty);
      if (mounted) _snack('$_qty adet sepete eklendi.');
    } catch (_) {
      if (mounted) _snack('Sepete eklenemedi.', error: true);
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  Future<void> _goToCheckout() async {
    if (_product == null) return;
    setState(() => _orderLoading = true);
    try {
      await _cartService.add(_product!.id, _qty);
      if (mounted) widget.onCheckout();
    } catch (_) {
      if (mounted) _snack('Sipariş oluşturulamadı.', error: true);
    } finally {
      if (mounted) setState(() => _orderLoading = false);
    }
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600)),
      backgroundColor: error ? _kDanger : _kSuccess,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator(color: _kPrimary)),
      );
    }

    if (_product == null) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: _kTextHint, size: 48),
              const SizedBox(height: 12),
              const Text('Ürün bulunamadı.',
                  style: TextStyle(color: _kTextSub, fontSize: 16)),
              const SizedBox(height: 12),
              TextButton(
                onPressed: widget.onBack,
                child: const Text('← Geri',
                    style: TextStyle(
                        color: _kPrimary, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      );
    }

    final p       = _product!;
    final color   = _catColor(p.category);
    final bg      = _catBg(p.category);
    final screenW = MediaQuery.of(context).size.width;
    final bool busy = _adding || _orderLoading;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Fotoğraf alanı ────────────────────────────────────────
                  Stack(
                    children: [
                      Container(
                        height: 300,
                        width: double.infinity,
                        color: bg,
                        child: p.images.isNotEmpty
                            ? PageView.builder(
                                itemCount: p.images.length,
                                onPageChanged: (i) =>
                                    setState(() => _imgIndex = i),
                                itemBuilder: (_, i) => CachedNetworkImage(
                                  imageUrl: p.images[i],
                                  fit: BoxFit.cover,
                                  width: screenW,
                                  placeholder: (_, __) => const Center(
                                      child: CircularProgressIndicator(
                                          color: _kPrimary)),
                                  errorWidget: (_, __, ___) => Center(
                                      child: Icon(Icons.directions_car,
                                          color: color.withOpacity(0.4),
                                          size: 80)),
                                ),
                              )
                            : Center(
                                child: Icon(Icons.directions_car,
                                    color: color.withOpacity(0.4), size: 80)),
                      ),

                      // Geri butonu
                      Positioned(
                        top: 48, left: 16,
                        child: GestureDetector(
                          onTap: widget.onBack,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 9),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2))
                              ],
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.arrow_back_ios_new,
                                    color: _kPrimary, size: 14),
                                SizedBox(width: 4),
                                Text('Geri',
                                    style: TextStyle(
                                        color: _kPrimary,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Nokta indikatörü
                  if (p.images.length > 1)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          p.images.length,
                          (i) => AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin:
                                const EdgeInsets.symmetric(horizontal: 3),
                            width: i == _imgIndex ? 20 : 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: i == _imgIndex ? _kPrimary : _kBorder,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      ),
                    ),

                  // ── Ürün bilgileri ────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Kategori + stok
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                  color: bg,
                                  borderRadius: BorderRadius.circular(8)),
                              child: Text(_catLabel(p.category),
                                  style: TextStyle(
                                      color: color, fontSize: 11,
                                      fontWeight: FontWeight.w700)),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: p.stock > 0
                                    ? const Color(0xFFD1FAE5)
                                    : const Color(0xFFFEE2E2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                p.stock > 0
                                    ? 'Stok: ${p.stock} adet'
                                    : 'Stok Yok',
                                style: TextStyle(
                                    color: p.stock > 0 ? _kSuccess : _kDanger,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 14),

                        // Ürün adı
                        Text(p.name.tr,
                            style: const TextStyle(
                                color: _kText, fontSize: 22,
                                fontWeight: FontWeight.w900, height: 1.2)),

                        if (p.name.en.trim().isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(p.name.en,
                              style: const TextStyle(
                                  color: _kTextHint, fontSize: 13)),
                        ],

                        const SizedBox(height: 16),

                        // Fiyat
                        Text('₺${p.price.toStringAsFixed(0)}',
                            style: const TextStyle(
                                color: _kPrimary, fontSize: 34,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -1)),

                        const SizedBox(height: 20),
                        const Divider(color: _kBorder, thickness: 1),
                        const SizedBox(height: 16),

                        // Açıklama başlığı
                        const Text('AÇIKLAMA',
                            style: TextStyle(
                                color: _kTextHint, fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1)),
                        const SizedBox(height: 8),

                        Text(
                          p.description.tr.trim().isNotEmpty
                              ? p.description.tr
                              : 'Bu ürün için henüz açıklama eklenmemiş.',
                          style: const TextStyle(
                              color: _kTextSub, fontSize: 14, height: 1.75),
                        ),

                        // Etiketler
                        if (p.tags.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 8, runSpacing: 6,
                            children: p.tags
                                .map((t) => Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: _kPrimaryBg,
                                        borderRadius:
                                            BorderRadius.circular(20),
                                        border: Border.all(
                                            color: _kPrimaryBorder),
                                      ),
                                      child: Text('#$t',
                                          style: const TextStyle(
                                              color: _kPrimary,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600)),
                                    ))
                                .toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Alt buton çubuğu ──────────────────────────────────────────────
          if (p.stock > 0)
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: _kBorder)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Üst satır: miktar + sepete ekle
                  Row(
                    children: [
                      // Miktar seçici
                      Container(
                        decoration: BoxDecoration(
                          color: _kSurface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _kBorder),
                        ),
                        child: Row(
                          children: [
                            _qtyBtn('−', () => setState(
                                () => _qty = (_qty - 1).clamp(1, p.stock))),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              child: Text('$_qty',
                                  style: const TextStyle(
                                      color: _kText, fontSize: 16,
                                      fontWeight: FontWeight.w700)),
                            ),
                            _qtyBtn('+', () => setState(
                                () => _qty = (_qty + 1).clamp(1, p.stock))),
                          ],
                        ),
                      ),

                      const SizedBox(width: 10),

                      // Sepete ekle
                      Expanded(
                        child: GestureDetector(
                          onTap: busy ? null : _addToCart,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: busy
                                  ? _kPrimary.withOpacity(0.7)
                                  : _kPrimary,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: _adding
                                ? const Center(
                                    child: SizedBox(
                                      width: 20, height: 20,
                                      child: CircularProgressIndicator(
                                          color: Colors.white, strokeWidth: 2),
                                    ),
                                  )
                                : const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.add_shopping_cart_rounded,
                                          color: Colors.white, size: 16),
                                      SizedBox(width: 6),
                                      Text('Sepete Ekle',
                                          style: TextStyle(
                                              color: Colors.white, fontSize: 15,
                                              fontWeight: FontWeight.w700)),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // Sipariş tamamla butonu (tam genişlik)
                  GestureDetector(
                    onTap: busy ? null : _goToCheckout,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: busy
                            ? _kSuccess.withOpacity(0.7)
                            : _kSuccess,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: _orderLoading
                          ? const Center(
                              child: SizedBox(
                                width: 20, height: 20,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2),
                              ),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.bolt_rounded,
                                    color: Colors.white, size: 18),
                                SizedBox(width: 6),
                                Text('Sipariş Tamamla',
                                    style: TextStyle(
                                        color: Colors.white, fontSize: 15,
                                        fontWeight: FontWeight.w700)),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              color: Colors.white,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                    color: _kBorder,
                    borderRadius: BorderRadius.circular(12)),
                child: const Center(
                  child: Text('Bu ürün tükendi',
                      style: TextStyle(
                          color: _kTextSub, fontSize: 15,
                          fontWeight: FontWeight.w700)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _qtyBtn(String label, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: 40, height: 46,
          child: Center(
            child: Text(label,
                style: const TextStyle(
                    color: _kText, fontSize: 20,
                    fontWeight: FontWeight.w400)),
          ),
        ),
      );
}
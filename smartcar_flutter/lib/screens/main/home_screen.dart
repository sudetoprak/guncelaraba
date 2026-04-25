import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../providers/models/models.dart';
import '../../services/products_service.dart';
import '../../services/cart_service.dart';
import '../../services/orders_service.dart';
import 'control_screen.dart';

// ─── Renk Sabitleri ──────────────────────────────────────────────────────────

const _kPrimary      = Color(0xFF1E3A8A);
const _kPrimaryMid   = Color(0xFF2563EB);
const _kPrimaryBg    = Color(0xFFEFF6FF);
const _kPrimaryBorder= Color(0xFFBFDBFE);
const _kGreen        = Color(0xFF065F46);
const _kGreenMid     = Color(0xFF10B981);
const _kSuccess      = Color(0xFF10B981);
const _kWarning      = Color(0xFFF59E0B);
const _kDanger       = Color(0xFFEF4444);
const _kText         = Color(0xFF0F172A);
const _kTextSub      = Color(0xFF64748B);
const _kTextHint     = Color(0xFF94A3B8);
const _kBorder       = Color(0xFFE2E8F0);
const _kSurface      = Color(0xFFF8FAFC);

const _categories = ['Tümü', 'araba', 'parca', 'batarya'];

enum _HomeView { dashboard, joystick, shop }

Color _catColor(String cat) {
  switch (cat.toLowerCase()) {
    case 'araba':   return _kPrimary;
    case 'batarya': return _kGreenMid;
    case 'parca':   return _kPrimaryMid;
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

// ─── Ana Widget ───────────────────────────────────────────────────────────────

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _productsService = ProductsService();
  final _cartService     = CartService();

  _HomeView _view     = _HomeView.dashboard;
  List<Product> _products = [];
  bool   _loading     = false;
  String _search      = '';
  String _category    = 'Tümü';
  String? _addingId;

  // ── Navigasyon ──────────────────────────────────────────────────────────────
  void _openShop()     { setState(() => _view = _HomeView.shop);     _fetch(); }
  void _openJoystick() => setState(() => _view = _HomeView.joystick);
  void _back()         => setState(() => _view = _HomeView.dashboard);

  // ── Servis Çağrıları ────────────────────────────────────────────────────────
  Future<void> _fetch() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final data = await _productsService.list(
        category: _category == 'Tümü' ? null : _category,
        search:   _search.isEmpty     ? null : _search,
      );
      if (mounted) setState(() => _products = data);
    } catch (_) {
      if (mounted) _snack('Ürünler yüklenemedi.', error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addToCart(String productId, {int qty = 1}) async {
    setState(() => _addingId = productId);
    try {
      await _cartService.add(productId, qty);
      if (mounted) _snack('Sepete eklendi!');
    } catch (_) {
      if (mounted) _snack('Sepete eklenemedi.', error: true);
    } finally {
      if (mounted) setState(() => _addingId = null);
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

  void _showDetail(Product product) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ProductDetailSheet(
        product: product,
        onAddToCart: (qty) {
          Navigator.pop(context);
          _addToCart(product.id, qty: qty);
        },
        onBuyNow: (qty) {
          Navigator.pop(context);
          _addToCart(product.id, qty: qty).then((_) {
            if (mounted) _showCheckout();
          });
        },
      ),
    );
  }

  void _showCheckout() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CheckoutSheet(
        onSuccess: () {
          Navigator.pop(context);
          _snack('Siparişiniz alındı!');
        },
      ),
    );
  }

  // ── Build ───────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    switch (_view) {
      case _HomeView.dashboard: return _buildDashboard();
      case _HomeView.joystick:  return _buildJoystick();
      case _HomeView.shop:      return _buildShop();
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // DASHBOARD
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildDashboard() {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          // Üst başlık bandı
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 52, 20, 28),
            decoration: const BoxDecoration(
              color: _kPrimary,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 38, height: 38,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.directions_car, color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 10),
                    const Text('SmartCar',
                        style: TextStyle(
                            color: Colors.white, fontSize: 22,
                            fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text('v1.0',
                          style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Text('Hoş geldiniz 👋',
                    style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                const Text('Ne yapmak istersiniz?',
                    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
              ],
            ),
          ),

          const SizedBox(height: 24),

          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  Expanded(
                    child: _DashCard(
                      icon: Icons.sports_esports_rounded,
                      title: 'Joystick Kontrolü',
                      subtitle: 'Aracini uzaktan yönet',
                      gradientStart: const Color(0xFF1E3A8A),
                      gradientEnd:   const Color(0xFF2563EB),
                      badge: 'CANLI',
                      onTap: _openJoystick,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: _DashCard(
                      icon: Icons.storefront_rounded,
                      title: 'Mağaza',
                      subtitle: 'Araç, parça ve batarya al',
                      gradientStart: const Color(0xFF065F46),
                      gradientEnd:   const Color(0xFF10B981),
                      badge: 'YENİ ÜRÜNLER',
                      onTap: _openShop,
                    ),
                  ),
                  const SizedBox(height: 28),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // JOYSTİCK
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildJoystick() {
    return Column(
      children: [
        _topBar('Joystick Kontrolü', Icons.sports_esports_rounded),
        const Expanded(child: ControlScreen()),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // MAĞAZA
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildShop() {
    return Column(
      children: [
        _topBar('Mağaza', Icons.storefront_rounded),

        // Arama kutusu
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
          child: TextField(
            onChanged: (v) { _search = v; _fetch(); },
            style: const TextStyle(color: _kText, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Ürün, kategori veya marka ara...',
              hintStyle: const TextStyle(color: _kTextHint, fontSize: 13),
              prefixIcon: const Icon(Icons.search, color: _kTextHint, size: 20),
              suffixIcon: const Icon(Icons.tune, color: _kPrimaryMid, size: 20),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: _kBorder)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: _kBorder)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: _kPrimary, width: 1.5)),
              contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
              isDense: true,
            ),
          ),
        ),

        const SizedBox(height: 10),

        // Kategori filtreleri
        SizedBox(
          height: 38,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            scrollDirection: Axis.horizontal,
            itemCount: _categories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final cat    = _categories[i];
              final active = _category == cat;
              final color  = cat == 'Tümü' ? _kPrimary : _catColor(cat);
              return GestureDetector(
                onTap: () { setState(() => _category = cat); _fetch(); },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                  decoration: BoxDecoration(
                    color: active ? color : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: active ? color : _kBorder, width: 1.5),
                    boxShadow: active
                        ? [BoxShadow(color: color.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2))]
                        : [],
                  ),
                  child: Text(
                    cat == 'Tümü' ? 'Tümü' : _catLabel(cat),
                    style: TextStyle(
                        color: active ? Colors.white : _kTextSub,
                        fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
              );
            },
          ),
        ),

        // Ürün sayısı
        if (!_loading && _products.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 16, top: 8, bottom: 2),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('${_products.length} ürün listelendi',
                  style: const TextStyle(color: _kTextHint, fontSize: 12)),
            ),
          ),

        const SizedBox(height: 4),

        // Ürünler
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: _kPrimary))
              : _products.isEmpty
                  ? _emptyState()
                  : RefreshIndicator(
                      color: _kPrimary,
                      onRefresh: _fetch,
                      child: GridView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: 0.70,
                        ),
                        itemCount: _products.length,
                        itemBuilder: (_, i) => _ProductGridCard(
                          product:    _products[i],
                          isAdding:   _addingId == _products[i].id,
                          onDetail:   () => _showDetail(_products[i]),
                          onAddToCart:() => _addToCart(_products[i].id),
                          onBuyNow:   () => _addToCart(_products[i].id)
                              .then((_) => mounted ? _showCheckout() : null),
                        ),
                      ),
                    ),
        ),
      ],
    );
  }

  // ── Yardımcı Widget'lar ─────────────────────────────────────────────────────
  Widget _emptyState() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80, height: 80,
              decoration: const BoxDecoration(color: _kPrimaryBg, shape: BoxShape.circle),
              child: const Icon(Icons.search_off, size: 38, color: _kPrimary),
            ),
            const SizedBox(height: 16),
            const Text('Ürün bulunamadı',
                style: TextStyle(color: _kText, fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            const Text('Farklı bir arama yapmayı deneyin',
                style: TextStyle(color: _kTextHint, fontSize: 13)),
          ],
        ),
      );

  Widget _topBar(String title, IconData icon) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: _kBorder)),
        ),
        child: Row(
          children: [
            IconButton(
              onPressed: _back,
              icon: const Icon(Icons.arrow_back_ios_new, color: _kPrimary, size: 18),
            ),
            Icon(icon, color: _kPrimary, size: 20),
            const SizedBox(width: 8),
            Text(title,
                style: const TextStyle(
                    color: _kText, fontSize: 16, fontWeight: FontWeight.w800)),
          ],
        ),
      );
}

// ══════════════════════════════════════════════════════════════════════════════
// DASHBOARD KARTI
// ══════════════════════════════════════════════════════════════════════════════
class _DashCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color gradientStart;
  final Color gradientEnd;
  final String badge;
  final VoidCallback onTap;

  const _DashCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.gradientStart,
    required this.gradientEnd,
    required this.badge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [gradientStart, gradientEnd],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: gradientStart.withOpacity(0.35),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Dekoratif daireler
            Positioned(
              right: -20, top: -20,
              child: Container(
                width: 120, height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.06),
                ),
              ),
            ),
            Positioned(
              right: 20, bottom: -28,
              child: Container(
                width: 90, height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.06),
                ),
              ),
            ),

            // İçerik
            Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Üst satır: ikon + badge
                  Row(
                    children: [
                      Container(
                        width: 52, height: 52,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(icon, color: Colors.white, size: 28),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(badge,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 10,
                                fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                      ),
                    ],
                  ),

                  // Alt satır: başlık + buton
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 20,
                              fontWeight: FontWeight.w900, letterSpacing: -0.3)),
                      const SizedBox(height: 4),
                      Text(subtitle,
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.75), fontSize: 13)),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Başla',
                                style: TextStyle(
                                    color: gradientStart, fontSize: 13,
                                    fontWeight: FontWeight.w800)),
                            const SizedBox(width: 4),
                            Icon(Icons.arrow_forward, color: gradientStart, size: 14),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// ÜRÜN KART
// ══════════════════════════════════════════════════════════════════════════════
class _ProductGridCard extends StatelessWidget {
  final Product product;
  final bool isAdding;
  final VoidCallback onDetail;
  final VoidCallback onAddToCart;
  final VoidCallback onBuyNow;

  const _ProductGridCard({
    required this.product,
    required this.isAdding,
    required this.onDetail,
    required this.onAddToCart,
    required this.onBuyNow,
  });

  @override
  Widget build(BuildContext context) {
    final color = _catColor(product.category);
    final bg    = _catBg(product.category);

    return GestureDetector(
      onTap: onDetail,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _kBorder, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12, offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Ürün görseli
            Stack(
              children: [
                Container(
                  height: 120,
                  width: double.infinity,
                  color: bg,
                  child: product.images.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: product.images[0],
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Center(
                              child: CircularProgressIndicator(color: color, strokeWidth: 2)),
                          errorWidget: (_, __, ___) => Center(
                              child: Icon(Icons.directions_car,
                                  color: color.withOpacity(0.5), size: 40)),
                        )
                      : Center(
                          child: Icon(Icons.directions_car,
                              color: color.withOpacity(0.5), size: 40)),
                ),

                // Stok rozeti
                if (product.stock == 0)
                  Positioned(
                    top: 8, left: 8,
                    child: _badge('Tükendi', _kDanger),
                  )
                else if (product.stock <= 5)
                  Positioned(
                    top: 8, left: 8,
                    child: _badge('Son ${product.stock}', _kWarning),
                  ),
              ],
            ),

            // Bilgiler
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Kategori etiketi
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: bg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(_catLabel(product.category),
                          style: TextStyle(
                              color: color, fontSize: 9, fontWeight: FontWeight.w700)),
                    ),

                    const SizedBox(height: 5),

                    Text(product.name.tr,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: _kText, fontSize: 12,
                            fontWeight: FontWeight.w700, height: 1.3)),

                    const Spacer(),

                    Text('₺${product.price.toStringAsFixed(0)}',
                        style: const TextStyle(
                            color: _kPrimary, fontSize: 16, fontWeight: FontWeight.w900)),

                    const SizedBox(height: 8),

                    // Sepete ekle butonu
                    SizedBox(
                      width: double.infinity,
                      child: GestureDetector(
                        onTap: product.stock == 0 ? null : (isAdding ? null : onAddToCart),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: product.stock == 0 ? _kBorder : color,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: isAdding
                              ? const Center(
                                  child: SizedBox(
                                    width: 14, height: 14,
                                    child: CircularProgressIndicator(
                                        color: Colors.white, strokeWidth: 2),
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.add_shopping_cart_rounded,
                                        color: Colors.white, size: 12),
                                    const SizedBox(width: 4),
                                    Text(
                                      product.stock == 0 ? 'Tükendi' : 'Sepete Ekle',
                                      style: const TextStyle(
                                          color: Colors.white, fontSize: 11,
                                          fontWeight: FontWeight.w700),
                                    ),
                                  ],
                                ),
                        ),
                      ),
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

  Widget _badge(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: color, borderRadius: BorderRadius.circular(6),
        ),
        child: Text(text,
            style: const TextStyle(
                color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800)),
      );
}

// ══════════════════════════════════════════════════════════════════════════════
// ÜRÜN DETAY BOTTOM SHEET
// ══════════════════════════════════════════════════════════════════════════════
class _ProductDetailSheet extends StatefulWidget {
  final Product product;
  final void Function(int qty) onAddToCart;
  final void Function(int qty) onBuyNow;

  const _ProductDetailSheet({
    required this.product,
    required this.onAddToCart,
    required this.onBuyNow,
  });

  @override
  State<_ProductDetailSheet> createState() => _ProductDetailSheetState();
}

class _ProductDetailSheetState extends State<_ProductDetailSheet> {
  int _qty = 1;
  int _imgIndex = 0;

  @override
  Widget build(BuildContext context) {
    final p      = widget.product;
    final color  = _catColor(p.category);
    final bg     = _catBg(p.category);
    final screenW = MediaQuery.of(context).size.width;

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 6),
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: _kBorder, borderRadius: BorderRadius.circular(2)),
            ),

            Expanded(
              child: SingleChildScrollView(
                controller: ctrl,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Fotoğraf
                    Container(
                      height: 260, color: bg,
                      child: p.images.isNotEmpty
                          ? PageView.builder(
                              itemCount: p.images.length,
                              onPageChanged: (i) => setState(() => _imgIndex = i),
                              itemBuilder: (_, i) => CachedNetworkImage(
                                imageUrl: p.images[i],
                                fit: BoxFit.cover,
                                width: screenW,
                                placeholder: (_, __) => const Center(
                                    child: CircularProgressIndicator(color: _kPrimary)),
                                errorWidget: (_, __, ___) => Center(
                                    child: Icon(Icons.directions_car,
                                        color: color.withOpacity(0.4), size: 64)),
                              ),
                            )
                          : Center(
                              child: Icon(Icons.directions_car,
                                  color: color.withOpacity(0.4), size: 64)),
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
                              margin: const EdgeInsets.symmetric(horizontal: 3),
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
                                    color: bg, borderRadius: BorderRadius.circular(8)),
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
                                  p.stock > 0 ? 'Stok: ${p.stock} adet' : 'Stok Yok',
                                  style: TextStyle(
                                      color: p.stock > 0 ? _kSuccess : _kDanger,
                                      fontSize: 11, fontWeight: FontWeight.w700),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 14),

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
                                  color: _kPrimary, fontSize: 32,
                                  fontWeight: FontWeight.w900, letterSpacing: -1)),

                          const SizedBox(height: 20),
                          const Divider(color: _kBorder, thickness: 1),
                          const SizedBox(height: 16),

                          // Açıklama
                          const Text('AÇIKLAMA',
                              style: TextStyle(
                                  color: _kTextHint, fontSize: 11,
                                  fontWeight: FontWeight.w700, letterSpacing: 1)),
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
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(color: _kPrimaryBorder),
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

            // Alt buton çubuğu
            if (p.stock > 0)
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: _kBorder)),
                ),
                child: Row(
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
                            padding: const EdgeInsets.symmetric(horizontal: 12),
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

                    // Sepete Ekle
                    Expanded(
                      child: GestureDetector(
                        onTap: () => widget.onAddToCart(_qty),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: _kPrimary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Center(
                            child: Text('Sepete Ekle',
                                style: TextStyle(
                                    color: Colors.white, fontSize: 13,
                                    fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Satın Al
                    Expanded(
                      child: GestureDetector(
                        onTap: () => widget.onBuyNow(_qty),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: _kGreenMid,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Center(
                            child: Text('Satın Al',
                                style: TextStyle(
                                    color: Colors.white, fontSize: 13,
                                    fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
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
                    color: _kText, fontSize: 20, fontWeight: FontWeight.w400)),
          ),
        ),
      );
}

// ══════════════════════════════════════════════════════════════════════════════
// ÖDEME BOTTOM SHEET
// ══════════════════════════════════════════════════════════════════════════════
class _CheckoutSheet extends StatefulWidget {
  final VoidCallback onSuccess;
  const _CheckoutSheet({required this.onSuccess});

  @override
  State<_CheckoutSheet> createState() => _CheckoutSheetState();
}

class _CheckoutSheetState extends State<_CheckoutSheet> {
  final _streetCtrl  = TextEditingController();
  final _cityCtrl    = TextEditingController();
  final _countryCtrl = TextEditingController(text: 'Türkiye');
  final _zipCtrl     = TextEditingController();
  String _payment    = 'credit_card';
  bool   _loading    = false;

  final _service = OrdersService();

  Future<void> _place() async {
    if (_streetCtrl.text.trim().isEmpty ||
        _cityCtrl.text.trim().isEmpty   ||
        _zipCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Adres bilgilerini doldurun.'),
          backgroundColor: _kDanger,
        ),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      await _service.create(
        shippingAddress: Address(
          street:  _streetCtrl.text.trim(),
          city:    _cityCtrl.text.trim(),
          country: _countryCtrl.text.trim(),
          zip:     _zipCtrl.text.trim(),
        ),
        paymentMethod: _payment,
      );
      widget.onSuccess();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Sipariş verilemedi.'),
              backgroundColor: _kDanger),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                      color: _kBorder, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),

              // Başlık
              Row(
                children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                        color: _kPrimaryBg, borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.local_shipping_outlined,
                        color: _kPrimary, size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Text('Teslimat & Ödeme',
                      style: TextStyle(
                          color: _kText, fontSize: 18, fontWeight: FontWeight.w800)),
                ],
              ),

              const SizedBox(height: 20),

              _field('Sokak *',       _streetCtrl,  'Atatürk Cad. No:5'),
              _field('Şehir *',       _cityCtrl,    'İstanbul'),
              _field('Ülke',          _countryCtrl, 'Türkiye'),
              _field('Posta Kodu *',  _zipCtrl,     '34000',
                  keyboard: TextInputType.number),

              const SizedBox(height: 20),

              const Text('Ödeme Yöntemi',
                  style: TextStyle(
                      color: _kText, fontSize: 15, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),

              ...[
                ('credit_card',      'Kredi Kartı',    Icons.credit_card),
                ('bank_transfer',    'Havale / EFT',   Icons.account_balance),
                ('cash_on_delivery', 'Kapıda Ödeme',   Icons.local_shipping),
              ].map((o) => _payOpt(o.$1, o.$2, o.$3)),

              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _place,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kPrimary,
                    disabledBackgroundColor: _kPrimary.withAlpha(100),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: _loading
                      ? const SizedBox(
                          height: 20, width: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Text('Siparişi Onayla',
                          style: TextStyle(
                              color: Colors.white, fontSize: 16,
                              fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl, String hint,
      {TextInputType keyboard = TextInputType.text}) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 5),
            child: Text(label,
                style: const TextStyle(
                    color: _kTextSub, fontSize: 12, fontWeight: FontWeight.w600)),
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
                  borderSide: const BorderSide(color: _kPrimary, width: 1.5)),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              isDense: true,
            ),
          ),
        ],
      );

  Widget _payOpt(String id, String label, IconData icon) => GestureDetector(
        onTap: () => setState(() => _payment = id),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: _payment == id ? _kPrimaryBg : _kSurface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: _payment == id ? _kPrimary : _kBorder,
                width: _payment == id ? 1.5 : 1),
          ),
          child: Row(
            children: [
              Icon(icon,
                  size: 18,
                  color: _payment == id ? _kPrimary : _kTextHint),
              const SizedBox(width: 12),
              Text(label,
                  style: TextStyle(
                      color: _payment == id ? _kText : _kTextSub,
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
              const Spacer(),
              if (_payment == id)
                const Icon(Icons.check_circle, color: _kPrimary, size: 18),
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
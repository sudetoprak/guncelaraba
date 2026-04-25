import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../providers/models/models.dart';
import '../../services/cart_service.dart';
import 'product_detail_screen.dart';

const _kPrimary   = Color(0xFF1E3A8A);
const _kPrimaryBg = Color(0xFFEFF6FF);
const _kDanger    = Color(0xFFEF4444);
const _kText      = Color(0xFF0F172A);
const _kTextSub   = Color(0xFF64748B);
const _kTextHint  = Color(0xFF94A3B8);
const _kBorder    = Color(0xFFE2E8F0);
const _kSurface   = Color(0xFFF8FAFC);

class CartScreen extends StatefulWidget {
  final VoidCallback onCheckout;
  const CartScreen({super.key, required this.onCheckout});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final _service = CartService();
  Cart? _cart;
  bool _loading = true;
  String? _removing;
  String? _detailProductId; // hangi ürünün detayı açık

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      final data = await _service.get();
      if (mounted) setState(() => _cart = data);
    } catch (_) {
      if (mounted) _snackError('Sepet yüklenemedi.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _remove(String productId) async {
    setState(() => _removing = productId);
    try {
      await _service.remove(productId);
      await _fetch();
    } catch (_) {
      if (mounted) _snackError('Ürün kaldırılamadı.');
    } finally {
      if (mounted) setState(() => _removing = null);
    }
  }

  void _openDetail(String productId) =>
      setState(() => _detailProductId = productId);

  void _closeDetail() {
    setState(() => _detailProductId = null);
    _fetch(); // detaydan sepete ürün eklenmiş olabilir
  }

  void _clearCart() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Sepeti Temizle',
            style: TextStyle(color: _kText, fontWeight: FontWeight.w800)),
        content: const Text('Tüm ürünler silinecek, emin misiniz?',
            style: TextStyle(color: _kTextSub)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal',
                style: TextStyle(color: _kTextHint, fontWeight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _service.clear();
                await _fetch();
              } catch (_) {
                if (mounted) _snackError('Sepet temizlenemedi.');
              }
            },
            child: const Text('Temizle',
                style: TextStyle(color: _kDanger, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _snackError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600)),
      backgroundColor: _kDanger,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    // Detay sayfası açıksa onu göster
    if (_detailProductId != null) {
      return ProductDetailScreen(
        productId: _detailProductId!,
        onBack: _closeDetail,
        onCheckout: widget.onCheckout,
      );
    }

    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: _kPrimary));
    }

    final isEmpty = _cart == null || _cart!.items.isEmpty;
    if (isEmpty) return _emptyState();

    return Column(
      children: [
        // ── Üst bar ──────────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: _kBorder)),
          ),
          child: Row(
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                    color: _kPrimaryBg,
                    borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.shopping_cart_rounded,
                    color: _kPrimary, size: 18),
              ),
              const SizedBox(width: 10),
              Text('${_cart!.items.length} ürün',
                  style: const TextStyle(
                      color: _kText, fontSize: 16, fontWeight: FontWeight.w800)),
              const Spacer(),
              GestureDetector(
                onTap: _clearCart,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(20)),
                  child: const Text('Temizle',
                      style: TextStyle(
                          color: _kDanger, fontSize: 12,
                          fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),

        // ── Ürün listesi ─────────────────────────────────────────────────────
        Expanded(
          child: RefreshIndicator(
            color: _kPrimary,
            onRefresh: _fetch,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              itemCount: _cart!.items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) => _CartItemTile(
                item: _cart!.items[i],
                isRemoving: _removing == _cart!.items[i].productId,
                onRemove: () => _remove(_cart!.items[i].productId),
                onTap: () => _openDetail(_cart!.items[i].productId),
              ),
            ),
          ),
        ),

        // ── Alt özet + buton ─────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: _kBorder)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Toplam',
                      style: TextStyle(color: _kTextSub, fontSize: 15)),
                  Text('₺${_cart!.total.toStringAsFixed(0)}',
                      style: const TextStyle(
                          color: _kPrimary, fontSize: 26,
                          fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: widget.onCheckout,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_outline,
                          color: Colors.white, size: 18),
                      SizedBox(width: 8),
                      Text('Siparişi Tamamla',
                          style: TextStyle(
                              color: Colors.white, fontSize: 16,
                              fontWeight: FontWeight.w700)),
                      SizedBox(width: 4),
                      Icon(Icons.arrow_forward,
                          color: Colors.white, size: 16),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _emptyState() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96, height: 96,
              decoration: const BoxDecoration(
                  color: _kPrimaryBg, shape: BoxShape.circle),
              child: const Icon(Icons.shopping_cart_outlined,
                  color: _kPrimary, size: 44),
            ),
            const SizedBox(height: 20),
            const Text('Sepetiniz boş',
                style: TextStyle(
                    color: _kText, fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            const Text('Ürün eklemek için mağazaya göz atın',
                style: TextStyle(color: _kTextHint, fontSize: 14)),
          ],
        ),
      );
}

// ─── Sepet Ürün Kartı ─────────────────────────────────────────────────────────

class _CartItemTile extends StatelessWidget {
  final CartItem item;
  final bool isRemoving;
  final VoidCallback onRemove;
  final VoidCallback onTap;

  const _CartItemTile({
    required this.item,
    required this.isRemoving,
    required this.onRemove,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _kBorder),
          boxShadow: const [
            BoxShadow(
                color: Color(0x05000000),
                blurRadius: 8,
                offset: Offset(0, 2)),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            // Görsel
            Container(
              width: 88, height: 88,
              color: _kPrimaryBg,
              child: item.image != null
                  ? CachedNetworkImage(
                      imageUrl: item.image!,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => const Center(
                          child: Icon(Icons.directions_car,
                              color: _kPrimary, size: 32)))
                  : const Center(
                      child: Icon(Icons.directions_car,
                          color: _kPrimary, size: 32)),
            ),

            // Bilgiler
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.name.tr,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: _kText, fontSize: 14,
                            fontWeight: FontWeight.w700, height: 1.3)),
                    const SizedBox(height: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                          color: _kSurface,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: _kBorder)),
                      child: Text('${item.quantity} adet',
                          style: const TextStyle(
                              color: _kTextSub, fontSize: 11,
                              fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(height: 6),
                    Text('₺${item.subtotal.toStringAsFixed(0)}',
                        style: const TextStyle(
                            color: _kPrimary, fontSize: 16,
                            fontWeight: FontWeight.w900)),
                  ],
                ),
              ),
            ),

            // Sağ taraf: ok + sil
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Padding(
                  padding: EdgeInsets.only(right: 12, bottom: 8),
                  child: Icon(Icons.chevron_right,
                      color: _kTextHint, size: 20),
                ),
                GestureDetector(
                  onTap: isRemoving ? null : onRemove,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: isRemoving
                        ? const SizedBox(
                            width: 22, height: 22,
                            child: CircularProgressIndicator(
                                color: _kDanger, strokeWidth: 2))
                        : Container(
                            width: 30, height: 30,
                            decoration: const BoxDecoration(
                                color: Color(0xFFFEE2E2),
                                shape: BoxShape.circle),
                            child: const Icon(Icons.close,
                                color: _kDanger, size: 15),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import '../../providers/models/models.dart';
import '../../services/orders_service.dart';

const _statusMap = {
  'pending': (label: 'Beklemede', color: Color(0xFFF59E0B)),
  'confirmed': (label: 'Onaylandı', color: Color(0xFF60A5FA)),
  'shipped': (label: 'Kargoya Verildi', color: Color(0xFFA78BFA)),
  'delivered': (label: 'Teslim Edildi', color: Color(0xFF34D399)),
  'cancelled': (label: 'İptal Edildi', color: Color(0xFFF87171)),
};

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  final _service = OrdersService();
  List<Order> _orders = [];
  bool _loading = true;
  String? _expanded;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      final data = await _service.list();
      if (mounted) setState(() => _orders = data);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Siparişler yüklenemedi.'),
              backgroundColor: Color(0xFFF87171)),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF3B82F6)));
    }

    if (_orders.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('📦', style: TextStyle(fontSize: 56)),
            SizedBox(height: 10),
            Text('Henüz sipariş yok',
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 16)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: const Color(0xFF3B82F6),
      onRefresh: _fetch,
      child: ListView.separated(
        padding: const EdgeInsets.all(14),
        itemCount: _orders.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) {
          final order = _orders[i];
          final status = _statusMap[order.status] ??
              (label: order.status, color: const Color(0xFF94A3B8));
          final isOpen = _expanded == order.id;

          return GestureDetector(
            onTap: () => setState(() => _expanded = isOpen ? null : order.id),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('#${order.id.substring(order.id.length - 8).toUpperCase()}',
                              style: const TextStyle(
                                  color: Color(0xFFF1F5F9),
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1)),
                          const SizedBox(height: 2),
                          Text(
                            _formatDate(order.createdAt),
                            style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: status.color.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(status.label,
                                style: TextStyle(
                                    color: status.color,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700)),
                          ),
                          const SizedBox(height: 4),
                          Text('${order.total.toStringAsFixed(2)} TRY',
                              style: const TextStyle(
                                  color: Color(0xFF34D399),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ],
                  ),
                  if (isOpen) ...[
                    const SizedBox(height: 14),
                    const Divider(color: Color(0xFF334155)),
                    const SizedBox(height: 8),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Ürünler',
                          style: TextStyle(
                              color: Color(0xFFCBD5E1),
                              fontSize: 14,
                              fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(height: 8),
                    ...order.items.map((item) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(item.name.tr,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        color: Color(0xFF94A3B8), fontSize: 13)),
                              ),
                              const SizedBox(width: 8),
                              Text('x${item.quantity}',
                                  style: const TextStyle(
                                      color: Color(0xFF64748B), fontSize: 13)),
                              const SizedBox(width: 8),
                              Text('${item.subtotal.toStringAsFixed(2)} TRY',
                                  style: const TextStyle(
                                      color: Color(0xFFF1F5F9),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                        )),
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Teslimat Adresi',
                              style: TextStyle(
                                  color: Color(0xFF64748B),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Text(
                            '${order.shippingAddress.street}, ${order.shippingAddress.city}, ${order.shippingAddress.zip} ${order.shippingAddress.country}',
                            style: const TextStyle(
                                color: Color(0xFF94A3B8), fontSize: 13, height: 1.5),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(isOpen ? '▲ Gizle' : '▼ Detay',
                      style: const TextStyle(color: Color(0xFF475569), fontSize: 12)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _formatDate(String isoDate) {
    try {
      final dt = DateTime.parse(isoDate);
      return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
    } catch (_) {
      return isoDate;
    }
  }
}

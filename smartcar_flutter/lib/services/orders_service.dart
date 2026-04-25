import 'package:dio/dio.dart';
import '../providers/models/models.dart';
import 'api_client.dart';

class OrdersService {
  final _dio = ApiClient().dio;

  Future<List<Order>> list() async {
    final res = await _dio.get('/orders/');
    return (res.data as List).map((o) => Order.fromJson(o)).toList();
  }

  Future<void> create({required Address shippingAddress, required String paymentMethod}) async {
    try {
      await _dio.post('/orders/', data: {
        'shipping_address': shippingAddress.toJson(),
        'payment_method': paymentMethod,
      });
    } on DioException catch (e) {
      final detail = e.response?.data?['detail'];
      if (detail != null) throw Exception(detail.toString());
      throw Exception('Sunucuya bağlanılamadı (${e.response?.statusCode ?? 'ağ hatası'})');
    }
  }
}

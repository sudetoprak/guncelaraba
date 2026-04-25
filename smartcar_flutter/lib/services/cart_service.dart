import '../providers/models/models.dart';
import 'api_client.dart';

class CartService {
  final _dio = ApiClient().dio;

  Future<Cart> get() async {
    final res = await _dio.get('/cart/');
    return Cart.fromJson(res.data);
  }

  Future<void> add(String productId, int quantity) async {
    await _dio.post('/cart/add', data: {'product_id': productId, 'quantity': quantity});
  }

  Future<void> remove(String productId) async {
    await _dio.delete('/cart/remove/$productId');
  }

  Future<void> clear() async {
    await _dio.delete('/cart/clear');
  }
}

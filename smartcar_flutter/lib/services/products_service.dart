import '../providers/models/models.dart';
import 'api_client.dart';

class ProductsService {
  final _dio = ApiClient().dio;

  Future<List<Product>> list({String? category, String? search}) async {
    final res = await _dio.get('/products', queryParameters: {
      if (category != null) 'category': category,
      if (search != null && search.isNotEmpty) 'search': search,
      'lang': 'tr',
    });
    return (res.data as List).map((p) => Product.fromJson(p)).toList();
  }

  Future<Product> get(String id) async {
    final res = await _dio.get('/products/$id');
    return Product.fromJson(res.data);
  }
}

import 'package:smartcar_flutter/services/api_client.dart';

// Göreceli URL'leri tam URL'ye çevirir (/uploads/... → http://sunucu/uploads/...)
String fixImageUrl(String url) {
  if (url.startsWith('/')) return '$serverBaseUrl$url';
  return url;
}

class LocalizedText {
  final String tr;
  final String en;

  LocalizedText({required this.tr, required this.en});

  factory LocalizedText.fromJson(Map<String, dynamic> json) =>
      LocalizedText(tr: json['tr'] ?? '', en: json['en'] ?? '');
}

class Address {
  final String street;
  final String city;
  final String country;
  final String zip;

  Address({
    required this.street,
    required this.city,
    required this.country,
    required this.zip,
  });

  factory Address.fromJson(Map<String, dynamic> json) => Address(
        street: json['street'] ?? '',
        city: json['city'] ?? '',
        country: json['country'] ?? '',
        zip: json['zip'] ?? '',
      );

  Map<String, dynamic> toJson() => {
        'street': street,
        'city': city,
        'country': country,
        'zip': zip,
      };
}

class User {
  final String id;
  final String email;
  final String username;
  final String fullName;
  final String? phone;
  final String role;
  final String language;
  final Address? address;
  final String createdAt;

  User({
    required this.id,
    required this.email,
    required this.username,
    required this.fullName,
    this.phone,
    required this.role,
    required this.language,
    this.address,
    required this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'] ?? '',
        email: json['email'] ?? '',
        username: json['username'] ?? '',
        fullName: json['full_name'] ?? '',
        phone: json['phone'],
        role: json['role'] ?? 'user',
        language: json['language'] ?? 'tr',
        address: json['address'] != null ? Address.fromJson(json['address']) : null,
        createdAt: json['created_at'] ?? '',
      );
}

class TokenResponse {
  final String accessToken;
  final String refreshToken;

  TokenResponse({required this.accessToken, required this.refreshToken});

  factory TokenResponse.fromJson(Map<String, dynamic> json) => TokenResponse(
        accessToken: json['access_token'] ?? '',
        refreshToken: json['refresh_token'] ?? '',
      );
}

class Product {
  final String id;
  final LocalizedText name;
  final LocalizedText description;
  final double price;
  final String currency;
  final int stock;
  final List<String> images;
  final String category;
  final List<String> tags;
  final bool isActive;
  final String createdAt;

  Product({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.currency,
    required this.stock,
    required this.images,
    required this.category,
    required this.tags,
    required this.isActive,
    required this.createdAt,
  });

  factory Product.fromJson(Map<String, dynamic> json) => Product(
        id: json['id'] ?? '',
        name: LocalizedText.fromJson(json['name']),
        description: LocalizedText.fromJson(json['description']),
        price: (json['price'] as num).toDouble(),
        currency: json['currency'] ?? 'TRY',
        stock: json['stock'] ?? 0,
        images: List<String>.from(json['images'] ?? []).map(fixImageUrl).toList(),
        category: json['category'] ?? '',
        tags: List<String>.from(json['tags'] ?? []),
        isActive: json['is_active'] ?? true,
        createdAt: json['created_at'] ?? '',
      );
}

class CartItem {
  final String productId;
  final LocalizedText name;
  final double price;
  final int quantity;
  final double subtotal;
  final String? image;

  CartItem({
    required this.productId,
    required this.name,
    required this.price,
    required this.quantity,
    required this.subtotal,
    this.image,
  });

  factory CartItem.fromJson(Map<String, dynamic> json) => CartItem(
        productId: json['product_id'] ?? '',
        name: LocalizedText.fromJson(json['name']),
        price: (json['price'] as num).toDouble(),
        quantity: json['quantity'] ?? 0,
        subtotal: (json['subtotal'] as num).toDouble(),
        image: json['image'] != null ? fixImageUrl(json['image']) : null,
      );
}

class Cart {
  final List<CartItem> items;
  final double total;

  Cart({required this.items, required this.total});

  factory Cart.fromJson(Map<String, dynamic> json) => Cart(
        items: (json['items'] as List).map((i) => CartItem.fromJson(i)).toList(),
        total: (json['total'] as num).toDouble(),
      );
}

class OrderItem {
  final String productId;
  final LocalizedText name;
  final double price;
  final int quantity;
  final double subtotal;

  OrderItem({
    required this.productId,
    required this.name,
    required this.price,
    required this.quantity,
    required this.subtotal,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) => OrderItem(
        productId: json['product_id'] ?? '',
        name: LocalizedText.fromJson(json['name']),
        price: (json['price'] as num).toDouble(),
        quantity: json['quantity'] ?? 0,
        subtotal: (json['subtotal'] as num).toDouble(),
      );
}

class Order {
  final String id;
  final List<OrderItem> items;
  final double total;
  final String status;
  final Address shippingAddress;
  final String createdAt;

  Order({
    required this.id,
    required this.items,
    required this.total,
    required this.status,
    required this.shippingAddress,
    required this.createdAt,
  });

  factory Order.fromJson(Map<String, dynamic> json) => Order(
        id: json['id'] ?? '',
        items: (json['items'] as List).map((i) => OrderItem.fromJson(i)).toList(),
        total: (json['total'] as num).toDouble(),
        status: json['status'] ?? '',
        shippingAddress: Address.fromJson(json['shipping_address']),
        createdAt: json['created_at'] ?? '',
      );
}

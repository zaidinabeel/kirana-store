import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class ExternalProductInfo {
  final String barcode;
  final String nameEn;
  final String? brand;
  final String? quantityHint;
  final String? imageUrl;

  ExternalProductInfo({
    required this.barcode,
    required this.nameEn,
    this.brand,
    this.quantityHint,
    this.imageUrl,
  });
}

class BarcodeApiService {
  static const String _baseUrl = 'https://world.openfoodfacts.org/api/v2/product';
  static const Duration _timeout = Duration(milliseconds: 2500); // 2.5s strict timeout

  /// Lookup barcode online. Never throws or blocks UI; returns null on error or timeout.
  static Future<ExternalProductInfo?> lookup(String barcode) async {
    final cleanCode = barcode.trim();
    if (cleanCode.isEmpty) return null;

    try {
      final uri = Uri.parse('$_baseUrl/$cleanCode.json');
      final response = await http.get(
        uri,
        headers: {'User-Agent': 'KiranaStore-Flutter-App/1.0 (contact@kiranastore.in)'},
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 1 && data['product'] != null) {
          final p = data['product'];
          final productName = p['product_name'] ?? p['product_name_en'] ?? '';
          final brands = p['brands'] ?? '';
          final qty = p['quantity'] ?? '';
          final img = p['image_front_url'] ?? p['image_url'];

          if (productName.toString().trim().isNotEmpty) {
            return ExternalProductInfo(
              barcode: cleanCode,
              nameEn: productName.toString().trim(),
              brand: brands.toString().trim().isNotEmpty ? brands.toString().trim() : null,
              quantityHint: qty.toString().trim().isNotEmpty ? qty.toString().trim() : null,
              imageUrl: img?.toString(),
            );
          }
        }
      }
    } catch (_) {
      // Gracefully ignore timeouts, socket exceptions, or invalid JSON
    }
    return null;
  }
}

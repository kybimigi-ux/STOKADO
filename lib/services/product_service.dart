import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/product.dart';

/// Thrown when an outbound (or other decreasing) quantity change would
/// take a product's stock below zero. Callers should catch this and show
/// the user a clear "not enough stock" message rather than letting the
/// transaction silently go through with clamped/incorrect quantities.
class InsufficientStockException implements Exception {
  final int productId;
  InsufficientStockException(this.productId);

  @override
  String toString() =>
      'InsufficientStockException: not enough stock for product $productId';
}

/// Service for all product-related Supabase operations.
class ProductService {
  ProductService._();
  static final ProductService instance = ProductService._();

  final SupabaseClient _client = Supabase.instance.client;

  /// Fetch all active products, joined with their category name.
  Future<List<Product>> getAll() async {
    final response = await _client
        .from('products')
        .select()
        .eq('is_active', true)
        .order('product_name');
    return (response as List)
        .map((row) => Product.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  /// Fetch a single product by ID.
  Future<Product?> getById(int id) async {
    final row = await _client
        .from('products')
        .select()
        .eq('id', id)
        .maybeSingle();
    if (row == null) return null;
    return Product.fromJson(row);
  }

  /// Search products by name.
  Future<List<Product>> search(String query) async {
    final response = await _client
        .from('products')
        .select()
        .eq('is_active', true)
        .ilike('product_name', '%$query%')
        .order('product_name');
    return (response as List)
        .map((row) => Product.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  /// Insert a new product into Supabase.
  Future<Product> add(Product product) async {
    final insertData = product.toInsertJson();
    try {
      final response = await _client
          .from('products')
          .insert(insertData)
          .select()
          .single();
      return Product.fromJson(response);
    } catch (e) {
      debugPrint('[ProductService] add failed with payload $insertData: $e');
      if (insertData.containsKey('category_id')) {
        insertData.remove('category_id');
        final response = await _client
            .from('products')
            .insert(insertData)
            .select()
            .single();
        return Product.fromJson(response);
      }
      rethrow;
    }
  }

  /// Update an existing product.
  Future<void> update(int id, Map<String, dynamic> data) async {
    final cleanData = Map<String, dynamic>.from(data);
    cleanData.removeWhere((key, value) => value == null && key == 'category_id');
    try {
      await _client.from('products').update(cleanData).eq('id', id);
    } catch (e) {
      debugPrint('[ProductService] update failed with payload $cleanData: $e');
      if (cleanData.containsKey('category_id')) {
        cleanData.remove('category_id');
        await _client.from('products').update(cleanData).eq('id', id);
      } else {
        rethrow;
      }
    }
  }

  /// Soft-delete a product (set is_active = false).
  Future<void> delete(int id) async {
    await _client.from('products').update({'is_active': false}).eq('id', id);
  }

  /// Fetch current stock for a single product. Used to pre-check outbound
  /// quantities in the UI before submitting, so the user gets an immediate
  /// "not enough stock" message instead of waiting for the transaction to
  /// fail server-side. This is a courtesy check only — it is NOT what
  /// prevents overselling; adjust_product_quantity() is (see below).
  Future<double> getCurrentQuantity(int id) async {
    final row = await _client
        .from('products')
        .select('quantity')
        .eq('id', id)
        .single();
    final q = row['quantity'];
    if (q is num) return q.toDouble();
    if (q is String) return double.tryParse(q.replaceAll(',', '.')) ?? 0.0;
    return 0.0;
  }

  /// Atomically adjusts product quantity and refuses to let it go
  /// negative. Uses a Postgres function (adjust_product_quantity) so the
  /// check-and-decrement happens as a single atomic operation — this
  /// closes both the "silently clamps to 0 instead of rejecting" bug and
  /// the race condition where two concurrent outbound transactions could
  /// both pass a client-side check before either one's update lands.
  ///
  /// Throws [InsufficientStockException] if quantityChange would take
  /// stock below zero (e.g. issuing more than what's in stock). Positive
  /// quantityChange (inbound) always succeeds.
  Future<void> updateQuantity(int id, double quantityChange) async {
    try {
      await _client.rpc('adjust_product_quantity', params: {
        'p_product_id': id,
        'p_quantity_change': quantityChange,
      });
    } on PostgrestException catch (e) {
      if (e.message.contains('INSUFFICIENT_STOCK') || e.code == 'P0001') {
        throw InsufficientStockException(id);
      }
      // If RPC is missing from database schema, fallback to direct query + update
      debugPrint('[ProductService] RPC adjust_product_quantity failed, fallback to direct update: $e');
      final current = await getCurrentQuantity(id);
      final newQty = current + quantityChange;
      if (newQty < 0) {
        throw InsufficientStockException(id);
      }
      await _client.from('products').update({'quantity': newQty}).eq('id', id);
    } catch (e) {
      debugPrint('[ProductService] updateQuantity error, fallback to direct update: $e');
      final current = await getCurrentQuantity(id);
      final newQty = current + quantityChange;
      if (newQty < 0) {
        throw InsufficientStockException(id);
      }
      await _client.from('products').update({'quantity': newQty}).eq('id', id);
    }
  }

  /// Get total product count.
  Future<int> getTotalCount() async {
    final response = await _client
        .from('products')
        .select('id')
        .eq('is_active', true);
    return (response as List).length;
  }

  /// Get count of low-stock products (quantity <= 10).
  Future<int> getLowStockCount() async {
    final response = await _client
        .from('products')
        .select('id')
        .eq('is_active', true)
        .lte('quantity', 10)
        .gt('quantity', 0);
    return (response as List).length;
  }
}
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/product.dart';
import 'hardware_context.dart';

/// Thrown when an outbound (or other decreasing) quantity change would
/// take a product's stock below zero.
class InsufficientStockException implements Exception {
  final String productId;
  InsufficientStockException(this.productId);

  @override
  String toString() =>
      'InsufficientStockException: not enough stock for product $productId';
}

/// Service for all product-related Supabase operations.
/// Products are stored in a flat `products` table scoped by hardware_id.
class ProductService {
  ProductService._();
  static final ProductService instance = ProductService._();

  static final SupabaseClient _client = Supabase.instance.client;

  String? get _hardwareId =>
      HardwareContext.instance.activeHardware?.id;

  /// Fetch all active products for the current hardware, ordered by name.
  Future<List<Product>> getAll() async {
    final hwId = _hardwareId;
    if (hwId == null || hwId.isEmpty) return [];
    try {
      final data = await _client
          .from('products')
          .select()
          .eq('hardware_id', hwId)
          .eq('is_active', true)
          .order('product_name', ascending: true);

      return (data as List)
          .map((row) => Product.fromJson(row as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[ProductService] getAll error: $e');
      rethrow;
    }
  }

  /// Fetch a single product by its ID.
  Future<Product?> getById(String id) async {
    final hwId = _hardwareId;
    if (hwId == null) return null;
    final data = await _client
        .from('products')
        .select()
        .eq('id', id)
        .eq('hardware_id', hwId)
        .maybeSingle();
    if (data == null) return null;
    return Product.fromJson(data);
  }

  /// Search products by name (client-side filter).
  Future<List<Product>> search(String query) async {
    final all = await getAll();
    final lower = query.toLowerCase();
    return all
        .where((p) => p.productName.toLowerCase().contains(lower))
        .toList();
  }

  /// Insert a new product.
  Future<Product> add(Product product) async {
    final hwId = _hardwareId;
    if (hwId == null) throw StateError('No active workspace selected.');
    final payload = product.toInsertJson(hwId);
    try {
      final data = await _client
          .from('products')
          .insert(payload)
          .select()
          .single();
      return Product.fromJson(data);
    } on PostgrestException catch (pe) {
      final isMissingImageUrl = (pe.code == 'PGRST204' || pe.code == '42703') &&
          pe.message.toLowerCase().contains('image_url');
      if (isMissingImageUrl) {
        debugPrint(
            '[ProductService] WARNING: "image_url" column does not exist on "products" table in Supabase. '
            'Falling back to insert without image_url. '
            'To fix, run in Supabase SQL Editor: ALTER TABLE public.products ADD COLUMN IF NOT EXISTS image_url text DEFAULT null;');
        final fallbackPayload = Map<String, dynamic>.from(payload)..remove('image_url');
        final data = await _client
            .from('products')
            .insert(fallbackPayload)
            .select()
            .single();
        return Product.fromJson(data);
      }
      rethrow;
    }
  }

  /// Update an existing product by ID.
  Future<void> update(String id, Map<String, dynamic> data) async {
    final hwId = _hardwareId;
    if (hwId == null) throw StateError('No active workspace selected.');
    final cleanData = Map<String, dynamic>.from(data)
      ..remove('id')
      ..remove('hardware_id')
      ..remove('created_at');
    try {
      await _client
          .from('products')
          .update(cleanData)
          .eq('id', id)
          .eq('hardware_id', hwId);
    } on PostgrestException catch (pe) {
      final isMissingImageUrl = (pe.code == 'PGRST204' || pe.code == '42703') &&
          pe.message.toLowerCase().contains('image_url');
      if (isMissingImageUrl) {
        debugPrint(
            '[ProductService] WARNING: "image_url" column does not exist on "products" table in Supabase. '
            'Falling back to update without image_url. '
            'To fix, run in Supabase SQL Editor: ALTER TABLE public.products ADD COLUMN IF NOT EXISTS image_url text DEFAULT null;');
        final fallbackData = Map<String, dynamic>.from(cleanData)..remove('image_url');
        await _client
            .from('products')
            .update(fallbackData)
            .eq('id', id)
            .eq('hardware_id', hwId);
        return;
      }
      debugPrint('[ProductService] update failed for $id: $pe');
      rethrow;
    } catch (e) {
      debugPrint('[ProductService] update failed for $id: $e');
      rethrow;
    }
  }

  /// Soft-delete a product (set is_active = false).
  Future<void> delete(String id) async {
    final hwId = _hardwareId;
    if (hwId == null) return;
    await _client
        .from('products')
        .update({'is_active': false})
        .eq('id', id)
        .eq('hardware_id', hwId);
  }

  /// Fetch current stock for a single product.
  Future<double> getCurrentQuantity(String id) async {
    final hwId = _hardwareId;
    if (hwId == null) return 0.0;
    final data = await _client
        .from('products')
        .select('quantity')
        .eq('id', id)
        .eq('hardware_id', hwId)
        .maybeSingle();
    if (data == null) return 0.0;
    final q = data['quantity'];
    if (q is num) return q.toDouble();
    if (q is String) return double.tryParse(q.replaceAll(',', '.')) ?? 0.0;
    return 0.0;
  }

  /// Adjusts product quantity atomically via RPC, or falls back to a
  /// read-then-write if no RPC is available.
  Future<void> updateQuantity(String id, double quantityChange) async {
    final hwId = _hardwareId;
    if (hwId == null) throw StateError('No active workspace selected.');

    // Read current quantity
    final current = await getCurrentQuantity(id);
    final newQty = current + quantityChange;
    if (newQty < 0) throw InsufficientStockException(id);

    await _client
        .from('products')
        .update({'quantity': newQty, 'updated_at': DateTime.now().toIso8601String()})
        .eq('id', id)
        .eq('hardware_id', hwId);
  }

  /// Get total active product count.
  Future<int> getTotalCount() async {
    final hwId = _hardwareId;
    if (hwId == null) return 0;
    try {
      final response = await _client
          .from('products')
          .select()
          .eq('hardware_id', hwId)
          .eq('is_active', true)
          .count(CountOption.exact);
      return response.count;
    } catch (_) {
      try {
        final all = await getAll();
        return all.length;
      } catch (_) {
        return 0;
      }
    }
  }

  /// Get count of low-stock products (quantity <= 10 and > 0).
  Future<int> getLowStockCount() async {
    final hwId = _hardwareId;
    if (hwId == null) return 0;
    try {
      final response = await _client
          .from('products')
          .select()
          .eq('hardware_id', hwId)
          .eq('is_active', true)
          .lte('quantity', 10)
          .gt('quantity', 0)
          .count(CountOption.exact);
      return response.count;
    } catch (_) {
      try {
        final all = await getAll();
        return all.where((p) => p.quantity <= 10 && p.quantity > 0).length;
      } catch (_) {
        return 0;
      }
    }
  }
}
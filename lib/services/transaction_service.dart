import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/transaction.dart';
import '../models/transaction_item.dart';
import 'hardware_context.dart';
import 'product_service.dart';
import 'package:uuid/uuid.dart';
import '../models/pending_transaction.dart';
import 'offline_queue_service.dart';

List<String>? _billNoCache;

bool _looksLikeConnectivityError(Object e) {
  final s = e.toString().toLowerCase();
  return s.contains('socketexception') ||
      s.contains('clientexception') ||
      s.contains('failed host lookup') ||
      s.contains('connection refused') ||
      s.contains('connection closed') ||
      s.contains('network is unreachable') ||
      s.contains('timeoutexception') ||
      s.contains('no internet') ||
      s.contains('unavailable');
}

/// Fetch distinct bill numbers for autocomplete. Cached in-memory after first fetch.
Future<List<String>> getAllBillNumbers() async {
  if (_billNoCache != null) return _billNoCache!;
  try {
    final hwId = HardwareContext.instance.activeHardware?.id;
    if (hwId == null || hwId.isEmpty) return [];
    final data = await Supabase.instance.client
        .from('transactions')
        .select('bill_no')
        .eq('hardware_id', hwId);
    final seen = <String>{};
    for (final row in (data as List)) {
      final billNo = row['bill_no']?.toString().trim();
      if (billNo != null && billNo.isNotEmpty) seen.add(billNo);
    }
    _billNoCache = seen.toList()..sort();
    return _billNoCache!;
  } catch (e) {
    debugPrint('[TransactionService] Failed to load bill numbers: $e');
    return _billNoCache ?? [];
  }
}

/// Call after creating a transaction so the next autocomplete is refreshed.
void refreshBillNoCache() => _billNoCache = null;

/// Thrown when an outbound transaction requests more of one or more
/// products than are currently in stock.
class InsufficientStockError implements Exception {
  final List<StockShortfall> shortfalls;
  InsufficientStockError(this.shortfalls);

  @override
  String toString() => 'InsufficientStockError: '
      '${shortfalls.map((s) => '${s.productId} (requested ${s.requested}, have ${s.available})').join(', ')}';
}

class StockShortfall {
  final String productId;
  final String? productName;
  final double requested;
  final double available;
  StockShortfall({
    required this.productId,
    required this.available,
    required this.requested,
    this.productName,
  });
}

/// Service for all transaction-related Supabase operations.
class TransactionService {
  TransactionService._();
  static final TransactionService instance = TransactionService._();

  static final SupabaseClient _client = Supabase.instance.client;

  String? get _hardwareId => HardwareContext.instance.activeHardware?.id;

  /// Map of userId -> fullName cache to avoid repeated reads.
  final Map<String, String> _userNameCache = {};

  /// Map of productId -> productName cache.
  final Map<String, String> _productNameCache = {};

  bool _userNamesPreloaded = false;

  /// Preload all user names from the users table in one read.
  Future<void> _preloadUserNames() async {
    if (_userNamesPreloaded) return;
    try {
      final data = await _client.from('users').select('id, full_name, role, email');
      for (final row in (data as List)) {
        final id = row['id'] as String?;
        if (id == null) continue;
        String? name = (row['full_name'] as String?)?.trim();
        if (name == null || name.isEmpty || name.toLowerCase() == 'user') {
          final role = (row['role'] as String?)?.trim();
          final email = (row['email'] as String?)?.trim();
          if (role != null && role.isNotEmpty) {
            name = role[0].toUpperCase() + role.substring(1);
          } else if (email != null && email.isNotEmpty) {
            name = email.split('@').first;
          }
        }
        if (name != null && name.isNotEmpty) {
          _userNameCache[id] = name;
        }
      }
      _userNamesPreloaded = true;
    } catch (e) {
      debugPrint('[TransactionService] Could not preload user names: $e');
    }
  }

  Future<String?> _getUserName(String? userId) async {
    if (userId == null || userId.isEmpty) {
      final current = _client.auth.currentUser;
      final metaName =
          (current?.userMetadata?['full_name'] as String?)?.trim();
      if (metaName != null &&
          metaName.isNotEmpty &&
          metaName.toLowerCase() != 'user') {
        return metaName;
      }
      final emailPart = current?.email?.split('@').first;
      if (emailPart != null && emailPart.isNotEmpty) return emailPart;
      return 'Admin';
    }

    if (_userNameCache.containsKey(userId)) return _userNameCache[userId];

    try {
      final data = await _client
          .from('users')
          .select('full_name, role, email')
          .eq('id', userId)
          .maybeSingle();
      if (data != null) {
        String? name = (data['full_name'] as String?)?.trim();
        if (name == null || name.isEmpty || name.toLowerCase() == 'user') {
          final role = (data['role'] as String?)?.trim();
          final email = (data['email'] as String?)?.trim();
          if (role != null && role.isNotEmpty) {
            name = role[0].toUpperCase() + role.substring(1);
          } else if (email != null && email.isNotEmpty) {
            name = email.split('@').first;
          }
        }
        if (name != null && name.isNotEmpty) {
          _userNameCache[userId] = name;
          return name;
        }
      }
    } catch (e) {
      debugPrint('[TransactionService] Could not resolve user name: $e');
    }

    final current = _client.auth.currentUser;
    if (current != null && current.id == userId) {
      final name =
          (current.userMetadata?['full_name'] as String?)?.trim();
      if (name != null && name.isNotEmpty && name.toLowerCase() != 'user') {
        _userNameCache[userId] = name;
        return name;
      }
      final emailPart = current.email?.split('@').first;
      if (emailPart != null && emailPart.isNotEmpty) {
        _userNameCache[userId] = emailPart;
        return emailPart;
      }
    }
    return 'Admin';
  }

  /// Preload all active product names into cache.
  Future<void> _preloadProductNames() async {
    try {
      final snap = await ProductService.instance.getAll();
      for (final p in snap) {
        if (p.id != null && p.productName.trim().isNotEmpty) {
          _productNameCache[p.id!] = p.productName.trim();
        }
      }
    } catch (e) {
      debugPrint('[TransactionService] Could not preload product names: $e');
    }
  }

  /// Build Transaction list from raw Supabase rows.
  Future<List<Transaction>> _buildTransactionList(List rows) async {
    await _preloadUserNames();
    await _preloadProductNames();

    final transactions = <Transaction>[];

    for (final row in rows) {
      final data = Map<String, dynamic>.from(row as Map);
      final txnId = data['id'] as String;

      // Load transaction items
      try {
        final itemsData = await _client
            .from('transaction_items')
            .select()
            .eq('transaction_id', txnId);

        final itemsList = (itemsData as List).map((itemRow) {
          final itemData = Map<String, dynamic>.from(itemRow as Map);
          final pid = itemData['product_id']?.toString();
          if ((itemData['product_name'] == null ||
                  itemData['product_name'].toString().trim().isEmpty) &&
              pid != null &&
              _productNameCache.containsKey(pid)) {
            itemData['product_name'] = _productNameCache[pid];
          }
          return itemData;
        }).toList();

        data['transaction_items'] = itemsList;
      } catch (e) {
        debugPrint(
            '[TransactionService] Could not load items for $txnId: $e');
      }

      final createdBy = data['created_by'] as String?;
      final userName = await _getUserName(createdBy);
      if (userName != null) {
        data['users'] = {'full_name': userName};
      }
      transactions.add(Transaction.fromJson(data));
    }

    return transactions;
  }

  /// Fetch all transactions, ordered by most recent.
  Future<List<Transaction>> getAll() async {
    final hwId = _hardwareId;
    if (hwId == null) return [];
    try {
      final data = await _client
          .from('transactions')
          .select()
          .eq('hardware_id', hwId)
          .order('created_at', ascending: false);
      return await _buildTransactionList(data as List);
    } catch (e) {
      debugPrint('[TransactionService] getAll error: $e');
      rethrow;
    }
  }

  /// Fetch all transactions associated with a specific product ID.
  Future<List<Transaction>> getByProductId(String productId) async {
    final hwId = _hardwareId;
    if (hwId == null) return [];

    // Find transaction IDs that have this product in their items
    final itemRows = await _client
        .from('transaction_items')
        .select('transaction_id')
        .eq('hardware_id', hwId)
        .eq('product_id', productId);

    if ((itemRows as List).isEmpty) return [];

    final txnIds = itemRows
        .map((r) => r['transaction_id'] as String)
        .toSet()
        .toList();

    final txnRows = await _client
        .from('transactions')
        .select()
        .eq('hardware_id', hwId)
        .inFilter('id', txnIds)
        .order('created_at', ascending: true);

    return _buildTransactionList(txnRows as List);
  }

  /// Fetch a single transaction with its items.
  Future<Transaction> getById(String id) async {
    final hwId = _hardwareId;
    if (hwId == null) throw StateError('No active workspace selected.');

    final data = await _client
        .from('transactions')
        .select()
        .eq('id', id)
        .eq('hardware_id', hwId)
        .maybeSingle();

    if (data == null) throw Exception('Transaction $id not found');

    await _preloadProductNames();

    final txnData = Map<String, dynamic>.from(data as Map);

    try {
      final itemsData = await _client
          .from('transaction_items')
          .select()
          .eq('transaction_id', id);

      final itemsList = (itemsData as List).map((itemRow) {
        final itemData = Map<String, dynamic>.from(itemRow as Map);
        final pid = itemData['product_id']?.toString();
        if ((itemData['product_name'] == null ||
                itemData['product_name'].toString().trim().isEmpty) &&
            pid != null &&
            _productNameCache.containsKey(pid)) {
          itemData['product_name'] = _productNameCache[pid];
        }
        return itemData;
      }).toList();

      txnData['transaction_items'] = itemsList;
    } catch (e) {
      debugPrint('[TransactionService] Failed to load items for $id: $e');
    }

    final createdBy = txnData['created_by'] as String?;
    final userName = await _getUserName(createdBy);
    if (userName != null) {
      txnData['users'] = {'full_name': userName};
    }

    return Transaction.fromJson(txnData);
  }

  /// Fetch the most recent transactions (for the dashboard).
  Future<List<Transaction>> getRecent({int limit = 5}) async {
    final hwId = _hardwareId;
    if (hwId == null) return [];
    final data = await _client
        .from('transactions')
        .select()
        .eq('hardware_id', hwId)
        .order('created_at', ascending: false)
        .limit(limit);
    return _buildTransactionList(data as List);
  }

  /// Pre-check outbound stock before creating any records.
  Future<List<StockShortfall>> _checkStockAvailability(
      List<TransactionItem> items) async {
    final shortfalls = <StockShortfall>[];
    final productService = ProductService.instance;

    for (final item in items) {
      if (item.productId == null) continue;
      try {
        final available =
            await productService.getCurrentQuantity(item.productId!);
        if (item.quantity > available) {
          shortfalls.add(StockShortfall(
            productId: item.productId!,
            productName: _productNameCache[item.productId!],
            requested: item.quantity,
            available: available,
          ));
        }
      } catch (e) {
        debugPrint(
            '[TransactionService] Stock pre-check failed for ${item.productId}: $e');
      }
    }
    return shortfalls;
  }

  /// Create a new transaction. If offline, queues locally and returns a
  /// pending-sync Transaction so the UI can show it immediately.
  Future<Transaction> create({
    required String billNo,
    required String type,
    String status = 'Completed',
    required List<TransactionItem> items,
    String? remarks,
    String? issuedTo,
    String? userId,
    DateTime? createdAt,
  }) async {
    // Pre-flight stock check for outbound transactions.
    if (type.toLowerCase() == 'release') {
      final shortfalls = await _checkStockAvailability(items);
      if (shortfalls.isNotEmpty) throw InsufficientStockError(shortfalls);
    }

    try {
      return await _createRemote(
        billNo: billNo,
        type: type,
        status: status,
        items: items,
        remarks: remarks,
        issuedTo: issuedTo,
        userId: userId,
        createdAt: createdAt,
      );
    } catch (e) {
      if (e is InsufficientStockError) rethrow;
      if (!_looksLikeConnectivityError(e)) rethrow;

      debugPrint(
          '[TransactionService] create() failed due to connectivity, queuing offline: $e');

      final localId = const Uuid().v4();
      final effectiveDate = createdAt ?? DateTime.now();
      final pending = PendingTransaction(
        localId: localId,
        billNo: billNo,
        type: type,
        status: status,
        items: items,
        remarks: remarks,
        issuedTo: issuedTo,
        userId: userId,
        queuedAt: DateTime.now(),
        createdAt: effectiveDate,
      );
      await OfflineQueueService.instance.enqueue(pending);

      return Transaction(
        id: null,
        billNo: billNo,
        type: type,
        totalItems: items.fold<double>(0.0, (acc, item) => acc + item.quantity),
        totalPrice: items.fold<double>(0.0, (acc, item) => acc + item.quantity * item.price),
        remarks: (remarks != null && remarks.trim().isNotEmpty)
            ? remarks.trim()
            : 'N/A',
        createdBy: userId,
        createdByName: null,
        createdAt: effectiveDate,
        items: items,
        localId: localId,
        isPendingSync: true,
      );
    }
  }

  /// Write the transaction and its items to Supabase, then update stock.
  Future<Transaction> _createRemote({
    required String billNo,
    required String type,
    String status = 'Completed',
    required List<TransactionItem> items,
    String? remarks,
    String? issuedTo,
    String? userId,
    DateTime? createdAt,
  }) async {
    final hwId = _hardwareId;
    if (hwId == null) throw StateError('No active workspace selected.');

    final totalItems =
        items.fold<double>(0.0, (acc, item) => acc + item.quantity);
    final totalPrice =
        items.fold<double>(0.0, (acc, item) => acc + item.quantity * item.price);
    final finalIssuedTo =
        (issuedTo != null && issuedTo.trim().isNotEmpty) ? issuedTo.trim() : 'N/A';
    final finalRemarks =
        (remarks != null && remarks.trim().isNotEmpty) ? remarks.trim() : 'N/A';

    final typeTitle = type.isNotEmpty
        ? (type[0].toUpperCase() + type.substring(1).toLowerCase())
        : type;
    final statusCapital = status.isNotEmpty
        ? (status[0].toUpperCase() + status.substring(1).toLowerCase())
        : status;

    // 1. Insert the transaction row
    final txnPayload = <String, dynamic>{
      'hardware_id': hwId,
      'bill_no': billNo,
      'type': typeTitle,
      'total_items': totalItems,
      'total_price': totalPrice,
      'status': statusCapital,
      'issued_to': finalIssuedTo,
      'remarks': finalRemarks,
      if (createdAt != null) 'created_at': createdAt.toIso8601String(),
      if (userId != null && userId.isNotEmpty) 'created_by': userId,
    };

    final txnData = await _client
        .from('transactions')
        .insert(txnPayload)
        .select()
        .single();

    final txnId = txnData['id'] as String;

    // 2. Insert items
    if (items.isNotEmpty) {
      final itemsPayload = items.map((item) => {
            'transaction_id': txnId,
            'hardware_id': hwId,
            'product_id': item.productId,
            'product_name': item.productName,
            'quantity': item.quantity,
            'unit': item.unit,
            'price': item.price,
          }).toList();
      await _client.from('transaction_items').insert(itemsPayload);
    }

    // 3. Update product stock
    final productService = ProductService.instance;
    for (final item in items) {
      if (item.productId != null) {
        final quantityChange = (type.toLowerCase() == 'receive' ||
                type.toLowerCase() == 'inbound' ||
                type.toLowerCase() == 'purchase')
            ? item.quantity
            : -item.quantity;
        await productService.updateQuantity(item.productId!, quantityChange);
      }
    }

    refreshBillNoCache();

    String? createdByName;
    if (userId != null && userId.isNotEmpty) {
      createdByName = await _getUserName(userId);
    }

    return Transaction(
      id: txnId,
      hardwareId: hwId,
      billNo: billNo,
      type: typeTitle,
      totalItems: totalItems,
      totalPrice: totalPrice,
      remarks: finalRemarks,
      issuedTo: finalIssuedTo,
      createdBy: userId,
      createdByName: createdByName,
      createdAt: createdAt ?? DateTime.now(),
      items: items,
    );
  }

  /// Update an existing transaction's core fields, replace its items,
  /// and automatically adjust product stock to match.
  Future<Transaction> update({
    required String transactionId,
    required String billNo,
    required String type,
    required List<TransactionItem> items,
    String? remarks,
    String? issuedTo,
    DateTime? createdAt,
  }) async {
    final hwId = _hardwareId;
    if (hwId == null) throw StateError('No active workspace selected.');

    // 1. Fetch original transaction to calculate stock delta.
    Transaction? oldTxn;
    try {
      oldTxn = await getById(transactionId);
    } catch (e) {
      debugPrint(
          '[TransactionService] Could not fetch original txn for stock adjustment: $e');
    }

    final productService = ProductService.instance;

    // 2. Revert the original stock impact.
    if (oldTxn != null) {
      final oldIsReceive = oldTxn.type.toLowerCase() == 'receive' ||
          oldTxn.type.toLowerCase() == 'inbound' ||
          oldTxn.type.toLowerCase() == 'purchase';
      for (final oldItem in oldTxn.items) {
        if (oldItem.productId != null) {
          final revertDelta =
              oldIsReceive ? -oldItem.quantity : oldItem.quantity;
          await productService.updateQuantity(oldItem.productId!, revertDelta);
        }
      }
    }

    // 3. Apply updated stock impact.
    final newIsReceive = type.toLowerCase() == 'receive' ||
        type.toLowerCase() == 'inbound' ||
        type.toLowerCase() == 'purchase';
    for (final newItem in items) {
      if (newItem.productId != null) {
        final applyDelta = newIsReceive ? newItem.quantity : -newItem.quantity;
        await productService.updateQuantity(newItem.productId!, applyDelta);
      }
    }

    final totalItems =
        items.fold<double>(0.0, (acc, item) => acc + item.quantity);
    final totalPrice =
        items.fold<double>(0.0, (acc, item) => acc + item.quantity * item.price);
    final finalIssuedTo =
        (issuedTo != null && issuedTo.trim().isNotEmpty) ? issuedTo.trim() : 'N/A';
    final finalRemarks =
        (remarks != null && remarks.trim().isNotEmpty) ? remarks.trim() : 'N/A';

    final typeTitle = type.isNotEmpty
        ? (type[0].toUpperCase() + type.substring(1).toLowerCase())
        : type;

    final updatePayload = <String, dynamic>{
      'bill_no': billNo,
      'type': typeTitle,
      'total_items': totalItems,
      'total_price': totalPrice,
      'issued_to': finalIssuedTo,
      'remarks': finalRemarks,
      if (createdAt != null) 'created_at': createdAt.toIso8601String(),
    };
    await _client
        .from('transactions')
        .update(updatePayload)
        .eq('id', transactionId)
        .eq('hardware_id', hwId);

    // Replace items: delete existing, insert new ones.
    try {
      await _client
          .from('transaction_items')
          .delete()
          .eq('transaction_id', transactionId);

      if (items.isNotEmpty) {
        final itemsPayload = items.map((item) => {
              'transaction_id': transactionId,
              'hardware_id': hwId,
              'product_id': item.productId,
              'product_name': item.productName,
              'quantity': item.quantity,
              'unit': item.unit,
              'price': item.price,
            }).toList();
        await _client.from('transaction_items').insert(itemsPayload);
      }
    } catch (e) {
      debugPrint(
          '[TransactionService] Failed to replace transaction items: $e');
      rethrow;
    }

    return getById(transactionId);
  }

  /// Delete a transaction and its items, reversing product stock.
  Future<void> deleteTransaction(String transactionId) async {
    final hwId = _hardwareId;
    if (hwId == null) return;

    // 1. Fetch original transaction to revert stock.
    Transaction? txn;
    try {
      txn = await getById(transactionId);
    } catch (e) {
      debugPrint(
          '[TransactionService] Could not fetch transaction to reverse stock: $e');
    }

    if (txn != null) {
      final productService = ProductService.instance;
      final isReceive = txn.type.toLowerCase() == 'receive' ||
          txn.type.toLowerCase() == 'inbound' ||
          txn.type.toLowerCase() == 'purchase';
      for (final item in txn.items) {
        if (item.productId != null) {
          final revertDelta = isReceive ? -item.quantity : item.quantity;
          try {
            await productService.updateQuantity(item.productId!, revertDelta);
          } catch (e) {
            debugPrint(
                '[TransactionService] Error reverting stock for ${item.productId}: $e');
          }
        }
      }
    }

    // 2. Delete items then the transaction (cascade would also work via FK).
    try {
      await _client
          .from('transaction_items')
          .delete()
          .eq('transaction_id', transactionId);
      await _client
          .from('transactions')
          .delete()
          .eq('id', transactionId)
          .eq('hardware_id', hwId);
    } catch (e) {
      debugPrint(
          '[TransactionService] Failed to delete transaction: $e');
      rethrow;
    }
  }
}

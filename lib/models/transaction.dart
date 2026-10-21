import 'transaction_item.dart';

class Transaction {
  final String? id;
  final String? hardwareId;
  final String billNo;
  final String type; // 'Receive' or 'Release'
  final double totalItems;
  final double totalPrice;
  final String? remarks;
  final String? issuedTo;
  final String? createdBy; // UID of the user
  final String? createdByName; // resolved from users table
  final DateTime? createdAt;
  final List<TransactionItem> items;

  /// Set only for transactions that were queued while offline.
  final String? localId;

  /// True until this transaction is confirmed to have reached the server.
  final bool isPendingSync;

  const Transaction({
    this.id,
    this.hardwareId,
    required this.billNo,
    required this.type,
    this.totalItems = 0.0,
    this.totalPrice = 0.0,
    this.remarks,
    this.issuedTo,
    this.createdBy,
    this.createdByName,
    this.createdAt,
    this.items = const [],
    this.localId,
    this.isPendingSync = false,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) {
    // Resolve user name that was injected by the service layer
    String? userName;
    if (json['users'] != null && json['users'] is Map) {
      userName = json['users']['full_name'] as String?;
    }
    userName ??= json['created_by_name'] as String?;

    // Handle transaction_items if present (injected by service layer)
    List<TransactionItem> txnItems = [];
    if (json['transaction_items'] != null &&
        json['transaction_items'] is List) {
      txnItems = (json['transaction_items'] as List)
          .map((item) =>
              TransactionItem.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    DateTime? parsedDate;
    final rawDate = json['created_at'];
    if (rawDate is String) {
      parsedDate = DateTime.tryParse(rawDate);
    } else if (rawDate is DateTime) {
      parsedDate = rawDate;
    }

    double parseNum(dynamic val) {
      if (val is num) return val.toDouble();
      if (val is String) {
        return double.tryParse(val.replaceAll(',', '.')) ?? 0.0;
      }
      return 0.0;
    }

    return Transaction(
      id: json['id']?.toString(),
      hardwareId: json['hardware_id']?.toString(),
      billNo: json['bill_no']?.toString() ?? '',
      type: json['type']?.toString() ?? 'Receive',
      totalItems: parseNum(json['total_items']),
      totalPrice: parseNum(json['total_price']),
      remarks: json['remarks']?.toString(),
      issuedTo: json['issued_to']?.toString(),
      createdBy: json['created_by']?.toString(),
      createdByName: userName,
      createdAt: parsedDate,
      items: txnItems,
      localId: null,
      isPendingSync: false,
    );
  }

  /// Formatted string representing totalItems without unnecessary trailing zeroes.
  String get formattedTotalItems {
    if (totalItems % 1 == 0) {
      return totalItems.toInt().toString();
    }
    return totalItems.toString().replaceAll(RegExp(r'([.]*0)(?!.*\d)'), '');
  }

  /// Formatted total price.
  String get formattedTotalPrice {
    if (totalPrice == 0) return '—';
    if (totalPrice % 1 == 0) return totalPrice.toInt().toString();
    return totalPrice.toStringAsFixed(2);
  }

  Map<String, dynamic> toInsertJson({String? hardwareId}) {
    return {
      if (hardwareId != null) 'hardware_id': hardwareId,
      'bill_no': billNo,
      'type': type,
      'status': 'Completed',
      'total_items': totalItems,
      'total_price': totalPrice,
      if (remarks != null && remarks!.isNotEmpty) 'remarks': remarks,
      if (createdBy != null) 'created_by': createdBy,
    };
  }
}
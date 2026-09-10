class TransactionItem {
  final int? id;
  final int? transactionId;
  final int? productId;
  final String productName;
  final double quantity;
  final String unit;

  const TransactionItem({
    this.id,
    this.transactionId,
    this.productId,
    required this.productName,
    required this.quantity,
    this.unit = 'pcs', // sensible default
  });

  factory TransactionItem.fromJson(Map<String, dynamic> json) {
    double parseDouble(dynamic val) {
      if (val is num) return val.toDouble();
      if (val is String) {
        return double.tryParse(val.replaceAll(',', '.')) ?? 0.0;
      }
      return 0.0;
    }

    int? parseInt(dynamic val) {
      if (val is int) return val;
      if (val is num) return val.toInt();
      if (val is String) return int.tryParse(val);
      return null;
    }

    return TransactionItem(
      id: json['id'] != null ? parseInt(json['id']) : null,
      transactionId: json['transaction_id'] != null
          ? parseInt(json['transaction_id'])
          : null,
      productId:
          json['product_id'] != null ? parseInt(json['product_id']) : null,
      productName: json['product_name']?.toString() ?? 'Item',
      quantity: parseDouble(json['quantity']),
      unit: json['unit']?.toString() ?? 'pcs',
    );
  }

  /// Formatted string representing quantity without unnecessary trailing zeroes.
  String get formattedQuantity {
    if (quantity % 1 == 0) {
      return quantity.toInt().toString();
    }
    return quantity.toString().replaceAll(RegExp(r'([.]*0)(?!.*\d)'), '');
  }

  Map<String, dynamic> toInsertJson(int txnId) {
    return {
      'transaction_id': txnId,
      'product_id': productId,
      'product_name': productName,
      'quantity': quantity,
      'unit': unit,
    };
  }
}

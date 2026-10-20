class TransactionItem {
  final String? id;
  final String? transactionId;
  final String? hardwareId;
  final String? productId;
  final String productName;
  final double quantity;
  final String unit;
  final double price;       // price per unit at time of transaction
  final double? lineTotal;  // computed: quantity × price (stored/generated in DB)

  const TransactionItem({
    this.id,
    this.transactionId,
    this.hardwareId,
    this.productId,
    required this.productName,
    required this.quantity,
    this.unit = 'pcs',
    this.price = 0.0,
    this.lineTotal,
  });

  factory TransactionItem.fromJson(Map<String, dynamic> json) {
    double parseDouble(dynamic val) {
      if (val is num) return val.toDouble();
      if (val is String) {
        return double.tryParse(val.replaceAll(',', '.')) ?? 0.0;
      }
      return 0.0;
    }

    return TransactionItem(
      id: json['id']?.toString(),
      transactionId: json['transaction_id']?.toString(),
      hardwareId: json['hardware_id']?.toString(),
      productId: json['product_id']?.toString(),
      productName: json['product_name']?.toString() ?? 'Item',
      quantity: parseDouble(json['quantity']),
      unit: json['unit']?.toString() ?? 'pcs',
      price: parseDouble(json['price']),
      lineTotal: json['line_total'] != null
          ? parseDouble(json['line_total'])
          : null,
    );
  }

  /// Formatted string representing quantity without unnecessary trailing zeroes.
  String get formattedQuantity {
    if (quantity % 1 == 0) {
      return quantity.toInt().toString();
    }
    return quantity.toString().replaceAll(RegExp(r'([.]*0)(?!.*\d)'), '');
  }

  /// Formatted price per unit.
  String get formattedPrice {
    if (price == 0) return '—';
    if (price % 1 == 0) return price.toInt().toString();
    return price.toStringAsFixed(2);
  }

  Map<String, dynamic> toInsertJson(String txnId, {String? hardwareId}) {
    return {
      'transaction_id': txnId,
      if (hardwareId != null) 'hardware_id': hardwareId,
      'product_id': productId,
      'product_name': productName,
      'quantity': quantity,
      'unit': unit,
      'price': price,
    };
  }
}

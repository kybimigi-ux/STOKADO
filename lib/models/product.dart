class Product {
  final String? id;
  final String? hardwareId;
  final String productName;
  final String? categoryId;
  final String? categoryName;
  final double quantity;
  final String unit;
  final double price;      // selling / retail price per unit
  final double costPrice;  // purchase / cost price per unit
  final bool isActive;
  final String? remarks;
  final String? imageUrl;  // optional product photo URL (Supabase Storage or external)
  final DateTime? createdAt;

  const Product({
    this.id,
    this.hardwareId,
    required this.productName,
    this.categoryId,
    this.categoryName,
    this.quantity = 0.0,
    this.unit = 'pcs',
    this.price = 0.0,
    this.costPrice = 0.0,
    this.isActive = true,
    this.remarks,
    this.imageUrl,
    this.createdAt,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    double parseQty(dynamic val) {
      if (val is num) return val.toDouble();
      if (val is String) {
        return double.tryParse(val.replaceAll(',', '.')) ?? 0.0;
      }
      return 0.0;
    }

    DateTime? parseDate(dynamic val) {
      if (val == null) return null;
      if (val is String) return DateTime.tryParse(val);
      if (val is DateTime) return val;
      return null;
    }

    final rawName = json['product_name'] ?? json['productName'] ?? json['name'] ?? '';
    final rawIsActive = json['is_active'] ?? json['isActive'];
    final bool active = rawIsActive is bool
        ? rawIsActive
        : (rawIsActive is String
            ? rawIsActive.toLowerCase() != 'false'
            : true);

    return Product(
      id: json['id']?.toString(),
      hardwareId: json['hardware_id']?.toString(),
      productName: rawName.toString(),
      categoryId: (json['category_id'] ?? json['categoryId'])?.toString(),
      categoryName: (json['category_name'] ?? json['categoryName'])?.toString(),
      quantity: parseQty(json['quantity']),
      unit: json['unit']?.toString() ?? 'pcs',
      price: parseQty(json['price']),
      costPrice: parseQty(json['cost_price'] ?? json['costPrice']),
      isActive: active,
      remarks: json['remarks']?.toString(),
      imageUrl: (json['image_url'] ?? json['imageUrl'])?.toString(),
      createdAt: parseDate(json['created_at'] ?? json['createdAt']),
    );
  }

  /// Formatted string representing quantity without unnecessary trailing zeroes.
  String get formattedQuantity {
    if (quantity % 1 == 0) {
      return quantity.toInt().toString();
    }
    return quantity.toString().replaceAll(RegExp(r'([.]*0)(?!\d)'), '');
  }

  /// Formatted string for the price.
  String get formattedPrice {
    if (price == 0) return '—';
    if (price % 1 == 0) return price.toInt().toString();
    return price.toStringAsFixed(2);
  }

  /// Serializes fields for INSERT / UPDATE (id is NOT included — DB manages it).
  Map<String, dynamic> toInsertJson(String hardwareId) {
    return {
      'hardware_id': hardwareId,
      'product_name': productName,
      if (categoryId != null) 'category_id': categoryId,
      'quantity': quantity,
      'unit': unit,
      'price': price,
      'cost_price': costPrice,
      'is_active': isActive,
      if (remarks != null && remarks!.isNotEmpty) 'remarks': remarks,
      if (imageUrl != null && imageUrl!.isNotEmpty) 'image_url': imageUrl,
    };
  }

  Product copyWith({
    String? id,
    String? hardwareId,
    String? productName,
    String? categoryId,
    String? categoryName,
    double? quantity,
    String? unit,
    double? price,
    double? costPrice,
    bool? isActive,
    String? remarks,
    String? imageUrl,
    DateTime? createdAt,
    bool clearImage = false,
  }) {
    return Product(
      id: id ?? this.id,
      hardwareId: hardwareId ?? this.hardwareId,
      productName: productName ?? this.productName,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      price: price ?? this.price,
      costPrice: costPrice ?? this.costPrice,
      isActive: isActive ?? this.isActive,
      remarks: remarks ?? this.remarks,
      imageUrl: clearImage ? null : (imageUrl ?? this.imageUrl),
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Product &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          productName == other.productName;

  @override
  int get hashCode => id.hashCode ^ productName.hashCode;
}

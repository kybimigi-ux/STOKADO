import 'package:flutter/material.dart';
import '../utils/buttons.dart';
import '../utils/section_card.dart';
import '../models/product.dart';
import '../theme/app_theme.dart';

enum ProductSort {
  recentlyAdded,
  nameAsc,
  nameDesc,
  quantityAsc,
  quantityDesc,
}

extension ProductSortLabel on ProductSort {
  String get label {
    switch (this) {
      case ProductSort.recentlyAdded:
        return 'Recently Added';
      case ProductSort.nameAsc:
        return 'Name (A-Z)';
      case ProductSort.nameDesc:
        return 'Name (Z-A)';
      case ProductSort.quantityAsc:
        return 'Quantity (Low-High)';
      case ProductSort.quantityDesc:
        return 'Quantity (High-Low)';
    }
  }
}

// Placeholder product list — no backend/service call.
final List<Product> _products = [
  const Product(productName: 'Product 1', quantity: 10),
  const Product(productName: 'Product 2', quantity: 5),
  const Product(productName: 'Product 3', quantity: 25),
  const Product(productName: 'Product 4', quantity: 2),
];

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  ProductSort _sortOption = ProductSort.recentlyAdded;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onAddProduct() {
    // Handle adding a new product
  }

  List<Product> get _filteredProducts {
    final query = _searchController.text.trim().toLowerCase();
    final filtered = _products
        .where((p) =>
            query.isEmpty || p.productName.toLowerCase().contains(query))
        .toList();

    switch (_sortOption) {
      case ProductSort.nameAsc:
        filtered.sort((a, b) =>
            a.productName.toLowerCase().compareTo(b.productName.toLowerCase()));
        break;
      case ProductSort.nameDesc:
        filtered.sort((a, b) =>
            b.productName.toLowerCase().compareTo(a.productName.toLowerCase()));
        break;
      case ProductSort.quantityAsc:
        filtered.sort((a, b) => a.quantity.compareTo(b.quantity));
        break;
      case ProductSort.quantityDesc:
        filtered.sort((a, b) => b.quantity.compareTo(a.quantity));
        break;
      case ProductSort.recentlyAdded:
        // Placeholder list has no real timestamp/id ordering, so this
        // is a no-op here — left in place to match the real sort options.
        break;
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredProducts;
    final screenWidth = MediaQuery.of(context).size.width;
    final compact = screenWidth < 600;
    final horizontalPadding = compact ? 16.0 : 32.0;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(horizontalPadding, 28, horizontalPadding, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ScreenHeader(
            title: 'Inventory',
            subtitle: '${_products.length} products',
            actions: [
              PrimaryButton(
                label: 'Add Product',
                onPressed: _onAddProduct,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          _buildFilterBar(),
          const SizedBox(height: AppSpacing.lg),
          SectionCard(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.sm),
            child: filtered.isEmpty
                ? SizedBox(
                    height: 160,
                    child: Center(
                      child: Text(
                        'No products match your search.',
                        style: AppTextStyles.body
                            .copyWith(color: AppColors.textSecondary),
                      ),
                    ),
                  )
                : _ProductList(products: filtered),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    final compact = MediaQuery.of(context).size.width < 600;

    final searchField = Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.search_rounded,
              size: 18, color: AppColors.textMuted),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration.collapsed(
                hintText: 'Search product name...',
                hintStyle: AppTextStyles.body
                    .copyWith(color: AppColors.textMuted),
              ),
              style: AppTextStyles.body,
            ),
          ),
          if (_searchController.text.isNotEmpty)
            GestureDetector(
              onTap: () {
                _searchController.clear();
                setState(() {});
              },
              child: const Icon(Icons.close_rounded,
                  size: 18, color: AppColors.textMuted),
            ),
        ],
      ),
    );

    final sortDropdown = Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<ProductSort>(
          value: _sortOption,
          icon: const Icon(Icons.expand_more_rounded,
              size: 18, color: AppColors.textSecondary),
          style: AppTextStyles.body,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          isExpanded: compact,
          items: ProductSort.values
              .map((s) => DropdownMenuItem(
                    value: s,
                    child: Text(s.label),
                  ))
              .toList(),
          onChanged: (v) =>
              setState(() => _sortOption = v ?? ProductSort.recentlyAdded),
        ),
      ),
    );

    if (compact) {
      return Column(
        children: [
          searchField,
          const SizedBox(height: AppSpacing.sm),
          sortDropdown,
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: searchField),
        const SizedBox(width: AppSpacing.md),
        sortDropdown,
      ],
    );
  }
}

class _ProductList extends StatelessWidget {
  final List<Product> products;

  const _ProductList({required this.products});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: products.map((p) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      p.productName,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: p.quantity <= 10
                          ? AppColors.warningSoft
                          : AppColors.successSoft,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${p.quantity}',
                      style: AppTextStyles.caption.copyWith(
                        color: p.quantity <= 10
                            ? AppColors.warning
                            : AppColors.success,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.border),
          ],
        );
      }).toList(),
    );
  }
}
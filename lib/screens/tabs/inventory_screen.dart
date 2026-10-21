import 'package:flutter/material.dart';
import '../../models/product.dart';
import '../../services/product_service.dart';
import '../../services/hardware_context.dart';
import '../../theme/app_theme.dart';
import '../../widgets/buttons.dart';
import '../../widgets/notification_banner.dart';
import '../../widgets/section_card.dart';
import '../dialogs_screen/add_product_dialog.dart';
import '../dialogs_screen/edit_product_dialog.dart';
import '../product_ledger_screen.dart';

enum ProductSort { recentlyAdded, nameAsc, nameDesc }

extension _ProductSortLabel on ProductSort {
  String get label {
    switch (this) {
      case ProductSort.recentlyAdded:
        return 'Recently Added';
      case ProductSort.nameAsc:
        return 'Name (A-Z)';
      case ProductSort.nameDesc:
        return 'Name (Z-A)';
    }
  }
}

/// Toggle between list and grid view for products.
enum _ViewMode { list, grid }

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Product> _products = [];
  bool _loading = true;
  String? _error;
  ProductSort _sortOption = ProductSort.recentlyAdded;
  _ViewMode _viewMode = _ViewMode.list;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final productsFuture = ProductService.instance.getAll();

      final results = await Future.wait([productsFuture]);

      if (!mounted) return;
      setState(() {
        _products = results[0];
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _onAddProduct() {
    AddProductDialog.show(
      context,
      onProductAdded: () {
        _loadData();
      },
    );
  }

  Future<void> _onOpenProductLedger(Product p) async {
    await ProductLedgerScreen.navigateTo(context, p);
    _loadData();
  }

  Future<void> _onEditProduct(Product p) async {
    final updated = await EditProductDialog.show(context, p);
    if (updated == true) {
      _loadData();
    }
  }

  Future<void> _onDeleteProduct(Product p) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete Product', style: AppTextStyles.h3),
        content: Text(
          'Are you sure you want to delete "${p.productName}"?',
          style: AppTextStyles.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel', style: AppTextStyles.bodyMedium),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true && p.id != null) {
      try {
        await ProductService.instance.delete(p.id!);
        if (!mounted) return;
        NotificationBanner.show(
          context,
          'Product "${p.productName}" deleted.',
          tone: NotificationTone.success,
        );
        _loadData();
      } catch (e) {
        if (!mounted) return;
        NotificationBanner.show(
          context,
          'Failed to delete product: $e',
          tone: NotificationTone.error,
        );
      }
    }
  }

  List<Product> get _filteredProducts {
    final query = _searchController.text.trim().toLowerCase();
    final filtered = _products.where((p) {
      final matchesQuery =
          query.isEmpty || p.productName.toLowerCase().contains(query);
      return matchesQuery;
    }).toList();

    switch (_sortOption) {
      case ProductSort.nameAsc:
        filtered.sort((a, b) =>
            a.productName.toLowerCase().compareTo(b.productName.toLowerCase()));
        break;
      case ProductSort.nameDesc:
        filtered.sort((a, b) =>
            b.productName.toLowerCase().compareTo(a.productName.toLowerCase()));
        break;
      case ProductSort.recentlyAdded:
        filtered.sort((a, b) => (b.createdAt ?? DateTime(1970))
            .compareTo(a.createdAt ?? DateTime(1970)));
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

    final canAdd = HardwareContext.instance.canAddProducts;
    final canEdit = HardwareContext.instance.canEditProducts;
    final canDelete = HardwareContext.instance.canRemoveProducts;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(horizontalPadding, 28, horizontalPadding, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ScreenHeader(
            title: 'Inventory',
            subtitle: _loading
                ? 'Loading products...'
                : '${_products.length} products in stock',
            actions: [
              if (canAdd)
                PrimaryButton(
                  label: 'Add New Product',
                  icon: Icons.add_rounded,
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
            child: _loading
                ? const SizedBox(
                    height: 240,
                    child: Center(child: CircularProgressIndicator()),
                  )
                : _error != null
                    ? SizedBox(
                        height: 200,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('Failed to load products',
                                  style: AppTextStyles.h3),
                              const SizedBox(height: 8),
                              Text(_error!,
                                  style: AppTextStyles.caption
                                      .copyWith(color: AppColors.danger)),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _loadData,
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : filtered.isEmpty
                        ? SizedBox(
                            height: 200,
                            child: Center(
                              child: Text(
                                _products.isEmpty
                                    ? 'No products added yet. Click "Add New Product" to create one.'
                                    : 'No products match your filter criteria.',
                                style: AppTextStyles.body
                                    .copyWith(color: AppColors.textSecondary),
                              ),
                            ),
                          )
                        : _viewMode == _ViewMode.grid
                            ? _ProductGrid(
                                products: filtered,
                                onSelectProduct: _onOpenProductLedger,
                                onEdit: _onEditProduct,
                                onDelete: _onDeleteProduct,
                                canEdit: canEdit,
                                canDelete: canDelete,
                              )
                            : _ProductTable(
                                products: filtered,
                                onSelectProduct: _onOpenProductLedger,
                                onEdit: _onEditProduct,
                                onDelete: _onDeleteProduct,
                                canEdit: canEdit,
                                canDelete: canDelete,
                              ),
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

    // View mode toggle
    final viewToggle = Container(
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ViewToggleButton(
            icon: Icons.view_list_rounded,
            selected: _viewMode == _ViewMode.list,
            tooltip: 'List view',
            onTap: () => setState(() => _viewMode = _ViewMode.list),
            leftRounded: true,
          ),
          Container(width: 1, color: AppColors.border),
          _ViewToggleButton(
            icon: Icons.grid_view_rounded,
            selected: _viewMode == _ViewMode.grid,
            tooltip: 'Grid view',
            onTap: () => setState(() => _viewMode = _ViewMode.grid),
            leftRounded: false,
          ),
        ],
      ),
    );

    if (compact) {
      return Column(
        children: [
          searchField,
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(child: sortDropdown),
              const SizedBox(width: AppSpacing.sm),
              viewToggle,
            ],
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: searchField),
        const SizedBox(width: AppSpacing.md),
        sortDropdown,
        const SizedBox(width: AppSpacing.sm),
        viewToggle,
      ],
    );
  }
}

class _ViewToggleButton extends StatelessWidget {
  final IconData icon;
  final bool selected;
  final String tooltip;
  final VoidCallback onTap;
  final bool leftRounded;

  const _ViewToggleButton({
    required this.icon,
    required this.selected,
    required this.tooltip,
    required this.onTap,
    required this.leftRounded,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.horizontal(
          left: leftRounded ? const Radius.circular(AppRadius.sm - 1) : Radius.zero,
          right: leftRounded ? Radius.zero : const Radius.circular(AppRadius.sm - 1),
        ),
        child: Container(
          width: 40,
          height: 44,
          decoration: BoxDecoration(
            color: selected ? AppColors.primarySoft : Colors.transparent,
          ),
          child: Icon(
            icon,
            size: 18,
            color: selected ? AppColors.primary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Grid view
// ─────────────────────────────────────────────────────────────────────────────

class _ProductGrid extends StatelessWidget {
  final List<Product> products;
  final Function(Product) onSelectProduct;
  final Function(Product) onEdit;
  final Function(Product) onDelete;
  final bool canEdit;
  final bool canDelete;

  const _ProductGrid({
    required this.products,
    required this.onSelectProduct,
    required this.onEdit,
    required this.onDelete,
    required this.canEdit,
    required this.canDelete,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final int crossAxisCount;
        final double childAspectRatio;

        if (width < 340) {
          crossAxisCount = 1;
          childAspectRatio = 1.15;
        } else if (width < 580) {
          crossAxisCount = 2;
          childAspectRatio = 0.62;
        } else if (width < 860) {
          crossAxisCount = 3;
          childAspectRatio = 0.66;
        } else if (width < 1180) {
          crossAxisCount = 4;
          childAspectRatio = 0.70;
        } else {
          crossAxisCount = 5;
          childAspectRatio = 0.72;
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(vertical: 8),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: childAspectRatio,
          ),
          itemCount: products.length,
          itemBuilder: (context, index) {
            final p = products[index];
            return _ProductGridCard(
              product: p,
              onTap: () => onSelectProduct(p),
              onEdit: canEdit ? () => onEdit(p) : null,
              onDelete: canDelete ? () => onDelete(p) : null,
            );
          },
        );
      },
    );
  }
}

class _ProductGridCard extends StatelessWidget {
  final Product product;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _ProductGridCard({
    required this.product,
    required this.onTap,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage =
        product.imageUrl != null && product.imageUrl!.trim().isNotEmpty;
    final isLowStock = product.quantity <= 10;

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Image Section (fills remaining space) ──
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(13)),
                  child: SizedBox.expand(
                    child: hasImage
                        ? Image.network(
                            product.imageUrl!.trim(),
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _imageFallback(),
                          )
                        : _imageFallback(),
                  ),
                ),
              ),

              // ── Info Section (natural content height, no flex overflow) ──
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.productName,
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),

                    // Price
                    Text(
                      product.price > 0
                          ? '₱${product.price % 1 == 0 ? product.price.toInt() : product.price.toStringAsFixed(2)}'
                          : '₱0.00',
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 5),

                    // Stock badge & actions
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: isLowStock
                                  ? AppColors.warningSoft
                                  : AppColors.successSoft,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${product.formattedQuantity} ${product.unit}',
                              style: AppTextStyles.caption.copyWith(
                                fontSize: 10,
                                color: isLowStock
                                    ? AppColors.warning
                                    : AppColors.success,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        if (onEdit != null || onDelete != null) ...[
                          const SizedBox(width: 4),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (onEdit != null)
                                _SmallIconButton(
                                  icon: Icons.edit_outlined,
                                  color: AppColors.primary,
                                  tooltip: 'Edit',
                                  onTap: onEdit!,
                                ),
                              if (onDelete != null)
                                _SmallIconButton(
                                  icon: Icons.delete_outline_rounded,
                                  color: AppColors.danger,
                                  tooltip: 'Delete',
                                  onTap: onDelete!,
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _imageFallback() {
    return Container(
      color: AppColors.neutralSoft,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.inventory_2_outlined,
                size: 28, color: AppColors.textMuted),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                product.productName,
                style: AppTextStyles.caption.copyWith(
                    color: AppColors.textMuted, fontSize: 10),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SmallIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  const _SmallIconButton({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: Icon(icon, size: 14, color: color),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// List / Table view (unchanged logic, minor style tweaks for image preview)
// ─────────────────────────────────────────────────────────────────────────────

class _ProductTable extends StatelessWidget {
  final List<Product> products;
  final Function(Product) onSelectProduct;
  final Function(Product) onEdit;
  final Function(Product) onDelete;
  final bool canEdit;
  final bool canDelete;

  const _ProductTable({
    required this.products,
    required this.onSelectProduct,
    required this.onEdit,
    required this.onDelete,
    required this.canEdit,
    required this.canDelete,
  });

  static const double _thumbSize = 36;
  static const double _priceColumnWidth = 90;
  static const double _stockColumnWidth = 120;
  static const double _actionsColumnWidth = 96;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.of(context).size.width < 600;

    if (compact) {
      return _buildMobileList();
    }
    return _buildDesktopTable();
  }

  Widget _buildMobileList() {
    return Column(
      children: products.map((p) {
        final hasImage =
            p.imageUrl != null && p.imageUrl!.trim().isNotEmpty;
        return Column(
          children: [
            InkWell(
              onTap: () => onSelectProduct(p),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                child: Row(
                  children: [
                    // Thumbnail
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: _thumbSize,
                        height: _thumbSize,
                        color: AppColors.neutralSoft,
                        child: hasImage
                            ? Image.network(p.imageUrl!.trim(),
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Icon(
                                    Icons.inventory_2_outlined,
                                    size: 18,
                                    color: AppColors.textMuted))
                            : const Icon(Icons.inventory_2_outlined,
                                size: 18, color: AppColors.textMuted),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.productName,
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: p.quantity <= 10
                                      ? AppColors.warningSoft
                                      : AppColors.successSoft,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '${p.formattedQuantity} ${p.unit}',
                                  style: AppTextStyles.caption.copyWith(
                                    color: p.quantity <= 10
                                        ? AppColors.warning
                                        : AppColors.success,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (p.price > 0)
                                Text(
                                  '\u20b1${p.price % 1 == 0 ? p.price.toInt() : p.price.toStringAsFixed(2)}',
                                  style: AppTextStyles.caption.copyWith(
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (canEdit)
                      IconButton(
                        onPressed: () => onEdit(p),
                        icon: const Icon(Icons.edit_outlined,
                            size: 18, color: AppColors.primary),
                        splashRadius: 18,
                        tooltip: 'Edit',
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.all(8),
                      ),
                    if (canEdit && canDelete) const SizedBox(width: 4),
                    if (canDelete)
                      IconButton(
                        onPressed: () => onDelete(p),
                        icon: const Icon(Icons.delete_outline_rounded,
                            size: 18, color: AppColors.danger),
                        splashRadius: 18,
                        tooltip: 'Delete',
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.all(8),
                      ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1, color: AppColors.border),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildDesktopTable() {
    return SizedBox(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header row
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                const SizedBox(width: _thumbSize + 10),
                Expanded(
                  child: Text('PRODUCT NAME', style: AppTextStyles.label),
                ),
                SizedBox(
                  width: _priceColumnWidth,
                  child: Text('PRICE',
                      textAlign: TextAlign.right, style: AppTextStyles.label),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: _stockColumnWidth,
                  child: Text('IN STOCK',
                      textAlign: TextAlign.right, style: AppTextStyles.label),
                ),
                if (canEdit || canDelete) ...[
                  const SizedBox(width: 28),
                  SizedBox(
                    width: _actionsColumnWidth,
                    child: Text('ACTIONS',
                        textAlign: TextAlign.right, style: AppTextStyles.label),
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          // Data rows
          ...products.map((p) {
            final hasImage =
                p.imageUrl != null && p.imageUrl!.trim().isNotEmpty;
            return Column(
              children: [
                InkWell(
                  onTap: () => onSelectProduct(p),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        vertical: 10, horizontal: 4),
                    child: Row(
                      children: [
                        // Thumbnail
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            width: _thumbSize,
                            height: _thumbSize,
                            color: AppColors.neutralSoft,
                            child: hasImage
                                ? Image.network(p.imageUrl!.trim(),
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        const Icon(Icons.inventory_2_outlined,
                                            size: 18,
                                            color: AppColors.textMuted))
                                : const Icon(Icons.inventory_2_outlined,
                                    size: 18, color: AppColors.textMuted),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            p.productName,
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: _priceColumnWidth,
                          child: Text(
                            p.price > 0
                                ? '\u20b1${p.price % 1 == 0 ? p.price.toInt() : p.price.toStringAsFixed(2)}'
                                : '—',
                            textAlign: TextAlign.right,
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: _stockColumnWidth,
                          child: Text(
                            '${p.formattedQuantity} ${p.unit}',
                            textAlign: TextAlign.right,
                            style: AppTextStyles.bodyMedium,
                          ),
                        ),
                        if (canEdit || canDelete) ...[
                          const SizedBox(width: 28),
                          SizedBox(
                            width: _actionsColumnWidth,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                if (canEdit)
                                  IconButton(
                                    onPressed: () => onEdit(p),
                                    icon: const Icon(Icons.edit_outlined,
                                        size: 18, color: AppColors.primary),
                                    splashRadius: 18,
                                    tooltip: 'Edit',
                                  ),
                                if (canDelete)
                                  IconButton(
                                    onPressed: () => onDelete(p),
                                    icon: const Icon(
                                        Icons.delete_outline_rounded,
                                        size: 18,
                                        color: AppColors.danger),
                                    splashRadius: 18,
                                    tooltip: 'Delete',
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const Divider(height: 1, color: AppColors.border),
              ],
            );
          }),
        ],
      ),
    );
  }
}
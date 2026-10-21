import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/product.dart';
import '../../services/product_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/notification_banner.dart';
import '../dialogs_screen/image_url_picker.dart';

/// A dialog for editing an existing product.
class EditProductDialog extends StatefulWidget {
  final Product product;

  const EditProductDialog({super.key, required this.product});

  /// Shows the dialog and returns `true` if the product was updated.
  static Future<bool?> show(BuildContext context, Product product) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => EditProductDialog(product: product),
    );
  }

  @override
  State<EditProductDialog> createState() => _EditProductDialogState();
}

class _EditProductDialogState extends State<EditProductDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _quantityController;
  late final TextEditingController _priceController;
  late final TextEditingController _remarksController;
  late String _selectedUnit;
  String? _imageUrl;
  bool _loading = false;

  bool get _allowsDecimals {
    final u = _selectedUnit.trim().toLowerCase();
    return u == 'kg' || u == 'cubic';
  }

  static const _units = [
    'pcs',
    'kg',
    'cubic',
    'box',
    'pack',
    'meter',
    'set',
    'roll',
    'pair',
    'liter',
    'bag'
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.product.productName);
    _quantityController =
        TextEditingController(text: widget.product.formattedQuantity);
    _priceController = TextEditingController(
        text: widget.product.price > 0
            ? widget.product.price.toStringAsFixed(
                widget.product.price % 1 == 0 ? 0 : 2)
            : '0');
    _remarksController =
        TextEditingController(text: widget.product.remarks ?? '');
    _selectedUnit = widget.product.unit;
    _imageUrl = widget.product.imageUrl;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    _priceController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final url = await ImageUrlPicker.show(context, initialUrl: _imageUrl);
    if (url != null) {
      setState(() => _imageUrl = url.isEmpty ? null : url);
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      final qtyText = _quantityController.text.trim().replaceAll(',', '.');
      final parsedQty = double.tryParse(qtyText) ?? 0.0;
      final finalQty = _allowsDecimals ? parsedQty : parsedQty.truncateToDouble();
      final parsedPrice = double.tryParse(
            _priceController.text.trim().replaceAll(',', '.')) ?? 0.0;
      await ProductService.instance.update(widget.product.id!, {
        'product_name': _nameController.text.trim(),
        'quantity': finalQty,
        'unit': _selectedUnit,
        'price': parsedPrice,
        'remarks': _remarksController.text.trim(),
        'image_url': _imageUrl,
      });
      if (!mounted) return;

      NotificationBanner.show(
        context,
        'Product updated successfully!',
        tone: NotificationTone.success,
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      NotificationBanner.show(
        context,
        'Failed to update product: $e',
        tone: NotificationTone.error,
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final compact = width < 600;
    final dialogWidth = width > 600 ? 560.0 : width * 0.95;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: compact
          ? const EdgeInsets.symmetric(horizontal: 10, vertical: 16)
          : const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: dialogWidth,
        constraints: BoxConstraints(maxHeight: compact ? MediaQuery.of(context).size.height * 0.92 : 680),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(compact ? 16 : 20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 40,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(compact),
            const Divider(height: 1, color: AppColors.border),
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(compact ? 16 : 28, 16, compact ? 16 : 28, 8),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ─── Product Image ─────────────────────────────────
                      _buildImagePicker(compact),
                      const SizedBox(height: 18),
                      _buildField(
                        label: 'Product Name',
                        child: TextFormField(
                          controller: _nameController,
                          style: AppTextStyles.body
                              .copyWith(color: AppColors.textPrimary),
                          decoration: _inputDecoration('Product name'),
                          validator: (v) =>
                              v == null || v.trim().isEmpty ? 'Required' : null,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: _buildField(
                              label: 'Quantity',
                              child: Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        controller: _quantityController,
                                        style: AppTextStyles.body
                                            .copyWith(color: AppColors.textPrimary),
                                        decoration: _inputDecoration('0'),
                                        keyboardType: _allowsDecimals
                                            ? const TextInputType.numberWithOptions(
                                                decimal: true)
                                            : TextInputType.number,
                                        inputFormatters: [
                                          if (_allowsDecimals)
                                            FilteringTextInputFormatter.allow(
                                                RegExp(r'^\d*[\.,]?\d*'))
                                          else
                                            FilteringTextInputFormatter.digitsOnly,
                                        ],
                                        validator: (v) {
                                          if (v == null || v.trim().isEmpty) {
                                            return 'Required';
                                          }
                                          if (_allowsDecimals) {
                                            final parsed = double.tryParse(
                                                v.trim().replaceAll(',', '.'));
                                            if (parsed == null || parsed < 0) {
                                              return 'Invalid';
                                            }
                                          } else {
                                            final parsed = int.tryParse(v.trim());
                                            if (parsed == null || parsed < 0) {
                                              return 'Whole numbers only';
                                            }
                                          }
                                          return null;
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      height: 48,
                                      decoration: BoxDecoration(
                                        color: AppColors.surface,
                                        border: Border.all(color: AppColors.border),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          InkWell(
                                            onTap: () {
                                              final raw = _quantityController.text.trim().replaceAll(',', '.');
                                              final current = double.tryParse(raw) ?? 0.0;
                                              final next = current + 1.0;
                                              _quantityController.text = next % 1 == 0
                                                  ? next.toInt().toString()
                                                  : next.toString();
                                            },
                                            borderRadius: const BorderRadius.vertical(
                                                top: Radius.circular(8)),
                                            child: const SizedBox(
                                              width: 28,
                                              height: 22,
                                              child: Icon(
                                                  Icons.keyboard_arrow_up_rounded,
                                                  size: 18,
                                                  color: AppColors.textSecondary),
                                            ),
                                          ),
                                          const Divider(
                                              height: 1,
                                              thickness: 1,
                                              color: AppColors.border),
                                          InkWell(
                                            onTap: () {
                                              final raw = _quantityController.text.trim().replaceAll(',', '.');
                                              final current = double.tryParse(raw) ?? 0.0;
                                              if (current > 0) {
                                                final next = (current - 1.0).clamp(0.0, double.infinity);
                                                _quantityController.text = next % 1 == 0
                                                    ? next.toInt().toString()
                                                    : next.toString();
                                              }
                                            },
                                            borderRadius: const BorderRadius.vertical(
                                                bottom: Radius.circular(8)),
                                            child: const SizedBox(
                                              width: 28,
                                              height: 22,
                                              child: Icon(
                                                  Icons.keyboard_arrow_down_rounded,
                                                  size: 18,
                                                  color: AppColors.textSecondary),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildField(
                              label: 'Unit',
                              child: DropdownButtonFormField<String>(
                                initialValue: _units.contains(_selectedUnit)
                                    ? _selectedUnit
                                    : 'pcs',
                                decoration: _inputDecoration(''),
                                style: AppTextStyles.body
                                    .copyWith(color: AppColors.textPrimary),
                                borderRadius: BorderRadius.circular(12),
                                items: _units
                                    .map((u) => DropdownMenuItem(
                                        value: u, child: Text(u)))
                                    .toList(),
                                onChanged: (v) {
                                  final newUnit = v ?? 'pcs';
                                  setState(() {
                                    _selectedUnit = newUnit;
                                    if (!_allowsDecimals) {
                                      final raw = _quantityController.text
                                          .trim()
                                          .replaceAll(',', '.');
                                      final val = double.tryParse(raw);
                                      if (val != null) {
                                        _quantityController.text =
                                            val.toInt().toString();
                                      }
                                    }
                                  });
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      _buildField(
                        label: 'Price per Unit (₱)',
                        child: TextFormField(
                          controller: _priceController,
                          style: AppTextStyles.body
                              .copyWith(color: AppColors.textPrimary),
                          decoration: _inputDecoration('0.00'),
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                                RegExp(r'^\d*[\.,]?\d*')),
                          ],
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return null;
                            final parsed = double.tryParse(
                                v.trim().replaceAll(',', '.'));
                            if (parsed == null || parsed < 0) {
                              return 'Invalid price';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(height: 18),
                      _buildField(
                        label: 'Remarks / Notes (Optional)',
                        child: TextFormField(
                          controller: _remarksController,
                          style: AppTextStyles.body
                              .copyWith(color: AppColors.textPrimary),
                          decoration: _inputDecoration('Notes or remarks'),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
            const Divider(height: 1, color: AppColors.border),
            _buildActions(compact),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePicker(bool compact) {
    final hasImage = _imageUrl != null && _imageUrl!.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Product Image (Optional)', style: AppTextStyles.label),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _pickImage,
          child: Container(
            height: 110,
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: hasImage ? AppColors.primary : AppColors.border,
                width: hasImage ? 1.5 : 1,
              ),
            ),
            child: hasImage
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(11),
                    child: Stack(
                      children: [
                        Image.network(
                          _imageUrl!,
                          width: double.infinity,
                          height: 110,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              _imagePlaceholder(true),
                        ),
                        Positioned(
                          top: 6,
                          right: 6,
                          child: GestureDetector(
                            onTap: () => setState(() => _imageUrl = null),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.5),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close,
                                  size: 14, color: Colors.white),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 6,
                          right: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text('Change',
                                style: TextStyle(
                                    color: Colors.white, fontSize: 11)),
                          ),
                        ),
                      ],
                    ),
                  )
                : _imagePlaceholder(false),
          ),
        ),
      ],
    );
  }

  Widget _imagePlaceholder(bool error) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          error
              ? Icons.broken_image_outlined
              : Icons.add_photo_alternate_outlined,
          size: 28,
          color: AppColors.textMuted,
        ),
        const SizedBox(height: 6),
        Text(
          error ? 'Could not load image' : 'Click to upload or choose product photo',
          style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 2),
        Text(
          error ? 'Tap to change' : 'Upload from device or enter image URL',
          style: AppTextStyles.caption
              .copyWith(color: AppColors.textMuted, fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildHeader(bool compact) {
    return Padding(
      padding: EdgeInsets.fromLTRB(compact ? 16 : 28, compact ? 16 : 22, compact ? 12 : 16, compact ? 12 : 16),
      child: Row(
        children: [
          Container(
            width: compact ? 34 : 40,
            height: compact ? 34 : 40,
            decoration: BoxDecoration(
              color: AppColors.warningSoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.edit_rounded,
                color: AppColors.warning, size: compact ? 18 : 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Edit Product', style: AppTextStyles.h3.copyWith(fontSize: compact ? 16 : 18)),
                const SizedBox(height: 2),
                Text('Update product details below.',
                    style: AppTextStyles.caption.copyWith(fontSize: compact ? 11 : 12)),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(false),
            icon: const Icon(Icons.close_rounded,
                color: AppColors.textMuted, size: 20),
            splashRadius: 18,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(bool compact) {
    return Padding(
      padding: EdgeInsets.fromLTRB(compact ? 16 : 28, 12, compact ? 16 : 28, compact ? 14 : 18),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 44,
              child: OutlinedButton(
                onPressed:
                    _loading ? null : () => Navigator.of(context).pop(false),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  side: const BorderSide(color: AppColors.border),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('Cancel', style: AppTextStyles.bodyMedium),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SizedBox(
              height: 44,
              child: ElevatedButton(
                onPressed: _loading ? null : _handleSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor:
                      AppColors.primary.withValues(alpha: 0.6),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text('Save Changes',
                        style: AppTextStyles.bodyMedium
                            .copyWith(color: Colors.white)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField({required String label, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.label),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: AppTextStyles.body.copyWith(color: AppColors.textMuted),
      filled: true,
      fillColor: AppColors.background,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.danger),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
      ),
    );
  }
}

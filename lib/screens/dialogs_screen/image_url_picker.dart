import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/image_upload_service.dart';
import '../../theme/app_theme.dart';

enum _PickerTab { upload, url }

/// Dialog that lets users either upload a product image from their device/camera
/// or enter a web image URL.
/// Returns the resulting URL string (empty = clear image), or null if cancelled.
class ImageUrlPicker extends StatefulWidget {
  final String? initialUrl;
  const ImageUrlPicker({super.key, this.initialUrl});

  static Future<String?> show(BuildContext context, {String? initialUrl}) {
    return showDialog<String>(
      context: context,
      builder: (_) => ImageUrlPicker(initialUrl: initialUrl),
    );
  }

  @override
  State<ImageUrlPicker> createState() => _ImageUrlPickerState();
}

class _ImageUrlPickerState extends State<ImageUrlPicker> {
  _PickerTab _currentTab = _PickerTab.upload;

  // ── URL Mode State ──
  late final TextEditingController _urlCtrl;
  bool _urlPreviewError = false;
  bool _urlPreviewing = false;

  // ── Upload Mode State ──
  XFile? _pickedFile;
  Uint8List? _pickedBytes;
  bool _uploading = false;
  String? _uploadError;

  @override
  void initState() {
    super.initState();
    final hasInitial = widget.initialUrl != null && widget.initialUrl!.isNotEmpty;
    _urlCtrl = TextEditingController(text: widget.initialUrl ?? '');
    _urlPreviewing = hasInitial;

    // If an initial URL already exists, default to URL tab if it's external,
    // otherwise start on Upload tab.
    if (hasInitial) {
      _currentTab = _PickerTab.url;
    } else {
      _currentTab = _PickerTab.upload;
    }
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    setState(() {
      _uploadError = null;
    });

    try {
      final file = await ImageUploadService.instance.pickImage(source: source);
      if (file == null) return;

      final bytes = await file.readAsBytes();
      if (!mounted) return;

      setState(() {
        _pickedFile = file;
        _pickedBytes = bytes;
        _uploadError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _uploadError = 'Failed to select image: $e';
      });
    }
  }

  Future<void> _handleUpload() async {
    if (_pickedBytes == null || _pickedFile == null) return;

    setState(() {
      _uploading = true;
      _uploadError = null;
    });

    try {
      final publicUrl = await ImageUploadService.instance.uploadProductImage(
        bytes: _pickedBytes!,
        originalFileName: _pickedFile!.name,
      );

      if (!mounted) return;
      Navigator.of(context).pop(publicUrl);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _uploading = false;
        _uploadError = e.toString();
      });
    }
  }

  void _previewUrl() {
    final url = _urlCtrl.text.trim();
    if (url.isEmpty) return;
    setState(() {
      _urlPreviewError = false;
      _urlPreviewing = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: 480,
        constraints: const BoxConstraints(maxHeight: 640),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.16),
              blurRadius: 36,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header ──
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 18, 16, 14),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.add_photo_alternate_rounded,
                        color: AppColors.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Product Photo',
                            style: AppTextStyles.h3.copyWith(fontSize: 16)),
                        Text('Upload from device or enter image URL',
                            style: AppTextStyles.caption),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded,
                        color: AppColors.textMuted, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),

            // ── Tab Bar ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _TabButton(
                        label: 'Upload Image',
                        icon: Icons.cloud_upload_outlined,
                        selected: _currentTab == _PickerTab.upload,
                        onTap: () => setState(() => _currentTab = _PickerTab.upload),
                      ),
                    ),
                    Expanded(
                      child: _TabButton(
                        label: 'Image URL',
                        icon: Icons.link_rounded,
                        selected: _currentTab == _PickerTab.url,
                        onTap: () => setState(() => _currentTab = _PickerTab.url),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 14),
            const Divider(height: 1, color: AppColors.border),

            // ── Tab Content ──
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: _currentTab == _PickerTab.upload
                    ? _buildUploadContent()
                    : _buildUrlContent(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Tab 1: Upload from Device
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildUploadContent() {
    final hasPicked = _pickedBytes != null;
    final sizeKb = hasPicked ? (_pickedBytes!.lengthInBytes / 1024).round() : 0;
    final sizeLabel = sizeKb > 1024
        ? '${(sizeKb / 1024).toStringAsFixed(1)} MB'
        : '$sizeKb KB';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!hasPicked) ...[
          // Empty State / Picker Zone
          Container(
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.border,
                style: BorderStyle.solid,
                width: 1.5,
              ),
            ),
            child: Column(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(
                    color: AppColors.primarySoft,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.file_upload_outlined,
                      size: 28, color: AppColors.primary),
                ),
                const SizedBox(height: 14),
                Text(
                  'Select a product photo to upload',
                  style: AppTextStyles.bodyMedium
                      .copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  'JPG, PNG or WebP • Optimized automatically for fast loading',
                  style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  alignment: WrapAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _pickImage(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library_outlined, size: 18),
                      label: const Text('Browse Files / Gallery'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _pickImage(ImageSource.camera),
                      icon: const Icon(Icons.camera_alt_outlined, size: 18),
                      label: const Text('Camera'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textPrimary,
                        side: const BorderSide(color: AppColors.border),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ] else ...[
          // Image Selected Preview
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Container(
              height: 200,
              width: double.infinity,
              color: AppColors.neutralSoft,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.memory(
                    _pickedBytes!,
                    fit: BoxFit.contain,
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Material(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(20),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () {
                          setState(() {
                            _pickedBytes = null;
                            _pickedFile = null;
                            _uploadError = null;
                          });
                        },
                        child: const Padding(
                          padding: EdgeInsets.all(6),
                          child: Icon(Icons.close_rounded,
                              size: 16, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // File info pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                const Icon(Icons.image_outlined,
                    size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _pickedFile?.name ?? 'image.jpg',
                    style: AppTextStyles.bodyMedium.copyWith(fontSize: 12.5),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  sizeLabel,
                  style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => _pickImage(ImageSource.gallery),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Change', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
        ],

        // Error message if any
        if (_uploadError != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.dangerSoft,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.danger.withValues(alpha: 0.4)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.error_outline_rounded,
                    color: AppColors.danger, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _uploadError!,
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.danger, height: 1.3),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 18),

        // Action Buttons
        Row(
          children: [
            if (widget.initialUrl != null && widget.initialUrl!.isNotEmpty) ...[
              OutlinedButton(
                onPressed: _uploading ? null : () => Navigator.of(context).pop(''),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.danger,
                  side: const BorderSide(color: AppColors.danger),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                child: const Text('Remove Image'),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: ElevatedButton(
                onPressed: (hasPicked && !_uploading) ? _handleUpload : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.neutralSoft,
                  disabledForegroundColor: AppColors.textMuted,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: _uploading
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(width: 10),
                          Text('Uploading to storage...'),
                        ],
                      )
                    : Text(
                        hasPicked ? 'Upload & Use Photo' : 'Select a photo first',
                        style: AppTextStyles.bodyMedium
                            .copyWith(color: Colors.white, fontWeight: FontWeight.w600),
                      ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Tab 2: Image URL
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildUrlContent() {
    final url = _urlCtrl.text.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Preview area
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: _urlPreviewing && !_urlPreviewError ? 180 : 0,
          child: _urlPreviewing && !_urlPreviewError
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    color: AppColors.neutralSoft,
                    child: Image.network(
                      url,
                      width: double.infinity,
                      height: 180,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) setState(() => _urlPreviewError = true);
                        });
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),

        if (_urlPreviewing && !_urlPreviewError) const SizedBox(height: 12),

        if (_urlPreviewError) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.dangerSoft,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.broken_image_outlined,
                    color: AppColors.danger, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Unable to load image from this URL',
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.danger)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        Text('Image Web URL', style: AppTextStyles.label),
        const SizedBox(height: 8),
        TextField(
          controller: _urlCtrl,
          style: AppTextStyles.body.copyWith(color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: 'https://example.com/product.jpg',
            hintStyle: AppTextStyles.body.copyWith(color: AppColors.textMuted),
            filled: true,
            fillColor: AppColors.background,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  const BorderSide(color: AppColors.primary, width: 1.5),
            ),
            suffixIcon: _urlCtrl.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close_rounded,
                        size: 16, color: AppColors.textMuted),
                    onPressed: () {
                      _urlCtrl.clear();
                      setState(() {
                        _urlPreviewing = false;
                        _urlPreviewError = false;
                      });
                    },
                  )
                : null,
          ),
          onChanged: (_) {
            setState(() {
              _urlPreviewing = false;
              _urlPreviewError = false;
            });
          },
          onSubmitted: (_) => _previewUrl(),
        ),
        const SizedBox(height: 8),
        Text(
          'Tip: You can use any direct image link ending in .jpg, .png, or web image address.',
          style: AppTextStyles.caption
              .copyWith(color: AppColors.textMuted, fontSize: 11),
        ),
        const SizedBox(height: 18),

        Row(
          children: [
            if (url.isNotEmpty) ...[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _previewUrl,
                  icon: const Icon(Icons.visibility_outlined, size: 16),
                  label: const Text('Preview'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(_urlCtrl.text.trim()),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: Text(
                  url.isEmpty ? 'Remove Image' : 'Use This Image',
                  style: AppTextStyles.bodyMedium.copyWith(color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _TabButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: selected ? AppColors.primary : AppColors.textMuted,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: AppTextStyles.bodyMedium.copyWith(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: selected ? AppColors.textPrimary : AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'hardware_context.dart';

class ImageUploadException implements Exception {
  final String message;
  final dynamic originalError;
  const ImageUploadException(this.message, [this.originalError]);

  @override
  String toString() => message;
}

class ImageUploadService {
  ImageUploadService._();
  static final ImageUploadService instance = ImageUploadService._();

  static final SupabaseClient _client = Supabase.instance.client;
  static const String bucketName = 'product-images';

  final ImagePicker _picker = ImagePicker();

  /// Pick an image from gallery or camera.
  /// Compresses and limits max dimension to 1024px for fast uploads and low storage.
  Future<XFile?> pickImage({ImageSource source = ImageSource.gallery}) async {
    try {
      final file = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      return file;
    } catch (e) {
      debugPrint('[ImageUploadService] pickImage error: $e');
      rethrow;
    }
  }

  /// Uploads image bytes to Supabase Storage under `product-images` bucket.
  /// Returns the permanent public URL to the uploaded file.
  Future<String> uploadProductImage({
    required Uint8List bytes,
    required String originalFileName,
  }) async {
    try {
      final rawExt = originalFileName.contains('.')
          ? originalFileName.split('.').last.toLowerCase()
          : 'jpg';
      final ext = ['jpg', 'jpeg', 'png', 'webp', 'gif'].contains(rawExt)
          ? rawExt
          : 'jpg';

      final mimeType = ext == 'png'
          ? 'image/png'
          : ext == 'webp'
              ? 'image/webp'
              : ext == 'gif'
                  ? 'image/gif'
                  : 'image/jpeg';

      final hwId = HardwareContext.instance.activeHardware?.id ?? 'global';
      final uniqueId = const Uuid().v4().substring(0, 8);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final storagePath = 'products/$hwId/${timestamp}_$uniqueId.$ext';

      await _client.storage.from(bucketName).uploadBinary(
            storagePath,
            bytes,
            fileOptions: FileOptions(
              contentType: mimeType,
              upsert: true,
            ),
          );

      final publicUrl = _client.storage.from(bucketName).getPublicUrl(storagePath);
      return publicUrl;
    } on StorageException catch (se) {
      debugPrint('[ImageUploadService] StorageException: ${se.message} (${se.statusCode})');
      if (se.message.toLowerCase().contains('bucket not found') ||
          se.statusCode == '404') {
        throw ImageUploadException(
          'Storage bucket "$bucketName" not found in Supabase. Please run the updated SQL migration or create the bucket in your Supabase dashboard.',
          se,
        );
      }
      throw ImageUploadException('Upload failed: ${se.message}', se);
    } catch (e) {
      debugPrint('[ImageUploadService] upload error: $e');
      throw ImageUploadException('Failed to upload image: $e', e);
    }
  }
}

import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

/// ImgBB image uploads. API key lives in the client for this MVP —
/// swap for a Cloud Function proxy before production.
class ImageUploadService {
  ImageUploadService._();

  static final ImageUploadService instance = ImageUploadService._();

  static const String apiKey = '784497969cc3de714800b63d178da983';
  static const String _endpoint = 'https://api.imgbb.com/1/upload';

  final ImagePicker _picker = ImagePicker();

  /// Opens the system picker and uploads the chosen image.
  /// Returns the hosted URL, or null if the user cancelled.
  Future<String?> pickAndUpload({
    ImageSource source = ImageSource.gallery,
    String? name,
  }) async {
    final file = await _picker.pickImage(
      source: source,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 88,
    );
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    return uploadBytes(
      bytes,
      filename: name ?? file.name,
      mimeType: _mimeFromName(file.name),
    );
  }

  Future<String> uploadBytes(
    List<int> bytes, {
    required String filename,
    String mimeType = 'image/jpeg',
  }) async {
    if (apiKey.isEmpty) {
      throw StateError('ImgBB API key is not configured.');
    }
    final uri = Uri.parse('$_endpoint?key=$apiKey');
    final request = http.MultipartRequest('POST', uri)
      ..fields['name'] = filename.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_')
      ..files.add(
        http.MultipartFile.fromBytes(
          'image',
          bytes is Uint8List ? bytes : Uint8List.fromList(bytes),
          filename: filename,
          contentType: _contentType(mimeType),
        ),
      );

    final streamed = await request.send().timeout(
          const Duration(seconds: 45),
        );
    final body = await streamed.stream.bytesToString();
    if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
      throw HttpException('ImgBB upload failed (${streamed.statusCode})');
    }
    final json = jsonDecode(body) as Map<String, dynamic>;
    if (json['success'] != true) {
      final err = json['error']?['message'] ?? 'Unknown ImgBB error';
      throw HttpException('$err');
    }
    final url = json['data']?['url'] as String?;
    if (url == null || url.isEmpty) {
      throw const HttpException('ImgBB returned no image URL.');
    }
    return url;
  }

  static String _mimeFromName(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.heic')) return 'image/heic';
    return 'image/jpeg';
  }

  static http.MediaType _contentType(String mime) =>
      http.MediaType.parse(mime);
}

class HttpException implements Exception {
  const HttpException(this.message);
  final String message;
  @override
  String toString() => message;
}

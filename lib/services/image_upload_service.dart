import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

/// Image uploads for cover art, avatars and product photos.
///
/// Primary host is **Cloudinary** (unsigned upload preset), which allows
/// direct uploads from every platform including web. ImgBB is kept as an
/// automatic fallback so uploads still succeed if one host is blocked.
///
/// Both credentials live in the client for this MVP — move the upload behind
/// a Cloud Function proxy before production.
class ImageUploadService {
  ImageUploadService._();

  static final ImageUploadService instance = ImageUploadService._();

  // ---------------------------------------------------------------------------
  // Cloudinary configuration
  //
  // Paste your values below, or leave them blank and pass
  // --dart-define=CLOUDINARY_CLOUD_NAME=... --dart-define=CLOUDINARY_UPLOAD_PRESET=...
  //
  //   _defaultCloudName    → Cloudinary dashboard home, "Cloud name"
  //   _defaultUploadPreset → Settings → Upload → Upload presets → the
  //                          UNSIGNED preset's *name*, e.g. "fandomverse_covers"
  // ---------------------------------------------------------------------------
  static const String _defaultCloudName = 'ahci5qr7';
  static const String _defaultUploadPreset = 'FandomVerse';

  static const String _envCloudName = String.fromEnvironment(
    'CLOUDINARY_CLOUD_NAME',
  );
  static const String _envUploadPreset = String.fromEnvironment(
    'CLOUDINARY_UPLOAD_PRESET',
  );

  static const String cloudinaryCloudName = _envCloudName == ''
      ? _defaultCloudName
      : _envCloudName;
  static const String cloudinaryUploadPreset = _envUploadPreset == ''
      ? _defaultUploadPreset
      : _envUploadPreset;

  /// Optional Cloudinary folder so uploads stay organised.
  static const String cloudinaryFolder = String.fromEnvironment(
    'CLOUDINARY_FOLDER',
    defaultValue: 'fandomverse',
  );

  static bool get cloudinaryConfigured =>
      cloudinaryCloudName.isNotEmpty && cloudinaryUploadPreset.isNotEmpty;

  // ---------------------------------------------------------------------------
  // ImgBB fallback configuration
  // ---------------------------------------------------------------------------
  static const String imgbbApiKey = '784497969cc3de714800b63d178da983';
  static const String _imgbbEndpoint = 'https://api.imgbb.com/1/upload';

  static const Duration _timeout = Duration(seconds: 45);

  final ImagePicker _picker = ImagePicker();

  /// Logs the technical detail so failures are diagnosable, and hands the
  /// caller a message that is safe to show to a person.
  static ImageUploadException _fail(String message, String technical) {
    debugPrint('ImageUploadService: $technical');
    return ImageUploadException(message, technical: technical);
  }

  /// Opens the system picker and uploads the chosen image.
  /// Returns the hosted URL, or null if the user cancelled.
  Future<String?> pickAndUpload({
    ImageSource source = ImageSource.gallery,
    String? name,
  }) async {
    XFile? file;
    try {
      file = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 88,
      );
    } catch (error) {
      throw _fail(
        'Could not open your files. Pick the image again.',
        'image_picker failed: $error',
      );
    }
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    return uploadBytes(
      bytes,
      filename: name ?? file.name,
      mimeType: _mimeFromName(file.name),
    );
  }

  /// Uploads raw bytes and returns the hosted URL.
  ///
  /// Tries Cloudinary first when configured, then ImgBB. The first host that
  /// answers with a URL wins; if every host fails, the primary host's reason
  /// is thrown so the user sees the most relevant message.
  Future<String> uploadBytes(
    List<int> bytes, {
    required String filename,
    String mimeType = 'image/jpeg',
  }) async {
    final failures = <ImageUploadException>[];

    if (cloudinaryConfigured) {
      try {
        return await _uploadToCloudinary(
          bytes,
          filename: filename,
          mimeType: mimeType,
        );
      } on ImageUploadException catch (error) {
        failures.add(error);
      }
    }

    try {
      return await _uploadToImgbb(
        bytes,
        filename: filename,
        mimeType: mimeType,
      );
    } on ImageUploadException catch (error) {
      failures.add(error);
    }

    if (failures.isEmpty) {
      throw _fail(
        'Image uploads are not configured yet.',
        'no image host credentials are set',
      );
    }

    final primary = failures.first;
    if (failures.length == 1) throw primary;
    debugPrint(
      'ImageUploadService: all hosts failed → '
      '${failures.map((f) => f.technical).join(' | ')}',
    );
    throw primary;
  }

  // ---------------------------------------------------------------------------
  // Cloudinary
  // ---------------------------------------------------------------------------
  Future<String> _uploadToCloudinary(
    List<int> bytes, {
    required String filename,
    required String mimeType,
  }) async {
    final uri = Uri.parse(
      'https://api.cloudinary.com/v1_1/$cloudinaryCloudName/image/upload',
    );
    final request = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = cloudinaryUploadPreset
      ..fields['folder'] = cloudinaryFolder
      ..files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes is Uint8List ? bytes : Uint8List.fromList(bytes),
          filename: filename,
          contentType: _contentType(mimeType),
        ),
      );

    final streamed = await _send(request, host: 'Cloudinary');
    final body = await streamed.stream.bytesToString();
    final json = _decode(body);

    if (streamed.statusCode >= 200 && streamed.statusCode < 300) {
      final url = json?['secure_url'] as String? ?? json?['url'] as String?;
      if (url != null && url.isNotEmpty) return url;
      throw _fail(
        'The image host did not return a link. Try again in a moment.',
        'Cloudinary returned ${streamed.statusCode} without secure_url',
      );
    }

    throw _cloudinaryFailure(
      statusCode: streamed.statusCode,
      hostMessage: json?['error']?['message'] as String?,
    );
  }

  static ImageUploadException _cloudinaryFailure({
    required int statusCode,
    String? hostMessage,
  }) {
    final technical =
        'Cloudinary HTTP $statusCode'
        '${hostMessage != null ? ': $hostMessage' : ''}';
    final lower = (hostMessage ?? '').toLowerCase();

    if (statusCode == 401 ||
        lower.contains('preset') ||
        lower.contains('unsigned') ||
        lower.contains('cloud name')) {
      return _fail(
        'Image uploads are not configured correctly. Check the Cloudinary preset.',
        technical,
      );
    }
    if (statusCode == 413) {
      return _fail('That image is too large. Try a smaller one.', technical);
    }
    if (statusCode == 420 || statusCode == 429) {
      return _fail(
        'Too many uploads right now. Wait a moment and try again.',
        technical,
      );
    }
    if (statusCode >= 500) {
      return _fail(
        'The image host is having trouble. Try again in a moment.',
        technical,
      );
    }
    return _fail(
      'The image could not be uploaded. Try again in a moment.',
      technical,
    );
  }

  // ---------------------------------------------------------------------------
  // ImgBB (fallback)
  // ---------------------------------------------------------------------------
  Future<String> _uploadToImgbb(
    List<int> bytes, {
    required String filename,
    required String mimeType,
  }) async {
    if (imgbbApiKey.isEmpty) {
      throw _fail(
        'Image uploads are not configured yet.',
        'ImgBB API key is empty',
      );
    }
    final uri = Uri.parse('$_imgbbEndpoint?key=$imgbbApiKey');
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

    final streamed = await _send(request, host: 'ImgBB');
    final body = await streamed.stream.bytesToString();
    final json = _decode(body);

    if (json?['success'] == true) {
      final url = json?['data']?['url'] as String?;
      if (url != null && url.isNotEmpty) return url;
      throw _fail(
        'The image host did not return a link. Try again in a moment.',
        'ImgBB returned success without data.url',
      );
    }

    throw _imgbbFailure(
      statusCode: streamed.statusCode,
      code: json?['error']?['code'],
      hostMessage: json?['error']?['message'] as String?,
    );
  }

  /// Maps an ImgBB failure response onto something worth reading.
  static ImageUploadException _imgbbFailure({
    required int statusCode,
    Object? code,
    String? hostMessage,
  }) {
    final technical =
        'ImgBB HTTP $statusCode'
        '${code != null ? ' code $code' : ''}'
        '${hostMessage != null ? ': $hostMessage' : ''}';

    switch (code) {
      case 100:
        return _fail(
          'Image uploads are not configured correctly. The image host rejected the key.',
          technical,
        );
      case 103:
      case 104:
        return _fail(
          'The image host blocked this upload from your network. Try again in a few minutes, or paste an image link instead.',
          technical,
        );
      case 130:
        return _fail('No image data was sent. Pick the image again.', technical);
    }
    if (statusCode == 429) {
      return _fail(
        'Too many uploads right now. Wait a moment and try again.',
        technical,
      );
    }
    if (statusCode >= 500) {
      return _fail(
        'The image host is having trouble. Try again in a moment.',
        technical,
      );
    }
    return _fail(
      'The image could not be uploaded. Try again in a moment.',
      technical,
    );
  }

  // ---------------------------------------------------------------------------
  // Shared helpers
  // ---------------------------------------------------------------------------
  Future<http.StreamedResponse> _send(
    http.MultipartRequest request, {
    required String host,
  }) async {
    try {
      return await request.send().timeout(_timeout);
    } on TimeoutException {
      throw _fail(
        'The upload timed out. Check your connection and try again.',
        '$host request timed out after 45s',
      );
    } on http.ClientException catch (error) {
      throw _fail(
        'Could not reach the image host. Check your internet connection and try again.',
        '$host network failure: $error',
      );
    }
  }

  static Map<String, dynamic>? _decode(String body) {
    try {
      return jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Short, human message for any upload failure. Raw exception text is
  /// never shown to the user.
  static String friendlyMessage(Object error) => error is ImageUploadException
      ? error.message
      : 'Image upload failed. Check your connection and try again.';

  static String _mimeFromName(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.heic')) return 'image/heic';
    return 'image/jpeg';
  }

  static http.MediaType _contentType(String mime) => http.MediaType.parse(mime);
}

/// A failed upload carrying a message that is safe to show to a person.
/// [technical] is for logs only.
class ImageUploadException implements Exception {
  const ImageUploadException(this.message, {this.technical});

  final String message;
  final String? technical;

  @override
  String toString() =>
      technical == null ? message : '$message [$technical]';
}

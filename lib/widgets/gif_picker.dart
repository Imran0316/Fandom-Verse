import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../core/theme/app_colors.dart';
import '../services/image_upload_service.dart';

/// GIF picker for comment composers.
///
/// Searches Giphy using the API key below. The key can be overridden at build
/// time (preferred, keeps it out of source control):
/// `flutter run --dart-define=GIPHY_API_KEY=your_key`
/// Without a key the sheet still works — it falls back to picking a GIF
/// from the device gallery (uploaded through [ImageUploadService]).
class GifPicker {
  GifPicker._();

  /// Giphy API key. Override with `--dart-define=GIPHY_API_KEY=...`.
  static const String _apiKey = String.fromEnvironment(
    'GIPHY_API_KEY',
    defaultValue: '1N5oU5fFBo5LK3M81sI3Bhxgu3bgj40r',
  );

  static bool get hasApiKey => _apiKey.isNotEmpty;

  /// Extracts GIF image URLs from a raw Giphy API response body.
  ///
  /// Prefers the `downsized` rendition and falls back to `original`. Throws
  /// a [FormatException] if [body] is not a JSON object.
  static List<String> parseGifUrls(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Unexpected Giphy response');
    }
    final data = decoded['data'];
    if (data is! List) return const [];

    final urls = <String>[];
    for (final item in data) {
      if (item is! Map<String, dynamic>) continue;
      final images = item['images'];
      if (images is! Map<String, dynamic>) continue;
      final url = _renditionUrl(images, 'downsized') ??
          _renditionUrl(images, 'original');
      if (url != null) urls.add(url);
    }
    return urls;
  }

  static String? _renditionUrl(Map<String, dynamic> images, String key) {
    final rendition = images[key];
    if (rendition is! Map<String, dynamic>) return null;
    final url = rendition['url'];
    if (url is! String || url.isEmpty) return null;
    return url;
  }

  /// Opens the picker sheet and returns a GIF image URL, or null on cancel.
  static Future<String?> show(BuildContext context) {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF14141C),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => const _GifPickerSheet(),
    );
  }
}

class _GifPickerSheet extends StatefulWidget {
  const _GifPickerSheet();

  @override
  State<_GifPickerSheet> createState() => _GifPickerSheetState();
}

class _GifPickerSheetState extends State<_GifPickerSheet> {
  final _searchController = TextEditingController();
  final List<String> _urls = <String>[];
  bool _loading = false;
  String? _error;
  bool _pickingDevice = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    if (GifPicker.hasApiKey) {
      _load(query: null);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load({String? query}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final Map<String, String> params = {
        'api_key': GifPicker._apiKey,
        'limit': '30',
        'rating': 'g',
      };
      String path;
      if (query == null || query.trim().isEmpty) {
        path = '/v1/gifs/trending';
      } else {
        path = '/v1/gifs/search';
        params['q'] = query.trim();
      }
      final uri = Uri.https('api.giphy.com', path, params);
      final res = await http.get(uri).timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) {
        throw Exception('Giphy returned ${res.statusCode}');
      }
      final urls = GifPicker.parseGifUrls(res.body);
      if (!mounted) return;
      setState(() {
        _urls
          ..clear()
          ..addAll(urls);
        _loading = false;
        if (urls.isEmpty) _error = 'No GIFs found — try another search.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = "Couldn't load GIFs. Check your connection.";
      });
    }
  }

  Future<void> _pickFromDevice() async {
    if (_pickingDevice) return;
    setState(() => _pickingDevice = true);
    try {
      final url = await ImageUploadService.instance.pickAndUpload(
        name: 'gif',
      );
      if (!mounted) return;
      if (url != null) Navigator.of(context).pop(url);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ImageUploadService.friendlyMessage(e))),
      );
    } finally {
      if (mounted) setState(() => _pickingDevice = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 14,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(99),
                color: Colors.white.withValues(alpha: 0.2),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Choose a GIF',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (GifPicker.hasApiKey)
                TextButton.icon(
                  onPressed: _pickingDevice ? null : _pickFromDevice,
                  icon: _pickingDevice
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white70,
                          ),
                        )
                      : const Icon(Icons.photo_library_outlined, size: 18),
                  label: const Text('Upload'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white70,
                  ),
                ),
            ],
          ),
          if (GifPicker.hasApiKey) ...[
            const SizedBox(height: 10),
            TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              textInputAction: TextInputAction.search,
              onSubmitted: (v) => _load(query: v),
              decoration: InputDecoration(
                hintText: 'Search GIFs…',
                hintStyle: const TextStyle(color: Colors.white38),
                isDense: true,
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                prefixIconColor: Colors.white54,
                suffixIcon: IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  color: Colors.white54,
                  onPressed: () {
                    _searchController.clear();
                    _load(query: null);
                  },
                ),
                suffixIconColor: Colors.white54,
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.07),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (!GifPicker.hasApiKey)
            _DeviceFallback(
              onPick: _pickFromDevice,
              picking: _pickingDevice,
            )
          else if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 36),
              child: Center(
                child: CircularProgressIndicator(color: AppColors.accent),
              ),
            )
          else if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Column(
                children: [
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white60, fontSize: 13.5),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: _pickFromDevice,
                    child: const Text('Pick from device instead'),
                  ),
                ],
              ),
            )
          else
            Flexible(
              child: GridView.builder(
                shrinkWrap: true,
                physics: const BouncingScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 6,
                  crossAxisSpacing: 6,
                  childAspectRatio: 1.15,
                ),
                itemCount: _urls.length,
                itemBuilder: (context, i) => GestureDetector(
                  onTap: () => Navigator.of(context).pop(_urls[i]),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      _urls[i],
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, progress) => progress ==
                              null
                          ? child
                          : Container(
                              color: Colors.white.withValues(alpha: 0.06),
                            ),
                      errorBuilder: (_, _, _) => Container(
                        color: Colors.white.withValues(alpha: 0.06),
                        child: const Icon(
                          Icons.gif_box_outlined,
                          color: Colors.white30,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          if (GifPicker.hasApiKey) ...[
            const SizedBox(height: 10),
            const Center(
              child: Text(
                'Powered by GIPHY',
                style: TextStyle(color: Colors.white30, fontSize: 10.5),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DeviceFallback extends StatelessWidget {
  const _DeviceFallback({required this.onPick, required this.picking});

  final VoidCallback onPick;
  final bool picking;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withValues(alpha: 0.05),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          const Icon(Icons.gif_box_outlined, color: Colors.white38, size: 40),
          const SizedBox(height: 12),
          const Text(
            'GIF search is not configured',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            GifPicker.hasApiKey
                ? ''
                : 'Run with --dart-define=GIPHY_API_KEY=your_key to search '
                    'online, or pick a GIF from your device now.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white54, fontSize: 12.5),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: picking ? null : onPick,
            icon: picking
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.upload_rounded, size: 18),
            label: const Text('Pick GIF from device'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

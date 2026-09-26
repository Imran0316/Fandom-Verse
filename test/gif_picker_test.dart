import 'package:flutter_test/flutter_test.dart';

import 'package:fandom_verse/widgets/gif_picker.dart';

/// A minimal Giphy payload: one item with both renditions, one with only
/// `original`, and one with no images at all.
const String _trendingBody = '''
{
  "data": [
    {
      "id": "gif-1",
      "images": {
        "downsized": { "url": "https://media.giphy.com/downsized-1.gif" },
        "original": { "url": "https://media.giphy.com/original-1.gif" }
      }
    },
    {
      "id": "gif-2",
      "images": {
        "original": { "url": "https://media.giphy.com/original-2.gif" }
      }
    },
    { "id": "gif-3" }
  ]
}
''';

void main() {
  group('GifPicker.hasApiKey', () {
    test('is true when a key is compiled in', () {
      // Regression guard: the key used to be passed to String.fromEnvironment
      // as the *value*, so the define name resolved to null and the key was
      // always empty. That silently disabled GIF search.
      expect(GifPicker.hasApiKey, isTrue);
    });
  });

  group('GifPicker.parseGifUrls', () {
    test('prefers the downsized rendition', () {
      expect(GifPicker.parseGifUrls(_trendingBody), [
        'https://media.giphy.com/downsized-1.gif',
        'https://media.giphy.com/original-2.gif',
      ]);
    });

    test('falls back to original when downsized is missing', () {
      // Covered by gif-2 above; assert in isolation to keep intent explicit.
      const body = '''
      {
        "data": [
          {
            "images": {
              "original": { "url": "https://media.giphy.com/original.gif" }
            }
          }
        ]
      }
      ''';
      expect(GifPicker.parseGifUrls(body), [
        'https://media.giphy.com/original.gif',
      ]);
    });

    test('skips items with no images or an empty url', () {
      const body = '''
      {
        "data": [
          { "id": "a" },
          { "images": {} },
          { "images": { "downsized": { "url": "" } } },
          { "images": { "downsized": { "url": null } } },
          { "images": { "downsized": { "url": "https://x/y.gif" } } }
        ]
      }
      ''';
      expect(GifPicker.parseGifUrls(body), ['https://x/y.gif']);
    });

    test('returns an empty list for an empty data array', () {
      expect(GifPicker.parseGifUrls('{"data": []}'), isEmpty);
    });

    test('returns an empty list when data is missing', () {
      expect(GifPicker.parseGifUrls('{}'), isEmpty);
    });

    test('throws FormatException when the body is not a JSON object', () {
      expect(
        () => GifPicker.parseGifUrls('[]'),
        throwsA(isA<FormatException>()),
      );
    });
  });
}

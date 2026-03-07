import '../utils/config.dart';

class ImageUrlFixer {
  /// Path suffix for checker-uploaded images when API returns filename only.
  /// Full URL = baseUrl + this + filename (e.g. after update_order).
  static const String _checkerImagesPath =
      'LaravelProject/public/uploads/orders/checker_images/';

  static String fix(String url) {
    if (url.isEmpty) return url;

    // Already a full URL or data URI or absolute path — only fix local dev if needed
    if (url.startsWith('http') || url.startsWith('data:') || url.startsWith('/')) {
      if (url.contains('192.168.')) {
        return url
            .replaceFirst('/LaravelProject', '')
            .replaceFirst('/public', '');
      }
      return url;
    }

    // API returned filename only (e.g. update_order response) — build full URL
    final base = ApiConfig.baseUrl;
    final path = base.endsWith('/') ? _checkerImagesPath : '$_checkerImagesPath';
    final fullUrl = '$base$path$url';
    if (fullUrl.contains('192.168.')) {
      return fullUrl
          .replaceFirst('/LaravelProject', '')
          .replaceFirst('/public', '');
    }
    return fullUrl;
  }
}

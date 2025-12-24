class ImageUrlFixer {
  static String fix(String url) {
    if (url.isEmpty) return url;

    // Fix only LOCAL dev URLs (192.168.x.x)
    if (url.contains('192.168.')) {
      return url
          .replaceFirst('/LaravelProject', '')
          .replaceFirst('/public', '');
    }

    // Production untouched
    return url;
  }
}

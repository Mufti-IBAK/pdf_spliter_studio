import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';
import 'package:pdfx/pdfx.dart';

/// Thread-safe, lazy-loaded PDF page renderer with an LRU image cache.
/// Serializes native `pdfx` calls so rendering Page 245 and Page 256 side-by-side
/// never collides on the platform channel.
class PdfRenderService {
  PdfDocument? _document;
  String? _currentPath;
  int _pageCount = 0;

  final LinkedHashMap<String, Uint8List> _cache = LinkedHashMap();
  static const int _maxCacheEntries = 60;

  Future<void> _renderLock = Future.value();

  int get pageCount => _pageCount;
  String? get currentPath => _currentPath;
  bool get isLoaded => _document != null;

  /// Opens a PDF file from disk and returns its total page count.
  Future<int> openDocument(String filePath) async {
    if (_currentPath == filePath && _document != null) {
      return _pageCount;
    }
    await closeDocument();
    final doc = await PdfDocument.openFile(filePath);
    _document = doc;
    _currentPath = filePath;
    _pageCount = doc.pagesCount;
    return _pageCount;
  }

  /// Renders a 1-based [pageNumber] into a PNG byte array.
  /// Uses an LRU cache and serializes native page rendering calls.
  Future<Uint8List?> renderPage(
    int pageNumber, {
    bool highRes = false,
  }) async {
    final doc = _document;
    if (doc == null || pageNumber < 1 || pageNumber > _pageCount) {
      return null;
    }

    final key = '${_currentPath}_${pageNumber}_${highRes ? "hd" : "thumb"}';
    final cached = _cache.remove(key);
    if (cached != null) {
      // Re-insert as most recently used
      _cache[key] = cached;
      return cached;
    }

    final completer = Completer<Uint8List?>();
    final previousLock = _renderLock;
    _renderLock = completer.future.then((_) {}).catchError((_) {});

    await previousLock;

    try {
      if (_document == null) {
        completer.complete(null);
        return null;
      }
      final page = await _document!.getPage(pageNumber);
      try {
        final targetWidth = highRes ? page.width * 2.2 : page.width * 0.85;
        final targetHeight = highRes ? page.height * 2.2 : page.height * 0.85;
        final pageImage = await page.render(
          width: targetWidth.clamp(240.0, 1800.0),
          height: targetHeight.clamp(320.0, 2400.0),
          format: PdfPageImageFormat.png,
          backgroundColor: '#FFFFFF',
        );
        final bytes = pageImage?.bytes;
        if (bytes != null) {
          _putInCache(key, bytes);
        }
        completer.complete(bytes);
        return bytes;
      } finally {
        await page.close();
      }
    } catch (_) {
      completer.complete(null);
      return null;
    }
  }

  void _putInCache(String key, Uint8List bytes) {
    if (_cache.length >= _maxCacheEntries) {
      _cache.remove(_cache.keys.first);
    }
    _cache[key] = bytes;
  }

  Future<void> closeDocument() async {
    _cache.clear();
    final doc = _document;
    _document = null;
    _currentPath = null;
    _pageCount = 0;
    if (doc != null) {
      try {
        await doc.close();
      } catch (_) {}
    }
  }
}

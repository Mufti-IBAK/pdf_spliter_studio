import 'package:flutter/material.dart';

/// Represents a single page-range selection (e.g., Page 245 to Page 256)
/// with support for excluding individual pages inside the range or rotating pages.
class SplitRange {
  final String id;
  final int startPage;
  final int endPage;
  final String customTitle;
  final int colorIndex;
  final Set<int> excludedPages;
  final Map<int, int> pageRotations; // pageNumber -> degrees (0, 90, 180, 270)

  const SplitRange({
    required this.id,
    required this.startPage,
    required this.endPage,
    required this.customTitle,
    this.colorIndex = 0,
    this.excludedPages = const {},
    this.pageRotations = const {},
  });

  /// Palette of modern accent colors for multi-range tags
  static const List<Color> palette = [
    Color(0xFF4F46E5), // Indigo
    Color(0xFF0D9488), // Teal
    Color(0xFFD97706), // Amber
    Color(0xFFE11D48), // Rose
    Color(0xFF7C3AED), // Violet
    Color(0xFF2563EB), // Blue
  ];

  Color get accentColor => palette[colorIndex % palette.length];

  /// Ordered list of 1-based page numbers that will be exported for this range.
  List<int> get includedPages {
    final lo = startPage <= endPage ? startPage : endPage;
    final hi = startPage <= endPage ? endPage : startPage;
    final pages = <int>[];
    for (int p = lo; p <= hi; p++) {
      if (!excludedPages.contains(p)) {
        pages.add(p);
      }
    }
    return pages;
  }

  /// Total span before exclusions.
  int get totalSpanCount => (endPage - startPage).abs() + 1;

  /// Active page count after exclusions.
  int get activePageCount => includedPages.length;

  /// Human-readable range label (e.g. "Pages 245–256" or "Page 245").
  String get rangeLabel =>
      startPage == endPage ? 'Page $startPage' : 'Pages $startPage–$endPage';

  /// Suggested safe filename without `.pdf` extension.
  String suggestedFileName(String basePdfName) {
    final cleanBase = basePdfName
        .replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '')
        .replaceAll(RegExp(r'[^\w\-]+'), '_');
    if (customTitle.trim().isNotEmpty) {
      final cleanCustom =
          customTitle.trim().replaceAll(RegExp(r'[^\w\- ]+'), '').trim();
      if (cleanCustom.isNotEmpty) {
        return '${cleanCustom.replaceAll(' ', '_')}_p$startPage-$endPage';
      }
    }
    return '${cleanBase}_p$startPage-$endPage';
  }

  SplitRange copyWith({
    String? id,
    int? startPage,
    int? endPage,
    String? customTitle,
    int? colorIndex,
    Set<int>? excludedPages,
    Map<int, int>? pageRotations,
  }) {
    return SplitRange(
      id: id ?? this.id,
      startPage: startPage ?? this.startPage,
      endPage: endPage ?? this.endPage,
      customTitle: customTitle ?? this.customTitle,
      colorIndex: colorIndex ?? this.colorIndex,
      excludedPages: excludedPages ?? this.excludedPages,
      pageRotations: pageRotations ?? this.pageRotations,
    );
  }
}

/// Controls how multiple ranges in the queue are exported.
enum MultiRangeExportMode {
  /// Each range is saved as its own separate `.pdf` file.
  separateFiles,

  /// All active ranges are combined in order into one single `.pdf` file.
  mergeIntoSinglePdf,
}

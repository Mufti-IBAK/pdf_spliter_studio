import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../models/saved_split_file.dart';
import '../models/split_range.dart';
import 'storage_service.dart';

/// Handles lossless PDF page extraction, multi-range splitting/merging,
/// and generating a 300-page test PDF for instant demonstration.
class PdfSplitService {
  final StorageService _storageService;

  PdfSplitService(this._storageService);

  /// Executes the split operation for one or more [ranges] from [sourceFilePath].
  /// Supports both [MultiRangeExportMode.separateFiles] and
  /// [MultiRangeExportMode.mergeIntoSinglePdf].
  Future<List<SavedSplitFile>> splitPdf({
    required String sourceFilePath,
    required String sourceFileName,
    required List<SplitRange> ranges,
    required MultiRangeExportMode exportMode,
    String? customMergedFileName,
  }) async {
    final sourceBytes = await File(sourceFilePath).readAsBytes();
    final sourceDoc = PdfDocument(inputBytes: sourceBytes);
    final totalSourcePages = sourceDoc.pages.count;

    final results = <SavedSplitFile>[];

    try {
      if (exportMode == MultiRangeExportMode.mergeIntoSinglePdf &&
          ranges.length > 1) {
        final outDoc = PdfDocument();
        outDoc.pageSettings.margins.all = 0;

        int totalCopied = 0;
        final rangeLabels = <String>[];

        for (final range in ranges) {
          final pages = range.includedPages;
          if (pages.isEmpty) continue;
          rangeLabels.add('p.${range.startPage}–${range.endPage}');

          for (final pageNum in pages) {
            if (pageNum < 1 || pageNum > totalSourcePages) continue;
            _copyPageWithRotation(
              sourceDoc: sourceDoc,
              targetDoc: outDoc,
              oneBasedPageIndex: pageNum,
              extraRotationDegrees: range.pageRotations[pageNum] ?? 0,
            );
            totalCopied++;
          }
        }

        final outBytes = Uint8List.fromList(await outDoc.save());
        outDoc.dispose();

        final cleanBase = sourceFileName
            .replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '')
            .replaceAll(RegExp(r'[^\w\-]+'), '_');
        final baseFileName = (customMergedFileName != null &&
                customMergedFileName.trim().isNotEmpty)
            ? customMergedFileName.trim()
            : '${cleanBase}_merged_${ranges.length}_ranges';

        final saved = await _storageService.savePdfBytes(
          bytes: outBytes,
          desiredFileName: baseFileName,
          sourceFileName: sourceFileName,
          rangeSummary: rangeLabels.join(' + '),
          pageCount: totalCopied,
          isMergedOutput: true,
        );
        results.add(saved);
      } else {
        // Export each SplitRange as its own standalone .pdf file
        for (final range in ranges) {
          final pages = range.includedPages;
          if (pages.isEmpty) continue;

          final outDoc = PdfDocument();
          outDoc.pageSettings.margins.all = 0;

          int copiedCount = 0;
          for (final pageNum in pages) {
            if (pageNum < 1 || pageNum > totalSourcePages) continue;
            _copyPageWithRotation(
              sourceDoc: sourceDoc,
              targetDoc: outDoc,
              oneBasedPageIndex: pageNum,
              extraRotationDegrees: range.pageRotations[pageNum] ?? 0,
            );
            copiedCount++;
          }

          final outBytes = Uint8List.fromList(await outDoc.save());
          outDoc.dispose();

          final baseName = range.suggestedFileName(sourceFileName);
          final exclusionNote = range.excludedPages.isNotEmpty
              ? ' (-${range.excludedPages.length} excl)'
              : '';

          final saved = await _storageService.savePdfBytes(
            bytes: outBytes,
            desiredFileName: baseName,
            sourceFileName: sourceFileName,
            rangeSummary: '${range.rangeLabel}$exclusionNote',
            pageCount: copiedCount,
            isMergedOutput: false,
          );
          results.add(saved);
        }
      }
    } finally {
      sourceDoc.dispose();
    }

    return results;
  }

  /// Copies a single 1-based page from [sourceDoc] into [targetDoc] using a
  /// lossless PDF template and applies any requested rotation.
  void _copyPageWithRotation({
    required PdfDocument sourceDoc,
    required PdfDocument targetDoc,
    required int oneBasedPageIndex,
    required int extraRotationDegrees,
  }) {
    final srcPage = sourceDoc.pages[oneBasedPageIndex - 1];
    final template = srcPage.createTemplate();

    final section = targetDoc.sections!.add();
    section.pageSettings.margins.all = 0;
    section.pageSettings.size = srcPage.size;
    section.pageSettings.orientation =
        srcPage.size.width > srcPage.size.height
            ? PdfPageOrientation.landscape
            : PdfPageOrientation.portrait;

    // Combine original page rotation with user-requested rotation
    final currentDeg = _angleToDegrees(srcPage.rotation);
    final totalDeg = (currentDeg + extraRotationDegrees) % 360;
    section.pageSettings.rotate = _degreesToAngle(totalDeg);

    final dstPage = section.pages.add();
    dstPage.graphics.drawPdfTemplate(
      template,
      Offset.zero,
      template.size,
    );
  }

  int _angleToDegrees(PdfPageRotateAngle angle) {
    switch (angle) {
      case PdfPageRotateAngle.rotateAngle90:
        return 90;
      case PdfPageRotateAngle.rotateAngle180:
        return 180;
      case PdfPageRotateAngle.rotateAngle270:
        return 270;
      case PdfPageRotateAngle.rotateAngle0:
        return 0;
    }
  }

  PdfPageRotateAngle _degreesToAngle(int degrees) {
    switch (degrees % 360) {
      case 90:
        return PdfPageRotateAngle.rotateAngle90;
      case 180:
        return PdfPageRotateAngle.rotateAngle180;
      case 270:
        return PdfPageRotateAngle.rotateAngle270;
      default:
        return PdfPageRotateAngle.rotateAngle0;
    }
  }

  /// Generates a realistic 300-page Sample PDF with clear page numbers,
  /// chapter banners, and visual landmarks so the user can test selecting
  /// pages 245 to 256 right away.
  Future<File> generateSample300PagePdf({int totalPages = 300}) async {
    final dir = await getTemporaryDirectory();
    final outFile = File('${dir.path}/Sample_300_Page_Handbook.pdf');
    if (await outFile.exists()) {
      return outFile;
    }

    final doc = PdfDocument();
    doc.pageSettings.margins.all = 32;

    final titleFont = PdfStandardFont(
      PdfFontFamily.helvetica,
      22,
      style: PdfFontStyle.bold,
    );
    final bigPageFont = PdfStandardFont(
      PdfFontFamily.helvetica,
      44,
      style: PdfFontStyle.bold,
    );
    final subtitleFont = PdfStandardFont(
      PdfFontFamily.helvetica,
      13,
      style: PdfFontStyle.bold,
    );
    final bodyFont = PdfStandardFont(PdfFontFamily.helvetica, 11);

    final accentBrush = PdfSolidBrush(PdfColor(79, 70, 229));
    final tealBrush = PdfSolidBrush(PdfColor(13, 148, 136));
    final darkBrush = PdfSolidBrush(PdfColor(15, 23, 42));
    final mutedBrush = PdfSolidBrush(PdfColor(100, 116, 139));
    final cardBgBrush = PdfSolidBrush(PdfColor(241, 245, 249));
    final highlightBrush = PdfSolidBrush(PdfColor(238, 242, 255));
    final borderPen = PdfPen(PdfColor(203, 213, 225), width: 1);

    for (int i = 1; i <= totalPages; i++) {
      final page = doc.pages.add();
      final g = page.graphics;
      final size = page.getClientSize();

      final chapter = ((i - 1) ~/ 20) + 1;
      final isHighlightedDemoRange = i >= 245 && i <= 256;

      // Top header banner
      g.drawRectangle(
        brush: isHighlightedDemoRange ? tealBrush : accentBrush,
        bounds: Rect.fromLTWH(0, 0, size.width, 54),
      );
      g.drawString(
        'SLICEPDF STUDIO • ENGINEERING HANDBOOK',
        subtitleFont,
        brush: PdfBrushes.white,
        bounds: const Rect.fromLTWH(16, 10, 420, 20),
      );
      g.drawString(
        'Chapter $chapter  |  Section $chapter.${((i - 1) % 20) + 1}',
        bodyFont,
        brush: PdfBrushes.white,
        bounds: const Rect.fromLTWH(16, 29, 420, 18),
      );

      // Center large page verification badge
      g.drawRectangle(
        brush: isHighlightedDemoRange ? highlightBrush : cardBgBrush,
        pen: borderPen,
        bounds: Rect.fromLTWH(0, 74, size.width, 130),
      );
      g.drawString(
        'PAGE $i OF $totalPages',
        bigPageFont,
        brush: darkBrush,
        bounds: Rect.fromLTWH(20, 94, size.width - 40, 56),
      );
      g.drawString(
        isHighlightedDemoRange
            ? '★ Target Demo Range (Pages 245 – 256) • Verify boundary & content'
            : 'Standard Document Page • Ready for instant range extraction',
        subtitleFont,
        brush: isHighlightedDemoRange ? tealBrush : mutedBrush,
        bounds: Rect.fromLTWH(20, 156, size.width - 40, 28),
      );

      // Body text blocks
      g.drawString(
        'Document Reference #DOC-2026-${i.toString().padLeft(4, '0')}',
        titleFont,
        brush: darkBrush,
        bounds: Rect.fromLTWH(0, 228, size.width, 30),
      );
      g.drawString(
        'This is page $i of the $totalPages-page sample PDF generated inside SlicePDF Studio.\n\n'
        'Use the Start Page and End Page controls (for example, Start = 245 and End = 256) '
        'to preview the exact starting and ending pages side-by-side, inspect every page '
        'in the filmstrip, and export or download the extracted PDF directly to your device.',
        bodyFont,
        brush: darkBrush,
        bounds: Rect.fromLTWH(0, 268, size.width, 140),
      );

      // Footer
      g.drawLine(
        borderPen,
        Offset(0, size.height - 32),
        Offset(size.width, size.height - 32),
      );
      g.drawString(
        'SlicePDF Studio Verification Document',
        bodyFont,
        brush: mutedBrush,
        bounds: Rect.fromLTWH(0, size.height - 22, 280, 20),
      );
      g.drawString(
        'Page $i / $totalPages',
        subtitleFont,
        brush: darkBrush,
        bounds: Rect.fromLTWH(size.width - 110, size.height - 22, 110, 20),
      );
    }

    final bytes = await doc.save();
    doc.dispose();
    await outFile.writeAsBytes(bytes, flush: true);
    return outFile;
  }
}

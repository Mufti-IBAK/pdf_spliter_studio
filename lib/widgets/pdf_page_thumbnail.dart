import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../services/pdf_render_service.dart';
import '../theme/app_theme.dart';

/// Displays a live rendered thumbnail of a specific 1-based PDF page
/// with support for rotation preview, badges, and full-screen zoom trigger.
class PdfPageThumbnail extends StatefulWidget {
  final PdfRenderService renderService;
  final int pageNumber;
  final int rotationDegrees;
  final bool isExcluded;
  final String? badgeText;
  final Color? badgeColor;
  final VoidCallback? onTap;
  final bool highRes;

  const PdfPageThumbnail({
    super.key,
    required this.renderService,
    required this.pageNumber,
    this.rotationDegrees = 0,
    this.isExcluded = false,
    this.badgeText,
    this.badgeColor,
    this.onTap,
    this.highRes = false,
  });

  @override
  State<PdfPageThumbnail> createState() => _PdfPageThumbnailState();
}

class _PdfPageThumbnailState extends State<PdfPageThumbnail> {
  Uint8List? _imageBytes;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPage();
  }

  @override
  void didUpdateWidget(covariant PdfPageThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pageNumber != widget.pageNumber ||
        oldWidget.highRes != widget.highRes ||
        oldWidget.renderService.currentPath !=
            widget.renderService.currentPath) {
      _loadPage();
    }
  }

  Future<void> _loadPage() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
    });
    final bytes = await widget.renderService.renderPage(
      widget.pageNumber,
      highRes: widget.highRes,
    );
    if (!mounted) return;
    setState(() {
      _imageBytes = bytes;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final badgeBg = widget.badgeColor ?? AppTheme.primary;

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: widget.isExcluded
                ? AppTheme.danger.withValues(alpha: 0.45)
                : AppTheme.borderSubtle,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Rendered PDF Page Content
            if (_loading)
              const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else if (_imageBytes != null)
              Opacity(
                opacity: widget.isExcluded ? 0.35 : 1.0,
                child: Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Transform.rotate(
                    angle: (widget.rotationDegrees % 360) * math.pi / 180,
                    child: Image.memory(
                      _imageBytes!,
                      fit: BoxFit.contain,
                      gaplessPlayback: true,
                    ),
                  ),
                ),
              )
            else
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.description_outlined,
                      size: 24,
                      color: AppTheme.textMuted,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'p. ${widget.pageNumber}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

            // Top-left role badge (e.g. START / END)
            if (widget.badgeText != null)
              Positioned(
                top: 6,
                left: 6,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    widget.badgeText!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),

            // Top-right zoom hint icon
            if (widget.onTap != null)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  padding: const EdgeInsets.all(3.5),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(
                    Icons.zoom_in_rounded,
                    size: 13,
                    color: Colors.white,
                  ),
                ),
              ),

            // Excluded overlay badge
            if (widget.isExcluded)
              Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.danger,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'SKIPPED',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),

            // Bottom page number pill
            Positioned(
              bottom: 6,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.textPrimary.withValues(alpha: 0.78),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    'Page ${widget.pageNumber}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

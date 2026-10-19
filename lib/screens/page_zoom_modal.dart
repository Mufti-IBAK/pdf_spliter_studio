import 'package:flutter/material.dart';
import '../services/pdf_render_service.dart';
import '../theme/app_theme.dart';
import '../widgets/pdf_page_thumbnail.dart';

/// Full-screen high-resolution page verifier with pinch-to-zoom,
/// page-to-page navigation, and one-tap "Use as Start" / "Use as End" buttons.
class PageZoomModal extends StatefulWidget {
  final PdfRenderService renderService;
  final int initialPage;
  final int totalPages;
  final int currentStartPage;
  final int currentEndPage;
  final ValueChanged<int>? onSetAsStart;
  final ValueChanged<int>? onSetAsEnd;

  const PageZoomModal({
    super.key,
    required this.renderService,
    required this.initialPage,
    required this.totalPages,
    required this.currentStartPage,
    required this.currentEndPage,
    this.onSetAsStart,
    this.onSetAsEnd,
  });

  @override
  State<PageZoomModal> createState() => _PageZoomModalState();
}

class _PageZoomModalState extends State<PageZoomModal> {
  late int _currentPage;
  final TransformationController _transformController =
      TransformationController();

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialPage.clamp(1, widget.totalPages);
  }

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  void _goToPage(int page) {
    final target = page.clamp(1, widget.totalPages);
    if (target == _currentPage) return;
    _transformController.value = Matrix4.identity();
    setState(() {
      _currentPage = target;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isStart = _currentPage == widget.currentStartPage;
    final isEnd = _currentPage == widget.currentEndPage;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Page $_currentPage of ${widget.totalPages}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Text(
              'Pinch to zoom & verify page content',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 11,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Previous Page',
            onPressed:
                _currentPage > 1 ? () => _goToPage(_currentPage - 1) : null,
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          IconButton(
            tooltip: 'Next Page',
            onPressed: _currentPage < widget.totalPages
                ? () => _goToPage(_currentPage + 1)
                : null,
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: InteractiveViewer(
              transformationController: _transformController,
              minScale: 1.0,
              maxScale: 4.5,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: AspectRatio(
                    aspectRatio: 0.72,
                    child: PdfPageThumbnail(
                      renderService: widget.renderService,
                      pageNumber: _currentPage,
                      highRes: true,
                      badgeText: isStart
                          ? 'CURRENT START'
                          : isEnd
                              ? 'CURRENT END'
                              : null,
                      badgeColor:
                          isStart ? AppTheme.primary : AppTheme.secondary,
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Bottom verification action bar
          if (widget.onSetAsStart != null || widget.onSetAsEnd != null)
            SafeArea(
              top: false,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: const BoxDecoration(
                  color: Color(0xFF1E293B),
                  border: Border(
                    top: BorderSide(color: Color(0xFF334155)),
                  ),
                ),
                child: Row(
                  children: [
                    if (widget.onSetAsStart != null)
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: BorderSide(
                              color: isStart
                                  ? AppTheme.primary
                                  : const Color(0xFF475569),
                            ),
                            backgroundColor: isStart
                                ? AppTheme.primary.withValues(alpha: 0.25)
                                : null,
                          ),
                          onPressed: () {
                            widget.onSetAsStart!(_currentPage);
                            Navigator.of(context).pop();
                          },
                          icon: const Icon(
                            Icons.first_page_rounded,
                            size: 16,
                          ),
                          label: Text('Set Start = $_currentPage'),
                        ),
                      ),
                    if (widget.onSetAsStart != null &&
                        widget.onSetAsEnd != null)
                      const SizedBox(width: 10),
                    if (widget.onSetAsEnd != null)
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: BorderSide(
                              color: isEnd
                                  ? AppTheme.secondary
                                  : const Color(0xFF475569),
                            ),
                            backgroundColor: isEnd
                                ? AppTheme.secondary.withValues(alpha: 0.25)
                                : null,
                          ),
                          onPressed: () {
                            widget.onSetAsEnd!(_currentPage);
                            Navigator.of(context).pop();
                          },
                          icon: const Icon(
                            Icons.last_page_rounded,
                            size: 16,
                          ),
                          label: Text('Set End = $_currentPage'),
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

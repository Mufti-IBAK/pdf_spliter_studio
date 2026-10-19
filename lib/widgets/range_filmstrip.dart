import 'package:flutter/material.dart';
import '../models/split_range.dart';
import '../services/pdf_render_service.dart';
import '../theme/app_theme.dart';
import 'pdf_page_thumbnail.dart';

/// Displays all pages inside the selected [SplitRange] (e.g., pages 245..256)
/// so the user can visually scroll through every page that will be included,
/// zoom any page, rotate sideways pages, or toggle individual pages on/off.
class RangeFilmstrip extends StatefulWidget {
  final PdfRenderService renderService;
  final SplitRange range;
  final ValueChanged<int> onInspectPage;
  final ValueChanged<int> onToggleExcludePage;
  final ValueChanged<int> onRotatePage;

  const RangeFilmstrip({
    super.key,
    required this.renderService,
    required this.range,
    required this.onInspectPage,
    required this.onToggleExcludePage,
    required this.onRotatePage,
  });

  @override
  State<RangeFilmstrip> createState() => _RangeFilmstripState();
}

class _RangeFilmstripState extends State<RangeFilmstrip> {
  bool _gridMode = false;

  @override
  Widget build(BuildContext context) {
    final lo = widget.range.startPage <= widget.range.endPage
        ? widget.range.startPage
        : widget.range.endPage;
    final hi = widget.range.startPage <= widget.range.endPage
        ? widget.range.endPage
        : widget.range.startPage;
    final spanCount = hi - lo + 1;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row with Filmstrip / Grid toggle
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppTheme.secondary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.view_carousel_outlined,
                    size: 16,
                    color: AppTheme.secondary,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pages in Selected Range ($lo–$hi)',
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        '${widget.range.activePageCount} of $spanCount pages included • Tap to zoom, rotate, or skip',
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: _gridMode ? 'Switch to Filmstrip' : 'Switch to Grid',
                  onPressed: () => setState(() => _gridMode = !_gridMode),
                  icon: Icon(
                    _gridMode
                        ? Icons.view_carousel_rounded
                        : Icons.grid_view_rounded,
                    size: 18,
                    color: AppTheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (!_gridMode)
              SizedBox(
                height: 188,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: spanCount,
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    final pageNum = lo + index;
                    return SizedBox(
                      width: 116,
                      child: _RangePageTile(
                        renderService: widget.renderService,
                        pageNumber: pageNum,
                        isStart: pageNum == lo,
                        isEnd: pageNum == hi && hi != lo,
                        isExcluded:
                            widget.range.excludedPages.contains(pageNum),
                        rotationDegrees:
                            widget.range.pageRotations[pageNum] ?? 0,
                        accentColor: widget.range.accentColor,
                        onTap: () => widget.onInspectPage(pageNum),
                        onToggleExclude: () =>
                            widget.onToggleExcludePage(pageNum),
                        onRotate: () => widget.onRotatePage(pageNum),
                      ),
                    );
                  },
                ),
              )
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  // Limit grid preview to 36 pages at once so 300-page full-range doesn't lag
                  final displayCount = spanCount > 36 ? 36 : spanCount;
                  final crossAxisCount = constraints.maxWidth > 640
                      ? 5
                      : constraints.maxWidth > 420
                          ? 3
                          : 2;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: displayCount,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio: 0.65,
                        ),
                        itemBuilder: (context, index) {
                          final pageNum = lo + index;
                          return _RangePageTile(
                            renderService: widget.renderService,
                            pageNumber: pageNum,
                            isStart: pageNum == lo,
                            isEnd: pageNum == hi && hi != lo,
                            isExcluded:
                                widget.range.excludedPages.contains(pageNum),
                            rotationDegrees:
                                widget.range.pageRotations[pageNum] ?? 0,
                            accentColor: widget.range.accentColor,
                            onTap: () => widget.onInspectPage(pageNum),
                            onToggleExclude: () =>
                                widget.onToggleExcludePage(pageNum),
                            onRotate: () => widget.onRotatePage(pageNum),
                          );
                        },
                      ),
                      if (spanCount > displayCount)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            'Showing first $displayCount of $spanCount pages in Grid mode. Switch to Filmstrip to scroll all $spanCount pages.',
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _RangePageTile extends StatelessWidget {
  final PdfRenderService renderService;
  final int pageNumber;
  final bool isStart;
  final bool isEnd;
  final bool isExcluded;
  final int rotationDegrees;
  final Color accentColor;
  final VoidCallback onTap;
  final VoidCallback onToggleExclude;
  final VoidCallback onRotate;

  const _RangePageTile({
    required this.renderService,
    required this.pageNumber,
    required this.isStart,
    required this.isEnd,
    required this.isExcluded,
    required this.rotationDegrees,
    required this.accentColor,
    required this.onTap,
    required this.onToggleExclude,
    required this.onRotate,
  });

  @override
  Widget build(BuildContext context) {
    String? badge;
    Color? badgeColor;
    if (isStart) {
      badge = 'START';
      badgeColor = accentColor;
    } else if (isEnd) {
      badge = 'END';
      badgeColor = AppTheme.secondary;
    }

    return Column(
      children: [
        Expanded(
          child: PdfPageThumbnail(
            renderService: renderService,
            pageNumber: pageNumber,
            rotationDegrees: rotationDegrees,
            isExcluded: isExcluded,
            badgeText: badge,
            badgeColor: badgeColor,
            onTap: onTap,
          ),
        ),
        const SizedBox(height: 5),
        // Compact action bar under each page
        Container(
          height: 26,
          decoration: BoxDecoration(
            color: AppTheme.surfaceBg,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: AppTheme.borderSubtle),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              InkWell(
                onTap: onRotate,
                borderRadius: BorderRadius.circular(5),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Icon(
                    Icons.rotate_right_rounded,
                    size: 14,
                    color: rotationDegrees > 0
                        ? AppTheme.primary
                        : AppTheme.textSecondary,
                  ),
                ),
              ),
              Container(width: 1, height: 14, color: AppTheme.borderSubtle),
              InkWell(
                onTap: onToggleExclude,
                borderRadius: BorderRadius.circular(5),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Icon(
                    isExcluded
                        ? Icons.add_circle_outline_rounded
                        : Icons.remove_circle_outline_rounded,
                    size: 14,
                    color: isExcluded ? AppTheme.success : AppTheme.danger,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

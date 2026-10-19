import 'package:flutter/material.dart';
import '../models/split_range.dart';
import '../services/pdf_render_service.dart';
import '../theme/app_theme.dart';
import 'pdf_page_thumbnail.dart';

/// Side-by-side live verification preview of the selected Start Page and End Page
/// (e.g., Page 245 and Page 256 of 300) so the user can visually confirm they
/// picked the exact boundary pages before splitting.
class BookendPreviewCard extends StatelessWidget {
  final PdfRenderService renderService;
  final SplitRange range;
  final int totalPages;
  final ValueChanged<int> onStartChanged;
  final ValueChanged<int> onEndChanged;
  final ValueChanged<int> onInspectPage;

  const BookendPreviewCard({
    super.key,
    required this.renderService,
    required this.range,
    required this.totalPages,
    required this.onStartChanged,
    required this.onEndChanged,
    required this.onInspectPage,
  });

  @override
  Widget build(BuildContext context) {
    final startPage = range.startPage;
    final endPage = range.endPage;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: range.accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.compare_rounded,
                    size: 16,
                    color: range.accentColor,
                  ),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Boundary Page Verification',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        'Tap either page to zoom in & verify text before splitting',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primarySoft,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    '${range.activePageCount} ${range.activePageCount == 1 ? "page" : "pages"}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Side-by-side Start Page & End Page cards
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _BoundaryColumn(
                    roleLabel: 'START PAGE',
                    pageNumber: startPage,
                    totalPages: totalPages,
                    badgeColor: range.accentColor,
                    renderService: renderService,
                    rotationDegrees: range.pageRotations[startPage] ?? 0,
                    canDecrement: startPage > 1,
                    canIncrement: startPage < endPage,
                    onDecrement: () => onStartChanged(startPage - 1),
                    onIncrement: () => onStartChanged(startPage + 1),
                    onTapPreview: () => onInspectPage(startPage),
                  ),
                ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 70),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 16,
                        color: range.accentColor,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'to',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: range.accentColor,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _BoundaryColumn(
                    roleLabel: 'END PAGE',
                    pageNumber: endPage,
                    totalPages: totalPages,
                    badgeColor: AppTheme.secondary,
                    renderService: renderService,
                    rotationDegrees: range.pageRotations[endPage] ?? 0,
                    canDecrement: endPage > startPage,
                    canIncrement: endPage < totalPages,
                    onDecrement: () => onEndChanged(endPage - 1),
                    onIncrement: () => onEndChanged(endPage + 1),
                    onTapPreview: () => onInspectPage(endPage),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BoundaryColumn extends StatelessWidget {
  final String roleLabel;
  final int pageNumber;
  final int totalPages;
  final Color badgeColor;
  final PdfRenderService renderService;
  final int rotationDegrees;
  final bool canDecrement;
  final bool canIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;
  final VoidCallback onTapPreview;

  const _BoundaryColumn({
    required this.roleLabel,
    required this.pageNumber,
    required this.totalPages,
    required this.badgeColor,
    required this.renderService,
    required this.rotationDegrees,
    required this.canDecrement,
    required this.canIncrement,
    required this.onDecrement,
    required this.onIncrement,
    required this.onTapPreview,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AspectRatio(
          aspectRatio: 0.74,
          child: PdfPageThumbnail(
            renderService: renderService,
            pageNumber: pageNumber,
            rotationDegrees: rotationDegrees,
            badgeText: roleLabel,
            badgeColor: badgeColor,
            onTap: onTapPreview,
          ),
        ),
        const SizedBox(height: 8),
        // Compact nudge bar (-1 / Page X / +1)
        Container(
          height: 32,
          decoration: BoxDecoration(
            color: AppTheme.surfaceBg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.borderSubtle),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _MiniNudgeButton(
                icon: Icons.remove_rounded,
                enabled: canDecrement,
                tooltip: 'Previous page',
                onTap: onDecrement,
              ),
              Flexible(
                child: GestureDetector(
                  onTap: onTapPreview,
                  child: Text(
                    'p. $pageNumber / $totalPages',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
              ),
              _MiniNudgeButton(
                icon: Icons.add_rounded,
                enabled: canIncrement,
                tooltip: 'Next page',
                onTap: onIncrement,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MiniNudgeButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final String tooltip;
  final VoidCallback onTap;

  const _MiniNudgeButton({
    required this.icon,
    required this.enabled,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(7),
      onTap: enabled ? onTap : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
        child: Icon(
          icon,
          size: 15,
          color: enabled ? AppTheme.textPrimary : AppTheme.textMuted,
        ),
      ),
    );
  }
}

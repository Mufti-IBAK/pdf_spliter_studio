import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/split_range.dart';
import '../theme/app_theme.dart';

/// Clean, responsive card for typing or scrubbing the exact Start Page and
/// End Page (e.g., 245 to 256 of 300), naming the split, and applying quick presets.
class RangeSelectorCard extends StatefulWidget {
  final SplitRange range;
  final int totalPages;
  final ValueChanged<int> onStartChanged;
  final ValueChanged<int> onEndChanged;
  final ValueChanged<String> onTitleChanged;

  const RangeSelectorCard({
    super.key,
    required this.range,
    required this.totalPages,
    required this.onStartChanged,
    required this.onEndChanged,
    required this.onTitleChanged,
  });

  @override
  State<RangeSelectorCard> createState() => _RangeSelectorCardState();
}

class _RangeSelectorCardState extends State<RangeSelectorCard> {
  late TextEditingController _startController;
  late TextEditingController _endController;
  late TextEditingController _titleController;
  final FocusNode _startFocus = FocusNode();
  final FocusNode _endFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _startController =
        TextEditingController(text: widget.range.startPage.toString());
    _endController =
        TextEditingController(text: widget.range.endPage.toString());
    _titleController = TextEditingController(text: widget.range.customTitle);

    _startFocus.addListener(() {
      if (!_startFocus.hasFocus) _commitStartText();
    });
    _endFocus.addListener(() {
      if (!_endFocus.hasFocus) _commitEndText();
    });
  }

  @override
  void didUpdateWidget(covariant RangeSelectorCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_startFocus.hasFocus &&
        _startController.text != widget.range.startPage.toString()) {
      _startController.text = widget.range.startPage.toString();
    }
    if (!_endFocus.hasFocus &&
        _endController.text != widget.range.endPage.toString()) {
      _endController.text = widget.range.endPage.toString();
    }
    if (oldWidget.range.id != widget.range.id &&
        _titleController.text != widget.range.customTitle) {
      _titleController.text = widget.range.customTitle;
    }
  }

  @override
  void dispose() {
    _startController.dispose();
    _endController.dispose();
    _titleController.dispose();
    _startFocus.dispose();
    _endFocus.dispose();
    super.dispose();
  }

  void _commitStartText() {
    final parsed = int.tryParse(_startController.text.trim());
    if (parsed == null) {
      _startController.text = widget.range.startPage.toString();
      return;
    }
    final clamped = parsed.clamp(1, widget.totalPages);
    _startController.text = clamped.toString();
    widget.onStartChanged(clamped);
  }

  void _commitEndText() {
    final parsed = int.tryParse(_endController.text.trim());
    if (parsed == null) {
      _endController.text = widget.range.endPage.toString();
      return;
    }
    final clamped = parsed.clamp(1, widget.totalPages);
    _endController.text = clamped.toString();
    widget.onEndChanged(clamped);
  }

  @override
  Widget build(BuildContext context) {
    final maxPages = widget.totalPages < 1 ? 1 : widget.totalPages;
    final startVal = widget.range.startPage.clamp(1, maxPages).toDouble();
    final endVal = widget.range.endPage.clamp(startVal.toInt(), maxPages).toDouble();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Card Header
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: widget.range.accentColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Select Page Range to Extract',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                Text(
                  'Total: $maxPages pages',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Start Page and End Page input boxes side by side
            Row(
              children: [
                Expanded(
                  child: _PageNumberField(
                    label: 'Start Page',
                    controller: _startController,
                    focusNode: _startFocus,
                    maxPages: maxPages,
                    accentColor: widget.range.accentColor,
                    onSubmitted: (_) => _commitStartText(),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Icon(
                    Icons.trending_flat_rounded,
                    size: 18,
                    color: AppTheme.textMuted,
                  ),
                ),
                Expanded(
                  child: _PageNumberField(
                    label: 'End Page',
                    controller: _endController,
                    focusNode: _endFocus,
                    maxPages: maxPages,
                    accentColor: AppTheme.secondary,
                    onSubmitted: (_) => _commitEndText(),
                  ),
                ),
              ],
            ),

            // Interactive Range Slider for quick scrubbing across large PDFs
            if (maxPages > 1) ...[
              const SizedBox(height: 6),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 4,
                  activeTrackColor: widget.range.accentColor,
                  inactiveTrackColor: AppTheme.borderSubtle,
                  thumbColor: widget.range.accentColor,
                  overlayColor: widget.range.accentColor.withValues(alpha: 0.12),
                  rangeThumbShape: const RoundRangeSliderThumbShape(
                    enabledThumbRadius: 8,
                  ),
                ),
                child: RangeSlider(
                  min: 1,
                  max: maxPages.toDouble(),
                  divisions: maxPages > 1 ? (maxPages - 1).clamp(1, 500) : null,
                  values: RangeValues(startVal, endVal),
                  labels: RangeLabels(
                    'p. ${startVal.round()}',
                    'p. ${endVal.round()}',
                  ),
                  onChanged: (values) {
                    final s = values.start.round().clamp(1, maxPages);
                    final e = values.end.round().clamp(s, maxPages);
                    widget.onStartChanged(s);
                    widget.onEndChanged(e);
                  },
                ),
              ),
            ],

            // Quick Jump Presets (Responsive Wrap - never overflows)
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (maxPages >= 256)
                  _QuickRangeChip(
                    label: 'Pages 245–256',
                    isSelected: widget.range.startPage == 245 &&
                        widget.range.endPage == 256,
                    accentColor: widget.range.accentColor,
                    onTap: () {
                      widget.onStartChanged(245);
                      widget.onEndChanged(256);
                    },
                  ),
                _QuickRangeChip(
                  label: 'First 10',
                  isSelected: widget.range.startPage == 1 &&
                      widget.range.endPage == (maxPages >= 10 ? 10 : maxPages),
                  accentColor: widget.range.accentColor,
                  onTap: () {
                    widget.onStartChanged(1);
                    widget.onEndChanged(maxPages >= 10 ? 10 : maxPages);
                  },
                ),
                if (maxPages >= 20)
                  _QuickRangeChip(
                    label: 'Mid 10 Pages',
                    isSelected: false,
                    accentColor: widget.range.accentColor,
                    onTap: () {
                      final mid = (maxPages ~/ 2).clamp(1, maxPages);
                      final end = (mid + 9).clamp(mid, maxPages);
                      widget.onStartChanged(mid);
                      widget.onEndChanged(end);
                    },
                  ),
                if (maxPages > 10)
                  _QuickRangeChip(
                    label: 'Last 10',
                    isSelected: widget.range.startPage == maxPages - 9 &&
                        widget.range.endPage == maxPages,
                    accentColor: widget.range.accentColor,
                    onTap: () {
                      widget.onStartChanged((maxPages - 9).clamp(1, maxPages));
                      widget.onEndChanged(maxPages);
                    },
                  ),
                _QuickRangeChip(
                  label: 'Single Page (${widget.range.startPage})',
                  isSelected: widget.range.startPage == widget.range.endPage,
                  accentColor: widget.range.accentColor,
                  onTap: () {
                    widget.onEndChanged(widget.range.startPage);
                  },
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Custom Output File Name prefix
            TextField(
              controller: _titleController,
              onChanged: widget.onTitleChanged,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppTheme.textPrimary,
              ),
              decoration: InputDecoration(
                labelText: 'Custom Output Name (Optional)',
                hintText:
                    'e.g. Chapter_12_Extract (saves as p${widget.range.startPage}-${widget.range.endPage}.pdf)',
                prefixIcon: const Icon(
                  Icons.drive_file_rename_outline_rounded,
                  size: 17,
                  color: AppTheme.textSecondary,
                ),
                suffixIcon: _titleController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 16),
                        onPressed: () {
                          _titleController.clear();
                          widget.onTitleChanged('');
                          setState(() {});
                        },
                      )
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PageNumberField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final FocusNode focusNode;
  final int maxPages;
  final Color accentColor;
  final ValueChanged<String> onSubmitted;

  const _PageNumberField({
    required this.label,
    required this.controller,
    required this.focusNode,
    required this.maxPages,
    required this.accentColor,
    required this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.done,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      onSubmitted: onSubmitted,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: AppTheme.textPrimary,
      ),
      decoration: InputDecoration(
        labelText: label,
        suffixText: '/ $maxPages',
        suffixStyle: const TextStyle(
          fontSize: 11.5,
          color: AppTheme.textMuted,
          fontWeight: FontWeight.w600,
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 34),
        prefixIcon: Icon(
          Icons.tag_rounded,
          size: 16,
          color: accentColor,
        ),
      ),
    );
  }
}

class _QuickRangeChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color accentColor;
  final VoidCallback onTap;

  const _QuickRangeChip({
    required this.label,
    required this.isSelected,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? accentColor.withValues(alpha: 0.12)
              : AppTheme.surfaceBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? accentColor : AppTheme.borderSubtle,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: isSelected ? accentColor : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}

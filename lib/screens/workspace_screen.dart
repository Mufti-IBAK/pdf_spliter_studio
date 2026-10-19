import 'package:flutter/material.dart';
import '../models/split_range.dart';
import '../services/pdf_render_service.dart';
import '../services/pdf_split_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/bookend_preview_card.dart';
import '../widgets/pdf_page_thumbnail.dart';
import '../widgets/range_filmstrip.dart';
import '../widgets/range_selector_card.dart';
import 'export_success_screen.dart';
import 'page_zoom_modal.dart';

/// Main Splitter Studio screen for selecting Start/End pages (e.g., 245–256),
/// verifying live boundary & range previews, queueing multiple ranges,
/// choosing Separate vs. Merged PDF output, and saving/downloading the result.
class WorkspaceScreen extends StatefulWidget {
  final String filePath;
  final String fileName;
  final StorageService storageService;
  final int? initialStartPage;
  final int? initialEndPage;

  const WorkspaceScreen({
    super.key,
    required this.filePath,
    required this.fileName,
    required this.storageService,
    this.initialStartPage,
    this.initialEndPage,
  });

  @override
  State<WorkspaceScreen> createState() => _WorkspaceScreenState();
}

class _WorkspaceScreenState extends State<WorkspaceScreen> {
  final PdfRenderService _renderService = PdfRenderService();
  late final PdfSplitService _splitService;

  bool _initializing = true;
  bool _exporting = false;
  String? _errorMessage;
  int _totalPages = 0;

  final List<SplitRange> _ranges = [];
  int _selectedRangeIndex = 0;
  MultiRangeExportMode _exportMode = MultiRangeExportMode.separateFiles;

  @override
  void initState() {
    super.initState();
    _splitService = PdfSplitService(widget.storageService);
    _openPdf();
  }

  @override
  void dispose() {
    _renderService.closeDocument();
    super.dispose();
  }

  Future<void> _openPdf() async {
    try {
      final count = await _renderService.openDocument(widget.filePath);
      if (!mounted) return;

      final defaultStart = widget.initialStartPage != null
          ? widget.initialStartPage!.clamp(1, count)
          : (count >= 256 ? 245 : 1);
      final defaultEnd = widget.initialEndPage != null
          ? widget.initialEndPage!.clamp(defaultStart, count)
          : (count >= 256 ? 256 : (count >= 10 ? 10 : count));

      setState(() {
        _totalPages = count;
        _ranges
          ..clear()
          ..add(
            SplitRange(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              startPage: defaultStart,
              endPage: defaultEnd,
              customTitle: '',
              colorIndex: 0,
            ),
          );
        _selectedRangeIndex = 0;
        _initializing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Could not open PDF file: $e';
        _initializing = false;
      });
    }
  }

  SplitRange get _activeRange => _ranges[_selectedRangeIndex];

  void _updateActiveRange(SplitRange updated) {
    setState(() {
      _ranges[_selectedRangeIndex] = updated;
    });
  }

  void _handleStartChanged(int newStart) {
    final clampedStart = newStart.clamp(1, _totalPages);
    final adjustedEnd = _activeRange.endPage < clampedStart
        ? clampedStart
        : _activeRange.endPage;
    _updateActiveRange(
      _activeRange.copyWith(
        startPage: clampedStart,
        endPage: adjustedEnd,
      ),
    );
  }

  void _handleEndChanged(int newEnd) {
    final clampedEnd = newEnd.clamp(1, _totalPages);
    final adjustedStart = _activeRange.startPage > clampedEnd
        ? clampedEnd
        : _activeRange.startPage;
    _updateActiveRange(
      _activeRange.copyWith(
        startPage: adjustedStart,
        endPage: clampedEnd,
      ),
    );
  }

  void _handleTitleChanged(String newTitle) {
    _updateActiveRange(_activeRange.copyWith(customTitle: newTitle));
  }

  void _handleToggleExcludePage(int pageNumber) {
    final current = Set<int>.from(_activeRange.excludedPages);
    if (current.contains(pageNumber)) {
      current.remove(pageNumber);
    } else {
      // Ensure at least 1 active page remains in the range
      if (_activeRange.activePageCount <= 1) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text('At least 1 page must remain in the selected range.'),
          ),
        );
        return;
      }
      current.add(pageNumber);
    }
    _updateActiveRange(_activeRange.copyWith(excludedPages: current));
  }

  void _handleRotatePage(int pageNumber) {
    final rotations = Map<int, int>.from(_activeRange.pageRotations);
    final currentDeg = rotations[pageNumber] ?? 0;
    rotations[pageNumber] = (currentDeg + 90) % 360;
    _updateActiveRange(_activeRange.copyWith(pageRotations: rotations));
  }

  void _addNewRange() {
    final lastEnd = _ranges.last.endPage;
    final nextStart = (lastEnd + 1).clamp(1, _totalPages);
    final nextEnd = (nextStart + 9).clamp(nextStart, _totalPages);

    setState(() {
      _ranges.add(
        SplitRange(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          startPage: nextStart,
          endPage: nextEnd,
          customTitle: '',
          colorIndex: _ranges.length,
        ),
      );
      _selectedRangeIndex = _ranges.length - 1;
    });
  }

  void _removeRangeAt(int index) {
    if (_ranges.length <= 1) return;
    setState(() {
      _ranges.removeAt(index);
      if (_selectedRangeIndex >= _ranges.length) {
        _selectedRangeIndex = _ranges.length - 1;
      }
    });
  }

  Future<void> _showFixedChunkDialog() async {
    final controller = TextEditingController(text: '25');
    final chunkSize = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Split Every N Pages',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Automatically generate page ranges across all $_totalPages pages.',
              style: const TextStyle(
                fontSize: 12.5,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Pages per split file',
                suffixText: 'pages',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final val = int.tryParse(controller.text.trim());
              Navigator.of(context).pop(val);
            },
            child: const Text('Generate Ranges'),
          ),
        ],
      ),
    );

    if (chunkSize == null || chunkSize < 1) return;
    final step = chunkSize.clamp(1, _totalPages);
    final generated = <SplitRange>[];
    int colorIdx = 0;
    for (int s = 1; s <= _totalPages && generated.length < 30; s += step) {
      final e = (s + step - 1).clamp(s, _totalPages);
      generated.add(
        SplitRange(
          id: '${DateTime.now().microsecondsSinceEpoch}_$s',
          startPage: s,
          endPage: e,
          customTitle: 'Part_${colorIdx + 1}',
          colorIndex: colorIdx++,
        ),
      );
    }

    if (generated.isNotEmpty) {
      setState(() {
        _ranges
          ..clear()
          ..addAll(generated);
        _selectedRangeIndex = 0;
        _exportMode = MultiRangeExportMode.separateFiles;
      });
    }
  }

  Future<void> _openInspectPageModal(int pageNumber) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PageZoomModal(
          renderService: _renderService,
          initialPage: pageNumber,
          totalPages: _totalPages,
          currentStartPage: _activeRange.startPage,
          currentEndPage: _activeRange.endPage,
          onSetAsStart: _handleStartChanged,
          onSetAsEnd: _handleEndChanged,
        ),
      ),
    );
  }

  Future<void> _openAllPagesBrowserSheet() async {
    final jumpController =
        TextEditingController(text: _activeRange.startPage.toString());
    int browseStart = (_activeRange.startPage - 6).clamp(1, _totalPages);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final windowCount =
                (_totalPages - browseStart + 1).clamp(1, 24);
            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.78,
              minChildSize: 0.5,
              maxChildSize: 0.94,
              builder: (context, scrollController) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 36,
                          height: 4,
                          decoration: BoxDecoration(
                            color: AppTheme.borderSubtle,
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Jump & Browse Document Pages',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  'Tap any page to zoom or assign Start / End',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(
                            width: 115,
                            child: TextField(
                              controller: jumpController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'Go to page',
                                suffixIcon: IconButton(
                                  icon: const Icon(
                                    Icons.arrow_forward_rounded,
                                    size: 16,
                                  ),
                                  onPressed: () {
                                    final p = int.tryParse(
                                      jumpController.text.trim(),
                                    );
                                    if (p != null) {
                                      setSheetState(() {
                                        browseStart =
                                            p.clamp(1, _totalPages);
                                      });
                                    }
                                  },
                                ),
                              ),
                              onSubmitted: (val) {
                                final p = int.tryParse(val.trim());
                                if (p != null) {
                                  setSheetState(() {
                                    browseStart = p.clamp(1, _totalPages);
                                  });
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      // Window navigation row for 300+ page documents
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          OutlinedButton.icon(
                            onPressed: browseStart > 1
                                ? () => setSheetState(() {
                                      browseStart = (browseStart - 24)
                                          .clamp(1, _totalPages);
                                    })
                                : null,
                            icon: const Icon(
                              Icons.chevron_left_rounded,
                              size: 16,
                            ),
                            label: const Text('Prev 24'),
                          ),
                          Text(
                            'Showing p. $browseStart – ${browseStart + windowCount - 1} of $_totalPages',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed:
                                (browseStart + windowCount - 1) < _totalPages
                                    ? () => setSheetState(() {
                                          browseStart = (browseStart + 24)
                                              .clamp(1, _totalPages);
                                        })
                                    : null,
                            icon: const Icon(
                              Icons.chevron_right_rounded,
                              size: 16,
                            ),
                            label: const Text('Next 24'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: GridView.builder(
                          controller: scrollController,
                          itemCount: windowCount,
                          gridDelegate:
                              const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 145,
                            mainAxisSpacing: 10,
                            crossAxisSpacing: 10,
                            childAspectRatio: 0.72,
                          ),
                          itemBuilder: (context, index) {
                            final pageNum = browseStart + index;
                            final inRange = pageNum >= _activeRange.startPage &&
                                pageNum <= _activeRange.endPage;
                            return PdfPageThumbnail(
                              renderService: _renderService,
                              pageNumber: pageNum,
                              badgeText: pageNum == _activeRange.startPage
                                  ? 'START'
                                  : pageNum == _activeRange.endPage
                                      ? 'END'
                                      : inRange
                                          ? 'IN RANGE'
                                          : null,
                              badgeColor: pageNum == _activeRange.startPage
                                  ? _activeRange.accentColor
                                  : pageNum == _activeRange.endPage
                                      ? AppTheme.secondary
                                      : AppTheme.primary.withValues(alpha: 0.7),
                              onTap: () {
                                Navigator.of(context).pop();
                                _openInspectPageModal(pageNum);
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _executeSplitAndSave() async {
    if (_exporting) return;
    setState(() {
      _exporting = true;
    });

    try {
      final savedFiles = await _splitService.splitPdf(
        sourceFilePath: widget.filePath,
        sourceFileName: widget.fileName,
        ranges: _ranges,
        exportMode: _exportMode,
      );

      if (!mounted) return;
      setState(() {
        _exporting = false;
      });

      if (savedFiles.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No active pages selected to export.'),
          ),
        );
        return;
      }

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ExportSuccessScreen(
            savedFiles: savedFiles,
            storageService: widget.storageService,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _exporting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.danger,
          content: Text('Error creating split PDF: $e'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_initializing) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.fileName)),
        body: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 12),
              Text(
                'Loading PDF pages...',
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('PDF Error')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.danger),
            ),
          ),
        ),
      );
    }

    final totalSelectedPages = _ranges.fold<int>(
      0,
      (sum, r) => sum + r.activePageCount,
    );

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.fileName,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              '$_totalPages total pages • ${_ranges.length} ${_ranges.length == 1 ? "range" : "ranges"}',
              style: const TextStyle(
                fontSize: 11.5,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: OutlinedButton.icon(
              onPressed: _openAllPagesBrowserSheet,
              icon: const Icon(Icons.grid_on_rounded, size: 15),
              label: const Text('Browse All'),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: 'Auto-Split Every N Pages',
              onPressed: _showFixedChunkDialog,
              icon: const Icon(Icons.auto_awesome_motion_rounded, size: 19),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Top Multi-Range Queue Strip
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(color: AppTheme.borderSubtle),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ...List.generate(_ranges.length, (index) {
                        final item = _ranges[index];
                        final isSelected = index == _selectedRangeIndex;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(9),
                            onTap: () =>
                                setState(() => _selectedRangeIndex = index),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 160),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? item.accentColor
                                    : item.accentColor.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(9),
                                border: Border.all(
                                  color: item.accentColor,
                                  width: isSelected ? 1.5 : 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.content_cut_rounded,
                                    size: 13,
                                    color: isSelected
                                        ? Colors.white
                                        : item.accentColor,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    'p. ${item.startPage}–${item.endPage}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: isSelected
                                          ? Colors.white
                                          : item.accentColor,
                                    ),
                                  ),
                                  if (_ranges.length > 1) ...[
                                    const SizedBox(width: 6),
                                    GestureDetector(
                                      onTap: () => _removeRangeAt(index),
                                      child: Icon(
                                        Icons.close_rounded,
                                        size: 14,
                                        color: isSelected
                                            ? Colors.white70
                                            : item.accentColor,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                      OutlinedButton.icon(
                        onPressed: _addNewRange,
                        icon: const Icon(Icons.add_rounded, size: 15),
                        label: const Text('Add Range'),
                      ),
                    ],
                  ),
                ),

                // Separate PDFs vs Merge into 1 PDF selector when multiple ranges exist
                if (_ranges.length > 1) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.borderSubtle),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.tune_rounded,
                          size: 15,
                          color: AppTheme.textSecondary,
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'Multi-Range Output:',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            alignment: WrapAlignment.end,
                            children: [
                              _ExportModeChoiceChip(
                                label:
                                    'Separate PDFs (${_ranges.length})',
                                icon: Icons.file_copy_outlined,
                                selected: _exportMode ==
                                    MultiRangeExportMode.separateFiles,
                                onTap: () => setState(() {
                                  _exportMode =
                                      MultiRangeExportMode.separateFiles;
                                }),
                              ),
                              _ExportModeChoiceChip(
                                label: 'Merge into 1 PDF',
                                icon: Icons.merge_type_rounded,
                                selected: _exportMode ==
                                    MultiRangeExportMode.mergeIntoSinglePdf,
                                onTap: () => setState(() {
                                  _exportMode =
                                      MultiRangeExportMode.mergeIntoSinglePdf;
                                }),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Main Responsive Studio Content
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 760;

                if (isWide) {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 5,
                              child: RangeSelectorCard(
                                range: _activeRange,
                                totalPages: _totalPages,
                                onStartChanged: _handleStartChanged,
                                onEndChanged: _handleEndChanged,
                                onTitleChanged: _handleTitleChanged,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              flex: 6,
                              child: BookendPreviewCard(
                                renderService: _renderService,
                                range: _activeRange,
                                totalPages: _totalPages,
                                onStartChanged: _handleStartChanged,
                                onEndChanged: _handleEndChanged,
                                onInspectPage: _openInspectPageModal,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        RangeFilmstrip(
                          renderService: _renderService,
                          range: _activeRange,
                          onInspectPage: _openInspectPageModal,
                          onToggleExcludePage: _handleToggleExcludePage,
                          onRotatePage: _handleRotatePage,
                        ),
                      ],
                    ),
                  );
                }

                return ListView(
                  padding: const EdgeInsets.all(14),
                  children: [
                    RangeSelectorCard(
                      range: _activeRange,
                      totalPages: _totalPages,
                      onStartChanged: _handleStartChanged,
                      onEndChanged: _handleEndChanged,
                      onTitleChanged: _handleTitleChanged,
                    ),
                    const SizedBox(height: 12),
                    BookendPreviewCard(
                      renderService: _renderService,
                      range: _activeRange,
                      totalPages: _totalPages,
                      onStartChanged: _handleStartChanged,
                      onEndChanged: _handleEndChanged,
                      onInspectPage: _openInspectPageModal,
                    ),
                    const SizedBox(height: 12),
                    RangeFilmstrip(
                      renderService: _renderService,
                      range: _activeRange,
                      onInspectPage: _openInspectPageModal,
                      onToggleExcludePage: _handleToggleExcludePage,
                      onRotatePage: _handleRotatePage,
                    ),
                    const SizedBox(height: 16),
                  ],
                );
              },
            ),
          ),

          // Compact Bottom Export Bar
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: AppTheme.borderSubtle),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _ranges.length == 1
                              ? _activeRange.rangeLabel
                              : _exportMode ==
                                      MultiRangeExportMode.mergeIntoSinglePdf
                                  ? 'Merge ${_ranges.length} ranges into 1 PDF'
                                  : 'Save ${_ranges.length} separate PDFs',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '$totalSelectedPages total ${totalSelectedPages == 1 ? "page" : "pages"} ready to save as .pdf',
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: AppTheme.textSecondary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: _exporting ? null : _executeSplitAndSave,
                    icon: _exporting
                        ? const SizedBox(
                            width: 15,
                            height: 15,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save_alt_rounded, size: 17),
                    label: Text(
                      _exporting
                          ? 'Splitting...'
                          : _ranges.length > 1 &&
                                  _exportMode ==
                                      MultiRangeExportMode.mergeIntoSinglePdf
                              ? 'Merge & Save PDF'
                              : 'Split & Save PDF',
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

class _ExportModeChoiceChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _ExportModeChoiceChip({
    required this.label,
    required this.icon,
    required this.selected,
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
          color: selected ? AppTheme.primary : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? AppTheme.primary : AppTheme.borderSubtle,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: selected ? Colors.white : AppTheme.textSecondary,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : AppTheme.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

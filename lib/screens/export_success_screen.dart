import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import '../models/saved_split_file.dart';
import '../services/pdf_render_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/pdf_page_thumbnail.dart';
import 'settings_screen.dart';

/// Displays the newly generated & saved `.pdf` files after splitting,
/// saving directly to the user's Default Save Location and keeping the user
/// inside the app without any blank screen.
class ExportSuccessScreen extends StatefulWidget {
  final List<SavedSplitFile> savedFiles;
  final StorageService storageService;

  const ExportSuccessScreen({
    super.key,
    required this.savedFiles,
    required this.storageService,
  });

  @override
  State<ExportSuccessScreen> createState() => _ExportSuccessScreenState();
}

class _ExportSuccessScreenState extends State<ExportSuccessScreen> {
  final Map<String, String> _downloadedPaths = {};
  String _defaultFolder = '';

  @override
  void initState() {
    super.initState();
    _loadDefaultFolder();
  }

  Future<void> _loadDefaultFolder() async {
    final folder = await widget.storageService.getDefaultSaveDirectoryPath();
    if (!mounted) return;
    setState(() {
      _defaultFolder = folder;
    });
  }

  Future<void> _saveToPhone(SavedSplitFile item) async {
    final savedPath =
        await widget.storageService.downloadToUserSelectedLocation(item);
    if (!mounted) return;
    if (savedPath != null) {
      setState(() {
        _downloadedPaths[item.id] = savedPath;
      });
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: AppTheme.success, size: 22),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Saved to Phone!',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.fileName,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Location on your device:',
                style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.borderSubtle),
                ),
                child: Text(
                  savedPath,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primary,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => SettingsScreen(
                      storageService: widget.storageService,
                      onHistoryChanged: _loadDefaultFolder,
                    ),
                  ),
                );
              },
              child: const Text('Change Default Folder'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Done'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _shareFile(SavedSplitFile item) async {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(item.filePath, mimeType: 'application/pdf')],
        subject: item.fileName,
        text: 'Split PDF: ${item.fileName} (${item.rangeSummary})',
      ),
    );
  }

  Future<void> _openInAppPreview(SavedSplitFile item) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SplitPdfPreviewScreen(file: item),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.savedFiles.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Split PDF Saved'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton.icon(
              onPressed: () =>
                  Navigator.of(context).popUntil((route) => route.isFirst),
              icon: const Icon(Icons.home_outlined, size: 17),
              label: const Text('Home'),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Top Success Banner Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF4F46E5), Color(0xFF0D9488)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.check_circle_outline_rounded,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            count == 1
                                ? '1 Split PDF Saved to Phone'
                                : '$count Split PDFs Saved to Phone',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _defaultFolder.isNotEmpty
                                ? 'Default Folder: $_defaultFolder'
                                : 'Saved as standard .pdf files on your device.',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF1E1B4B),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back_rounded, size: 16),
                      label: const Text('Back to PDF Splitter'),
                    ),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.35),
                        ),
                      ),
                      onPressed: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => SettingsScreen(
                              storageService: widget.storageService,
                              onHistoryChanged: _loadDefaultFolder,
                            ),
                          ),
                        );
                        await _loadDefaultFolder();
                      },
                      icon: const Icon(Icons.folder_outlined, size: 15),
                      label: const Text('Save Location Settings'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Generated PDF Cards
          ...widget.savedFiles.map((item) {
            final savedLocation =
                _downloadedPaths[item.id] ?? item.downloadPath ?? item.filePath;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(9),
                            decoration: BoxDecoration(
                              color: AppTheme.primarySoft,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.picture_as_pdf_rounded,
                              color: AppTheme.primary,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.fileName,
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 4,
                                  children: [
                                    _MetaPill(
                                      icon: Icons.layers_outlined,
                                      label:
                                          '${item.pageCount} ${item.pageCount == 1 ? "page" : "pages"}',
                                    ),
                                    _MetaPill(
                                      icon: Icons.content_cut_rounded,
                                      label: item.rangeSummary,
                                    ),
                                    _MetaPill(
                                      icon: Icons.sd_storage_outlined,
                                      label: item.formattedSize,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.success.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.task_alt_rounded,
                              size: 14,
                              color: AppTheme.success,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Saved at: $savedLocation',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.textSecondary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Responsive compact buttons row
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilledButton.icon(
                            onPressed: () => _saveToPhone(item),
                            icon: const Icon(
                              Icons.download_done_rounded,
                              size: 16,
                            ),
                            label: const Text('Save to Phone'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => _openInAppPreview(item),
                            icon: const Icon(
                              Icons.visibility_outlined,
                              size: 16,
                            ),
                            label: const Text('Preview PDF'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => _shareFile(item),
                            icon: const Icon(
                              Icons.ios_share_rounded,
                              size: 15,
                            ),
                            label: const Text('Share'),
                          ),
                          TextButton.icon(
                            onPressed: () => OpenFilex.open(item.filePath),
                            icon: const Icon(
                              Icons.open_in_new_rounded,
                              size: 15,
                            ),
                            label: const Text('External App'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetaPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.surfaceBg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppTheme.textSecondary),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Built-in PDF reader screen using our serialized `PdfRenderService` so
/// previewing a saved PDF never causes a blank screen on any Android phone.
class SplitPdfPreviewScreen extends StatefulWidget {
  final SavedSplitFile file;

  const SplitPdfPreviewScreen({super.key, required this.file});

  @override
  State<SplitPdfPreviewScreen> createState() => _SplitPdfPreviewScreenState();
}

class _SplitPdfPreviewScreenState extends State<SplitPdfPreviewScreen> {
  final PdfRenderService _renderService = PdfRenderService();
  bool _loading = true;
  int _pageCount = 0;

  @override
  void initState() {
    super.initState();
    _initDoc();
  }

  Future<void> _initDoc() async {
    final count = await _renderService.openDocument(widget.file.filePath);
    if (!mounted) return;
    setState(() {
      _pageCount = count;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _renderService.closeDocument();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.file.fileName,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            Text(
              '${widget.file.rangeSummary} • $_pageCount pages',
              style: const TextStyle(
                fontSize: 11,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _pageCount,
              separatorBuilder: (_, _) => const SizedBox(height: 14),
              itemBuilder: (context, index) {
                final pageNum = index + 1;
                return AspectRatio(
                  aspectRatio: 0.72,
                  child: PdfPageThumbnail(
                    renderService: _renderService,
                    pageNumber: pageNum,
                    highRes: true,
                    badgeText: 'PAGE $pageNum OF $_pageCount',
                  ),
                );
              },
            ),
    );
  }
}

import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/saved_split_file.dart';
import '../services/pdf_split_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import 'export_success_screen.dart';
import 'settings_screen.dart';
import 'workspace_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final StorageService _storageService = StorageService();
  late final PdfSplitService _splitService;

  List<SavedSplitFile> _history = [];
  bool _loadingHistory = true;
  bool _generatingDemo = false;
  bool _pickingFile = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _splitService = PdfSplitService(_storageService);
    _refreshHistory();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      // Force a frame repaint whenever the app returns from Android File Storage
      WidgetsBinding.instance.scheduleForcedFrame();
      setState(() {});
    }
  }

  Future<void> _refreshHistory() async {
    final items = await _storageService.loadHistory();
    if (!mounted) return;
    setState(() {
      _history = items;
      _loadingHistory = false;
    });
  }

  /// Waits until the Android activity has fully resumed and rendered a frame
  /// after returning from the external system file picker before navigating.
  Future<void> _waitForActivityResume() async {
    for (int i = 0; i < 15; i++) {
      final lifecycle = WidgetsBinding.instance.lifecycleState;
      if (lifecycle == null || lifecycle == AppLifecycleState.resumed) {
        break;
      }
      await Future.delayed(const Duration(milliseconds: 60));
    }
    await Future.delayed(const Duration(milliseconds: 120));
    if (mounted) {
      WidgetsBinding.instance.scheduleForcedFrame();
      await WidgetsBinding.instance.endOfFrame;
    }
  }

  Future<void> _openPdfInWorkspace({
    required String filePath,
    required String fileName,
    int? initialStartPage,
    int? initialEndPage,
  }) async {
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WorkspaceScreen(
          filePath: filePath,
          fileName: fileName,
          storageService: _storageService,
          initialStartPage: initialStartPage,
          initialEndPage: initialEndPage,
        ),
      ),
    );
    await _refreshHistory();
  }

  Future<void> _pickPdfFromDevice() async {
    if (_pickingFile) return;
    setState(() {
      _pickingFile = true;
    });

    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      // Wait for the Android Activity & GPU surface to finish resuming
      await _waitForActivityResume();

      if (!mounted) return;

      if (files.isEmpty) {
        setState(() {
          _pickingFile = false;
        });
        return;
      }
      final picked = files.first;

      String? resolvedPath = picked.path;
      // On Android, FilePicker v13 returns a content:// URI where picked.path is null.
      // Read the PDF via ContentResolver (picked.readAsBytes()) and save to a local file
      // so pdfx and Syncfusion can open it reliably every single time.
      if (resolvedPath == null || !await File(resolvedPath).exists()) {
        final bytes = await picked.readAsBytes();
        if (bytes.isNotEmpty) {
          final tempDir = await getTemporaryDirectory();
          final safeName =
              picked.name.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
          final finalName = safeName.toLowerCase().endsWith('.pdf')
              ? safeName
              : '$safeName.pdf';
          final tempFile = File('${tempDir.path}/picked_$finalName');
          await tempFile.writeAsBytes(bytes, flush: true);
          resolvedPath = tempFile.path;
        }
      }

      if (!mounted) return;
      setState(() {
        _pickingFile = false;
      });

      if (resolvedPath == null) return;

      await _openPdfInWorkspace(
        filePath: resolvedPath,
        fileName: picked.name,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _pickingFile = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.danger,
          content: Text('Could not open selected PDF: $e'),
        ),
      );
    }
  }

  /// Opens an in-app PDF scanner sheet that finds PDFs in Downloads/Documents
  /// so the user can pick files without even leaving the app, or launch the
  /// system storage browser.
  Future<void> _showInAppPdfQuickPicker() async {
    final foundFiles = <File>[];
    final candidateFolders = <String>[
      '/storage/emulated/0/Download',
      '/storage/emulated/0/Download/SlicePDF_Studio',
      '/storage/emulated/0/Documents',
      '/storage/emulated/0/Documents/SlicePDF_Studio',
    ];

    for (final folderPath in candidateFolders) {
      try {
        final dir = Directory(folderPath);
        if (await dir.exists()) {
          final entities = dir.listSync(followLinks: false);
          for (final entity in entities) {
            if (entity is File &&
                entity.path.toLowerCase().endsWith('.pdf')) {
              foundFiles.add(entity);
            }
          }
        }
      } catch (_) {}
    }

    if (!mounted) return;

    // If no direct files are readable without system picker, open system picker directly
    if (foundFiles.isEmpty) {
      await _pickPdfFromDevice();
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.65,
          minChildSize: 0.45,
          maxChildSize: 0.9,
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
                              'Select PDF Document',
                              style: TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            Text(
                              'Pick instantly below or browse all device folders',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: () {
                          Navigator.of(sheetContext).pop();
                          _pickPdfFromDevice();
                        },
                        icon: const Icon(Icons.folder_open_rounded, size: 16),
                        label: const Text('Browse Storage'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.separated(
                      controller: scrollController,
                      itemCount: foundFiles.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final f = foundFiles[index];
                        final name = f.uri.pathSegments.last;
                        final sizeKb =
                            (f.lengthSync() / 1024).toStringAsFixed(1);
                        return Card(
                          child: ListTile(
                            dense: true,
                            leading: Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: AppTheme.primarySoft,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.picture_as_pdf_rounded,
                                size: 18,
                                color: AppTheme.primary,
                              ),
                            ),
                            title: Text(
                              name,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              '$sizeKb KB • ${f.parent.path}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppTheme.textSecondary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: const Icon(
                              Icons.chevron_right_rounded,
                              size: 18,
                            ),
                            onTap: () {
                              Navigator.of(sheetContext).pop();
                              _openPdfInWorkspace(
                                filePath: f.path,
                                fileName: name,
                              );
                            },
                          ),
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
  }

  Future<void> _open300PageSamplePdf() async {
    if (_generatingDemo) return;
    setState(() {
      _generatingDemo = true;
    });

    try {
      final sampleFile =
          await _splitService.generateSample300PagePdf(totalPages: 300);
      if (!mounted) return;
      setState(() {
        _generatingDemo = false;
      });

      await _openPdfInWorkspace(
        filePath: sampleFile.path,
        fileName: 'Sample_300_Page_Handbook.pdf',
        initialStartPage: 245,
        initialEndPage: 256,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _generatingDemo = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.danger,
          content: Text('Failed to generate sample PDF: $e'),
        ),
      );
    }
  }

  Future<void> _downloadSavedFile(SavedSplitFile item) async {
    final path = await _storageService.downloadToUserSelectedLocation(item);
    if (!mounted) return;
    if (path != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Saved to Phone: $path'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('MMM d, h:mm a');

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                'assets/images/logo_smalll.jpg',
                width: 30,
                height: 30,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 10),
            const Flexible(
              child: Text(
                'SlicePDF Studio',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.primarySoft,
                borderRadius: BorderRadius.circular(99),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.shield_outlined,
                    size: 13,
                    color: AppTheme.primary,
                  ),
                  SizedBox(width: 4),
                  Text(
                    '100% Offline',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            tooltip: 'Settings & About',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => SettingsScreen(
                    storageService: _storageService,
                    onHistoryChanged: _refreshHistory,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.settings_outlined, size: 20),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Main Hero Card: Pick PDF or Try 300-Page Demo
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E1B4B), Color(0xFF312E81)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primary.withValues(alpha: 0.16),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'PRECISION RANGE SPLITTER & VERIFIER',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Split exact page ranges with live visual verification',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Pick any Start & End page (e.g., pages 245 to 256 of 300), inspect live boundary previews, and save or merge directly to a downloadable .pdf.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12.5,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),

                // Responsive Compact Buttons
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF1E1B4B),
                      ),
                      onPressed: _pickingFile ? null : _pickPdfFromDevice,
                      icon: _pickingFile
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF1E1B4B),
                              ),
                            )
                          : const Icon(Icons.upload_file_rounded, size: 17),
                      label: Text(
                        _pickingFile ? 'Opening PDF...' : 'Select PDF File',
                      ),
                    ),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.35),
                        ),
                      ),
                      onPressed: _showInAppPdfQuickPicker,
                      icon: const Icon(Icons.bolt_rounded, size: 16),
                      label: const Text('Quick Pick (In-App)'),
                    ),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.35),
                        ),
                      ),
                      onPressed:
                          _generatingDemo ? null : _open300PageSamplePdf,
                      icon: _generatingDemo
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.auto_stories_outlined, size: 16),
                      label: Text(
                        _generatingDemo
                            ? 'Preparing 300 Pages...'
                            : 'Try 300-Page Demo (p. 245–256)',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Responsive Feature Highlights Cards
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 600;
              final features = [
                const _FeatureInfoCard(
                  icon: Icons.compare_rounded,
                  color: AppTheme.primary,
                  title: 'Start & End Preview',
                  subtitle:
                      'Side-by-side live preview of your exact Start and End pages with -1/+1 nudging.',
                ),
                const _FeatureInfoCard(
                  icon: Icons.merge_type_rounded,
                  color: AppTheme.secondary,
                  title: 'Separate or Merge',
                  subtitle:
                      'Queue multiple page ranges and export them as separate PDFs or 1 combined PDF.',
                ),
                const _FeatureInfoCard(
                  icon: Icons.download_done_rounded,
                  color: Color(0xFFD97706),
                  title: 'True .PDF Download',
                  subtitle:
                      'Losslessly saves real .pdf files to your configured Default Save Location.',
                ),
              ];

              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: features[0]),
                    const SizedBox(width: 10),
                    Expanded(child: features[1]),
                    const SizedBox(width: 10),
                    Expanded(child: features[2]),
                  ],
                );
              }
              return Column(
                children: [
                  features[0],
                  const SizedBox(height: 8),
                  features[1],
                  const SizedBox(height: 8),
                  features[2],
                ],
              );
            },
          ),
          const SizedBox(height: 20),

          // Saved & Downloaded Split PDFs Library Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Saved & Downloaded Splits',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              if (_history.isNotEmpty)
                Text(
                  '${_history.length} ${_history.length == 1 ? "file" : "files"}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),

          if (_loadingHistory)
            const Padding(
              padding: EdgeInsets.all(24.0),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_history.isEmpty)
            Card(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.folder_copy_outlined,
                        size: 24,
                        color: AppTheme.textMuted,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'No split PDFs saved yet',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Select a PDF or tap "Try 300-Page Demo (p. 245–256)" above to extract and download your first PDF.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ..._history.map((item) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: item.isMergedOutput
                                    ? AppTheme.secondary.withValues(alpha: 0.12)
                                    : AppTheme.primarySoft,
                                borderRadius: BorderRadius.circular(9),
                              ),
                              child: Icon(
                                Icons.picture_as_pdf_rounded,
                                size: 18,
                                color: item.isMergedOutput
                                    ? AppTheme.secondary
                                    : AppTheme.primary,
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
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${item.rangeSummary} • ${item.pageCount} pages • ${item.formattedSize} • ${dateFmt.format(item.createdAt)}',
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
                              tooltip: 'Delete from history',
                              onPressed: () async {
                                await _storageService.deleteSavedSplit(item);
                                await _refreshHistory();
                              },
                              icon: const Icon(
                                Icons.delete_outline_rounded,
                                size: 17,
                                color: AppTheme.textMuted,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        SplitPdfPreviewScreen(file: item),
                                  ),
                                );
                              },
                              icon: const Icon(
                                Icons.visibility_outlined,
                                size: 15,
                              ),
                              label: const Text('Preview'),
                            ),
                            OutlinedButton.icon(
                              onPressed: () => _downloadSavedFile(item),
                              icon: const Icon(
                                Icons.download_rounded,
                                size: 15,
                              ),
                              label: const Text('Save to Phone'),
                            ),
                            OutlinedButton.icon(
                              onPressed: () {
                                SharePlus.instance.share(
                                  ShareParams(
                                    files: [
                                      XFile(
                                        item.filePath,
                                        mimeType: 'application/pdf',
                                      ),
                                    ],
                                    subject: item.fileName,
                                  ),
                                );
                              },
                              icon: const Icon(
                                Icons.ios_share_rounded,
                                size: 14,
                              ),
                              label: const Text('Share'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          const SizedBox(height: 18),
          Center(
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => SettingsScreen(
                      storageService: _storageService,
                      onHistoryChanged: _refreshHistory,
                    ),
                  ),
                );
              },
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.verified_rounded,
                      size: 14,
                      color: AppTheme.primary,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Built by Plexus Labs & Systems LTD',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _FeatureInfoCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  const _FeatureInfoCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 16, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppTheme.textSecondary,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

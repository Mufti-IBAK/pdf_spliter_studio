import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/saved_split_file.dart';

/// Represents a selectable Default Save Location preset or custom folder.
class SaveLocationOption {
  final String id;
  final String title;
  final String subtitle;
  final String path;

  const SaveLocationOption({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.path,
  });
}

/// Manages saving generated `.pdf` files to the user's configured Default Save
/// Location on the phone, exporting to custom folders, and persisting history.
class StorageService {
  static const String _historyPrefsKey = 'slicepdf_saved_splits_v1';
  static const String _defaultSaveDirPrefsKey = 'slicepdf_default_save_dir_v1';

  Future<Directory> _getInternalSplitsDir() async {
    final baseDir = await getApplicationDocumentsDirectory();
    final splitsDir = Directory('${baseDir.path}/SavedSplits');
    if (!await splitsDir.exists()) {
      await splitsDir.create(recursive: true);
    }
    return splitsDir;
  }

  /// Returns the list of standard save location options on the device.
  Future<List<SaveLocationOption>> getPresetSaveLocations() async {
    final internalDir = await _getInternalSplitsDir();
    if (Platform.isAndroid) {
      return [
        const SaveLocationOption(
          id: 'downloads_slicepdf',
          title: 'Phone Downloads / SlicePDF_Studio',
          subtitle: '/storage/emulated/0/Download/SlicePDF_Studio',
          path: '/storage/emulated/0/Download/SlicePDF_Studio',
        ),
        const SaveLocationOption(
          id: 'downloads_root',
          title: 'Phone Downloads Folder (Root)',
          subtitle: '/storage/emulated/0/Download',
          path: '/storage/emulated/0/Download',
        ),
        const SaveLocationOption(
          id: 'documents_slicepdf',
          title: 'Phone Documents / SlicePDF_Studio',
          subtitle: '/storage/emulated/0/Documents/SlicePDF_Studio',
          path: '/storage/emulated/0/Documents/SlicePDF_Studio',
        ),
        SaveLocationOption(
          id: 'app_internal',
          title: 'App Private Library',
          subtitle: internalDir.path,
          path: internalDir.path,
        ),
      ];
    }

    return [
      SaveLocationOption(
        id: 'ios_files',
        title: 'On My iPhone / SlicePDF Studio',
        subtitle: internalDir.path,
        path: internalDir.path,
      ),
    ];
  }

  static String? _cachedDefaultSaveDir;
  static final List<SavedSplitFile> _memoryHistory = [];

  /// Gets the currently configured Default Save Location folder path.
  Future<String> getDefaultSaveDirectoryPath() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_defaultSaveDirPrefsKey);
      if (saved != null && saved.trim().isNotEmpty) {
        _cachedDefaultSaveDir = saved.trim();
        return saved.trim();
      }
    } catch (_) {
      if (_cachedDefaultSaveDir != null && _cachedDefaultSaveDir!.isNotEmpty) {
        return _cachedDefaultSaveDir!;
      }
    }
    if (Platform.isAndroid) {
      return '/storage/emulated/0/Download/SlicePDF_Studio';
    }
    final internalDir = await _getInternalSplitsDir();
    return internalDir.path;
  }

  /// Persists the user's chosen Default Save Location folder path.
  Future<void> setDefaultSaveDirectoryPath(String path) async {
    _cachedDefaultSaveDir = path.trim();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_defaultSaveDirPrefsKey, path.trim());
    } catch (_) {}
  }

  /// Allows the user to browse for a custom default folder in Settings.
  /// Falls back gracefully if the device ROM does not support directory picker.
  Future<String?> pickCustomDirectory() async {
    try {
      final selectedDir = await FilePicker.getDirectoryPath(
        dialogTitle: 'Select Default Save Folder for Split PDFs',
      );
      if (selectedDir != null && selectedDir.trim().isNotEmpty) {
        await setDefaultSaveDirectoryPath(selectedDir.trim());
        return selectedDir.trim();
      }
    } catch (_) {}
    return null;
  }

  /// Saves raw PDF bytes as a `.pdf` file in both the internal app library
  /// and the user's configured Default Save Location on the phone.
  Future<SavedSplitFile> savePdfBytes({
    required Uint8List bytes,
    required String desiredFileName,
    required String sourceFileName,
    required String rangeSummary,
    required int pageCount,
    bool isMergedOutput = false,
  }) async {
    final splitsDir = await _getInternalSplitsDir();
    final safeName = _sanitizeFileName(desiredFileName);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final finalFileName =
        safeName.toLowerCase().endsWith('.pdf') ? safeName : '$safeName.pdf';

    // 1. Save to internal app library so in-app preview & share always work
    File internalFile = File('${splitsDir.path}/$finalFileName');
    if (await internalFile.exists()) {
      final stem = finalFileName.substring(0, finalFileName.length - 4);
      internalFile = File('${splitsDir.path}/${stem}_$timestamp.pdf');
    }
    await internalFile.writeAsBytes(bytes, flush: true);

    // 2. Also save directly to the user's configured Default Save Location
    final publicDownloadPath = await _writeToDefaultPhoneFolder(
      bytes: bytes,
      fileName: internalFile.uri.pathSegments.last,
    );

    final record = SavedSplitFile(
      id: timestamp.toString(),
      fileName: internalFile.uri.pathSegments.last,
      filePath: internalFile.path,
      downloadPath: publicDownloadPath ?? internalFile.path,
      sourceFileName: sourceFileName,
      rangeSummary: rangeSummary,
      pageCount: pageCount,
      fileSizeBytes: bytes.lengthInBytes,
      createdAt: DateTime.now(),
      isMergedOutput: isMergedOutput,
    );

    await _prependToHistory(record);
    return record;
  }

  /// Saves a copy of [splitFile] directly into the user's Default Save Location
  /// on the phone without launching an external intent that could leave a blank screen.
  Future<String?> downloadToUserSelectedLocation(
    SavedSplitFile splitFile,
  ) async {
    final file = File(splitFile.filePath);
    if (!await file.exists()) return null;
    final bytes = await file.readAsBytes();

    // Write directly to the user's configured Default Save Location first
    final savedInDefault = await _writeToDefaultPhoneFolder(
      bytes: bytes,
      fileName: splitFile.fileName,
    );
    if (savedInDefault != null) {
      return savedInDefault;
    }

    // Fallback to internal app file path
    return splitFile.filePath;
  }

  Future<String?> _writeToDefaultPhoneFolder({
    required Uint8List bytes,
    required String fileName,
  }) async {
    final preferredDirPath = await getDefaultSaveDirectoryPath();
    final candidateDirs = <String>[
      preferredDirPath,
      if (Platform.isAndroid) '/storage/emulated/0/Download/SlicePDF_Studio',
      if (Platform.isAndroid) '/storage/emulated/0/Download',
      if (Platform.isAndroid) '/storage/emulated/0/Documents',
    ];

    for (final dirPath in candidateDirs) {
      try {
        final dir = Directory(dirPath);
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
        File outFile = File('${dir.path}/$fileName');
        await outFile.writeAsBytes(bytes, flush: true);
        if (await outFile.exists() && await outFile.length() > 0) {
          return outFile.path;
        }
      } catch (_) {
        // Try next candidate directory
      }
    }
    return null;
  }

  Future<List<SavedSplitFile>> loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawList = prefs.getStringList(_historyPrefsKey) ?? [];
      final items = <SavedSplitFile>[];
      for (final raw in rawList) {
        try {
          final item = SavedSplitFile.fromJson(raw);
          if (await File(item.filePath).exists()) {
            items.add(item);
          }
        } catch (_) {}
      }
      _memoryHistory
        ..clear()
        ..addAll(items);
      return items;
    } catch (_) {
      return List<SavedSplitFile>.from(_memoryHistory);
    }
  }

  Future<void> deleteSavedSplit(SavedSplitFile item) async {
    try {
      final f = File(item.filePath);
      if (await f.exists()) {
        await f.delete();
      }
    } catch (_) {}
    _memoryHistory.removeWhere((e) => e.id == item.id);
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawList = prefs.getStringList(_historyPrefsKey) ?? [];
      rawList.removeWhere((raw) {
        try {
          return SavedSplitFile.fromJson(raw).id == item.id;
        } catch (_) {
          return false;
        }
      });
      await prefs.setStringList(_historyPrefsKey, rawList);
    } catch (_) {}
  }

  Future<void> _prependToHistory(SavedSplitFile record) async {
    _memoryHistory.removeWhere((e) => e.id == record.id);
    _memoryHistory.insert(0, record);
    if (_memoryHistory.length > 50) {
      _memoryHistory.removeRange(50, _memoryHistory.length);
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawList = prefs.getStringList(_historyPrefsKey) ?? [];
      rawList.insert(0, record.toJson());
      if (rawList.length > 50) {
        rawList.removeRange(50, rawList.length);
      }
      await prefs.setStringList(_historyPrefsKey, rawList);
    } catch (_) {}
  }

  String _sanitizeFileName(String input) {
    final cleaned = input
        .trim()
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
        .replaceAll(RegExp(r'\s+'), '_');
    return cleaned.isEmpty ? 'split_document.pdf' : cleaned;
  }
}

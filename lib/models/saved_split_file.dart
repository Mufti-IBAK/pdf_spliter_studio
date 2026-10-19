import 'dart:convert';

/// Metadata for a split PDF file saved on the device.
class SavedSplitFile {
  final String id;
  final String fileName;
  final String filePath;
  final String? downloadPath;
  final String sourceFileName;
  final String rangeSummary;
  final int pageCount;
  final int fileSizeBytes;
  final DateTime createdAt;
  final bool isMergedOutput;

  const SavedSplitFile({
    required this.id,
    required this.fileName,
    required this.filePath,
    this.downloadPath,
    required this.sourceFileName,
    required this.rangeSummary,
    required this.pageCount,
    required this.fileSizeBytes,
    required this.createdAt,
    this.isMergedOutput = false,
  });

  String get formattedSize {
    if (fileSizeBytes < 1024) return '$fileSizeBytes B';
    final kb = fileSizeBytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    final mb = kb / 1024;
    return '${mb.toStringAsFixed(2)} MB';
  }

  SavedSplitFile copyWith({
    String? filePath,
    String? downloadPath,
  }) {
    return SavedSplitFile(
      id: id,
      fileName: fileName,
      filePath: filePath ?? this.filePath,
      downloadPath: downloadPath ?? this.downloadPath,
      sourceFileName: sourceFileName,
      rangeSummary: rangeSummary,
      pageCount: pageCount,
      fileSizeBytes: fileSizeBytes,
      createdAt: createdAt,
      isMergedOutput: isMergedOutput,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'fileName': fileName,
      'filePath': filePath,
      'downloadPath': downloadPath,
      'sourceFileName': sourceFileName,
      'rangeSummary': rangeSummary,
      'pageCount': pageCount,
      'fileSizeBytes': fileSizeBytes,
      'createdAt': createdAt.toIso8601String(),
      'isMergedOutput': isMergedOutput,
    };
  }

  factory SavedSplitFile.fromMap(Map<String, dynamic> map) {
    return SavedSplitFile(
      id: map['id'] as String? ?? '',
      fileName: map['fileName'] as String? ?? 'split.pdf',
      filePath: map['filePath'] as String? ?? '',
      downloadPath: map['downloadPath'] as String?,
      sourceFileName: map['sourceFileName'] as String? ?? 'Document.pdf',
      rangeSummary: map['rangeSummary'] as String? ?? '',
      pageCount: (map['pageCount'] as num?)?.toInt() ?? 1,
      fileSizeBytes: (map['fileSizeBytes'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ??
          DateTime.now(),
      isMergedOutput: map['isMergedOutput'] as bool? ?? false,
    );
  }

  String toJson() => jsonEncode(toMap());

  factory SavedSplitFile.fromJson(String source) =>
      SavedSplitFile.fromMap(jsonDecode(source) as Map<String, dynamic>);
}

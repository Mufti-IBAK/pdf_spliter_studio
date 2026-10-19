import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';

/// Settings & Ownership Recognition screen featuring configurable Default Save
/// Location on the phone, export defaults, and Plexus Labs & Systems LTD branding.
class SettingsScreen extends StatefulWidget {
  final StorageService storageService;
  final VoidCallback onHistoryChanged;

  const SettingsScreen({
    super.key,
    required this.storageService,
    required this.onHistoryChanged,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const String _prefDefaultMergeKey = 'pref_default_merge_ranges';
  static const String _prefHighResPreviewKey = 'pref_high_res_preview';

  bool _defaultMergeRanges = false;
  bool _highResBoundaryPreview = true;
  String _currentSaveDirPath = '';
  List<SaveLocationOption> _presetLocations = [];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final currentDir = await widget.storageService.getDefaultSaveDirectoryPath();
    final presets = await widget.storageService.getPresetSaveLocations();
    if (!mounted) return;
    setState(() {
      _defaultMergeRanges = prefs.getBool(_prefDefaultMergeKey) ?? false;
      _highResBoundaryPreview = prefs.getBool(_prefHighResPreviewKey) ?? true;
      _currentSaveDirPath = currentDir;
      _presetLocations = presets;
    });
  }

  Future<void> _selectSaveLocation(String path) async {
    await widget.storageService.setDefaultSaveDirectoryPath(path);
    if (!mounted) return;
    setState(() {
      _currentSaveDirPath = path;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text('Default save location set to: $path'),
      ),
    );
  }

  Future<void> _browseCustomFolder() async {
    final picked = await widget.storageService.pickCustomDirectory();
    if (!mounted) return;
    if (picked != null) {
      setState(() {
        _currentSaveDirPath = picked;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Default save location updated: $picked'),
        ),
      );
    } else {
      // Allow manual path entry if system folder picker was cancelled or unsupported
      await _showEditCustomPathDialog();
    }
  }

  Future<void> _showEditCustomPathDialog() async {
    final controller = TextEditingController(text: _currentSaveDirPath);
    final newPath = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Set Default Save Folder Path',
          style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter the folder path on your device where split PDFs should be saved automatically:',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Folder Path',
                hintText: '/storage/emulated/0/Download/SlicePDF_Studio',
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
            onPressed: () =>
                Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Save Location'),
          ),
        ],
      ),
    );

    if (newPath != null && newPath.isNotEmpty) {
      await _selectSaveLocation(newPath);
    }
  }

  Future<void> _toggleDefaultMerge(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefDefaultMergeKey, value);
    if (!mounted) return;
    setState(() => _defaultMergeRanges = value);
  }

  Future<void> _toggleHighResPreview(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefHighResPreviewKey, value);
    if (!mounted) return;
    setState(() => _highResBoundaryPreview = value);
  }

  Future<void> _clearAllSavedSplits() async {
    final items = await widget.storageService.loadHistory();
    for (final item in items) {
      await widget.storageService.deleteSavedSplit(item);
    }
    widget.onHistoryChanged();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text('Cleared saved split history.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings & About'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Prominent Plexus Labs & Systems LTD Ownership Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F172A), Color(0xFF1E1B4B)],
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
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.asset(
                        'assets/images/logo_smalll.jpg',
                        width: 46,
                        height: 46,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Built by Plexus Labs & Systems LTD',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'SlicePDF Studio • Official Mobile Edition v1.0.0',
                            style: TextStyle(
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
                const Divider(color: Color(0xFF334155), height: 1),
                const SizedBox(height: 12),
                const Text(
                  'Designed and engineered by Plexus Labs & Systems LTD for high-speed, 100% offline PDF range extraction, boundary verification, and lossless document management on Android and iOS.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Default Save Location Configuration Section
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'DEFAULT SAVE LOCATION',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppTheme.textSecondary,
                letterSpacing: 0.6,
              ),
            ),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: AppTheme.primarySoft,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.folder_special_outlined,
                          size: 18,
                          color: AppTheme.primary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Active Save Folder',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _currentSaveDirPath,
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: AppTheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Choose where split PDFs are automatically saved on your phone:',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Preset location radio tiles
                  ..._presetLocations.map((loc) {
                    final isSelected = _currentSaveDirPath == loc.path;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => _selectSaveLocation(loc.path),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppTheme.primarySoft
                                : AppTheme.surfaceBg,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected
                                  ? AppTheme.primary
                                  : AppTheme.borderSubtle,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isSelected
                                    ? Icons.radio_button_checked_rounded
                                    : Icons.radio_button_off_rounded,
                                size: 17,
                                color: isSelected
                                    ? AppTheme.primary
                                    : AppTheme.textMuted,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      loc.title,
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700,
                                        color: isSelected
                                            ? AppTheme.primary
                                            : AppTheme.textPrimary,
                                      ),
                                    ),
                                    Text(
                                      loc.subtitle,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppTheme.textSecondary,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),

                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _browseCustomFolder,
                        icon: const Icon(Icons.create_new_folder_outlined, size: 15),
                        label: const Text('Browse Folder'),
                      ),
                      TextButton.icon(
                        onPressed: _showEditCustomPathDialog,
                        icon: const Icon(Icons.edit_outlined, size: 15),
                        label: const Text('Edit Path Manually'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Export & Preview Preferences Card
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'SPLITTER PREFERENCES',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppTheme.textSecondary,
                letterSpacing: 0.6,
              ),
            ),
          ),
          Card(
            child: Column(
              children: [
                SwitchListTile.adaptive(
                  dense: true,
                  value: _defaultMergeRanges,
                  onChanged: _toggleDefaultMerge,
                  title: const Text(
                    'Default to Merge Multi-Range Splits',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  subtitle: const Text(
                    'When multiple ranges are added, combine them into 1 PDF by default instead of separate PDFs.',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
                const Divider(),
                SwitchListTile.adaptive(
                  dense: true,
                  value: _highResBoundaryPreview,
                  onChanged: _toggleHighResPreview,
                  title: const Text(
                    'Sharp Boundary Verification Previews',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  subtitle: const Text(
                    'Render Start & End page thumbnails at crisp DPI for easy text verification.',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Storage & Data Management
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'STORAGE & LIBRARY',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppTheme.textSecondary,
                letterSpacing: 0.6,
              ),
            ),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Clear Saved Splits Library',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Remove cached split files from the in-app recent history list.',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    onPressed: _clearAllSavedSplits,
                    icon: const Icon(
                      Icons.cleaning_services_outlined,
                      size: 15,
                    ),
                    label: const Text('Clear'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Footer Ownership Stamp
          const Center(
            child: Column(
              children: [
                Text(
                  '© 2026 Plexus Labs & Systems LTD. All rights reserved.',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  '100% Local Processing • Zero Cloud Uploads',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

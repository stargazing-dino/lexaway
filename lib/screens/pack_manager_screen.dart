import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../data/pack_manager.dart';

class PackManagerScreen extends StatefulWidget {
  /// When used as the root screen (first launch), this callback is invoked
  /// instead of Navigator.pop so the parent can load the selected pack.
  final void Function(String lang)? onPackSelected;

  const PackManagerScreen({super.key, this.onPackSelected});

  @override
  State<PackManagerScreen> createState() => _PackManagerScreenState();
}

class _PackManagerScreenState extends State<PackManagerScreen> {
  final _pm = PackManager();
  Manifest? _manifest;
  Map<String, LocalPack> _local = {};
  String? _error;
  final Map<String, double> _downloading = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _local = await _pm.getLocalPacks();
    try {
      _manifest = await _pm.fetchManifest();
      _error = null;
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) setState(() {});
  }

  Future<void> _download(String lang) async {
    if (_downloading.containsKey(lang)) return;
    setState(() => _downloading[lang] = 0);
    try {
      await _pm.downloadPack(lang, onProgress: (p) {
        if (mounted) setState(() => _downloading[lang] = p);
      });
      _local = await _pm.getLocalPacks();
      if (mounted) setState(() => _downloading.remove(lang));
    } catch (e) {
      if (mounted) {
        setState(() {
          _downloading.remove(lang);
          _error = 'Download failed: $e';
        });
      }
    }
  }

  Future<void> _delete(String lang) async {
    await _pm.deletePack(lang);
    _local = await _pm.getLocalPacks();
    if (mounted) setState(() {});
  }

  void _select(String lang) {
    if (widget.onPackSelected != null) {
      widget.onPackSelected!(lang);
    } else {
      Navigator.pop(context, lang);
    }
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: Colors.brown.shade900,
      body: Padding(
        padding: EdgeInsets.only(top: topPadding + 16, bottom: bottomPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  if (Navigator.canPop(context))
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white70),
                      onPressed: () => Navigator.pop(context),
                    ),
                  Text(
                    'Language Packs',
                    style: GoogleFonts.pixelifySans(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Download a pack to start learning',
                style: TextStyle(color: Colors.white54, fontSize: 14),
              ),
            ),
            const SizedBox(height: 20),

            // Error banner
            if (_error != null)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade900.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber, color: Colors.orangeAccent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_error!,
                          style: const TextStyle(color: Colors.white70)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh, color: Colors.white70),
                      onPressed: () {
                        setState(() => _error = null);
                        _load();
                      },
                    ),
                  ],
                ),
              ),

            // Pack list
            Expanded(
              child: _manifest == null && _error == null
                  ? const Center(
                      child:
                          CircularProgressIndicator(color: Colors.white54))
                  : _manifest == null
                      ? const SizedBox.shrink()
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: _manifest!.packs.length,
                          itemBuilder: (context, i) {
                            final pack = _manifest!.packs[i];
                            return _PackTile(
                              pack: pack,
                              local: _local[pack.lang],
                              progress: _downloading[pack.lang],
                              onDownload: () => _download(pack.lang),
                              onDelete: () => _delete(pack.lang),
                              onSelect: () => _select(pack.lang),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PackTile extends StatelessWidget {
  final PackInfo pack;
  final LocalPack? local;
  final double? progress;
  final VoidCallback onDownload;
  final VoidCallback onDelete;
  final VoidCallback onSelect;

  const _PackTile({
    required this.pack,
    required this.local,
    required this.progress,
    required this.onDownload,
    required this.onDelete,
    required this.onSelect,
  });

  bool get _isDownloaded => local != null;
  bool get _isDownloading => progress != null;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.brown.shade800.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _isDownloaded
              ? Colors.green.shade700.withValues(alpha: 0.5)
              : Colors.brown.shade600.withValues(alpha: 0.4),
          width: 2,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: _isDownloaded ? onSelect : null,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.brown.shade700,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        pack.lang.toUpperCase(),
                        style: GoogleFonts.pixelifySans(
                          color: Colors.white70,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            pack.name,
                            style: GoogleFonts.pixelifySans(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (_isDownloaded)
                            Text(
                              '${(local!.sizeBytes / 1024 / 1024).toStringAsFixed(1)} MB',
                              style: const TextStyle(
                                  color: Colors.white38, fontSize: 12),
                            ),
                        ],
                      ),
                    ),
                    _buildAction(),
                  ],
                ),
                if (_isDownloading) ...[
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: Colors.brown.shade700,
                      valueColor: AlwaysStoppedAnimation(Colors.green.shade400),
                      minHeight: 6,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAction() {
    if (_isDownloading) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
            strokeWidth: 2, color: Colors.white54),
      );
    }
    if (_isDownloaded) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 22),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(Icons.delete_outline,
                color: Colors.white.withValues(alpha: 0.4), size: 20),
            onPressed: onDelete,
          ),
        ],
      );
    }
    return IconButton(
      icon: const Icon(Icons.download_rounded,
          color: Colors.white70, size: 28),
      onPressed: onDownload,
    );
  }
}

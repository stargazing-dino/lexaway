import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../data/pack_manager.dart';
import '../data/tts_manager.dart';
import '../providers.dart';

class PackManagerScreen extends ConsumerStatefulWidget {
  const PackManagerScreen({super.key});

  @override
  ConsumerState<PackManagerScreen> createState() => _PackManagerScreenState();
}

class _PackManagerScreenState extends ConsumerState<PackManagerScreen> {
  /// Endonyms — language names in their own language. Always display these
  /// regardless of the current UI locale.
  static const _endonyms = {'en': 'English', 'es': 'Español'};

  void _showLocalePicker(BuildContext context) {
    // Resolve what "System default" would actually give the user.
    final systemLang =
        WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    final systemEndonym = _endonyms[systemLang] ?? _endonyms['en']!;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.brown.shade800,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        // Consumer so the checkmark stays reactive (#1 fix).
        return Consumer(
          builder: (ctx, ref, _) {
            final current = ref.watch(localeProvider);
            final l10n = AppLocalizations.of(context)!;
            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Globe icon instead of localized text — universally
                  // recognizable even if the user is stuck in the wrong
                  // language (#5 fix).
                  const Padding(
                    padding: EdgeInsets.fromLTRB(20, 16, 20, 4),
                    child: Icon(
                      Icons.language,
                      color: Colors.white70,
                      size: 32,
                    ),
                  ),
                  // System default — show resolved endonym as subtitle so
                  // it's understandable regardless of current UI language.
                  _LocaleOption(
                    label: l10n.systemDefault,
                    subtitle: systemEndonym,
                    selected: current == null,
                    onTap: () {
                      ref.read(localeProvider.notifier).setLocale(null);
                      Navigator.pop(ctx);
                    },
                  ),
                  // Each supported locale
                  for (final locale in AppLocalizations.supportedLocales)
                    _LocaleOption(
                      label:
                          _endonyms[locale.languageCode] ?? locale.languageCode,
                      selected: current?.languageCode == locale.languageCode,
                      onTap: () {
                        ref.read(localeProvider.notifier).setLocale(locale);
                        Navigator.pop(ctx);
                      },
                    ),
                  const SizedBox(height: 8),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showError(String message, {VoidCallback? onRetry}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 10),
        action: onRetry != null
            ? SnackBarAction(
                label: AppLocalizations.of(context)!.retry,
                onPressed: onRetry,
              )
            : null,
      ),
    );
  }

  Future<void> _download(String lang) async {
    final includeVoice = ref.read(includeVoiceProvider(lang));
    try {
      await ref
          .read(localPacksProvider.notifier)
          .download(lang, includeVoice: includeVoice);
    } catch (e) {
      if (mounted) {
        _showError(
          AppLocalizations.of(context)!.downloadFailed(e.toString()),
          onRetry: () => _download(lang),
        );
      }
    }
  }

  Future<void> _downloadVoice(String lang) async {
    try {
      await ref.read(localPacksProvider.notifier).downloadVoice(lang);
    } catch (e) {
      if (mounted) {
        _showError(
          AppLocalizations.of(context)!.downloadFailed(e.toString()),
          onRetry: () => _downloadVoice(lang),
        );
      }
    }
  }

  Future<void> _delete(String lang) async {
    await ref.read(localPacksProvider.notifier).delete(lang);
  }

  Future<void> _select(String lang) async {
    await ref.read(activePackProvider.notifier).switchPack(lang);
    if (mounted) context.go('/game');
  }

  @override
  void initState() {
    super.initState();
    ref.listenManual(manifestProvider, (_, next) {
      if (next.hasError && mounted) {
        _showError(
          '${next.error}',
          onRetry: () => ref.invalidate(manifestProvider),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final manifest = ref.watch(manifestProvider);
    final localPacks = ref.watch(localPacksProvider);
    final local = localPacks.valueOrNull ?? {};

    return Scaffold(
      backgroundColor: Colors.brown.shade900,
      appBar: AppBar(
        backgroundColor: Colors.brown.shade900,
        foregroundColor: Colors.white70,
        title: Text(AppLocalizations.of(context)!.packManagerTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.language),
            tooltip: AppLocalizations.of(context)!.appLanguage,
            onPressed: () => _showLocalePicker(context),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              AppLocalizations.of(context)!.packManagerSubtitle,
              style: TextStyle(color: Colors.white54, fontSize: 14),
            ),
          ),
          const SizedBox(height: 20),

          // Pack list
          Expanded(
            child: manifest.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: Colors.white54),
              ),
              error: (_, __) => const SizedBox.shrink(),
              data: (m) => ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: m.packs.length,
                itemBuilder: (context, i) {
                  final pack = m.packs[i];
                  return _PackTile(
                    pack: pack,
                    local: local[pack.lang],
                    packProgress: ref.watch(
                      downloadProgressProvider(pack.lang),
                    ),
                    voiceProgress: ref.watch(
                      voiceDownloadProgressProvider(pack.lang),
                    ),
                    voiceDownloaded: ref.watch(ttsManagerProvider)
                        .isModelDownloaded(pack.lang),
                    includeVoice: ref.watch(includeVoiceProvider(pack.lang)),
                    onToggleVoice: (value) {
                      ref.read(includeVoiceProvider(pack.lang).notifier).state =
                          value;
                    },
                    onDownload: () => _download(pack.lang),
                    onDownloadVoice: () => _downloadVoice(pack.lang),
                    onDelete: () => _delete(pack.lang),
                    onSelect: () => _select(pack.lang),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PackTile extends StatelessWidget {
  final PackInfo pack;
  final LocalPack? local;
  final double? packProgress;
  final double? voiceProgress;
  final bool voiceDownloaded;
  final bool includeVoice;
  final ValueChanged<bool> onToggleVoice;
  final VoidCallback onDownload;
  final VoidCallback onDownloadVoice;
  final VoidCallback onDelete;
  final VoidCallback onSelect;

  const _PackTile({
    required this.pack,
    required this.local,
    required this.packProgress,
    required this.voiceProgress,
    required this.voiceDownloaded,
    required this.includeVoice,
    required this.onToggleVoice,
    required this.onDownload,
    required this.onDownloadVoice,
    required this.onDelete,
    required this.onSelect,
  });

  bool get _isDownloaded => local != null;
  bool get _hasVoiceSupport => TtsManager.isSupported(pack.lang);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
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
      child: Column(
        children: [
          // -- Sentences row (primary, always present) --
          _ContentRow(
            icon: Icons.text_snippet_outlined,
            label: AppLocalizations.of(context)!.sentences,
            sizeText: _isDownloaded ? _formatMB(local!.sizeBytes) : null,
            downloaded: _isDownloaded,
            progress: packProgress,
            onTap: _isDownloaded ? onSelect : onDownload,
            trailing: _buildSentencesTrailing(),
            // Top row gets the language badge
            leading: Container(
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
            title: pack.name,
          ),
          // -- Voice row (optional, only if TTS is supported) --
          if (_hasVoiceSupport) ...[
            Divider(
              height: 1,
              thickness: 1,
              color: Colors.brown.shade700.withValues(alpha: 0.6),
            ),
            _ContentRow(
              icon: Icons.volume_up_rounded,
              label: AppLocalizations.of(context)!.voice,
              sizeText:
                  '~${ttsModelRegistry[pack.lang]!.approximateSizeMB} MB',
              downloaded: voiceDownloaded,
              progress: voiceProgress,
              onTap: !_isDownloaded && !voiceDownloaded
                  ? () => onToggleVoice(!includeVoice)
                  : null,
              trailing: _buildVoiceTrailing(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSentencesTrailing() {
    if (packProgress != null) {
      return const SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54),
      );
    }
    if (_isDownloaded) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 20),
          const SizedBox(width: 4),
          IconButton(
            icon: Icon(
              Icons.delete_outline,
              color: Colors.white.withValues(alpha: 0.4),
              size: 18,
            ),
            visualDensity: VisualDensity.compact,
            onPressed: onDelete,
          ),
        ],
      );
    }
    return IconButton(
      icon: const Icon(Icons.download_rounded, color: Colors.white70, size: 24),
      visualDensity: VisualDensity.compact,
      onPressed: onDownload,
    );
  }

  Widget _buildVoiceTrailing() {
    if (voiceProgress != null) {
      return Padding(
        padding: const EdgeInsets.all(8),
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            value: voiceProgress,
            color: Colors.white54,
            backgroundColor: Colors.brown.shade700,
          ),
        ),
      );
    }
    if (voiceDownloaded) {
      return const Padding(
        padding: EdgeInsets.all(8),
        child: Icon(Icons.check_circle, color: Colors.green, size: 20),
      );
    }
    // Sentences installed but voice isn't — show download button
    if (_isDownloaded) {
      return IconButton(
        icon: Icon(
          Icons.download_rounded,
          color: Colors.white.withValues(alpha: 0.5),
          size: 22,
        ),
        visualDensity: VisualDensity.compact,
        onPressed: onDownloadVoice,
      );
    }
    // Nothing installed yet — toggle inclusion for bundled download
    return GestureDetector(
      onTap: () => onToggleVoice(!includeVoice),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: includeVoice
                  ? Colors.amber.shade600
                  : Colors.white.withValues(alpha: 0.25),
              width: 2,
            ),
            color: includeVoice ? Colors.amber.shade600 : Colors.transparent,
          ),
          child: includeVoice
              ? const Icon(Icons.check, size: 14, color: Colors.white)
              : null,
        ),
      ),
    );
  }

  String _formatMB(int bytes) =>
      '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
}

/// A single content-type row within a pack card.
class _ContentRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? sizeText;
  final bool downloaded;
  final double? progress;
  final VoidCallback? onTap;
  final Widget trailing;
  final Widget? leading;
  final String? title;

  const _ContentRow({
    required this.icon,
    required this.label,
    required this.sizeText,
    required this.downloaded,
    required this.progress,
    required this.onTap,
    required this.trailing,
    this.leading,
    this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Column(
            children: [
              Row(
                children: [
                  if (leading != null) ...[
                    leading!,
                    const SizedBox(width: 14),
                  ] else
                    // Indent to align with rows that have a leading badge
                    const SizedBox(width: 58),
                  Icon(icon, color: Colors.white38, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (title != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Text(
                              title!,
                              style: GoogleFonts.pixelifySans(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        Row(
                          children: [
                            Text(
                              label,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.5),
                                fontSize: 13,
                              ),
                            ),
                            if (sizeText != null) ...[
                              const SizedBox(width: 8),
                              Text(
                                sizeText!,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.25),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  trailing,
                ],
              ),
              // Progress bar
              if (progress != null) ...[
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.brown.shade700,
                    valueColor: AlwaysStoppedAnimation(Colors.amber.shade600),
                    minHeight: 4,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _LocaleOption extends StatelessWidget {
  final String label;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _LocaleOption({
    required this.label,
    this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(
        label,
        style: TextStyle(
          color: selected ? Colors.white : Colors.white70,
          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      subtitle: subtitle != null
          ? Text(subtitle!, style: const TextStyle(color: Colors.white38))
          : null,
      trailing: selected
          ? const Icon(Icons.check, color: Colors.green, size: 20)
          : null,
      onTap: onTap,
    );
  }
}

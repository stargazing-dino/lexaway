import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../game/egg_preview_game.dart';
import '../l10n/app_localizations.dart';
import '../models/character.dart';
import '../providers.dart';

class EggSelectionScreen extends ConsumerStatefulWidget {
  const EggSelectionScreen({super.key});

  @override
  ConsumerState<EggSelectionScreen> createState() => _EggSelectionScreenState();
}

class _EggSelectionScreenState extends ConsumerState<EggSelectionScreen>
    with SingleTickerProviderStateMixin {
  /// The character names are chosen once; switching gender keeps the same names
  /// but swaps the sprite set.
  late List<String> _eggNames;
  late List<CharacterInfo> _eggs;
  final Map<int, EggPreviewGame> _games = {};
  int? _selected;
  bool _hatching = false;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    // Pick 3 names that are valid for both genders so toggling works.
    final pool = CharacterRegistry.allNames
        .where((n) => !CharacterRegistry.incompleteMale.contains(n))
        .toList()
      ..shuffle();
    _eggNames = pool.take(3).toList();
    _rebuildGames();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  void _rebuildGames() {
    final gender = ref.read(genderProvider);
    _eggs = _eggNames
        .map((n) => CharacterInfo(name: n, gender: gender))
        .toList();
    _games.clear();
    _selected = null;
    _hatching = false;
    _fadeController.reset();
    for (var i = 0; i < _eggs.length; i++) {
      _games[i] = EggPreviewGame(character: _eggs[i]);
    }
  }

  void _onEggTapped(int index) {
    if (_hatching) return;
    setState(() {
      _selected = index;
      _hatching = true;
    });

    // Fade out the others
    _fadeController.forward();

    // Start the hatch sequence on the selected egg
    final game = _games[index]!;
    game.onAllPhasesComplete = _onHatchComplete;
    game.startHatchSequence();
  }

  void _onHatchComplete() {
    if (!mounted || _selected == null) return;
    final lang = ref.read(activePackProvider.notifier).activeLang;
    if (lang == null) return;

    final character = _eggs[_selected!];
    ref.read(hiveBoxProvider).put('character_$lang', character.key);

    // Brief pause to admire the new dino, then go
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) context.go('/game');
    });
  }

  void _onGenderChanged(String gender) {
    ref.read(genderProvider.notifier).set(gender);
    setState(_rebuildGames);
  }

  @override
  Widget build(BuildContext context) {
    final gender = ref.watch(genderProvider);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Colors.brown.shade900,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 32),

            // Title
            Text(
              l10n.chooseYourEgg,
              style: GoogleFonts.pixelifySans(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.whoWillHatch,
              style: GoogleFonts.pixelifySans(
                color: Colors.white54,
                fontSize: 16,
              ),
            ),

            const SizedBox(height: 24),

            // Gender toggle
            if (!_hatching)
              _GenderToggle(
                selected: gender,
                onChanged: _onGenderChanged,
              ),

            // Egg area – eggs drift to centre when one is selected
            Expanded(
              child: Stack(
                children: List.generate(_eggs.length, (i) {
                  final isSelected = _selected == i;
                  final shouldFade = _selected != null && !isSelected;

                  // Spread eggs horizontally; selected one slides to centre
                  final dx = (i - (_eggs.length - 1) / 2) * 0.6;
                  final alignment = _hatching && isSelected
                      ? Alignment.center
                      : Alignment(dx, 0);

                  return AnimatedAlign(
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeInOut,
                    alignment: alignment,
                    child: AnimatedBuilder(
                      animation: _fadeAnimation,
                      builder: (context, child) {
                        final opacity =
                            shouldFade ? 1.0 - _fadeAnimation.value : 1.0;
                        return Opacity(opacity: opacity, child: child);
                      },
                      child: GestureDetector(
                        onTap: _hatching ? null : () => _onEggTapped(i),
                        child: SizedBox(
                          width: 96,
                          height: 96,
                          child: GameWidget(
                            game: _games[i]!,
                            backgroundBuilder: (_) =>
                                const SizedBox.shrink(),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GenderToggle extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;

  const _GenderToggle({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _GenderButton(
          label: '\u2640',
          value: 'female',
          selected: selected == 'female',
          onTap: () => onChanged('female'),
        ),
        const SizedBox(width: 12),
        _GenderButton(
          label: '\u2642',
          value: 'male',
          selected: selected == 'male',
          onTap: () => onChanged('male'),
        ),
      ],
    );
  }
}

class _GenderButton extends StatelessWidget {
  final String label;
  final String value;
  final bool selected;
  final VoidCallback onTap;

  const _GenderButton({
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: selected
              ? Colors.brown.shade600
              : Colors.brown.shade800.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? Colors.amber.shade300.withValues(alpha: 0.6)
                : Colors.brown.shade600.withValues(alpha: 0.3),
            width: 2,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 24,
            color: selected ? Colors.white : Colors.white54,
          ),
        ),
      ),
    );
  }
}

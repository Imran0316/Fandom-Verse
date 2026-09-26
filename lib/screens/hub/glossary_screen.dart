import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../data/fan_hub_data.dart';

/// Searchable A–Z glossary of fandom terms.
///
/// Pass [terms] in tests to swap the built-in vocabulary.
class GlossaryScreen extends StatefulWidget {
  const GlossaryScreen({super.key, this.terms});

  final List<GlossaryTerm>? terms;

  @override
  State<GlossaryScreen> createState() => _GlossaryScreenState();
}

class _GlossaryScreenState extends State<GlossaryScreen> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<GlossaryTerm> get _filtered {
    final all = widget.terms ?? kGlossaryTerms;
    if (_query.isEmpty) return all;
    final q = _query.toLowerCase();
    return all
        .where((t) =>
            t.term.toLowerCase().contains(q) ||
            t.definition.toLowerCase().contains(q) ||
            t.category.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final terms = _filtered;
    final grouped = <String, List<GlossaryTerm>>{};
    for (final t in terms) {
      grouped.putIfAbsent(t.letter, () => []).add(t);
    }
    final letters = grouped.keys.toList()..sort();

    return Scaffold(
      backgroundColor: AppColors.backgroundDeep,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 16, 8),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        style: IconButton.styleFrom(
                          backgroundColor:
                              Colors.white.withValues(alpha: 0.08),
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                      const Expanded(
                        child: Text(
                          'Fandom Glossary',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Text(
                        '${(widget.terms ?? kGlossaryTerms).length} terms',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: _controller,
                    onChanged: (v) => setState(() => _query = v.trim()),
                    style: const TextStyle(color: Colors.white),
                    cursorColor: AppColors.accent,
                    decoration: InputDecoration(
                      hintText: 'Search a term or meaning...',
                      hintStyle: const TextStyle(color: AppColors.textMuted),
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        color: AppColors.textMuted,
                      ),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              onPressed: () {
                                _controller.clear();
                                setState(() => _query = '');
                              },
                              icon: const Icon(
                                Icons.close_rounded,
                                color: AppColors.textSecondary,
                              ),
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: terms.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(32),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.search_off_rounded,
                                  size: 52,
                                  color: AppColors.textMuted,
                                ),
                                SizedBox(height: 14),
                                Text(
                                  'No terms found',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                SizedBox(height: 6),
                                Text(
                                  'Try a shorter word — "ship", "canon", "con".',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                          physics: const BouncingScrollPhysics(),
                          children: [
                            for (final letter in letters) ...[
                              Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(4, 12, 0, 6),
                                child: Text(
                                  letter,
                                  style: const TextStyle(
                                    color: AppColors.accent,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              for (final t in grouped[letter]!)
                                _TermCard(term: t),
                            ],
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TermCard extends StatelessWidget {
  const _TermCard({required this.term});

  final GlossaryTerm term;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  term.term,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  term.category,
                  style: const TextStyle(
                    color: AppColors.accent,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            term.definition,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

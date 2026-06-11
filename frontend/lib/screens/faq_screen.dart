import 'package:flutter/material.dart';
import '../models/faq.dart';
import '../services/profile_service.dart';
import '../l10n/app_localizations.dart';
import '../providers/app_settings.dart';

class FAQScreen extends StatefulWidget {
  const FAQScreen({Key? key}) : super(key: key);

  @override
  _FAQScreenState createState() => _FAQScreenState();
}

class _FAQScreenState extends State<FAQScreen> {
  final _profileService = ProfileService();
  final _searchCtrl = TextEditingController();

  List<FAQ> _allFAQs = [];
  List<FAQ> _filteredFAQs = [];
  bool _loading = true;
  int? _openIndex;

  @override
  void initState() {
    super.initState();
    _loadFAQs();
    _searchCtrl.addListener(_filterFAQs);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadFAQs() async {
    try {
      final faqs = await _profileService.fetchFAQs();
      if (mounted) {
        setState(() {
          _allFAQs = faqs;
          _filteredFAQs = faqs;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _filterFAQs() {
    final query = _searchCtrl.text.toLowerCase();
    setState(() {
      _openIndex = null;
      _filteredFAQs = query.isEmpty
          ? _allFAQs
          : _allFAQs.where((f) =>
              f.question.toLowerCase().contains(query) ||
              (f.questionAr?.toLowerCase().contains(query) ?? false) ||
              f.answer.toLowerCase().contains(query) ||
              (f.answerAr?.toLowerCase().contains(query) ?? false)).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppSettings.instance,
      builder: (context, _) {
        final l = AppLocalizations.of(context);
        final lang = AppSettings.instance.locale.languageCode;
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final primary = Theme.of(context).colorScheme.primary;

        return Column(
          children: [
            // ── Header ──────────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [const Color(0xFF1A1A2E), const Color(0xFF2D1B69)]
                      : [const Color(0xFF6A1B9A), const Color(0xFF9C27B0)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                children: [
                  Text(
                    l.t('faq_title'),
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 4),
                  Text(l.t('faq_subtitle'), style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13)),
                  const SizedBox(height: 16),
                  // Search bar
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextField(
                      controller: _searchCtrl,
                      style: const TextStyle(color: Colors.black87),
                      decoration: InputDecoration(
                        hintText: l.t('search_faq'),
                        hintStyle: const TextStyle(color: Colors.grey),
                        prefixIcon: const Icon(Icons.search, color: Colors.grey),
                        suffixIcon: _searchCtrl.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, color: Colors.grey),
                                onPressed: () { _searchCtrl.clear(); _filterFAQs(); },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── FAQ List ─────────────────────────────────────────────────────
            Expanded(
              child: _loading
                  ? Center(child: CircularProgressIndicator(color: primary))
                  : _filteredFAQs.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.search_off, size: 64, color: Colors.grey.shade300),
                              const SizedBox(height: 12),
                              Text(l.t('no_faqs'), style: TextStyle(color: Colors.grey.shade400, fontSize: 16)),
                            ],
                          ),
                        )
                      : ListView(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          children: [
                            ..._filteredFAQs.asMap().entries.map((entry) {
                              final idx = entry.key;
                              final faq = entry.value;
                              return _FAQItem(
                                faq: faq,
                                lang: lang,
                                isOpen: _openIndex == idx,
                                onToggle: () {
                                  setState(() => _openIndex = _openIndex == idx ? null : idx);
                                },
                                isDark: isDark,
                                primary: primary,
                              );
                            }).toList(),
                            const SizedBox(height: 12),
                            // Contact Support
                            _ContactSupportCard(l: l, isDark: isDark, primary: primary),
                            const SizedBox(height: 24),
                          ],
                        ),
            ),
          ],
        );
      },
    );
  }
}

class _FAQItem extends StatelessWidget {
  final FAQ faq;
  final String lang;
  final bool isOpen;
  final VoidCallback onToggle;
  final bool isDark;
  final Color primary;

  const _FAQItem({
    required this.faq,
    required this.lang,
    required this.isOpen,
    required this.onToggle,
    required this.isDark,
    required this.primary,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isOpen ? primary.withOpacity(0.5) : Colors.transparent,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.06),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Column(
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onToggle,
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          faq.localizedQuestion(lang),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: isOpen ? primary : null,
                          ),
                        ),
                      ),
                      AnimatedRotation(
                        turns: isOpen ? 0.5 : 0,
                        duration: const Duration(milliseconds: 250),
                        child: Icon(Icons.keyboard_arrow_down, color: isOpen ? primary : Colors.grey.shade400),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  children: [
                    Divider(color: Colors.grey.shade200, height: 1),
                    const SizedBox(height: 12),
                    Text(
                      faq.localizedAnswer(lang),
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                        height: 1.55,
                      ),
                    ),
                  ],
                ),
              ),
              crossFadeState: isOpen ? CrossFadeState.showSecond : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 250),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContactSupportCard extends StatelessWidget {
  final AppLocalizations l;
  final bool isDark;
  final Color primary;

  const _ContactSupportCard({required this.l, required this.isDark, required this.primary});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primary.withOpacity(0.85), primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.headset_mic_outlined, color: Colors.white, size: 36),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.t('contact_support'), style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                Text(l.t('contact_support_sub'), style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13)),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
        ],
      ),
    );
  }
}

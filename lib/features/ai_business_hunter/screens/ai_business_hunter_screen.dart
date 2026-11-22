import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';
import '../../../widgets/shared/app_bar_actions.dart';
import '../../../widgets/shared/app_shell.dart';
import '../data/hunter_repository.dart';
import '../models/hunter_models.dart';

final hunterRepoProvider =
    Provider<HunterRepository>((ref) => HunterRepository());

class AiBusinessHunterScreen extends ConsumerStatefulWidget {
  const AiBusinessHunterScreen({super.key});

  @override
  ConsumerState<AiBusinessHunterScreen> createState() =>
      _AiBusinessHunterScreenState();
}

class _AiBusinessHunterScreenState
    extends ConsumerState<AiBusinessHunterScreen> {
  final _industryCtrl = TextEditingController();
  final _productsCtrl = TextEditingController();
  final _countriesCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isStarting = false;
  String? _jobId;
  String? _startError;

  @override
  void dispose() {
    _industryCtrl.dispose();
    _productsCtrl.dispose();
    _countriesCtrl.dispose();
    super.dispose();
  }

  Future<void> _startSearch() async {
    if (_isStarting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();

    setState(() {
      _isStarting = true;
      _startError = null;
    });

    try {
      final repo = ref.read(hunterRepoProvider);

      // ← جلب اللغة الحالية من التطبيق
      final currentLang = context.locale.languageCode;

      final jobId = await repo.startHunt(
        industry: _industryCtrl.text.trim(),
        products: _splitComma(_productsCtrl.text),
        countries: _splitComma(_countriesCtrl.text),
        language: currentLang, // ← تمرير اللغة
      );

      if (!mounted) return;
      setState(() {
        _jobId = jobId;
        _isStarting = false;
      });
    } on HunterException catch (e) {
      if (!mounted) return;
      setState(() {
        _startError = e.message;
        _isStarting = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _startError = 'Something went wrong. Please try again.';
        _isStarting = false;
      });
    }
  }

  void _resetForm() {
    setState(() {
      _jobId = null;
      _startError = null;
      _isStarting = false;
    });
  }

  List<String> _splitComma(String s) =>
      s.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 900;

    return AppShell(
      currentRoute: '/ai-business-hunter',
      child: Scaffold(
        appBar: AppBar(
          title: Text('ai_business_hunter'.tr()),
          automaticallyImplyLeading: false,
          leading: !isWide
              ? Builder(
                  builder: (context) => IconButton(
                    icon: const Icon(Icons.menu),
                    onPressed: () => Scaffold.of(context).openDrawer(),
                  ),
                )
              : null,
          actions: const [AppBarActions()],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_jobId == null && !_isStarting) _buildForm(),
                    if (_startError != null) _buildStartError(),
                    if (_isStarting) _buildStartingLoader(),
                    if (_jobId != null) _buildResults(_jobId!),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.radar, color: AppColors.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'hunter_start_new'.tr(),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _industryCtrl,
                decoration: InputDecoration(
                  labelText: 'hunter_industry_label'.tr(),
                  hintText: 'hunter_industry_hint'.tr(),
                  prefixIcon: const Icon(Icons.factory_outlined),
                ),
                validator: (v) => (v?.trim() ?? '').length < 3
                    ? 'hunter_err_industry'.tr()
                    : null,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _productsCtrl,
                decoration: InputDecoration(
                  labelText: 'hunter_products_label'.tr(),
                  hintText: 'hunter_products_hint'.tr(),
                  helperText: 'hunter_products_helper'.tr(),
                  prefixIcon: const Icon(Icons.inventory_2_outlined),
                ),
                validator: (v) => _splitComma(v ?? '').isEmpty
                    ? 'hunter_err_products'.tr()
                    : null,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _countriesCtrl,
                decoration: InputDecoration(
                  labelText: 'hunter_countries_label'.tr(),
                  hintText: 'hunter_countries_hint'.tr(),
                  helperText: 'hunter_countries_helper'.tr(),
                  prefixIcon: const Icon(Icons.public),
                ),
                validator: (v) => _splitComma(v ?? '').isEmpty
                    ? 'hunter_err_countries'.tr()
                    : null,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _startSearch(),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _startSearch,
                  icon: const Icon(Icons.rocket_launch),
                  label: Text('hunter_start_button'.tr()),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStartingLoader() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            const SizedBox(
              width: 56,
              height: 56,
              child: CircularProgressIndicator(strokeWidth: 4),
            ),
            const SizedBox(height: 20),
            Text(
              'hunter_generating_queries'.tr(),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'hunter_generating_queries_hint'.tr(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondaryLight,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStartError() {
    return Card(
      color: AppColors.warning.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.error_outline,
                    color: AppColors.warning, size: 24),
                const SizedBox(width: 8),
                Text(
                  'hunter_start_failed'.tr(),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _startError ?? '',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondaryLight,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => setState(() => _startError = null),
                  child: Text('common_dismiss'.tr()),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _startSearch,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: Text('common_retry'.tr()),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResults(String jobId) {
    final repo = ref.read(hunterRepoProvider);
    return StreamBuilder<HunterJob>(
      stream: repo.watchJob(jobId),
      builder: (context, jobSnap) {
        if (jobSnap.hasError) return _buildJobError(jobSnap.error);
        if (!jobSnap.hasData) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final job = jobSnap.data!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _JobProgressCard(job: job, onReset: _resetForm),
            if (job.hasFailed) _buildFailureCard(job),
            if (job.leadsCount > 0 || job.isCompleted) ...[
              const SizedBox(height: 20),
              _buildLeadsSection(repo, job),
            ],
          ],
        );
      },
    );
  }

  Widget _buildJobError(Object? error) {
    return Card(
      color: AppColors.warning.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Icon(Icons.cloud_off, size: 40, color: AppColors.warning),
            const SizedBox(height: 8),
            Text('hunter_connection_error'.tr()),
            const SizedBox(height: 4),
            Text(
              error?.toString() ?? 'Unknown error',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondaryLight,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _resetForm,
              icon: const Icon(Icons.refresh),
              label: Text('hunter_new_search'.tr()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFailureCard(HunterJob job) {
    return Card(
      color: AppColors.warning.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.error_outline,
                    color: AppColors.warning, size: 20),
                const SizedBox(width: 8),
                Text(
                  'hunter_failed'.tr(),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
            if (job.errorMessage != null) ...[
              const SizedBox(height: 6),
              Text(
                job.errorMessage!,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondaryLight,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLeadsSection(HunterRepository repo, HunterJob job) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'hunter_found_leads'.tr(args: ['${job.leadsCount}']),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 8),
            if (job.isActive)
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary.withValues(alpha: 0.6),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        StreamBuilder<List<HunterLead>>(
          stream: repo.watchLeads(job.id),
          builder: (context, leadSnap) {
            if (leadSnap.hasError) {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('hunter_leads_error'.tr()),
                ),
              );
            }
            if (!leadSnap.hasData) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final leads = leadSnap.data!;
            if (leads.isEmpty) {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'hunter_searching_leads'.tr(),
                          style: const TextStyle(
                            color: AppColors.textSecondaryLight,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }
            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: leads.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) =>
                  _LeadCard(lead: leads[i], repo: repo),
            );
          },
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════
// JOB PROGRESS CARD
// ═══════════════════════════════════════════════════
class _JobProgressCard extends StatelessWidget {
  final HunterJob job;
  final VoidCallback onReset;

  const _JobProgressCard({required this.job, required this.onReset});

  Color _stageColor() {
    if (job.hasFailed) return AppColors.warning;
    if (job.isCompleted) return AppColors.success;
    return AppColors.primary;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: _stageColor(),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${job.stageLabel} • ${job.progress}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                // ✅ FIX: spread form for multi-line if
                if (job.isTerminal) ...[
                  TextButton.icon(
                    onPressed: onReset,
                    icon: const Icon(Icons.add, size: 16),
                    label: Text(
                      'hunter_new_search'.tr(),
                      style: const TextStyle(fontSize: 12),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.white.withValues(alpha: 0.15),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: job.progress / 100,
                minHeight: 6,
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                valueColor:
                    const AlwaysStoppedAnimation<Color>(AppColors.secondary),
              ),
            ),
            if (job.providerUsed != null) ...[
              const SizedBox(height: 8),
              Text(
                'AI: ${job.providerUsed}',
                style: const TextStyle(color: Colors.white70, fontSize: 11),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════
// LEAD CARD
// ═══════════════════════════════════════════════════
class _LeadCard extends StatelessWidget {
  final HunterLead lead;
  final HunterRepository repo;

  const _LeadCard({required this.lead, required this.repo});

  Color get _scoreColor {
    switch (lead.scoreTier) {
      case 'hot':
        return AppColors.success;
      case 'warm':
        return AppColors.info;
      case 'cold':
        return AppColors.warning;
      default:
        return AppColors.textSecondaryLight;
    }
  }

  Future<void> _openUrl(String? url) async {
    if (url == null || url.isEmpty) return;
    final uri = Uri.tryParse(url.startsWith('http') ? url : 'https://$url');
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: _scoreColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${lead.score}',
                    style: TextStyle(
                      color: _scoreColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lead.companyName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      InkWell(
                        onTap: () => _openUrl(lead.website),
                        child: Text(
                          lead.website ?? lead.sourceUrl,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.info,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                      // ✅ FIX: spread form for multi-line if
                      if (lead.country != null) ...[
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.public,
                                size: 11,
                                color: AppColors.textSecondaryLight,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                lead.country!,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondaryLight,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (lead.scoreReasons.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: lead.scoreReasons
                    .take(4)
                    .map(
                      (r) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.backgroundLight,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          r,
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.textSecondaryLight,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
            if (lead.hasMessage) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.secondary.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.mail_outline,
                          size: 14,
                          color: AppColors.secondary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'hunter_draft_prefix'.tr(),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.secondary,
                          ),
                        ),
                        const Spacer(),
                        InkWell(
                          onTap: () {
                            Clipboard.setData(
                              ClipboardData(text: lead.outreachMessage!),
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('hunter_copied'.tr()),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          },
                          child: const Padding(
                            padding: EdgeInsets.all(4),
                            child: Icon(
                              Icons.copy,
                              size: 14,
                              color: AppColors.textSecondaryLight,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      lead.outreachMessage!,
                      style: const TextStyle(fontSize: 12, height: 1.5),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                // ✅ FIX: spread form for multi-line if
                if (lead.website != null) ...[
                  TextButton.icon(
                    onPressed: () => _openUrl(lead.website),
                    icon: const Icon(Icons.open_in_new, size: 14),
                    label: Text(
                      'hunter_visit'.tr(),
                      style: const TextStyle(fontSize: 11),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
                const Spacer(),
                _LeadStatusButton(lead: lead, repo: repo),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LeadStatusButton extends StatelessWidget {
  final HunterLead lead;
  final HunterRepository repo;

  const _LeadStatusButton({required this.lead, required this.repo});

  @override
  Widget build(BuildContext context) {
    final isSaved = lead.status == 'saved';
    return TextButton.icon(
      onPressed: () async {
        try {
          await repo.updateLeadStatus(lead.id, isSaved ? 'new' : 'saved');
        } catch (_) {
          // ignore — stream will reflect
        }
      },
      icon: Icon(
        isSaved ? Icons.bookmark : Icons.bookmark_border,
        size: 14,
        color: isSaved ? AppColors.secondary : null,
      ),
      label: Text(
        isSaved ? 'hunter_saved'.tr() : 'hunter_save'.tr(),
        style: const TextStyle(fontSize: 11),
      ),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

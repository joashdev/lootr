import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../application/categorization/categorization_rules.dart';
import '../../../application/providers/categorization_rules_provider.dart';
import '../../../application/providers/categories_provider.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/typography.dart';
import '../../../domain/entities/category.dart';
import '../../shared/components/app_snackbar.dart';
import '../../shared/components/empty_state.dart';

class CategorizationRulesScreen extends ConsumerWidget {
  const CategorizationRulesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rulesAsync = ref.watch(categorizationRulesProvider);
    final categories =
        ref.watch(categoriesProvider).asData?.value ?? const <Category>[];

    return Scaffold(
      appBar: AppBar(centerTitle: false, title: const Text('Category Rules')),
      body: rulesAsync.when(
        data: (rules) {
          if (rules.isEmpty) {
            return EmptyState(
              headline: 'No remembered rules',
              subtext:
                  'Choose “Remember this correction” in Add after changing a '
                  'suggested category. Rules never change saved transactions.',
              ctaLabel: 'Back to Settings',
              onCtaPressed: () => Navigator.maybePop(context),
            );
          }
          final categoryNames = {
            for (final category in categories) category.id: category.name,
          };
          return ListView.separated(
            padding: EdgeInsets.only(
              bottom:
                  AppSpacing.bottomNavClearance +
                  MediaQuery.paddingOf(context).bottom,
            ),
            itemCount: rules.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final rule = rules[index];
              return _RuleTile(
                rule: rule,
                categoryName:
                    categoryNames[rule.categoryId] ?? 'Missing category',
                onToggle: rule.isArchived
                    ? null
                    : (active) => ref
                          .read(categorizationRulesCommandsProvider)
                          .setActive(rule.id, active),
                onEdit: rule.isArchived
                    ? null
                    : () => _showRuleSheet(
                        context,
                        ref,
                        categories: categories,
                        initial: rule,
                      ),
                onArchive: rule.isArchived
                    ? null
                    : () => _archiveRule(context, ref, rule),
                onRestore: rule.isArchived
                    ? () => _restoreRule(context, ref, rule)
                    : null,
                onDelete: () => _deleteRule(context, ref, rule),
              );
            },
          );
        },
        error: (error, _) =>
            Center(child: Text('Category rules could not be loaded: $error')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Future<void> _archiveRule(
    BuildContext context,
    WidgetRef ref,
    CategorizationRuleView rule,
  ) async {
    await ref.read(categorizationRulesCommandsProvider).archive(rule.id);
    if (!context.mounted) return;
    AppSnackBar.show(context, 'Rule archived.');
  }

  Future<void> _restoreRule(
    BuildContext context,
    WidgetRef ref,
    CategorizationRuleView rule,
  ) async {
    await ref.read(categorizationRulesCommandsProvider).restore(rule.id);
    if (!context.mounted) return;
    AppSnackBar.show(context, 'Rule restored.');
  }

  Future<void> _deleteRule(
    BuildContext context,
    WidgetRef ref,
    CategorizationRuleView rule,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete rule?'),
        content: Text(
          '“${rule.pattern}” will stop suggesting a category. '
          'Saved transactions will not change.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(categorizationRulesCommandsProvider).delete(rule.id);
    if (!context.mounted) return;
    AppSnackBar.show(context, 'Rule deleted.');
  }
}

class _RuleTile extends StatelessWidget {
  const _RuleTile({
    required this.rule,
    required this.categoryName,
    required this.onToggle,
    required this.onEdit,
    required this.onArchive,
    required this.onRestore,
    required this.onDelete,
  });

  final CategorizationRuleView rule;
  final String categoryName;
  final ValueChanged<bool>? onToggle;
  final VoidCallback? onEdit;
  final VoidCallback? onArchive;
  final VoidCallback? onRestore;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = context.lootrColors;
    final status = rule.isArchived
        ? 'Archived'
        : rule.isActive
        ? 'Active'
        : 'Disabled';
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.pagePaddingMobile,
        vertical: AppSpacing.space1,
      ),
      leading: Icon(
        rule.matchKind == 'exact' ? LucideIcons.equal : LucideIcons.textSearch,
        color: rule.isActive && !rule.isArchived
            ? Theme.of(context).colorScheme.primary
            : colors.textTertiary,
      ),
      title: Text(
        rule.pattern,
        style: AppTypography.bodyMedium,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${_sentenceCase(rule.matchTarget)} · ${rule.matchKind} → '
        '$categoryName\n$status',
        style: AppTypography.caption.copyWith(color: colors.textSecondary),
      ),
      isThreeLine: true,
      trailing: PopupMenuButton<String>(
        tooltip: 'Rule actions',
        onSelected: (action) {
          switch (action) {
            case 'toggle':
              onToggle?.call(!rule.isActive);
            case 'edit':
              onEdit?.call();
            case 'archive':
              onArchive?.call();
            case 'restore':
              onRestore?.call();
            case 'delete':
              onDelete();
          }
        },
        itemBuilder: (_) => [
          if (!rule.isArchived)
            PopupMenuItem(
              value: 'toggle',
              child: Text(rule.isActive ? 'Disable' : 'Enable'),
            ),
          if (onEdit != null)
            const PopupMenuItem(value: 'edit', child: Text('Edit')),
          if (onArchive != null)
            const PopupMenuItem(value: 'archive', child: Text('Archive')),
          if (onRestore != null)
            const PopupMenuItem(value: 'restore', child: Text('Restore')),
          const PopupMenuItem(value: 'delete', child: Text('Delete')),
        ],
      ),
    );
  }

  String _sentenceCase(String value) =>
      value.isEmpty ? value : '${value[0].toUpperCase()}${value.substring(1)}';
}

Future<void> _showRuleSheet(
  BuildContext context,
  WidgetRef ref, {
  required List<Category> categories,
  required CategorizationRuleView initial,
}) async {
  final patternController = TextEditingController(text: initial.pattern);
  var target = initial.matchTarget;
  var kind = initial.matchKind;
  var categoryId = initial.categoryId;
  final formKey = GlobalKey<FormState>();

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) => StatefulBuilder(
      builder: (context, setState) => Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.pagePaddingMobile,
          AppSpacing.space5,
          AppSpacing.pagePaddingMobile,
          MediaQuery.viewInsetsOf(context).bottom + AppSpacing.space5,
        ),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Edit Category Rule',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.space4),
              TextFormField(
                controller: patternController,
                decoration: const InputDecoration(
                  labelText: 'Text to match',
                  hintText: 'e.g. Corner Market',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter text to match.'
                    : null,
              ),
              const SizedBox(height: AppSpacing.space3),
              DropdownButtonFormField<String>(
                initialValue: target,
                decoration: const InputDecoration(
                  labelText: 'Match field',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'payee', child: Text('Payee')),
                  DropdownMenuItem(value: 'title', child: Text('Title')),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => target = value);
                },
              ),
              const SizedBox(height: AppSpacing.space3),
              DropdownButtonFormField<String>(
                initialValue: kind,
                decoration: const InputDecoration(
                  labelText: 'Match type',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'exact', child: Text('Exact match')),
                  DropdownMenuItem(value: 'contains', child: Text('Contains')),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => kind = value);
                },
              ),
              const SizedBox(height: AppSpacing.space3),
              DropdownButtonFormField<String>(
                initialValue: categoryId,
                decoration: const InputDecoration(
                  labelText: 'Suggested category',
                  border: OutlineInputBorder(),
                ),
                items: categories
                    .where((category) => category.deletedAt == null)
                    .map(
                      (category) => DropdownMenuItem(
                        value: category.id,
                        child: Text(category.name),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => categoryId = value);
                },
              ),
              const SizedBox(height: AppSpacing.space5),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    if (formKey.currentState?.validate() != true) return;
                    await ref
                        .read(categorizationRulesCommandsProvider)
                        .update(
                          UpdateCategorizationRuleCommand(
                            id: initial.id,
                            matchTarget: target,
                            matchKind: kind,
                            pattern: patternController.text.trim(),
                            categoryId: categoryId,
                            priority: initial.priority,
                          ),
                        );
                    if (!sheetContext.mounted) return;
                    Navigator.pop(sheetContext);
                  },
                  child: const Text('Save Changes'),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  patternController.dispose();
}

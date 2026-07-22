import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../../application/migration/migration_models.dart';
import '../../../../../application/providers/migration_providers.dart';
import '../../../../../core/theme/colors.dart';
import '../../../../../core/theme/spacing.dart';
import '../../../../../core/theme/typography.dart';
import 'migration_ui.dart';

class CashewImportPrepareScreen extends ConsumerStatefulWidget {
  const CashewImportPrepareScreen({super.key});

  @override
  ConsumerState<CashewImportPrepareScreen> createState() =>
      _CashewImportPrepareScreenState();
}

class _CashewImportPrepareScreenState
    extends ConsumerState<CashewImportPrepareScreen> {
  MigrationSourceSelection? _selection;
  MigrationTitlePolicy _titlePolicy = MigrationTitlePolicy.preserveAndSuggest;
  String? _timezoneId;
  bool _busy = false;
  String? _pickerMessage;

  @override
  Widget build(BuildContext context) {
    final timezones = ref.watch(migrationTimezoneOptionsProvider);
    _timezoneId ??= timezones.first.id;
    final selectedTimezone = timezones.firstWhere(
      (option) => option.id == _timezoneId,
      orElse: () => timezones.first,
    );

    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: AppBar(
          centerTitle: false,
          title: const Text('Import from Cashew'),
        ),
        body: MigrationPageBody(
          bottom: MigrationPrimaryAction(
            key: const ValueKey('start-cashew-import'),
            label: _busy ? 'Preparing…' : 'Continue to dry run',
            icon: LucideIcons.arrowRight,
            onPressed: _selection == null || _busy
                ? null
                : () => _createRun(selectedTimezone),
          ),
          children: [
            const MigrationHeading(
              title: 'Bring your history with you',
              body:
                  'Lootr analyzes the backup on this device. Nothing is '
                  'published until you review and confirm the dry run.',
            ),
            const SizedBox(height: AppSpacing.space5),
            const _PrivacyNotice(),
            const SizedBox(height: AppSpacing.space4),
            Semantics(
              header: true,
              child: Text('1. Choose your file', style: AppTypography.h2),
            ),
            const SizedBox(height: AppSpacing.space2),
            Text(
              'In Cashew, create a fresh data-file export after your latest '
              'changes. Lootr leaves the original untouched.',
              style: AppTypography.body.copyWith(
                color: context.lootrColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.space3),
            MigrationSecondaryAction(
              key: const ValueKey('choose-cashew-file'),
              label: _selection == null ? 'Choose Cashew file' : 'Choose again',
              icon: LucideIcons.fileUp,
              onPressed: _busy ? null : _chooseFile,
            ),
            if (_selection != null) ...[
              const SizedBox(height: AppSpacing.space2),
              Semantics(
                liveRegion: true,
                label: 'Cashew backup selected',
                child: Text(
                  _selection!.safeLabel,
                  key: const ValueKey('selected-source-label'),
                  style: AppTypography.captionMedium.copyWith(
                    color: context.lootrColors.success,
                  ),
                ),
              ),
            ],
            if (_pickerMessage != null) ...[
              const SizedBox(height: AppSpacing.space2),
              Semantics(
                liveRegion: true,
                child: Text(
                  _pickerMessage!,
                  key: const ValueKey('picker-message'),
                  style: AppTypography.caption.copyWith(
                    color: context.lootrColors.warning,
                  ),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.space6),
            Semantics(
              header: true,
              child: Text('2. Confirm time', style: AppTypography.h2),
            ),
            const SizedBox(height: AppSpacing.space2),
            Text(
              'Cashew stores timestamps without a per-record timezone. You can '
              'review this choice again before import.',
              style: AppTypography.body.copyWith(
                color: context.lootrColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.space3),
            DropdownButtonFormField<String>(
              key: const ValueKey('migration-timezone'),
              initialValue: _timezoneId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Timezone'),
              items: [
                for (final option in timezones)
                  DropdownMenuItem(
                    value: option.id,
                    child: Text(option.label, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: _busy
                  ? null
                  : (value) => setState(() => _timezoneId = value),
            ),
            const SizedBox(height: AppSpacing.space6),
            Semantics(
              header: true,
              child: Text('3. Choose title policy', style: AppTypography.h2),
            ),
            const SizedBox(height: AppSpacing.space2),
            Text(
              'Every option preserves the original title and can be reversed.',
              style: AppTypography.body.copyWith(
                color: context.lootrColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.space2),
            RadioGroup<MigrationTitlePolicy>(
              groupValue: _titlePolicy,
              onChanged: (value) {
                if (!_busy && value != null) {
                  setState(() => _titlePolicy = value);
                }
              },
              child: Column(
                children: [
                  for (final policy in MigrationTitlePolicy.values)
                    RadioListTile<MigrationTitlePolicy>(
                      key: ValueKey('title-policy-${policy.name}'),
                      value: policy,
                      enabled: !_busy,
                      contentPadding: EdgeInsets.zero,
                      title: Text(policy.label),
                      subtitle: Text(policy.description),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _chooseFile() async {
    setState(() {
      _busy = true;
      _pickerMessage = null;
    });
    MigrationPickerResult result;
    try {
      result = await ref.read(migrationSourcePickerProvider).chooseCashewFile();
    } catch (_) {
      result = const MigrationPickerResult.unavailable(
        'The file chooser could not be opened. No data was accessed.',
      );
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      switch (result.status) {
        case MigrationPickerStatus.selected:
          _selection = result.selection;
        case MigrationPickerStatus.cancelled:
          _pickerMessage = 'No file selected. Nothing was changed.';
        case MigrationPickerStatus.unavailable:
          _pickerMessage =
              result.message ?? 'File selection is currently unavailable.';
      }
    });
  }

  Future<void> _createRun(MigrationTimezoneOption timezone) async {
    final selection = _selection;
    if (selection == null) return;
    setState(() => _busy = true);
    MigrationRunProjection run;
    try {
      run = await ref
          .read(migrationCoordinatorProvider)
          .createRun(
            source: selection,
            timezone: timezone,
            titlePolicy: _titlePolicy,
          );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _pickerMessage =
            'The migration engine is unavailable. No data was changed.';
      });
      return;
    }
    if (!mounted) return;
    context.pushReplacement('/more/settings/data/import-cashew/${run.id}');
  }
}

class _PrivacyNotice extends StatelessWidget {
  const _PrivacyNotice();

  @override
  Widget build(BuildContext context) {
    return MigrationSectionCard(
      semanticLabel: 'Privacy notice',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            LucideIcons.shieldCheck,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: AppSpacing.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Private by design', style: AppTypography.h3),
                const SizedBox(height: AppSpacing.space1),
                Text(
                  'The file is copied into private staging, opened read-only, '
                  'and removed after completion or cancellation. Secure '
                  'deletion is best-effort on flash storage.',
                  style: AppTypography.body.copyWith(
                    color: context.lootrColors.textSecondary,
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

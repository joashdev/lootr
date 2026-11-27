import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../application/providers/accounts_provider.dart';
import '../../../../application/providers/current_user_provider.dart';
import '../../../../application/providers/repo_providers.dart';
import '../../../../core/format/money_format.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../data/database/app_database.dart';
import '../../../../data/repositories/user_repo.dart';
import '../../../shared/components/buttons/primary_button.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentUserProvider);
    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        title: const Text('Profile & Preferences'),
      ),
      body: profile.when(
        data: (user) => _ProfileForm(
          key: ValueKey(user?.id ?? UserRepo.localProfileId),
          user: user,
        ),
        error: (_, _) => Center(
          child: TextButton(
            onPressed: () => ref.invalidate(currentUserProvider),
            child: const Text('Could not load your profile. Retry'),
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _ProfileForm extends ConsumerStatefulWidget {
  const _ProfileForm({super.key, required this.user});

  final UserData? user;

  @override
  ConsumerState<_ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends ConsumerState<_ProfileForm> {
  late final _name = TextEditingController(text: widget.user?.displayName);
  late String _currency = widget.user?.currencyCode ?? 'PHP';

  bool _saving = false;

  bool get _hasChanges =>
      _name.text != (widget.user?.displayName ?? '') ||
      _currency != (widget.user?.currencyCode ?? 'PHP');

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_hasChanges) return;
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    final existing = widget.user?.displayName;
    final edited = _name.text.trim();
    final displayName = _name.text == (existing ?? '')
        ? existing
        : (edited.isEmpty ? null : edited);

    try {
      await ref
          .read(userRepoProvider)
          .saveProfile(displayName: displayName, currencyCode: _currency);
      if (!mounted) return;
      _name.text = displayName ?? '';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile saved.')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save your profile. Try again.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(accountsProvider).value ?? const [];
    final currencies = {
      ...MoneyFormat.supportedCurrencies,
      for (final account in accounts)
        if (!account.isHidden) account.currencyCode,
      _currency,
    };
    return SafeArea(
      top: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.pagePaddingMobile,
          AppSpacing.pagePaddingMobile,
          AppSpacing.pagePaddingMobile,
          AppSpacing.bottomNavOverlayClearance,
        ),
        children: [
          TextFormField(
            controller: _name,
            enabled: !_saving,
            onChanged: (_) => setState(() {}),
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Display name',
              hintText: 'Local User',
            ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Email'),
            subtitle: Text(widget.user?.email ?? 'No account connected'),
            trailing: const Icon(LucideIcons.lock, semanticLabel: 'Read only'),
          ),
          const SizedBox(height: AppSpacing.space4),
          DropdownButtonFormField<String>(
            key: const ValueKey('profile-currency'),
            initialValue: _currency,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Dashboard currency',
              helperText: 'Shows totals for accounts in this currency.',
              helperMaxLines: 2,
            ),
            items: [
              for (final code in currencies)
                DropdownMenuItem(value: code, child: Text(code)),
            ],
            onChanged: _saving
                ? null
                : (code) {
                    if (code != null) setState(() => _currency = code);
                  },
          ),
          const SizedBox(height: AppSpacing.space4),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Reminder time zone'),
            subtitle: Text(widget.user?.timezone ?? 'Automatic'),
            trailing: const Icon(LucideIcons.lock, semanticLabel: 'Read only'),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Locale'),
            subtitle: Text(widget.user?.locale ?? 'App default'),
            trailing: const Icon(LucideIcons.lock, semanticLabel: 'Read only'),
          ),
          const SizedBox(height: AppSpacing.space4),
          PrimaryButton(
            label: 'Save changes',
            isLoading: _saving,
            onPressed: _hasChanges ? _save : null,
          ),
        ],
      ),
    );
  }
}

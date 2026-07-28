import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'repo_providers.dart';

enum ModelDownloadStatus { notDownloaded, downloading, downloaded, failed }

class AiSettingsState {
  final bool aiEnabled;
  final ModelDownloadStatus modelStatus;
  final int modelSizeBytes;
  final int modelDownloadedBytes;

  const AiSettingsState({
    this.aiEnabled = false,
    this.modelStatus = ModelDownloadStatus.notDownloaded,
    this.modelSizeBytes = 0,
    this.modelDownloadedBytes = 0,
  });

  AiSettingsState copyWith({
    bool? aiEnabled,
    ModelDownloadStatus? modelStatus,
    int? modelSizeBytes,
    int? modelDownloadedBytes,
  }) {
    return AiSettingsState(
      aiEnabled: aiEnabled ?? this.aiEnabled,
      modelStatus: modelStatus ?? this.modelStatus,
      modelSizeBytes: modelSizeBytes ?? this.modelSizeBytes,
      modelDownloadedBytes: modelDownloadedBytes ?? this.modelDownloadedBytes,
    );
  }
}

class AiSettingsNotifier extends Notifier<AiSettingsState> {
  var _settingsVersion = 0;

  @override
  AiSettingsState build() {
    _loadAiEnabled();
    return const AiSettingsState();
  }

  Future<void> _loadAiEnabled() async {
    final loadVersion = _settingsVersion;
    final user = await ref.read(userRepoProvider).getCurrentUser();
    if (loadVersion != _settingsVersion) return;
    state = state.copyWith(aiEnabled: user?.aiEnabled ?? false);
  }

  Future<void> toggleAi() async {
    final newEnabled = !state.aiEnabled;
    _settingsVersion++;
    final userRepo = ref.read(userRepoProvider);
    await userRepo.updateAiEnabled(newEnabled);
    state = state.copyWith(aiEnabled: newEnabled);
  }

  void updateModelDownload({
    ModelDownloadStatus? status,
    int? sizeBytes,
    int? downloadedBytes,
  }) {
    state = state.copyWith(
      modelStatus: status,
      modelSizeBytes: sizeBytes,
      modelDownloadedBytes: downloadedBytes,
    );
  }
}

final aiSettingsProvider =
    NotifierProvider<AiSettingsNotifier, AiSettingsState>(
      AiSettingsNotifier.new,
    );

final aiEnabledProvider = Provider<bool>((ref) {
  return ref.watch(aiSettingsProvider).aiEnabled;
});

/// User-facing alias for the persisted `users.ai_enabled` flag.
///
/// The current alpha has deterministic parsing, ML Kit OCR, and local
/// categorization heuristics, but no downloadable generative model. Keeping
/// this alias makes that boundary explicit without a database migration.
final smartEntryAssistanceEnabledProvider = Provider<bool>((ref) {
  return ref.watch(aiEnabledProvider);
});

final modelDownloadStatusProvider = Provider<ModelDownloadStatus>((ref) {
  return ref.watch(aiSettingsProvider).modelStatus;
});

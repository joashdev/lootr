import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'repo_providers.dart';

enum ModelDownloadStatus {
  notDownloaded,
  downloading,
  downloaded,
  failed,
}

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
  @override
  AiSettingsState build() {
    _loadAiEnabled();
    return const AiSettingsState();
  }

  Future<void> _loadAiEnabled() async {
    final user = await ref.read(userRepoProvider).getCurrentUser();
    state = state.copyWith(aiEnabled: user?.aiEnabled ?? false);
  }

  Future<void> toggleAi() async {
    final newEnabled = !state.aiEnabled;
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

final modelDownloadStatusProvider = Provider<ModelDownloadStatus>((ref) {
  return ref.watch(aiSettingsProvider).modelStatus;
});

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/format/money_format.dart';
import '../../../application/providers/ai_entry_providers.dart';
import '../../../application/providers/ai_settings_provider.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/radius.dart';
import '../../../core/theme/typography.dart';
import '../../../domain/use_cases/run_ocr.dart';
import '../../../domain/value_objects/ocr_payload.dart';
import '../../sheets/add_transaction_sheet.dart';
import '../../shared/components/app_snackbar.dart';
import '../../shared/components/buttons/primary_button.dart';

/// Full-screen receipt capture flow.
///
/// Provides a real camera viewfinder (when a camera is available), a gallery
/// picker, and a flash toggle. Captured / picked images are run through the
/// ML Kit backed [RunOCR] use case and the extracted fields are previewed
/// before the user continues to the Add Transaction sheet.
class OcrScanScreen extends ConsumerStatefulWidget {
  const OcrScanScreen({super.key, this.runOcr});

  /// Injectable use case for testing. Defaults to a real ML Kit pipeline.
  final RunOCR? runOcr;

  @override
  ConsumerState<OcrScanScreen> createState() => _OcrScanScreenState();
}

class _OcrScanScreenState extends ConsumerState<OcrScanScreen>
    with WidgetsBindingObserver {
  final ImagePicker _picker = ImagePicker();

  CameraController? _cameraController;
  Future<void>? _cameraInitFuture;
  bool _cameraAvailable = false;
  String? _cameraError;

  bool _isFlashEnabled = false;
  bool _isProcessing = false;
  String? _selectedImagePath;
  OcrPayload? _payload;

  RunOCR get _runOcr => widget.runOcr ?? ref.read(runOCRProvider);
  bool get _assistanceEnabled =>
      widget.runOcr != null || ref.read(smartEntryAssistanceEnabledProvider);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      controller.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (!mounted) return;
        setState(() {
          _cameraAvailable = false;
          _cameraError = 'No camera available on this device.';
        });
        return;
      }

      final controller = CameraController(
        cameras.first,
        ResolutionPreset.high,
        enableAudio: false,
      );
      final initFuture = controller.initialize();
      if (!mounted) {
        await initFuture;
        await controller.dispose();
        return;
      }
      setState(() {
        _cameraController = controller;
        _cameraInitFuture = initFuture;
        _cameraAvailable = true;
        _cameraError = null;
      });
      await initFuture;
      if (mounted) setState(() {});
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _cameraAvailable = false;
        _cameraError = 'Camera unavailable: $error';
      });
    }
  }

  Future<void> _toggleFlash() async {
    final controller = _cameraController;
    final next = !_isFlashEnabled;
    setState(() => _isFlashEnabled = next);
    if (controller != null && controller.value.isInitialized) {
      try {
        await controller.setFlashMode(next ? FlashMode.torch : FlashMode.off);
      } catch (_) {
        // Flash not supported — keep the toggle visible but inert.
      }
    }
  }

  Future<void> _capture() async {
    if (!_assistanceEnabled) {
      _showSnackBar(
        'Enable Smart Entry Assistance in Settings to scan receipts.',
      );
      return;
    }
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) {
      _showSnackBar('Camera is not ready yet.');
      return;
    }
    try {
      final file = await controller.takePicture();
      setState(() {
        _selectedImagePath = file.path;
        _payload = null;
      });
      await _processImage(file.path);
    } catch (error) {
      _showSnackBar('Could not capture photo: $error');
    }
  }

  Future<void> _pickFromGallery() async {
    if (!_assistanceEnabled) {
      _showSnackBar(
        'Enable Smart Entry Assistance in Settings to scan receipts.',
      );
      return;
    }
    try {
      final file = await _picker.pickImage(source: ImageSource.gallery);
      if (file == null) return;
      setState(() {
        _selectedImagePath = file.path;
        _payload = null;
      });
      await _processImage(file.path);
    } catch (error) {
      _showSnackBar('Could not open gallery: $error');
    }
  }

  Future<void> _processImage(String imagePath) async {
    setState(() => _isProcessing = true);
    final result = await _runOcr(imagePath);
    if (!mounted) return;
    setState(() => _isProcessing = false);
    result.fold(
      onSuccess: (payload) {
        setState(() => _payload = payload);
        if (payload.rawText.trim().isEmpty) {
          _showSnackBar('No text found. Try again with a clearer photo.');
        }
      },
      onFailure: (message, _) => _showSnackBar(message),
    );
  }

  void _showSnackBar(String message) {
    AppSnackBar.show(context, message, variant: AppSnackBarVariant.warning);
  }

  void _continueToSave() {
    final payload = _payload;
    if (payload == null) return;
    context.push(
      '/transactions/new',
      extra: AddTransactionSheetArgs(
        initialParsedTransaction: payload.extractedFields,
        entrySource: 'ocr',
        sourceConfidence: payload.confidence,
        sourceSummary: 'On-device receipt scan',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final assistanceEnabled =
        widget.runOcr != null || ref.watch(smartEntryAssistanceEnabledProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(child: _buildViewfinder(colorScheme)),
            if (!assistanceEnabled)
              const Positioned.fill(
                child: ColoredBox(
                  color: Colors.black54,
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text(
                        'Smart Entry Assistance is off. Enable it in Settings '
                        'to scan receipts.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ),
            Positioned(
              top: 8,
              left: 8,
              child: IconButton(
                onPressed: () => context.pop(),
                icon: const Icon(LucideIcons.x, color: Colors.white),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                tooltip: 'Toggle flash',
                onPressed: _toggleFlash,
                icon: Icon(
                  _isFlashEnabled ? LucideIcons.zap : LucideIcons.zapOff,
                  color: Colors.white,
                ),
              ),
            ),
            if (_isProcessing)
              const Positioned.fill(
                child: ColoredBox(
                  color: Colors.black54,
                  child: Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                ),
              ),
            Align(
              alignment: Alignment.bottomCenter,
              child: _buildBottomBar(colorScheme, assistanceEnabled),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildViewfinder(ColorScheme colorScheme) {
    final controller = _cameraController;
    if (_cameraAvailable &&
        controller != null &&
        controller.value.isInitialized) {
      return FutureBuilder<void>(
        future: _cameraInitFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return Stack(
              fit: StackFit.expand,
              children: [
                CameraPreview(controller),
                Center(
                  child: Container(
                    margin: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppColors.primary500, width: 2),
                    ),
                  ),
                ),
              ],
            );
          }
          return const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        },
      );
    }

    // Fallback when no camera is available (e.g. simulator / headless).
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.receipt, size: 48, color: Colors.white70),
            const SizedBox(height: 12),
            Text(
              _selectedImagePath ??
                  _cameraError ??
                  'Point the camera at a receipt, or pick from your gallery.',
              textAlign: TextAlign.center,
              style: AppTypography.body.copyWith(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar(ColorScheme colorScheme, bool assistanceEnabled) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      decoration: const BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_payload != null) ...[
            _OcrPreviewCard(payload: _payload!),
            const SizedBox(height: 16),
          ],
          Row(
            children: [
              IconButton(
                tooltip: 'Pick from gallery',
                onPressed: _isProcessing || !assistanceEnabled
                    ? null
                    : _pickFromGallery,
                icon: const Icon(LucideIcons.image, color: Colors.white),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _isProcessing || !assistanceEnabled ? null : _capture,
                child: Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colorScheme.primary,
                    border: Border.all(color: Colors.white, width: 4),
                  ),
                  child: const Icon(LucideIcons.camera, color: Colors.white),
                ),
              ),
              const Spacer(),
              const SizedBox(width: 48),
            ],
          ),
          if (_payload != null) ...[
            const SizedBox(height: 16),
            PrimaryButton(
              label: 'Continue to Save',
              onPressed: _continueToSave,
            ),
          ],
        ],
      ),
    );
  }
}

class _OcrPreviewCard extends StatelessWidget {
  const _OcrPreviewCard({required this.payload});

  final OcrPayload payload;

  @override
  Widget build(BuildContext context) {
    final extracted = payload.extractedFields;

    Widget previewRow(String label, String value) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            SizedBox(
              width: 84,
              child: Text(
                label,
                style: AppTypography.caption.copyWith(color: Colors.white70),
              ),
            ),
            Expanded(
              child: Text(
                value,
                style: AppTypography.body.copyWith(color: Colors.white),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Extracted Fields',
            style: AppTypography.captionMedium.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 12),
          if (extracted.amount != null)
            previewRow('Amount', MoneyFormat.exact(extracted.amount!, 'PHP')),
          if (extracted.payee != null) previewRow('Payee', extracted.payee!),
          if (extracted.account != null)
            previewRow('Account', extracted.account!),
          if (payload.rawText.trim().isEmpty)
            previewRow('Text', 'No text detected'),
        ],
      ),
    );
  }
}

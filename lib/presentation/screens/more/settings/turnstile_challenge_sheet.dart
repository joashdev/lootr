import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';

class TurnstileChallengeSheet extends StatefulWidget {
  const TurnstileChallengeSheet({super.key, required this.challengeUri});

  final Uri challengeUri;

  @override
  State<TurnstileChallengeSheet> createState() =>
      _TurnstileChallengeSheetState();
}

class _TurnstileChallengeSheetState extends State<TurnstileChallengeSheet> {
  late final WebViewController _controller;
  bool _challengeFailed = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            final uri = Uri.tryParse(request.url);
            final sameOrigin =
                uri?.scheme == widget.challengeUri.scheme &&
                uri?.host == widget.challengeUri.host;
            final isTurnstile = uri?.host == 'challenges.cloudflare.com';
            return sameOrigin || isTurnstile
                ? NavigationDecision.navigate
                : NavigationDecision.prevent;
          },
        ),
      )
      ..addJavaScriptChannel(
        'LootrTurnstile',
        onMessageReceived: (message) {
          if (!mounted) return;
          if (message.message == '__turnstile_error__') {
            setState(() => _challengeFailed = true);
          } else if (message.message.isNotEmpty) {
            Navigator.of(context).pop(message.message);
          }
        },
      )
      ..loadRequest(widget.challengeUri);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.pagePaddingMobile,
          AppSpacing.space2,
          AppSpacing.pagePaddingMobile,
          AppSpacing.space4,
        ),
        child: SizedBox(
          height: 360,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('Quick verification', style: AppTypography.h2),
                  ),
                  IconButton(
                    tooltip: 'Cancel',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.space1),
              Text(
                'Cloudflare checks that this report is from a person. '
                'The one-time result is not included in your public issue.',
                style: AppTypography.body,
              ),
              const SizedBox(height: AppSpacing.space3),
              Expanded(
                child: _challengeFailed
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'Verification could not finish. Your report is '
                            'still here.',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: AppSpacing.space3),
                          FilledButton(
                            onPressed: () {
                              setState(() => _challengeFailed = false);
                              _controller.reload();
                            },
                            child: const Text('Try verification again'),
                          ),
                        ],
                      )
                    : WebViewWidget(controller: _controller),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

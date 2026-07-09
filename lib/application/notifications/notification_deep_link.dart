import 'dart:convert';

class NotificationDeepLinkPayload {
  const NotificationDeepLinkPayload({
    required this.notificationId,
    required this.path,
  });

  final String notificationId;
  final String path;

  Map<String, dynamic> toJson() => {
    'notificationId': notificationId,
    'path': path,
  };

  static NotificationDeepLinkPayload? tryParse(String? raw) {
    if (raw == null || raw.isEmpty) return null;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;

      final notificationId = decoded['notificationId'];
      final path = decoded['path'];
      if (notificationId is! String || path is! String) return null;

      return NotificationDeepLinkPayload(
        notificationId: notificationId,
        path: path,
      );
    } catch (_) {
      return null;
    }
  }

  String encode() => jsonEncode(toJson());
}

String notificationDeepLinkFor({
  required String notificationType,
  String? relatedEntityId,
}) {
  switch (notificationType) {
    case 'bill_due':
    case 'installment_due':
      return '/transactions?filter=installment';
    case 'recurring_reminder':
      return '/recurring/$relatedEntityId';
    case 'debt_reminder':
      return '/debts/$relatedEntityId';
    case 'subscription_reminder':
      return '/recurring?filter=subscription';
    default:
      return '/';
  }
}

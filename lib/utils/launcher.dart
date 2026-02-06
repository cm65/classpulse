import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'helpers.dart';

/// Utility class for launching external apps (phone, sms, whatsapp, etc.)
class Launcher {
  /// Make a phone call
  static Future<bool> makePhoneCall(String phoneNumber) async {
    final formattedPhone = PhoneHelpers.formatWithCountryCode(phoneNumber);
    final uri = Uri.parse('tel:$formattedPhone');

    if (await canLaunchUrl(uri)) {
      return await launchUrl(uri);
    }
    return false;
  }

  /// Send SMS
  static Future<bool> sendSms(String phoneNumber, {String? body}) async {
    final formattedPhone = PhoneHelpers.formatWithCountryCode(phoneNumber);
    final uri = Uri.parse(body != null
        ? 'sms:$formattedPhone?body=${Uri.encodeComponent(body)}'
        : 'sms:$formattedPhone');

    if (await canLaunchUrl(uri)) {
      return await launchUrl(uri);
    }
    return false;
  }

  /// Open WhatsApp chat
  static Future<bool> openWhatsApp(String phoneNumber, {String? message}) async {
    final whatsappPhone = PhoneHelpers.formatForWhatsApp(phoneNumber);
    final uri = Uri.parse(message != null
        ? 'whatsapp://send?phone=$whatsappPhone&text=${Uri.encodeComponent(message)}'
        : 'whatsapp://send?phone=$whatsappPhone');

    if (await canLaunchUrl(uri)) {
      return await launchUrl(uri);
    }

    // Fallback to wa.me link (opens in browser if WhatsApp not installed)
    final webUri = Uri.parse(message != null
        ? 'https://wa.me/$whatsappPhone?text=${Uri.encodeComponent(message)}'
        : 'https://wa.me/$whatsappPhone');

    if (await canLaunchUrl(webUri)) {
      return await launchUrl(webUri, mode: LaunchMode.externalApplication);
    }
    return false;
  }

  /// Send email
  static Future<bool> sendEmail(String email, {String? subject, String? body}) async {
    final queryParams = <String, String>{};
    if (subject != null) queryParams['subject'] = subject;
    if (body != null) queryParams['body'] = body;

    final uri = Uri(
      scheme: 'mailto',
      path: email,
      queryParameters: queryParams.isNotEmpty ? queryParams : null,
    );

    if (await canLaunchUrl(uri)) {
      return await launchUrl(uri);
    }
    return false;
  }

  /// Open URL in browser
  static Future<bool> openUrl(String url) async {
    final uri = Uri.parse(url);

    if (await canLaunchUrl(uri)) {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    return false;
  }

  /// Show contact options bottom sheet
  static Future<void> showContactOptions({
    required BuildContext context,
    required String phoneNumber,
    required String name,
    String? message,
  }) async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Contact $name',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.phone, color: Colors.green),
              ),
              title: const Text('Call'),
              subtitle: Text(PhoneHelpers.formatForDisplay(phoneNumber)),
              onTap: () async {
                Navigator.pop(context);
                final success = await makePhoneCall(phoneNumber);
                if (!success && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Could not open phone app')),
                  );
                }
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green[700]!.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.chat, color: Colors.green[700]),
              ),
              title: const Text('WhatsApp'),
              subtitle: const Text('Open chat'),
              onTap: () async {
                Navigator.pop(context);
                final success = await openWhatsApp(phoneNumber, message: message);
                if (!success && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Could not open WhatsApp')),
                  );
                }
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.message, color: Colors.blue),
              ),
              title: const Text('SMS'),
              subtitle: const Text('Send text message'),
              onTap: () async {
                Navigator.pop(context);
                final success = await sendSms(phoneNumber, body: message);
                if (!success && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Could not open SMS app')),
                  );
                }
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

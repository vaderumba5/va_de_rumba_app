import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/concert.dart';

class ConcertActions {
  const ConcertActions._();

  static Future<void> openLocation(
      BuildContext context, Concert concert) async {
    final rawUrl = concert.mapsUrl.trim();
    final query = concert.venueName.trim().isNotEmpty
        ? concert.venueName.trim()
        : concert.address.trim().isNotEmpty
            ? concert.address.trim()
            : concert.place.trim();
    final uri = concert.googlePlaceId.trim().isNotEmpty
        ? Uri.parse(
            'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(query)}&query_place_id=${Uri.encodeComponent(concert.googlePlaceId.trim())}')
        : concert.latitude != null && concert.longitude != null
            ? Uri.parse(
                'https://www.google.com/maps/search/?api=1&query=${concert.latitude},${concert.longitude}')
            : rawUrl.isNotEmpty
                ? Uri.tryParse(rawUrl)
                : Uri.parse(
                    'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(concert.address.trim())}');
    if (uri == null) {
      _showLocationError(context);
      return;
    }
    try {
      final opened = await launchUrl(uri,
          mode: LaunchMode.platformDefault, webOnlyWindowName: '_blank');
      if (!opened && context.mounted) _showLocationError(context);
    } catch (_) {
      if (context.mounted) _showLocationError(context);
    }
  }

  static Future<void> openConcertLocation(
      BuildContext context, String? location) async {
    final query = location?.trim() ?? '';
    if (query.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Este concierto no tiene una ubicación guardada')));
      return;
    }
    final uri = Uri.https('www.google.com', '/maps/dir/',
        <String, String>{'api': '1', 'destination': query});
    try {
      final opened = await launchUrl(uri,
          mode: LaunchMode.platformDefault, webOnlyWindowName: '_blank');
      if (!opened && context.mounted) _showLocationError(context);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al abrir Google Maps: $error')));
      }
    }
  }

  static Future<void> searchLocationInGoogleMaps(
      BuildContext context, String location) async {
    final query = location.trim();
    if (query.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Introduce una ubicación antes de buscarla')));
      return;
    }
    final uri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(query)}');
    try {
      final opened = await launchUrl(uri,
          mode: LaunchMode.platformDefault, webOnlyWindowName: '_blank');
      if (!opened && context.mounted) _showLocationError(context);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al abrir Google Maps: $error')));
      }
    }
  }

  static Future<void> copyPhone(BuildContext context, String phone) async {
    await Clipboard.setData(ClipboardData(text: phone));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Teléfono copiado')));
  }

  static Future<void> openUrl(BuildContext context, String value) async {
    final uri = Uri.tryParse(value);
    if (uri == null) return;
    try {
      final opened = await launchUrl(
        uri,
        mode: LaunchMode.platformDefault,
        webOnlyWindowName: '_blank',
      );
      if (!opened && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se ha podido abrir el enlace')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se ha podido abrir el enlace')),
        );
      }
    }
  }

  static Future<void> callPhone(BuildContext context, String phone) async {
    final uri =
        Uri(scheme: 'tel', path: phone.replaceAll(RegExp(r'[^0-9+]'), ''));
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && context.mounted) _showLocationError(context);
    } catch (_) {
      if (context.mounted) _showLocationError(context);
    }
  }

  static void _showLocationError(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se ha podido abrir la ubicación')));
  }
}

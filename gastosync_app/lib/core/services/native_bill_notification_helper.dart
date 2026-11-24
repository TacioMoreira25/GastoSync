import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Ponte de notificações nativas Android (`flutter_local_notifications`)
/// para alertar nos 2 horários diários de boletos mesmo com o app fechado.
class NativeBillNotificationHelper {
  NativeBillNotificationHelper._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static const String _channelId = 'gastosync_bill_reminders';
  static const String _channelName = 'Lembretes de Boletos';
  static const String _channelDescription =
      'Alertas diários nos 2 horários configurados para boletos vencendo ou em atraso.';

  static Future<void> ensureInitialized() async {
    if (kIsWeb || _initialized) return;
    try {
      tz_data.initializeTimeZones();
      const androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const initSettings = InitializationSettings(android: androidSettings);
      await _plugin.initialize(initSettings);

      final androidImpl = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await androidImpl?.requestNotificationsPermission();
      _initialized = true;
    } catch (_) {
      // Ignora em ambientes de teste unitário sem canal nativo
    }
  }

  static Future<void> showImmediateAlert({
    required int id,
    required String title,
    required String body,
  }) async {
    if (kIsWeb) return;
    try {
      await ensureInitialized();
      if (!_initialized) return;
      const details = NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.high,
          priority: Priority.high,
        ),
      );
      await _plugin.show(id, title, body, details);
    } catch (_) {}
  }

  static Future<void> scheduleDailyBillReminders({
    required String reminderTime1,
    required String reminderTime2,
    required int actionableCount,
    required String summaryBody,
  }) async {
    if (kIsWeb) return;
    try {
      await ensureInitialized();
      if (!_initialized) return;

      // Cancela agendamentos antigos dos 2 turnos antes de reagendar
      await _plugin.cancel(1001);
      await _plugin.cancel(1002);

      if (actionableCount <= 0) return;

      await _scheduleSlot(
        id: 1001,
        hhmm: reminderTime1,
        title: 'GastoSync • Lembrete de Boletos',
        body: summaryBody,
      );
      await _scheduleSlot(
        id: 1002,
        hhmm: reminderTime2,
        title: 'GastoSync • Lembrete de Boletos',
        body: summaryBody,
      );
    } catch (_) {}
  }

  static Future<void> _scheduleSlot({
    required int id,
    required String hhmm,
    required String title,
    required String body,
  }) async {
    final parts = hhmm.trim().split(':');
    if (parts.length != 2) return;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return;

    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour.clamp(0, 23),
      minute.clamp(0, 59),
    );
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.high,
        priority: Priority.high,
      ),
    );

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      scheduled,
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }
}

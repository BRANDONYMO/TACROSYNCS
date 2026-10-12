import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> initNotification() async {
    tz.initializeTimeZones();

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await notificationsPlugin.initialize(settings: initializationSettings);

    final androidImplementation = notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    if (androidImplementation != null) {
      await androidImplementation.requestNotificationsPermission();
      await androidImplementation.requestExactAlarmsPermission();
    }
  }

  /// Convierte cualquier identificador (int o String de Firebase) a un entero seguro para Android
  int _convertirAIdSeguro(dynamic id) {
    if (id is int) {
      return id.abs() % 100000;
    }
    return id.toString().hashCode.abs() % 100000;
  }

  /// Método para programar una notificación individual
  Future<void> programarNotificacionAutomatica({
    required dynamic id,
    required String titulo,
    required String cuerpo,
    required DateTime fechaHoraProgramada,
  }) async {
    try {
      final int notifId = _convertirAIdSeguro(id);
      var tzFecha = tz.TZDateTime.from(fechaHoraProgramada, tz.local);
      final ahora = tz.TZDateTime.now(tz.local);

      if (tzFecha.isBefore(ahora)) {
        tzFecha = tzFecha.add(const Duration(days: 1));
      }

      debugPrint('⏰ Notificación $notifId programada para: $tzFecha');

      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
            'tacrosync_auto_channel',
            'Recordatorios Automáticos de Medicamentos',
            channelDescription:
                'Alertas automáticas para toma de medicamentos controlados',
            importance: Importance.max,
            priority: Priority.high,
            showWhen: true,
            audioAttributesUsage: AudioAttributesUsage.alarm,
            playSound: true,
            enableVibration: true,
          );

      const NotificationDetails notificationDetails = NotificationDetails(
        android: androidDetails,
      );

      await notificationsPlugin.zonedSchedule(
        id: notifId,
        title: titulo,
        body: cuerpo,
        scheduledDate: tzFecha,
        notificationDetails: notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    } catch (e) {
      debugPrint('❌ Error programando notificación: $e');
    }
  }

  /// 🚀 Programa las próximas N tomas por adelantado en Android
  Future<void> programarTomasFuturasMultipes({
    required dynamic medicamentoId,
    required String titulo,
    required String cuerpo,
    required DateTime primeraToma,
    required int intervaloHoras,
    int cantidadTomasFuturas = 15,
  }) async {
    try {
      final int baseId = _convertirAIdSeguro(medicamentoId);
      final ahora = tz.TZDateTime.now(tz.local);
      var baseFecha = tz.TZDateTime.from(primeraToma, tz.local);

      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
            'tacrosync_auto_channel',
            'Recordatorios Automáticos de Medicamentos',
            channelDescription:
                'Alertas automáticas para toma de medicamentos controlados',
            importance: Importance.max,
            priority: Priority.high,
            showWhen: true,
            audioAttributesUsage: AudioAttributesUsage.alarm,
            playSound: true,
            enableVibration: true,
          );

      const NotificationDetails notificationDetails = NotificationDetails(
        android: androidDetails,
      );

      // Limpiamos notificaciones previas de este medicamento antes de reagendar
      await cancelarNotificacionesMedicamento(baseId, cantidadTomasFuturas);

      int programadasCount = 0;
      int iteracion = 0;

      while (programadasCount < cantidadTomasFuturas && iteracion < 50) {
        final tzFechaToma = baseFecha.add(
          Duration(hours: intervaloHoras * iteracion),
        );

        if (tzFechaToma.isAfter(ahora)) {
          final int notificationId = (baseId * 100) + programadasCount;

          await notificationsPlugin.zonedSchedule(
            id: notificationId,
            title: titulo,
            body: cuerpo,
            scheduledDate: tzFechaToma,
            notificationDetails: notificationDetails,
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          );

          debugPrint(
            '⏰ [Multi-Notificación] ID $notificationId agendada para: $tzFechaToma',
          );
          programadasCount++;
        }
        iteracion++;
      }
    } catch (e) {
      debugPrint('❌ Error al agendar tomas múltiples futuras: $e');
    }
  }

  /// Cancela todas las ráfagas de notificaciones asociadas a un medicamento
  Future<void> cancelarNotificacionesMedicamento(
    dynamic medicamentoId, [
    int limiteTomas = 20,
  ]) async {
    final int baseId = _convertirAIdSeguro(medicamentoId);
    for (int i = 0; i < limiteTomas; i++) {
      final int notificationId = (baseId * 100) + i;
      await cancelarNotificacion(notificationId);
    }
  }

  Future<void> cancelarNotificacion(dynamic id) async {
    try {
      final int notifId = _convertirAIdSeguro(id);
      await notificationsPlugin.cancel(id: notifId);
    } catch (e) {
      debugPrint('Error al cancelar notificación: $e');
    }
  }
}

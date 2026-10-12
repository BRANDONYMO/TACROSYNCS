import 'package:flutter/material.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'core/constants/app_colors.dart';
import 'services/notification_service.dart';
import 'views/auth/login_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // 1. Inicializar base de datos de zonas horarias
  tz.initializeTimeZones();

  // 2. Establecer la ubicación local del dispositivo (por defecto America/Mexico_City o tu zona)
  // Si gustas puedes definir la zona por defecto:
  tz.setLocalLocation(tz.getLocation('America/Mexico_City'));

  // 3. Inicializar el servicio de notificaciones
  await NotificationService().initNotification();

  runApp(const TacrnoSyncApp());
}

class TacrnoSyncApp extends StatelessWidget {
  const TacrnoSyncApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Tacrosync Mobile',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.primaryTeal,
          surface: AppColors.cardBg,
        ),
      ),
      home: const LoginScreen(),
    );
  }
}

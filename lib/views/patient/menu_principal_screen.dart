import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
// Mantenemos todas tus importaciones originales
import '../../core/constants/app_colors.dart';
import '../../services/database_helper.dart';
import '../auth/login_screen.dart';
import 'administracion_medicamentos_screen.dart';
import 'agregar_editar_medicamento_screen.dart';
import 'confirmar_toma_screen.dart';
import 'historial_calendario_screen.dart';
import 'medicamentos_tomados_screen.dart';
import 'mis_medicamentos_screen.dart';
import 'enviar_reporte_screen.dart';

class MenuPrincipalScreen extends StatefulWidget {
  final Map<String, dynamic> usuario;
  const MenuPrincipalScreen({super.key, required this.usuario});

  @override
  State<MenuPrincipalScreen> createState() => _MenuPrincipalScreenState();
}

class _MenuPrincipalScreenState extends State<MenuPrincipalScreen>
    with WidgetsBindingObserver {
  List<Map<String, dynamic>> _proximosMedicamentos = [];
  bool _cargandoProxima = true;

  // --- COLORES CLEAN CLINICAL PREMIUM DIRECTOS ---
  final Color bgBlancoPerla = const Color(0xFFF8F9FA);
  final Color blancoTarjeta = Colors.white;
  final Color textoPrincipal = const Color(0xFF2B2D42);
  final Color textoSecundario = const Color(0xFF8D99AE);
  final Color turquesaVibrante = const Color(0xFF00B4D8);

  final List<BoxShadow> sombraSuave = [
    BoxShadow(
      color: Colors.black.withOpacity(0.05),
      blurRadius: 15,
      offset: const Offset(0, 5),
    ),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _cargarProximaToma();
    _verificarYPedirPermisosNotificaciones();
  }

  // TODA TU LÓGICA DE FIREBASE Y SQLITE SE MANTIENE INTACTA
  Future<void> _verificarYPedirPermisosNotificaciones() async {
    final androidPlugin = FlutterLocalNotificationsPlugin()
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    if (androidPlugin != null) {
      await androidPlugin.requestNotificationsPermission();
      await androidPlugin.requestExactAlarmsPermission();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _cerrarSesion();
    } else if (state == AppLifecycleState.resumed) {
      _cargarProximaToma();
    }
  }

  Future<void> _cerrarSesion() async {
    await GoogleSignIn().signOut();
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (r) => false,
    );
  }

  Future<void> _cargarProximaToma() async {
    if (!mounted) return;
    setState(() => _cargandoProxima = true);

    final dynamic usuarioId = widget.usuario['id'] ?? widget.usuario['uid'];
    await DatabaseHelper.instance.evaluarTomasVencidas(usuarioId);
    final pendientes = await DatabaseHelper.instance.obtenerPendientes(
      usuarioId,
    );

    if (pendientes.isNotEmpty) {
      final primeraHora = pendientes.first['hora'];
      final listaCoincidentes = pendientes
          .where((m) => m['hora'] == primeraHora)
          .toList();
      if (mounted) {
        setState(() {
          _proximosMedicamentos = listaCoincidentes;
          _cargandoProxima = false;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _proximosMedicamentos = [];
          _cargandoProxima = false;
        });
      }
    }
  }

  bool _puedoMarcarToma(
    String horaProgramada, {
    String? fechaProgramadaStr,
    int margenPrevioMinutos = 5,
    int margenToleranciaMinutos = 40,
  }) {
    final partes = horaProgramada.split(':');
    if (partes.length != 2) return false;

    final horaProg = int.tryParse(partes[0]) ?? 0;
    final minProg = int.tryParse(partes[1]) ?? 0;
    final ahora = DateTime.now();
    DateTime fechaHoraProg;

    if (fechaProgramadaStr != null && fechaProgramadaStr.isNotEmpty) {
      final partesFecha = fechaProgramadaStr.split('-');
      if (partesFecha.length == 3) {
        final anio = int.tryParse(partesFecha[0]) ?? ahora.year;
        final mes = int.tryParse(partesFecha[1]) ?? ahora.month;
        final dia = int.tryParse(partesFecha[2]) ?? ahora.day;
        fechaHoraProg = DateTime(anio, mes, dia, horaProg, minProg);
      } else {
        fechaHoraProg = DateTime(
          ahora.year,
          ahora.month,
          ahora.day,
          horaProg,
          minProg,
        );
      }
    } else {
      fechaHoraProg = DateTime(
        ahora.year,
        ahora.month,
        ahora.day,
        horaProg,
        minProg,
      );
    }

    final inicioPermitido = fechaHoraProg.subtract(
      Duration(minutes: margenPrevioMinutos),
    );
    final finPermitido = fechaHoraProg.add(
      Duration(minutes: margenToleranciaMinutos),
    );

    return ahora.isAfter(inicioPermitido) && ahora.isBefore(finPermitido);
  }

  @override
  Widget build(BuildContext context) {
    final dynamic usuarioId = widget.usuario['id'] ?? widget.usuario['uid'];
    final String horaComun = _proximosMedicamentos.isNotEmpty
        ? (_proximosMedicamentos.first['hora'] ?? '')
        : '';
    final String fechaComun = _proximosMedicamentos.isNotEmpty
        ? (_proximosMedicamentos.first['fecha_programada'] ??
              _proximosMedicamentos.first['fecha'] ??
              '')
        : '';
    final bool estaEnRangoDeToma =
        horaComun.isNotEmpty &&
        _puedoMarcarToma(horaComun, fechaProgramadaStr: fechaComun);

    return Scaffold(
      backgroundColor: bgBlancoPerla,

      // BARRA SUPERIOR LIMPIA
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
            onPressed: _cerrarSesion,
          ),
        ],
      ),

      // CONTENIDO PRINCIPAL
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // SALUDO GRANDE (Estilo del render)
              Text(
                'Hola,\n${widget.usuario['nombre'] ?? 'Paciente'}.',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  color: textoPrincipal,
                  height: 1.1,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 32),

              // TARJETA DE PRÓXIMA TOMA (Render)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: blancoTarjeta,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: sombraSuave,
                ),
                child: _cargandoProxima
                    ? Center(
                        child: CircularProgressIndicator(
                          color: turquesaVibrante,
                        ),
                      )
                    : _proximosMedicamentos.isEmpty
                    ? Column(
                        children: [
                          Icon(
                            Icons.check_circle_outline_rounded,
                            size: 64,
                            color: turquesaVibrante.withOpacity(0.5),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Sin tomas pendientes',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: textoPrincipal,
                            ),
                          ),
                          Text(
                            'Estás al día con tus dosis.',
                            style: TextStyle(color: textoSecundario),
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            'Próxima Toma:',
                            style: TextStyle(
                              fontSize: 14,
                              color: textoSecundario,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '$horaComun hrs',
                            style: TextStyle(
                              fontSize: 42,
                              fontWeight: FontWeight.bold,
                              color: textoPrincipal,
                              letterSpacing: -1.5,
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Lista de medicamentos en la toma
                          ..._proximosMedicamentos.map((med) {
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: bgBlancoPerla,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.medication_rounded,
                                    size: 14,
                                    color: turquesaVibrante,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${med['nombre']} - Dosis: ${med['dosis']}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: textoPrincipal,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                          const SizedBox(height: 24),

                          // BOTÓN REGISTRAR TOMA
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: estaEnRangoDeToma
                                  ? () async {
                                      await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => ConfirmarTomaScreen(
                                            listaMedicamentos:
                                                _proximosMedicamentos,
                                            usuarioId: usuarioId,
                                          ),
                                        ),
                                      );
                                      _cargarProximaToma();
                                    }
                                  : () {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: const Text(
                                            '⏰ Disponible 5 min antes.',
                                          ),
                                          backgroundColor: Colors.orange,
                                        ),
                                      );
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: estaEnRangoDeToma
                                    ? turquesaVibrante
                                    : Colors.grey.shade300,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: Text(
                                'REGISTRAR TOMA',
                                style: TextStyle(
                                  color: estaEnRangoDeToma
                                      ? Colors.white
                                      : textoSecundario,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (!estaEnRangoDeToma)
                            Text(
                              '🔒 Se habilitará pronto',
                              style: TextStyle(
                                fontSize: 12,
                                color: textoSecundario,
                              ),
                            ),
                        ],
                      ),
              ),
              const SizedBox(height: 32),

              // SECCIÓN: PENDIENTES Y TOMAS HOY (En tarjetas modernas)
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                MisMedicamentosScreen(usuarioId: usuarioId),
                          ),
                        );
                        _cargarProximaToma();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: blancoTarjeta,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: sombraSuave,
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.pending_actions_rounded,
                              color: turquesaVibrante,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Pendientes',
                              style: TextStyle(
                                color: textoPrincipal,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              MedicamentosTomadosScreen(usuarioId: usuarioId),
                        ),
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: blancoTarjeta,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: sombraSuave,
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.check_circle_outline_rounded,
                              color: Colors.green,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Tomas Hoy',
                              style: TextStyle(
                                color: textoPrincipal,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),

      // BARRA DE NAVEGACIÓN INFERIOR (Estilo Render)
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  AgregarEditarMedicamentoScreen(usuarioId: usuarioId),
            ),
          );
          _cargarProximaToma();
        },
        backgroundColor: turquesaVibrante,
        elevation: 4,
        shape: const CircleBorder(),
        child: const Icon(Icons.add, color: Colors.white, size: 32),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        color: blancoTarjeta,
        shape: const CircularNotchedRectangle(),
        notchMargin: 8.0,
        elevation: 10,
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                Icons.home_rounded,
                'Inicio',
                turquesaVibrante,
                () {},
              ),
              _buildNavItem(
                Icons.calendar_month_rounded,
                'Calendario',
                textoSecundario,
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          HistorialCalendarioScreen(usuarioId: usuarioId),
                    ),
                  );
                },
              ),
              const SizedBox(width: 40), // Espacio para el botón flotante
              _buildNavItem(
                Icons.settings_suggest_rounded,
                'Gestión',
                textoSecundario,
                () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AdministracionMedicamentosScreen(
                        usuarioId: usuarioId,
                      ),
                    ),
                  );
                  _cargarProximaToma();
                },
              ),
              _buildNavItem(
                Icons.send_rounded,
                'Reportes',
                textoSecundario,
                () {
                  final usuarioActual = FirebaseAuth.instance.currentUser;
                  if (usuarioActual != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => EnviarReporteScreen(
                          pacienteId: usuarioActual.uid,
                          pacienteNombre:
                              usuarioActual.displayName ??
                              widget.usuario['nombre'] ??
                              'Paciente',
                        ),
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Widget de ayuda para la barra de navegación
  Widget _buildNavItem(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

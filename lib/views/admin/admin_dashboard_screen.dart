import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/constants/app_colors.dart';
import '../../services/database_helper.dart';
import '../auth/login_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  List<Map<String, dynamic>> _usuarios = [];

  // --- COLORES CLEAN CLINICAL PREMIUM ---
  final Color bgBlancoPerla = const Color(0xFFF8F9FA);
  final Color blancoTarjeta = Colors.white;
  final Color textoPrincipal = const Color(0xFF2B2D42);
  final Color textoSecundario = const Color(0xFF8D99AE);
  final Color adminOrange = const Color(
    0xFFF59E0B,
  ); // Naranja premium para el admin

  // Sombra suave reutilizable
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
    _cargarUsuarios();
  }

  // TODA TU LÓGICA DE GESTIÓN SE MANTIENE INTACTA
  Future<void> _cargarUsuarios() async {
    final datos = await DatabaseHelper.instance.obtenerUsuarios();
    if (mounted) {
      setState(() => _usuarios = datos);
    }
  }

  Future<void> _alternarEstado(dynamic id, dynamic estadoActual) async {
    final bool esActivo = estadoActual == true || estadoActual == 1;
    final nuevoEstado = esActivo ? 0 : 1;
    await DatabaseHelper.instance.cambiarEstadoUsuario(id, nuevoEstado);
    _cargarUsuarios();
  }

  Future<void> _eliminar(dynamic id) async {
    await DatabaseHelper.instance.eliminarUsuario(id);
    _cargarUsuarios();
  }

  Future<void> _cerrarSesion() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (r) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgBlancoPerla,

      // BARRA SUPERIOR (Limpia y transparente)
      appBar: AppBar(
        title: Text(
          'Panel Admin (Gestión)',
          style: TextStyle(color: adminOrange, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
            tooltip: 'Cerrar Sesión',
            onPressed: _cerrarSesion,
          ),
        ],
      ),

      // CUERPO DEL PANEL
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            // TARJETA PRINCIPAL DE ESTADÍSTICAS
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: blancoTarjeta,
                borderRadius: BorderRadius.circular(20),
                boxShadow: sombraSuave,
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: adminOrange.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.admin_panel_settings_rounded,
                      size: 32,
                      color: adminOrange,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_usuarios.length} Pacientes',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: textoPrincipal,
                            letterSpacing: -0.5,
                          ),
                        ),
                        Text(
                          'Registrados en el sistema',
                          style: TextStyle(
                            fontSize: 13,
                            color: textoSecundario,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // LISTA DE PACIENTES (En tarjetas individuales)
            Expanded(
              child: _usuarios.isEmpty
                  ? Center(
                      child: Text(
                        'No hay pacientes registrados.',
                        style: TextStyle(color: textoSecundario, fontSize: 16),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _usuarios.length,
                      itemBuilder: (context, i) {
                        final u = _usuarios[i];
                        final bool activo =
                            u['activo'] == true || u['activo'] == 1;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: blancoTarjeta,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: sombraSuave,
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            title: Text(
                              u['nombre'] ?? 'Sin nombre',
                              style: TextStyle(
                                color: activo
                                    ? textoPrincipal
                                    : textoSecundario,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                decoration: activo
                                    ? null
                                    : TextDecoration
                                          .lineThrough, // Tacha el nombre si está inhabilitado
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text(
                                  u['email'] ?? '',
                                  style: TextStyle(
                                    color: textoSecundario,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Estado: ${activo ? "ACTIVO" : "INHABILITADO"}',
                                  style: TextStyle(
                                    color: activo
                                        ? Colors.green.shade600
                                        : Colors.redAccent,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Botón Activar/Desactivar
                                IconButton(
                                  icon: Icon(
                                    activo
                                        ? Icons.check_circle_rounded
                                        : Icons.cancel_rounded,
                                    color: activo
                                        ? Colors.green.shade500
                                        : Colors.grey.shade300,
                                    size: 28,
                                  ),
                                  onPressed: () =>
                                      _alternarEstado(u['id'], u['activo']),
                                  tooltip: activo
                                      ? 'Deshabilitar'
                                      : 'Habilitar',
                                ),
                                // Botón Eliminar
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline_rounded,
                                    color: Colors.redAccent,
                                    size: 26,
                                  ),
                                  onPressed: () => _eliminar(u['id']),
                                  tooltip: 'Eliminar paciente',
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

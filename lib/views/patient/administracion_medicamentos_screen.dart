import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../services/database_helper.dart';
import '../../services/notification_service.dart';
import 'agregar_editar_medicamento_screen.dart';

class AdministracionMedicamentosScreen extends StatefulWidget {
  final dynamic usuarioId;
  const AdministracionMedicamentosScreen({super.key, required this.usuarioId});

  @override
  State<AdministracionMedicamentosScreen> createState() =>
      _AdministracionMedicamentosScreenState();
}

class _AdministracionMedicamentosScreenState
    extends State<AdministracionMedicamentosScreen> {
  List<Map<String, dynamic>> _lista = [];

  // --- COLORES CLEAN CLINICAL PREMIUM ---
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
    _cargarLista();
  }

  Future<void> _cargarLista() async {
    final datos = await DatabaseHelper.instance.obtenerTodosMedicamentos(
      widget.usuarioId,
    );
    if (mounted) {
      setState(() => _lista = datos);
    }
  }

  Future<void> _eliminar(dynamic id) async {
    try {
      await DatabaseHelper.instance.eliminarMedicamento(id, widget.usuarioId);
      final notifId = id.toString().hashCode.abs() % 100000;
      await NotificationService().cancelarNotificacionesMedicamento(notifId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Medicamento eliminado con éxito.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
      _cargarLista();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '❌ Ocurrió una falla: No se pudo eliminar el medicamento.',
            ),
            backgroundColor: Colors.redAccent,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgBlancoPerla,
      appBar: AppBar(
        title: Text(
          'Administración de Medicamentos',
          style: TextStyle(
            color: textoPrincipal,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textoPrincipal),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        child: _lista.isEmpty
            ? Center(
                child: Text(
                  'No hay medicamentos para administrar.',
                  style: TextStyle(color: textoSecundario, fontSize: 16),
                ),
              )
            : ListView.builder(
                physics: const BouncingScrollPhysics(),
                itemCount: _lista.length,
                itemBuilder: (context, i) {
                  final item = _lista[i];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: blancoTarjeta,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: sombraSuave,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: turquesaVibrante.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.medication_rounded,
                            color: turquesaVibrante,
                            size: 24,
                          ),
                        ),
                        title: Text(
                          item['nombre'] ?? '',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: textoPrincipal,
                            fontSize: 16,
                          ),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            'Horario: ${item['hora']} hrs | ${item['frecuencia'] ?? 'Todos los días'}\nDosis: ${item['dosis']}',
                            style: TextStyle(
                              color: textoSecundario,
                              height: 1.4,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(
                                Icons.edit_rounded,
                                color: Colors.blue.shade600,
                                size: 24,
                              ),
                              tooltip: 'Editar',
                              onPressed: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        AgregarEditarMedicamentoScreen(
                                          medicamentoEditar: item,
                                          usuarioId: widget.usuarioId,
                                        ),
                                  ),
                                );
                                _cargarLista();
                              },
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline_rounded,
                                color: Colors.redAccent,
                                size: 26,
                              ),
                              tooltip: 'Eliminar',
                              onPressed: () => _eliminar(item['id']),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

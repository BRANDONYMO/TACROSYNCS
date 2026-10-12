import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../services/database_helper.dart';

class MisMedicamentosScreen extends StatefulWidget {
  final dynamic usuarioId;
  const MisMedicamentosScreen({super.key, required this.usuarioId});

  @override
  State<MisMedicamentosScreen> createState() => _MisMedicamentosScreenState();
}

class _MisMedicamentosScreenState extends State<MisMedicamentosScreen> {
  List<Map<String, dynamic>> _todosMedicamentos = [];
  List<Map<String, dynamic>> _tomadosHoy = [];
  bool _cargando = true;
  dynamic _procesandoId;

  // --- COLORES CLEAN CLINICAL PREMIUM ---
  final Color bgBlancoPerla = const Color(0xFFF8F9FA);
  final Color blancoTarjeta = Colors.white;
  final Color textoPrincipal = const Color(0xFF2B2D42);
  final Color textoSecundario = const Color(0xFF8D99AE);
  final Color turquesaVibrante = const Color(0xFF00B4D8);
  final Color grisPildora = const Color(
    0xFF64748B,
  ); // Gris premium para etiqueta "PRÓXIMAMENTE"

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
    _cargarMedicamentos();
  }

  // --- TODA TU LÓGICA INTACTA ---
  Future<void> _cargarMedicamentos() async {
    if (!mounted) return;
    setState(() => _cargando = true);

    await DatabaseHelper.instance.evaluarTomasVencidas(widget.usuarioId);

    final todos = await DatabaseHelper.instance.obtenerTodosMedicamentos(
      widget.usuarioId,
    );
    final tomados = await DatabaseHelper.instance.obtenerTomadosHoy(
      widget.usuarioId,
    );

    if (mounted) {
      setState(() {
        _tomadosHoy = tomados;
        _todosMedicamentos = todos;
        _cargando = false;
      });
    }
  }

  int _obtenerToleranciaMinutos(String? frecuenciaStr) {
    if (frecuenciaStr == null || frecuenciaStr.isEmpty) return 30;
    final exp = RegExp(r'\d+');
    final match = exp.firstMatch(frecuenciaStr);
    if (match != null) {
      final horas = int.tryParse(match.group(0)!) ?? 24;
      if (horas <= 1) return 25;
      if (horas <= 2) return 40;
    }
    return 45;
  }

  bool _puedoMarcarToma(
    String horaProgramada, {
    String? fechaProgramadaStr,
    String? frecuenciaStr,
    int margenPrevioMinutos = 5,
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

    final int tolerancia = _obtenerToleranciaMinutos(frecuenciaStr);
    final inicioPermitido = fechaHoraProg.subtract(
      Duration(minutes: margenPrevioMinutos),
    );
    final finPermitido = fechaHoraProg.add(Duration(minutes: tolerancia));

    return ahora.isAfter(inicioPermitido) && ahora.isBefore(finPermitido);
  }

  bool _yaFueTomadaEstaHoraExacta(Map<String, dynamic> item) {
    final String medId = (item['id'] ?? '').toString();
    final String horaActualProg = item['hora'] ?? '';
    if (horaActualProg.isEmpty) return false;

    for (var toma in _tomadosHoy) {
      final String idTomado = (toma['medicamentoId'] ?? toma['id'] ?? '')
          .toString();
      final String horaTomadaProg =
          toma['horaProgramada'] ??
          toma['hora_programada'] ??
          toma['hora'] ??
          '';
      if (idTomado == medId && horaTomadaProg == horaActualProg) {
        return true;
      }
    }
    return false;
  }

  Future<void> _marcarTomado(Map<String, dynamic> med) async {
    final dynamic medId = med['id'];
    if (_procesandoId == medId) return;

    final String hora = med['hora'] ?? '';
    final String fecha = med['fecha_programada'] ?? med['fecha'] ?? '';
    final String frecuencia = med['frecuencia'] ?? '';
    final bool estaEnRango = _puedoMarcarToma(
      hora,
      fechaProgramadaStr: fecha,
      frecuenciaStr: frecuencia,
    );

    if (!estaEnRango) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '⏰ Aún no es la hora de este medicamento (disponible 5 min antes).',
          ),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    setState(() => _procesandoId = medId);

    try {
      await DatabaseHelper.instance.registrarTomaYProgramarSiguiente(
        med,
        widget.usuarioId,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ ¡Toma de ${med['nombre']} registrada correctamente!',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
      await _cargarMedicamentos();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al registrar toma: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _procesandoId = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgBlancoPerla,
      appBar: AppBar(
        title: Text(
          'Estado de Medicamentos',
          style: TextStyle(color: textoPrincipal, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textoPrincipal),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: textoPrincipal),
            onPressed: _cargarMedicamentos,
            tooltip: 'Actualizar lista',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        child: _cargando
            ? Center(child: CircularProgressIndicator(color: turquesaVibrante))
            : _todosMedicamentos.isEmpty
            ? Center(
                child: Text(
                  '¡No hay medicamentos pendientes!',
                  style: TextStyle(color: textoSecundario, fontSize: 16),
                ),
              )
            : ListView.builder(
                physics: const BouncingScrollPhysics(),
                itemCount: _todosMedicamentos.length,
                itemBuilder: (context, i) {
                  final item = _todosMedicamentos[i];
                  final dynamic id = item['id'];
                  final String hora = item['hora'] ?? '';
                  final String fecha =
                      item['fecha_programada'] ?? item['fecha'] ?? '';
                  final String frecuencia = item['frecuencia'] ?? '';

                  final bool enRango = _puedoMarcarToma(
                    hora,
                    fechaProgramadaStr: fecha,
                    frecuenciaStr: frecuencia,
                  );
                  final bool yaTomadoEstaHora = _yaFueTomadaEstaHoraExacta(
                    item,
                  );
                  final bool estaProcesando = _procesandoId == id;

                  // Configuración de estilos según el estado de la toma
                  String etiquetaEstado;
                  Color colorFondoEtiqueta;
                  IconData iconoAccion;
                  Color colorIcono;
                  bool esHabilitadoParaToma = false;

                  if (enRango && !yaTomadoEstaHora) {
                    etiquetaEstado = 'DISPONIBLE';
                    colorFondoEtiqueta = turquesaVibrante;
                    iconoAccion = Icons.touch_app_rounded;
                    colorIcono = turquesaVibrante;
                    esHabilitadoParaToma = true;
                  } else if (yaTomadoEstaHora) {
                    etiquetaEstado = 'TOMADO';
                    colorFondoEtiqueta = Colors.green.shade500;
                    iconoAccion = Icons.check_circle_rounded;
                    colorIcono = Colors.green.shade500;
                    esHabilitadoParaToma = false;
                  } else {
                    etiquetaEstado = 'PRÓXIMAMENTE';
                    colorFondoEtiqueta = grisPildora;
                    iconoAccion = Icons.lock_clock_rounded;
                    colorIcono = textoSecundario;
                    esHabilitadoParaToma = false;
                  }

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
                        leading: estaProcesando
                            ? SizedBox(
                                width: 28,
                                height: 28,
                                child: CircularProgressIndicator(
                                  strokeWidth: 3,
                                  color: turquesaVibrante,
                                ),
                              )
                            : IconButton(
                                icon: Icon(
                                  iconoAccion,
                                  color: colorIcono,
                                  size: 28,
                                ),
                                onPressed: esHabilitadoParaToma
                                    ? () => _marcarTomado(item)
                                    : null,
                              ),
                        title: Text(
                          item['nombre'] ?? '',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: yaTomadoEstaHora
                                ? textoSecundario
                                : textoPrincipal,
                            decoration: yaTomadoEstaHora
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            'Dosis: ${item['dosis']} | Frecuencia:\n${item['frecuencia'] ?? 'Todos los días'}\nPróxima Alarma: $hora hrs',
                            style: TextStyle(
                              color: textoSecundario,
                              height: 1.4,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: colorFondoEtiqueta,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            etiquetaEstado,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
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

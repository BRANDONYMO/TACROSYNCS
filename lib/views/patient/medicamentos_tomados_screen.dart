import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../services/database_helper.dart';

class MedicamentosTomadosScreen extends StatefulWidget {
  final dynamic usuarioId;
  const MedicamentosTomadosScreen({super.key, required this.usuarioId});

  @override
  State<MedicamentosTomadosScreen> createState() =>
      _MedicamentosTomadosScreenState();
}

class _MedicamentosTomadosScreenState extends State<MedicamentosTomadosScreen> {
  List<Map<String, dynamic>> _tomados = [];
  List<Map<String, dynamic>> _noTomados = [];
  bool _cargando = true;

  // --- COLORES CLEAN CLINICAL PREMIUM ---
  final Color bgBlancoPerla = const Color(0xFFF8F9FA);
  final Color blancoTarjeta = Colors.white;
  final Color textoPrincipal = const Color(0xFF2B2D42);
  final Color textoSecundario = const Color(0xFF8D99AE);

  // Colores de estado ajustados para fondo claro
  final Color colorExito = Colors.green.shade600;
  final Color colorAlerta = Colors.red.shade600;

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
    _cargarTomados();
  }

  Future<void> _cargarTomados() async {
    final datos = await DatabaseHelper.instance.obtenerTomadosHoy(
      widget.usuarioId,
    );
    if (mounted) {
      setState(() {
        _tomados = datos.where((item) => item['estado'] == 'Tomada').toList();
        _noTomados = datos
            .where((item) => item['estado'] == 'Vencida')
            .toList();
        _cargando = false;
      });
    }
  }

  Widget _construirTarjetaMedicamento(
    Map<String, dynamic> item,
    bool esTomada,
  ) {
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
          leading: Icon(
            esTomada ? Icons.check_circle_rounded : Icons.cancel_rounded,
            color: esTomada ? colorExito : colorAlerta,
            size: 32,
          ),
          title: Text(
            item['nombre'] ?? '',
            style: TextStyle(
              color: textoPrincipal,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Text(
              'Fecha: ${item['fecha'] ?? ''}\n'
              'Dosis: ${item['dosis'] ?? ''} | Prog: ${item['horaProgramada'] ?? ''} hrs',
              style: TextStyle(
                color: textoSecundario,
                height: 1.4,
                fontSize: 13,
              ),
            ),
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                esTomada ? 'Tomado a las' : 'NO TOMADA',
                style: TextStyle(
                  color: esTomada ? colorExito : colorAlerta,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                esTomada ? '${item['horaRealizada'] ?? ''}' : '(Vencida)',
                style: TextStyle(
                  color: esTomada ? colorExito : colorAlerta,
                  fontSize: esTomada ? 14 : 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _construirEncabezadoSeccion(
    String titulo,
    IconData icono,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Row(
        children: [
          Icon(icono, color: color, size: 22),
          const SizedBox(width: 8),
          Text(
            titulo,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool estaVacio = _tomados.isEmpty && _noTomados.isEmpty;

    return Scaffold(
      backgroundColor: bgBlancoPerla,
      appBar: AppBar(
        title: Text(
          'Tomas Realizadas Hoy',
          style: TextStyle(color: textoPrincipal, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textoPrincipal),
      ),
      body: _cargando
          ? Center(child: CircularProgressIndicator(color: colorExito))
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: estaVacio
                  ? Center(
                      child: Text(
                        'No hay registros de tomas para el día de hoy',
                        style: TextStyle(color: textoSecundario, fontSize: 16),
                      ),
                    )
                  : ListView(
                      physics: const BouncingScrollPhysics(),
                      children: [
                        // --- SECCIÓN: MEDICAMENTOS TOMADOS ---
                        _construirEncabezadoSeccion(
                          'Medicamentos Tomados (${_tomados.length})',
                          Icons.check_circle_outline_rounded,
                          colorExito,
                        ),
                        if (_tomados.isEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16.0),
                            child: Text(
                              'Aún no has tomado ningún medicamento hoy',
                              style: TextStyle(
                                color: textoSecundario,
                                fontSize: 14,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          )
                        else
                          ..._tomados.map(
                            (item) => _construirTarjetaMedicamento(item, true),
                          ),

                        const SizedBox(height: 16),
                        const Divider(height: 1, color: Colors.black12),
                        const SizedBox(height: 8),

                        // --- SECCIÓN: MEDICAMENTOS NO TOMADOS (VENCIDOS) ---
                        _construirEncabezadoSeccion(
                          'Medicamentos No Tomados (${_noTomados.length})',
                          Icons.highlight_off_rounded,
                          colorAlerta,
                        ),
                        if (_noTomados.isEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16.0),
                            child: Text(
                              '¡Excelente! No hay tomas omitidas hoy',
                              style: TextStyle(
                                color: textoSecundario,
                                fontSize: 14,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          )
                        else
                          ..._noTomados.map(
                            (item) => _construirTarjetaMedicamento(item, false),
                          ),
                        const SizedBox(height: 32), // Espacio final
                      ],
                    ),
            ),
    );
  }
}

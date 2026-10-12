import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../core/constants/app_colors.dart';
import '../../services/database_helper.dart';

class HistorialCalendarioScreen extends StatefulWidget {
  final dynamic usuarioId;
  const HistorialCalendarioScreen({super.key, required this.usuarioId});

  @override
  State<HistorialCalendarioScreen> createState() =>
      _HistorialCalendarioScreenState();
}

class _HistorialCalendarioScreenState extends State<HistorialCalendarioScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();

  List<Map<String, dynamic>> _tomados = [];
  List<Map<String, dynamic>> _noTomados = [];
  bool _cargando = false;

  // --- COLORES CLEAN CLINICAL PREMIUM ---
  final Color bgBlancoPerla = const Color(0xFFF8F9FA);
  final Color blancoTarjeta = Colors.white;
  final Color textoPrincipal = const Color(0xFF2B2D42);
  final Color textoSecundario = const Color(0xFF8D99AE);
  final Color turquesaVibrante = const Color(0xFF00B4D8);

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
    _cargarHistorialPorDia(_selectedDay);
  }

  // Formatea la fecha a String 'YYYY-MM-DD'
  String _formatearFecha(DateTime date) {
    String month = date.month.toString().padLeft(2, '0');
    String day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  Future<void> _cargarHistorialPorDia(DateTime dia) async {
    setState(() => _cargando = true);

    final fechaStr = _formatearFecha(dia);
    final datos = await DatabaseHelper.instance.obtenerHistorialPorFecha(
      widget.usuarioId,
      fechaStr,
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
              'Dosis: ${item['dosis'] ?? ''}\nHora programada: ${item['horaProgramada'] ?? ''} hrs',
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
                esTomada ? '${item['horaRealizada'] ?? ''} hrs' : '(Vencida)',
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgBlancoPerla,
      appBar: AppBar(
        title: Text(
          'Historial por Calendario',
          style: TextStyle(color: textoPrincipal, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textoPrincipal),
      ),
      body: Column(
        children: [
          // --- COMPONENTE CALENDARIO (ESTILO PREMIUM) ---
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            padding: const EdgeInsets.only(bottom: 12.0),
            decoration: BoxDecoration(
              color: blancoTarjeta,
              borderRadius: BorderRadius.circular(20),
              boxShadow: sombraSuave,
            ),
            child: TableCalendar(
              firstDay: DateTime.utc(2024, 1, 1),
              lastDay: DateTime.now().add(const Duration(days: 365)),
              focusedDay: _focusedDay,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                });
                _cargarHistorialPorDia(selectedDay);
              },
              calendarStyle: CalendarStyle(
                todayDecoration: BoxDecoration(
                  color: turquesaVibrante.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                selectedDecoration: BoxDecoration(
                  color: turquesaVibrante,
                  shape: BoxShape.circle,
                ),
                selectedTextStyle: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
                defaultTextStyle: TextStyle(
                  color: textoPrincipal,
                  fontWeight: FontWeight.w500,
                ),
                weekendTextStyle: TextStyle(
                  color: textoSecundario,
                  fontWeight: FontWeight.w500,
                ),
                outsideTextStyle: TextStyle(
                  color: textoSecundario.withOpacity(0.5),
                ),
              ),
              headerStyle: HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
                titleTextStyle: TextStyle(
                  color: textoPrincipal,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                leftChevronIcon: Icon(
                  Icons.chevron_left_rounded,
                  color: turquesaVibrante,
                  size: 28,
                ),
                rightChevronIcon: Icon(
                  Icons.chevron_right_rounded,
                  color: turquesaVibrante,
                  size: 28,
                ),
              ),
              daysOfWeekStyle: DaysOfWeekStyle(
                weekdayStyle: TextStyle(
                  color: textoSecundario,
                  fontWeight: FontWeight.bold,
                ),
                weekendStyle: TextStyle(
                  color: textoSecundario,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // --- DETALLE DE TOMAS DEL DÍA SELECCIONADO ---
          Expanded(
            child: _cargando
                ? Center(
                    child: CircularProgressIndicator(color: turquesaVibrante),
                  )
                : _tomados.isEmpty && _noTomados.isEmpty
                ? Center(
                    child: Text(
                      'No hay registros para el ${_formatearFecha(_selectedDay)}',
                      style: TextStyle(color: textoSecundario, fontSize: 16),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    physics: const BouncingScrollPhysics(),
                    children: [
                      if (_tomados.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12.0),
                          child: Row(
                            children: [
                              Icon(
                                Icons.check_circle_outline_rounded,
                                color: colorExito,
                                size: 22,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Tomados',
                                style: TextStyle(
                                  color: colorExito,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ..._tomados.map(
                          (item) => _construirTarjetaMedicamento(item, true),
                        ),
                      ],
                      if (_noTomados.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12.0),
                          child: Row(
                            children: [
                              Icon(
                                Icons.highlight_off_rounded,
                                color: colorAlerta,
                                size: 22,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'No Tomados / Vencidos',
                                style: TextStyle(
                                  color: colorAlerta,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ..._noTomados.map(
                          (item) => _construirTarjetaMedicamento(item, false),
                        ),
                      ],
                      const SizedBox(height: 20),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

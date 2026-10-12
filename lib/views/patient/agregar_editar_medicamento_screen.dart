import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../services/database_helper.dart';
import '../../services/notification_service.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_textfield.dart';

class AgregarEditarMedicamentoScreen extends StatefulWidget {
  final Map<String, dynamic>? medicamentoEditar;
  final dynamic usuarioId;

  const AgregarEditarMedicamentoScreen({
    super.key,
    this.medicamentoEditar,
    required this.usuarioId,
  });

  @override
  State<AgregarEditarMedicamentoScreen> createState() =>
      _AgregarEditarMedicamentoScreenState();
}

class _AgregarEditarMedicamentoScreenState
    extends State<AgregarEditarMedicamentoScreen> {
  final _nombreCtrl = TextEditingController();
  final _dosisCtrl = TextEditingController();
  final _horasPersonalizadasCtrl = TextEditingController();
  TimeOfDay _horaSeleccionada = TimeOfDay.now();

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

  // Opciones completas de frecuencia
  final List<String> _opcionesFrecuencia = [
    'Cada 1 hora',
    'Cada 2 horas',
    'Cada 3 horas',
    'Cada 4 horas',
    'Cada 6 horas',
    'Cada 8 horas',
    'Cada 12 horas',
    'Cada 24 horas',
    'Todos los días',
    'Cada 2 días',
    'Personalizado (en horas)',
  ];
  late String _frecuenciaSeleccionada;

  @override
  void initState() {
    super.initState();
    _frecuenciaSeleccionada = 'Cada 8 horas';

    if (widget.medicamentoEditar != null) {
      _nombreCtrl.text = widget.medicamentoEditar!['nombre'] ?? '';
      _dosisCtrl.text = widget.medicamentoEditar!['dosis'] ?? '';

      final valFrec = widget.medicamentoEditar!['frecuencia'];
      if (valFrec != null) {
        if (_opcionesFrecuencia.contains(valFrec)) {
          _frecuenciaSeleccionada = valFrec;
        } else {
          _frecuenciaSeleccionada = 'Personalizado (en horas)';
          final RegExp regExp = RegExp(r'\d+');
          final match = regExp.firstMatch(valFrec);
          if (match != null) {
            _horasPersonalizadasCtrl.text = match.group(0)!;
          }
        }
      }

      final partes = (widget.medicamentoEditar!['hora'] ?? '').toString().split(
        ':',
      );
      if (partes.length == 2) {
        _horaSeleccionada = TimeOfDay(
          hour: int.tryParse(partes[0]) ?? 8,
          minute: int.tryParse(partes[1]) ?? 0,
        );
      }
    }
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _dosisCtrl.dispose();
    _horasPersonalizadasCtrl.dispose();
    super.dispose();
  }

  int _extraerHorasDeFrecuencia(String frecuenciaStr) {
    if (frecuenciaStr == 'Cada 2 días') return 48;
    if (frecuenciaStr == 'Todos los días') return 24;

    final RegExp regExp = RegExp(r'\d+');
    final match = regExp.firstMatch(frecuenciaStr);
    if (match != null) {
      return int.tryParse(match.group(0)!) ?? 24;
    }

    return 24;
  }

  Future<void> _seleccionarHora() async {
    final TimeOfDay? pick = await showTimePicker(
      context: context,
      initialTime: _horaSeleccionada,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: turquesaVibrante,
              onPrimary: Colors.white,
              onSurface: textoPrincipal,
            ),
          ),
          child: child!,
        );
      },
    );
    if (pick != null) {
      setState(() => _horaSeleccionada = pick);
    }
  }

  Future<void> _guardarYProgramar() async {
    final nombre = _nombreCtrl.text.trim();
    final dosisStr = _dosisCtrl.text.trim().isNotEmpty
        ? _dosisCtrl.text.trim()
        : '1 Cáp.';
    final esEdicion = widget.medicamentoEditar != null;

    if (nombre.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Por favor ingresa el nombre del medicamento'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    String frecuenciaFinal = _frecuenciaSeleccionada;
    if (_frecuenciaSeleccionada == 'Personalizado (en horas)') {
      final horasTexto = _horasPersonalizadasCtrl.text.trim();
      final numHoras = int.tryParse(horasTexto);
      if (numHoras == null || numHoras <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ Ingresa un número de horas personalizado válido'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
        return;
      }
      frecuenciaFinal = 'Cada $numHoras horas';
    }

    final dynamic idExcluir = esEdicion
        ? widget.medicamentoEditar!['id']
        : null;
    final duplicado = await DatabaseHelper.instance.existeMedicamentoConNombre(
      nombre,
      widget.usuarioId,
      idExcluir: idExcluir,
    );

    if (duplicado) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '⚠️ Ya existe un medicamento registrado con este nombre.',
          ),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    final horaTexto =
        '${_horaSeleccionada.hour.toString().padLeft(2, '0')}:${_horaSeleccionada.minute.toString().padLeft(2, '0')}';
    final int intervaloHoras = _extraerHorasDeFrecuencia(frecuenciaFinal);
    final ahora = DateTime.now();
    var fechaProgramada = DateTime(
      ahora.year,
      ahora.month,
      ahora.day,
      _horaSeleccionada.hour,
      _horaSeleccionada.minute,
    );

    while (fechaProgramada.isBefore(ahora)) {
      fechaProgramada = fechaProgramada.add(Duration(hours: intervaloHoras));
    }

    try {
      dynamic idMedicamento;
      if (esEdicion) {
        idMedicamento = widget.medicamentoEditar!['id'];
        await DatabaseHelper.instance.actualizarMedicamento(idMedicamento, {
          'nombre': nombre,
          'dosis': dosisStr,
          'hora': horaTexto,
          'frecuencia': frecuenciaFinal,
        });
      } else {
        idMedicamento = await DatabaseHelper.instance.insertarMedicamento({
          'usuarioId': widget.usuarioId,
          'nombre': nombre,
          'dosis': dosisStr,
          'hora': horaTexto,
          'frecuencia': frecuenciaFinal,
          'tomado': 0,
        });
      }

      final notifId = idMedicamento.toString().hashCode.abs() % 100000;
      await NotificationService().programarTomasFuturasMultipes(
        medicamentoId: notifId,
        titulo: '💊 Recordatorio Tacrosync',
        cuerpo: 'Es hora de tomar tu medicamento: $nombre ($dosisStr)',
        primeraToma: fechaProgramada,
        intervaloHoras: intervaloHoras,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            esEdicion
                ? 'El medicamento se actualizó correctamente.'
                : 'Registro exitoso. Alarmas programadas a partir de las $horaTexto hrs.',
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            esEdicion
                ? 'Ocurrió una falla: No se pudo actualizar el medicamento.'
                : 'Ocurrió una falla: No se pudo programar el medicamento.',
          ),
          backgroundColor: Colors.redAccent,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  // Helper local para garantizar que el TextField se vea premium y blanco
  Widget _buildPremiumInput({
    required String hint,
    required IconData icon,
    required TextEditingController controller,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: blancoTarjeta,
        borderRadius: BorderRadius.circular(16),
        boxShadow: sombraSuave,
      ),
      child: TextField(
        controller: controller,
        style: TextStyle(color: textoPrincipal, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: textoSecundario),
          prefixIcon: Icon(icon, color: turquesaVibrante),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 18,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final esEdicion = widget.medicamentoEditar != null;
    return Scaffold(
      backgroundColor: bgBlancoPerla,
      appBar: AppBar(
        title: Text(
          esEdicion ? 'Editar Medicamento' : 'Agregar Medicamento',
          style: TextStyle(color: textoPrincipal, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textoPrincipal),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPremiumInput(
              hint: 'Nombre del Medicamento (Ej: Tacrolimus)',
              icon: Icons.medication_rounded,
              controller: _nombreCtrl,
            ),
            const SizedBox(height: 16),
            _buildPremiumInput(
              hint: 'Dosis (Ej: 1 mg)',
              icon: Icons.straighten_rounded,
              controller: _dosisCtrl,
            ),
            const SizedBox(height: 16),

            // Dropdown de Frecuencia estilo Premium
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: blancoTarjeta,
                borderRadius: BorderRadius.circular(16),
                boxShadow: sombraSuave,
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _frecuenciaSeleccionada,
                  isExpanded: true,
                  dropdownColor: blancoTarjeta,
                  icon: Icon(Icons.repeat_rounded, color: turquesaVibrante),
                  style: TextStyle(
                    color: textoPrincipal,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                  items: _opcionesFrecuencia.map((String opc) {
                    return DropdownMenuItem<String>(
                      value: opc,
                      child: Text('Frecuencia: $opc'),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _frecuenciaSeleccionada = val);
                    }
                  },
                ),
              ),
            ),

            if (_frecuenciaSeleccionada == 'Personalizado (en horas)') ...[
              const SizedBox(height: 16),
              _buildPremiumInput(
                hint: 'Ingresa intervalo en horas (ej: 5, 18)',
                icon: Icons.timer_outlined,
                controller: _horasPersonalizadasCtrl,
              ),
            ],

            const SizedBox(height: 24),

            // Tarjeta de Selección de Hora
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: blancoTarjeta,
                borderRadius: BorderRadius.circular(16),
                boxShadow: sombraSuave,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hora de la toma',
                        style: TextStyle(color: textoSecundario, fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _horaSeleccionada.format(context),
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: turquesaVibrante,
                        ),
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: turquesaVibrante,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    icon: const Icon(
                      Icons.access_time_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                    label: const Text(
                      'Cambiar Hora',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed: _seleccionarHora,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Botón Principal
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _guardarYProgramar,
                style: ElevatedButton.styleFrom(
                  backgroundColor: turquesaVibrante,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  esEdicion
                      ? 'ACTUALIZAR MEDICAMENTO'
                      : 'GUARDAR Y PROGRAMAR ALARMA',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

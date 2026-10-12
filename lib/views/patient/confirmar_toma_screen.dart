import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../services/database_helper.dart';
import '../../widgets/custom_button.dart';

class ConfirmarTomaScreen extends StatefulWidget {
  final List<Map<String, dynamic>> listaMedicamentos;
  final dynamic usuarioId;

  const ConfirmarTomaScreen({
    super.key,
    required this.listaMedicamentos,
    required this.usuarioId,
  });

  @override
  State<ConfirmarTomaScreen> createState() => _ConfirmarTomaScreenState();
}

class _ConfirmarTomaScreenState extends State<ConfirmarTomaScreen> {
  bool _cargando = false;

  // --- COLORES CLEAN CLINICAL PREMIUM ---
  final Color bgBlancoPerla = const Color(0xFFF8F9FA);
  final Color blancoTarjeta = Colors.white;
  final Color textoPrincipal = const Color(0xFF2B2D42);
  final Color textoSecundario = const Color(0xFF8D99AE);
  final Color turquesaVibrante = const Color(0xFF00B4D8);

  final List<BoxShadow> sombraSuave = [
    BoxShadow(
      color: Colors.black.withOpacity(0.08),
      blurRadius: 20,
      offset: const Offset(0, 8),
    ),
  ];

  Future<void> _registrarTodasLasTomas(BuildContext context) async {
    if (_cargando) return; // Evita ejecuciones dobles simultáneas

    setState(() {
      _cargando = true;
    });

    try {
      for (var med in widget.listaMedicamentos) {
        await DatabaseHelper.instance.registrarTomaYProgramarSiguiente(
          med,
          widget.usuarioId,
        );
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '✅ ¡Toma(s) registrada(s)! Se reprogramaron automáticamente las siguientes alarmas.',
          ),
          backgroundColor: Colors.green,
        ),
      );

      // Notificar a la pantalla anterior que se realizaron cambios para refrescar UI
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error al registrar toma: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _cargando = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.listaMedicamentos.isEmpty) {
      return Scaffold(
        backgroundColor: bgBlancoPerla,
        appBar: AppBar(
          title: Text(
            'Confirmar Toma',
            style: TextStyle(
              color: textoPrincipal,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: textoPrincipal),
        ),
        body: Center(
          child: Text(
            'No hay medicamentos para confirmar.',
            style: TextStyle(color: textoSecundario, fontSize: 16),
          ),
        ),
      );
    }

    final hora = widget.listaMedicamentos.first['hora'] ?? '';

    return Scaffold(
      backgroundColor: bgBlancoPerla,
      appBar: AppBar(
        title: Text(
          'Confirmar Toma',
          style: TextStyle(color: textoPrincipal, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textoPrincipal),
      ),
      body: Center(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 24.0,
              vertical: 16.0,
            ),
            child: Container(
              padding: const EdgeInsets.all(32.0),
              decoration: BoxDecoration(
                color: blancoTarjeta,
                borderRadius: BorderRadius.circular(28),
                boxShadow:
                    sombraSuave, // Sombra profunda y suave que le da volumen
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Icono central con fondo sutil
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: turquesaVibrante.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.alarm_on_rounded,
                      size: 72,
                      color: turquesaVibrante,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Título
                  Text(
                    'Medicamento(s) a tomar:',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textoPrincipal,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Lista de medicamentos dentro de la tarjeta
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: widget.listaMedicamentos.length,
                      itemBuilder: (context, i) {
                        final med = widget.listaMedicamentos[i];
                        return Container(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color:
                                bgBlancoPerla, // Fondo ligerito para diferenciar la medicina
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  med['nombre'] ?? '',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: turquesaVibrante,
                                  ),
                                ),
                              ),
                              Text(
                                'Dosis: ${med['dosis'] ?? ''}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: textoPrincipal,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Hora
                  Text(
                    'Hora programada: $hora hrs',
                    style: TextStyle(
                      fontSize: 14,
                      color: textoSecundario,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Botón de acción principal
                  _cargando
                      ? CircularProgressIndicator(color: turquesaVibrante)
                      : SizedBox(
                          width: double.infinity,
                          height: 55,
                          child: ElevatedButton(
                            onPressed: () => _registrarTodasLasTomas(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: turquesaVibrante,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: const Text(
                              'REGISTRAR COMO TOMADO(S)',
                              style: TextStyle(
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
          ),
        ),
      ),
    );
  }
}

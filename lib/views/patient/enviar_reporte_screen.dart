import 'package:flutter/material.dart';
import '../../services/reporte_service.dart';

class EnviarReporteScreen extends StatefulWidget {
  final String pacienteId; // ID del usuario actual en Firebase
  final String pacienteNombre; // Nombre del paciente

  const EnviarReporteScreen({
    Key? key,
    required this.pacienteId,
    required this.pacienteNombre,
  }) : super(key: key);

  @override
  State<EnviarReporteScreen> createState() => _EnviarReporteScreenState();
}

class _EnviarReporteScreenState extends State<EnviarReporteScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nombreDoctorController = TextEditingController();
  final TextEditingController _correoDoctorController = TextEditingController();

  bool _isLoading = false; // Controla la bolita de carga

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

  Future<void> _enviarCorreo() async {
    // Valida que los campos no estén vacíos
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      // Ahora recibimos un String con el resultado
      String resultado = await ReporteService.generarYEnviarReporteFirebase(
        pacienteId: widget.pacienteId,
        doctorEmail: _correoDoctorController.text.trim(),
        doctorNombre: _nombreDoctorController.text.trim(),
        pacienteNombre: widget.pacienteNombre,
      );

      setState(() {
        _isLoading = false;
      });

      if (resultado == 'EXITO') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Reporte enviado exitosamente y corte realizado.'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context); // Regresa al menú después de enviar
      } else {
        // Imprimimos el error exacto en el cuadro rojo
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ $resultado'),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _nombreDoctorController.dispose();
    _correoDoctorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgBlancoPerla,

      appBar: AppBar(
        title: Text(
          'Enviar Reporte Médico',
          style: TextStyle(color: textoPrincipal, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textoPrincipal),
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Texto de instrucción elegante
              Text(
                'Ingresa los datos de tu médico. Se enviará un reporte con todas tus tomas registradas desde la última vez que hiciste un envío.',
                style: TextStyle(
                  fontSize: 14,
                  color: textoSecundario,
                  height: 1.5, // Interlineado para mejor lectura
                ),
              ),
              const SizedBox(height: 28),

              // CAMPO: Nombre del Doctor (Tarjeta Premium)
              Container(
                decoration: BoxDecoration(
                  color: blancoTarjeta,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: sombraSuave,
                ),
                child: TextFormField(
                  controller: _nombreDoctorController,
                  style: TextStyle(
                    color: textoPrincipal,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Nombre del Doctor (Ej. Dr. Simi)',
                    labelStyle: TextStyle(color: textoSecundario),
                    border: InputBorder.none,
                    prefixIcon: Icon(
                      Icons.person_rounded,
                      color: turquesaVibrante,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 18,
                    ),
                  ),
                  validator: (value) =>
                      value!.isEmpty ? 'Por favor ingresa el nombre' : null,
                ),
              ),
              const SizedBox(height: 20),

              // CAMPO: Correo del Doctor (Tarjeta Premium)
              Container(
                decoration: BoxDecoration(
                  color: blancoTarjeta,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: sombraSuave,
                ),
                child: TextFormField(
                  controller: _correoDoctorController,
                  keyboardType: TextInputType.emailAddress,
                  style: TextStyle(
                    color: textoPrincipal,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Correo Electrónico del Doctor',
                    labelStyle: TextStyle(color: textoSecundario),
                    border: InputBorder.none,
                    prefixIcon: Icon(
                      Icons.email_rounded,
                      color: turquesaVibrante,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 18,
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Por favor ingresa el correo';
                    }
                    if (!value.contains('@')) {
                      return 'Ingresa un correo válido';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(height: 36),

              // BOTÓN PRINCIPAL
              _isLoading
                  ? Center(
                      child: CircularProgressIndicator(color: turquesaVibrante),
                    )
                  : SizedBox(
                      height:
                          55, // Altura estándar de todos los botones en la app
                      child: ElevatedButton.icon(
                        onPressed: _enviarCorreo,
                        icon: const Icon(
                          Icons.send_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                        label: const Text(
                          'ENVIAR REPORTE Y HACER CORTE',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: turquesaVibrante,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}

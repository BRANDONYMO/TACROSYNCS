import 'dart:convert';
import 'package:http/http.dart' as http;

class EmailService {
  static const String _serviceId = 'service_48czfs8';
  static const String _templateId = 'template_48brxh8';
  static const String _publicKey = 'kWXlboXIorObF8829';
  static const String _privateKey = 'fBHx68jihK_jhPEgxoCGS';

  // Ahora devuelve un String con el error real
  static Future<String> enviarReporte({
    required String correoDoctor,
    required String nombreDoctor,
    required String nombrePaciente,
    required String reporteMedicamentos,
  }) async {
    final url = Uri.parse('https://api.emailjs.com/api/v1.0/email/send');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'service_id': _serviceId,
          'template_id': _templateId,
          'user_id': _publicKey,
          'accessToken': _privateKey,
          'template_params': {
            'correo_doctor': correoDoctor,
            'nombre_doctor': nombreDoctor,
            'nombre_paciente': nombrePaciente,
            'reporte_medicamentos': reporteMedicamentos,
          },
        }),
      );

      if (response.statusCode == 200) {
        return 'EXITO';
      } else {
        // ESTO NOS DARÁ EL VERDADERO MOTIVO DEL RECHAZO
        return 'EmailJS dice: ${response.body}';
      }
    } catch (e) {
      return 'Error de conexión: $e';
    }
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'email_service.dart';

class ReporteService {
  static Future<String> generarYEnviarReporteFirebase({
    required String pacienteId,
    required String doctorEmail,
    required String doctorNombre,
    required String pacienteNombre,
  }) async {
    try {
      final firestore = FirebaseFirestore.instance;
      final usuarioRef = firestore.collection('usuarios').doc(pacienteId);

      final usuarioDoc = await usuarioRef.get();
      Timestamp? ultimoCorte;
      if (usuarioDoc.exists &&
          usuarioDoc.data() != null &&
          usuarioDoc.data()!.containsKey('fecha_ultimo_reporte')) {
        ultimoCorte = usuarioDoc.data()!['fecha_ultimo_reporte'];
      }

      final querySnapshot = await firestore
          .collection('historial_tomas')
          .where('usuarioId', isEqualTo: pacienteId)
          .get();

      var listaTomas = querySnapshot.docs.toList();

      if (ultimoCorte != null) {
        listaTomas = listaTomas.where((doc) {
          final data = doc.data();
          if (data['creadoEn'] == null) return false;
          Timestamp fechaCreacion = data['creadoEn'];
          return fechaCreacion.toDate().isAfter(ultimoCorte!.toDate());
        }).toList();
      }

      if (listaTomas.isEmpty) {
        return 'No hay tomas nuevas registradas después de tu último reporte enviado.';
      }

      listaTomas.sort((a, b) {
        Timestamp? tA = a.data()['creadoEn'];
        Timestamp? tB = b.data()['creadoEn'];
        if (tA == null || tB == null) return 0;
        return tA.compareTo(tB);
      });

      String reporteHTML = """
        <table style="width: 100%; border-collapse: collapse; font-family: Arial, sans-serif; font-size: 14px;">
          <thead>
            <tr style="background-color: #4A90E2; color: white;">
              <th style="padding: 10px; border: 1px solid #ddd; text-align: left;">Fecha</th>
              <th style="padding: 10px; border: 1px solid #ddd; text-align: left;">Hora</th>
              <th style="padding: 10px; border: 1px solid #ddd; text-align: left;">Medicamento</th>
              <th style="padding: 10px; border: 1px solid #ddd; text-align: center;">Estado</th>
            </tr>
          </thead>
          <tbody>
      """;

      for (var doc in listaTomas) {
        final data = doc.data();
        final nombreMed = data['nombre'] ?? 'Desconocido';
        final dosis = data['dosis'] ?? '';
        final fecha = data['fecha'] ?? '';
        final hora = data['horaProgramada'] ?? '';
        final estado = data['estado'] ?? 'Desconocido';

        String colorEstado = (estado == 'Tomada') ? 'green' : 'red';

        reporteHTML +=
            """
          <tr>
            <td style="padding: 8px; border: 1px solid #ddd;">$fecha</td>
            <td style="padding: 8px; border: 1px solid #ddd;">$hora</td>
            <td style="padding: 8px; border: 1px solid #ddd;"><strong>$nombreMed</strong> ($dosis)</td>
            <td style="padding: 8px; border: 1px solid #ddd; text-align: center; color: $colorEstado; font-weight: bold;">$estado</td>
          </tr>
        """;
      }

      reporteHTML += """
          </tbody>
        </table>
      """;

      // Guardamos la respuesta exacta de EmailJS
      String resultadoEmail = await EmailService.enviarReporte(
        correoDoctor: doctorEmail,
        nombreDoctor: doctorNombre,
        nombrePaciente: pacienteNombre,
        reporteMedicamentos: reporteHTML,
      );

      if (resultadoEmail == 'EXITO') {
        await usuarioRef.set({
          'fecha_ultimo_reporte': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        return 'EXITO';
      }

      // Si falla, pasamos el error exacto a la pantalla
      return resultadoEmail;
    } catch (e) {
      return 'Error de la app: $e';
    }
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'notification_service.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  DatabaseHelper._init();

  int _obtenerHorasDeFrecuencia(String frecuenciaStr) {
    if (frecuenciaStr == 'Cada 2 días') return 48;
    if (frecuenciaStr == 'Todos los días') return 24;

    final RegExp regExp = RegExp(r'\d+');
    final match = regExp.firstMatch(frecuenciaStr);
    if (match != null) {
      return int.tryParse(match.group(0)!) ?? 24;
    }

    return 24;
  }

  // --- USUARIOS ---

  Future<void> registrarUsuario(Map<String, dynamic> usuario) async {
    final String uid = usuario['uid'] ?? usuario['id']?.toString() ?? '';
    if (uid.isNotEmpty) {
      await _firestore
          .collection('usuarios')
          .doc(uid)
          .set(usuario, SetOptions(merge: true));
    } else {
      await _firestore.collection('usuarios').add(usuario);
    }
  }

  Future<Map<String, dynamic>?> buscarUsuarioPorEmail(String email) async {
    final snapshot = await _firestore
        .collection('usuarios')
        .where('email', isEqualTo: email.toLowerCase())
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      final doc = snapshot.docs.first;
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> obtenerUsuarios() async {
    final snapshot = await _firestore.collection('usuarios').get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    }).toList();
  }

  Future<void> cambiarEstadoUsuario(dynamic id, int nuevoEstado) async {
    await _firestore.collection('usuarios').doc(id.toString()).update({
      'activo': nuevoEstado == 1,
    });
  }

  Future<void> eliminarUsuario(dynamic id) async {
    await _firestore.collection('usuarios').doc(id.toString()).delete();
  }

  // --- MEDICAMENTOS ---

  Future<String> insertarMedicamento(Map<String, dynamic> med) async {
    final docRef = await _firestore.collection('medicamentos').add({
      'usuarioId': med['usuarioId'].toString(),
      'nombre': med['nombre'],
      'dosis': med['dosis'],
      'hora': med['hora'],
      'frecuencia': med['frecuencia'] ?? 'Todos los días',
      'tomado': med['tomado'] ?? 0,
      'horaTomado': med['horaTomado'],
      'creadoEn': FieldValue.serverTimestamp(),
    });
    return docRef.id;
  }

  Future<void> actualizarMedicamento(
    dynamic id,
    Map<String, dynamic> med,
  ) async {
    final datosActualizar = Map<String, dynamic>.from(med);
    if (datosActualizar.containsKey('usuarioId')) {
      datosActualizar['usuarioId'] = datosActualizar['usuarioId'].toString();
    }
    await _firestore
        .collection('medicamentos')
        .doc(id.toString())
        .update(datosActualizar);
  }

  Future<bool> existeMedicamentoConNombre(
    String nombre,
    dynamic usuarioId, {
    dynamic idExcluir,
  }) async {
    final snapshot = await _firestore
        .collection('medicamentos')
        .where('usuarioId', isEqualTo: usuarioId.toString())
        .get();

    final coincidencia = snapshot.docs.where((doc) {
      if (idExcluir != null && doc.id == idExcluir.toString()) {
        return false;
      }
      final nombreDoc = (doc.data()['nombre'] ?? '')
          .toString()
          .trim()
          .toLowerCase();
      return nombreDoc == nombre.trim().toLowerCase();
    });

    return coincidencia.isNotEmpty;
  }

  Future<bool> existeMedicamento(String nombre, dynamic usuarioId) async {
    return await existeMedicamentoConNombre(nombre, usuarioId);
  }

  Future<List<Map<String, dynamic>>> obtenerTodosMedicamentos(
    dynamic usuarioId,
  ) async {
    await evaluarTomasVencidas(usuarioId);

    final snapshot = await _firestore
        .collection('medicamentos')
        .where('usuarioId', isEqualTo: usuarioId.toString())
        .get();

    final lista = snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    }).toList();

    lista.sort(
      (a, b) =>
          (a['hora'] ?? '').toString().compareTo((b['hora'] ?? '').toString()),
    );
    return lista;
  }

  Future<List<Map<String, dynamic>>> obtenerPendientes(
    dynamic usuarioId,
  ) async {
    await evaluarTomasVencidas(usuarioId);

    final ahora = DateTime.now();
    final String fechaHoy =
        '${ahora.year}-${ahora.month.toString().padLeft(2, '0')}-${ahora.day.toString().padLeft(2, '0')}';

    final snapshotMeds = await _firestore
        .collection('medicamentos')
        .where('usuarioId', isEqualTo: usuarioId.toString())
        .get();

    final snapshotHistorial = await _firestore
        .collection('historial_tomas')
        .where('usuarioId', isEqualTo: usuarioId.toString())
        .where('fecha', isEqualTo: fechaHoy)
        .get();

    final hashSetTomados = <String>{};
    for (var doc in snapshotHistorial.docs) {
      final reg = doc.data();
      final key = "${reg['medicamentoId']}_${reg['horaProgramada']}";
      hashSetTomados.add(key);
    }

    final pendientes = <Map<String, dynamic>>[];
    for (var doc in snapshotMeds.docs) {
      final med = doc.data();
      med['id'] = doc.id;
      final key = "${doc.id}_${med['hora']}";
      if (!hashSetTomados.contains(key)) {
        pendientes.add(med);
      }
    }

    pendientes.sort(
      (a, b) =>
          (a['hora'] ?? '').toString().compareTo((b['hora'] ?? '').toString()),
    );
    return pendientes;
  }

  // --- TOMAS Y VENCIMIENTOS ---

  Future<void> registrarTomaYProgramarSiguiente(
    Map<String, dynamic> med,
    dynamic usuarioId,
  ) async {
    final dynamic id = med['id'];
    final String frecuencia = med['frecuencia'] ?? 'Todos los días';
    final ahora = DateTime.now();

    final String fechaHoy =
        '${ahora.year}-${ahora.month.toString().padLeft(2, '0')}-${ahora.day.toString().padLeft(2, '0')}';
    final String horaActualStr =
        '${ahora.hour.toString().padLeft(2, '0')}:${ahora.minute.toString().padLeft(2, '0')}';

    // 1. Guardar en Firestore historial_tomas
    await _firestore.collection('historial_tomas').add({
      'usuarioId': usuarioId.toString(),
      'medicamentoId': id.toString(),
      'nombre': med['nombre'],
      'dosis': med['dosis'],
      'fecha': fechaHoy,
      'horaProgramada': med['hora'],
      'horaRealizada': horaActualStr,
      'estado': 'Tomada',
      'creadoEn': FieldValue.serverTimestamp(),
    });

    // 2. Calcular la siguiente hora
    int horasASumar = _obtenerHorasDeFrecuencia(frecuencia);
    final partesHora = med['hora'].split(':');
    final horaProg = int.parse(partesHora[0]);
    final minProg = int.parse(partesHora[1]);

    final fechaHoraProgActual = DateTime(
      ahora.year,
      ahora.month,
      ahora.day,
      horaProg,
      minProg,
    );

    DateTime proximaFecha = fechaHoraProgActual.add(
      Duration(hours: horasASumar),
    );
    while (proximaFecha.isBefore(ahora)) {
      proximaFecha = proximaFecha.add(Duration(hours: horasASumar));
    }

    final proximaHoraStr =
        '${proximaFecha.hour.toString().padLeft(2, '0')}:${proximaFecha.minute.toString().padLeft(2, '0')}';

    // 3. Notificación local
    final notifId = id.hashCode.abs() % 100000;
    await NotificationService().programarTomasFuturasMultipes(
      medicamentoId: notifId,
      titulo: '💊 Recordatorio Tacrosync',
      cuerpo:
          'Es hora de tomar tu medicamento: ${med['nombre']} (${med['dosis']})',
      primeraToma: proximaFecha,
      intervaloHoras: horasASumar,
    );

    // 4. Actualizar medicamento en Firestore
    await _firestore.collection('medicamentos').doc(id.toString()).update({
      'tomado': 1,
      'horaTomado': horaActualStr,
      'hora': proximaHoraStr,
    });
  }

  Future<void> evaluarTomasVencidas(
    dynamic usuarioId, {
    int margenToleranciaMinutos = 40,
  }) async {
    final snapshotMeds = await _firestore
        .collection('medicamentos')
        .where('usuarioId', isEqualTo: usuarioId.toString())
        .get();

    final ahora = DateTime.now();

    for (var doc in snapshotMeds.docs) {
      final med = doc.data();
      final medId = doc.id;

      // 1. Obtener el historial completo para saber cuándo fue la última toma
      final snapshotHistorial = await _firestore
          .collection('historial_tomas')
          .where('usuarioId', isEqualTo: usuarioId.toString())
          .where('medicamentoId', isEqualTo: medId)
          .get();

      DateTime fechaBaseParaEvaluar;
      final String frecuencia =
          med['frecuencia']?.toString() ?? 'Todos los días';
      int horasASumar = _obtenerHorasDeFrecuencia(frecuencia);
      if (horasASumar <= 0) horasASumar = 24;

      if (snapshotHistorial.docs.isNotEmpty) {
        // Encontrar el último registro
        final listaHistorial = snapshotHistorial.docs
            .map((d) => d.data())
            .toList();
        listaHistorial.sort((a, b) {
          int cmpFecha = (b['fecha'] ?? '').toString().compareTo(
            (a['fecha'] ?? '').toString(),
          );
          if (cmpFecha != 0) return cmpFecha;
          return (b['horaProgramada'] ?? '').toString().compareTo(
            (a['horaProgramada'] ?? '').toString(),
          );
        });

        final ultimoRegistro = listaHistorial.first;
        final partesFecha = (ultimoRegistro['fecha'] as String).split('-');
        final partesHora = (ultimoRegistro['horaProgramada'] as String).split(
          ':',
        );

        DateTime ultimaFechaHora = DateTime(
          int.parse(partesFecha[0]),
          int.parse(partesFecha[1]),
          int.parse(partesFecha[2]),
          int.parse(partesHora[0]),
          int.parse(partesHora[1]),
        );

        fechaBaseParaEvaluar = ultimaFechaHora.add(
          Duration(hours: horasASumar),
        );
      } else {
        // Si no hay historial, usamos la hora actual registrada
        final partesHoraActual = med['hora'].toString().split(':');
        if (partesHoraActual.length == 2) {
          fechaBaseParaEvaluar = DateTime(
            ahora.year,
            ahora.month,
            ahora.day,
            int.parse(partesHoraActual[0]),
            int.parse(partesHoraActual[1]),
          );
        } else {
          continue;
        }
      }

      // 2. Ciclo Catch-Up
      bool huboActualizacion = false;

      while (fechaBaseParaEvaluar
          .add(Duration(minutes: margenToleranciaMinutos))
          .isBefore(ahora)) {
        final String fechaEval =
            '${fechaBaseParaEvaluar.year}-${fechaBaseParaEvaluar.month.toString().padLeft(2, '0')}-${fechaBaseParaEvaluar.day.toString().padLeft(2, '0')}';
        final String horaEval =
            '${fechaBaseParaEvaluar.hour.toString().padLeft(2, '0')}:${fechaBaseParaEvaluar.minute.toString().padLeft(2, '0')}';

        // Evitar duplicados
        final existe = snapshotHistorial.docs.any(
          (d) =>
              d.data()['fecha'] == fechaEval &&
              d.data()['horaProgramada'] == horaEval,
        );

        if (!existe) {
          await _firestore.collection('historial_tomas').add({
            'usuarioId': usuarioId.toString(),
            'medicamentoId': medId,
            'nombre': med['nombre'],
            'dosis': med['dosis'],
            'fecha': fechaEval,
            'horaProgramada': horaEval,
            'horaRealizada': null,
            'estado': 'Vencida',
            'creadoEn': FieldValue.serverTimestamp(),
          });
          huboActualizacion = true;
        }
        fechaBaseParaEvaluar = fechaBaseParaEvaluar.add(
          Duration(hours: horasASumar),
        );
      }

      // 3. Actualizar hora próxima
      if (huboActualizacion) {
        final proximaHoraStr =
            '${fechaBaseParaEvaluar.hour.toString().padLeft(2, '0')}:${fechaBaseParaEvaluar.minute.toString().padLeft(2, '0')}';

        await _firestore.collection('medicamentos').doc(medId).update({
          'hora': proximaHoraStr,
          'tomado': 0,
        });

        final notifId = medId.hashCode.abs() % 100000;
        await NotificationService().programarTomasFuturasMultipes(
          medicamentoId: notifId,
          titulo: '💊 Recordatorio Tacrosync',
          cuerpo: 'Es hora de tomar tu medicamento: ${med['nombre']}',
          primeraToma: fechaBaseParaEvaluar,
          intervaloHoras: horasASumar,
        );
      }
    }
  }

  Future<List<Map<String, dynamic>>> obtenerTomadosHoy(
    dynamic usuarioId,
  ) async {
    final ahora = DateTime.now();
    final String fechaHoy =
        '${ahora.year}-${ahora.month.toString().padLeft(2, '0')}-${ahora.day.toString().padLeft(2, '0')}';

    final snapshot = await _firestore
        .collection('historial_tomas')
        .where('usuarioId', isEqualTo: usuarioId.toString())
        .where('fecha', isEqualTo: fechaHoy)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    }).toList();
  }

  Future<List<Map<String, dynamic>>> obtenerHistorialPorFecha(
    dynamic usuarioId,
    String fecha,
  ) async {
    final snapshot = await _firestore
        .collection('historial_tomas')
        .where('usuarioId', isEqualTo: usuarioId.toString())
        .where('fecha', isEqualTo: fecha)
        .get();

    final lista = snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    }).toList();

    lista.sort(
      (a, b) => (a['horaProgramada'] ?? '').toString().compareTo(
        (b['horaProgramada'] ?? '').toString(),
      ),
    );
    return lista;
  }

  Future<void> eliminarMedicamento(dynamic id, dynamic usuarioId) async {
    final notifId = id.toString().hashCode.abs() % 100000;
    await NotificationService().cancelarNotificacionesMedicamento(notifId);
    await _firestore.collection('medicamentos').doc(id.toString()).delete();
  }
}

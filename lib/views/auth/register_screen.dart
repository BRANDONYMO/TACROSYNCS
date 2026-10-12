import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/app_colors.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_textfield.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nombreCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _cargando = false;

  // --- COLORES CLEAN CLINICAL PREMIUM DIRECTOS ---
  final Color textoPrincipal = const Color(0xFF2B2D42);
  final Color textoSecundario = const Color(0xFF8D99AE);
  final Color turquesaVibrante = const Color(0xFF00B4D8);

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  // --- LÓGICA DE FIREBASE INTACTA ---
  Future<void> _registrar() async {
    final nombre = _nombreCtrl.text.trim();
    final email = _emailCtrl.text.trim().toLowerCase();
    final pass = _passCtrl.text.trim();

    if (nombre.isEmpty || email.isEmpty || pass.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor completa todos los campos'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (pass.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La contraseña debe tener al menos 6 caracteres'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _cargando = true);

    try {
      // 1. Crear usuario en Firebase Authentication
      final userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: pass);

      final uid = userCredential.user?.uid;

      if (uid != null) {
        // Actualizar el display name en el Auth de Firebase
        await userCredential.user?.updateDisplayName(nombre);

        // 2. Guardar datos complementarios en Firestore (colección 'usuarios')
        final ahora = DateTime.now();
        await FirebaseFirestore.instance.collection('usuarios').doc(uid).set({
          'uid': uid,
          'nombre': nombre,
          'email': email,
          'rol': 'paciente',
          'activo': true,
          'fechaRegistro': ahora.toIso8601String(),
        });
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('¡Cuenta creada exitosamente! Inicia sesión.'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      String mensaje = 'Ocurrió un error al registrarte';
      if (e.code == 'email-already-in-use') {
        mensaje = 'Este correo ya se encuentra registrado';
      } else if (e.code == 'invalid-email') {
        mensaje = 'El correo electrónico no es válido';
      } else if (e.code == 'weak-password') {
        mensaje = 'La contraseña es muy débil';
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mensaje), backgroundColor: Colors.orange),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Fondo completamente blanco para que haga match con el Login
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Registro de Paciente',
          style: TextStyle(color: textoPrincipal, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textoPrincipal),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28.0),
            child: Column(
              children: [
                // Ícono superior
                Icon(
                  Icons.person_add_alt_1_rounded,
                  size: 64,
                  color: turquesaVibrante,
                ),
                const SizedBox(height: 12),
                Text(
                  'Únete a Tacrosync',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: textoPrincipal,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 40),

                // NUEVOS INPUTS REDONDOS CON ETIQUETA FLOTANTE
                CustomTextField(
                  hint: 'Nombre Completo',
                  icon: Icons.person_outline,
                  controller: _nombreCtrl,
                ),
                const SizedBox(height: 24),

                CustomTextField(
                  hint: 'Correo Electrónico',
                  icon: Icons.email_outlined,
                  controller: _emailCtrl,
                ),
                const SizedBox(height: 24),

                CustomTextField(
                  hint: 'Contraseña',
                  icon: Icons.lock_outline,
                  isPassword: true,
                  controller: _passCtrl,
                ),
                const SizedBox(height: 40),

                // BOTÓN REDONDO PRINCIPAL
                _cargando
                    ? CircularProgressIndicator(color: turquesaVibrante)
                    : Container(
                        decoration: BoxDecoration(
                          boxShadow: [
                            BoxShadow(
                              color: turquesaVibrante.withOpacity(0.3),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            ),
                          ],
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: ElevatedButton(
                          onPressed: _registrar,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: turquesaVibrante,
                            elevation: 0,
                            minimumSize: const Size(double.infinity, 55),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          child: const Text(
                            'REGISTRARME',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                      ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

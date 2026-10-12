import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
// Mantengo tus importaciones originales
import '../../core/constants/app_colors.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_textfield.dart';
import '../admin/admin_dashboard_screen.dart';
import '../patient/menu_principal_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _cargando = false;

  // --- COLORES CLEAN CLINICAL PREMIUM DIRECTOS ---
  final Color bgBlancoPerla = const Color(0xFFF8F9FA);
  final Color textoPrincipal = const Color(0xFF2B2D42);
  final Color textoSecundario = const Color(0xFF8D99AE);
  final Color turquesaVibrante = const Color(0xFF00B4D8);

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  // --- TUS FUNCIONES DE FIREBASE INTACTAS ---
  Future<void> _iniciarSesion() async {
    final email = _emailCtrl.text.trim().toLowerCase();
    final pass = _passCtrl.text.trim();

    if (email.isEmpty || pass.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor ingresa tu correo y contraseña'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (email == 'admin@tacrosync.com' && pass == 'admin123') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AdminDashboardScreen()),
      );
      return;
    }

    setState(() => _cargando = true);

    try {
      final userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: pass);

      final uid = userCredential.user?.uid;
      if (uid == null) {
        throw Exception('No se pudo obtener el identificador de usuario');
      }

      final docUsuario = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(uid)
          .get();

      if (!mounted) return;

      if (!docUsuario.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se encontraron los datos del perfil en el servidor',
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }

      final datos = docUsuario.data() ?? {};
      final bool activo = datos['activo'] ?? true;

      if (!activo) {
        await FirebaseAuth.instance.signOut();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ Usuario INHABILITADO por el administrador.'),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }

      final Map<String, dynamic> usuarioData = {
        'id': uid,
        'uid': uid,
        'nombre':
            datos['nombre'] ?? userCredential.user?.displayName ?? 'Usuario',
        'email': email,
        'rol': datos['rol'] ?? 'paciente',
        'activo': activo ? 1 : 0,
      };

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => MenuPrincipalScreen(usuario: usuarioData),
        ),
      );
    } on FirebaseAuthException catch (e) {
      String mensaje = 'Error al iniciar sesión';
      if (e.code == 'user-not-found')
        mensaje = 'El usuario no existe';
      else if (e.code == 'wrong-password' || e.code == 'invalid-credential')
        mensaje = 'Correo o contraseña incorrectos';
      else if (e.code == 'invalid-email')
        mensaje = 'Formato de correo no válido';
      else if (e.code == 'user-disabled')
        mensaje = 'Esta cuenta ha sido deshabilitada';

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mensaje), backgroundColor: Colors.redAccent),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _iniciarSesionConGoogle() async {
    setState(() => _cargando = true);
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        setState(() => _cargando = false);
        return;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await FirebaseAuth.instance
          .signInWithCredential(credential);
      final uid = userCredential.user?.uid;
      if (uid == null) throw Exception('No se pudo obtener el ID del usuario.');

      final docRef = FirebaseFirestore.instance.collection('usuarios').doc(uid);
      final docUsuario = await docRef.get();

      Map<String, dynamic> datos;
      if (!docUsuario.exists) {
        datos = {
          'id': uid,
          'uid': uid,
          'nombre': userCredential.user?.displayName ?? 'Usuario de Google',
          'email': userCredential.user?.email ?? '',
          'rol': 'paciente',
          'activo': true,
        };
        await docRef.set(datos);
      } else {
        datos = docUsuario.data() ?? {};
      }

      if (!mounted) return;

      final bool activo = datos['activo'] ?? true;
      if (!activo) {
        await FirebaseAuth.instance.signOut();
        await GoogleSignIn().signOut();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ Usuario INHABILITADO por el administrador.'),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }

      final Map<String, dynamic> usuarioData = {
        'id': uid,
        'uid': uid,
        'nombre':
            datos['nombre'] ?? userCredential.user?.displayName ?? 'Usuario',
        'email': datos['email'] ?? userCredential.user?.email ?? '',
        'rol': datos['rol'] ?? 'paciente',
        'activo': activo ? 1 : 0,
      };

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => MenuPrincipalScreen(usuario: usuarioData),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error con Google: ${e.toString()}'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Fondo completamente blanco como en la imagen
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // NUEVO LOGO TS+
                Image.asset(
                  'assets/logo.png', // Cuando recortes tu logo, guárdalo aquí
                  height: 90,
                  errorBuilder: (context, error, stackTrace) {
                    // Si la imagen no está aún, mostramos las letras TS+
                    return Text(
                      'TS+',
                      style: TextStyle(
                        fontSize: 64,
                        fontWeight: FontWeight.w900,
                        color: turquesaVibrante,
                        letterSpacing: -2.0,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                Text(
                  'Tacrosync',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: textoPrincipal,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  'Tu adherencia médica, segura.',
                  style: TextStyle(
                    fontSize: 16,
                    color: textoSecundario,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 48),

                // NUEVOS INPUTS REDONDOS (usando el Widget CustomTextField)
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
                const SizedBox(height: 36),

                _cargando
                    ? CircularProgressIndicator(color: turquesaVibrante)
                    : Column(
                        children: [
                          // BOTÓN PRINCIPAL REDONDO
                          Container(
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
                              onPressed: _iniciarSesion,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: turquesaVibrante,
                                elevation: 0,
                                minimumSize: const Size(double.infinity, 55),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                              ),
                              child: const Text(
                                'INICIAR SESIÓN',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 28),

                          // SEPARADOR
                          Row(
                            children: [
                              Expanded(
                                child: Divider(color: Colors.grey.shade300),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16.0,
                                ),
                                child: Text(
                                  'O entra con',
                                  style: TextStyle(
                                    color: textoSecundario,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Divider(color: Colors.grey.shade300),
                              ),
                            ],
                          ),
                          const SizedBox(height: 28),

                          // BOTÓN DE GOOGLE REDONDO
                          ElevatedButton.icon(
                            onPressed: _iniciarSesionConGoogle,
                            icon: Image.network(
                              'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/120px-Google_%22G%22_logo.svg.png',
                              height: 24,
                            ),
                            label: Text(
                              'Continuar con Google',
                              style: TextStyle(
                                color: textoPrincipal,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.grey.shade100,
                              minimumSize: const Size(double.infinity, 55),
                              elevation: 2,
                              shadowColor: Colors.black.withOpacity(0.2),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                                side: BorderSide(color: Colors.grey.shade200),
                              ),
                            ),
                          ),
                        ],
                      ),
                const SizedBox(height: 36),

                // TEXTO DE REGISTRO
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "¿No tienes cuenta? ",
                      style: TextStyle(color: textoSecundario),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const RegisterScreen(),
                          ),
                        );
                      },
                      child: Text(
                        "Regístrate",
                        style: TextStyle(
                          color: turquesaVibrante,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

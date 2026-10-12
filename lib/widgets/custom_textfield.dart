import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';

class CustomTextField extends StatefulWidget {
  final String hint;
  final IconData icon;
  final bool isPassword;
  final TextEditingController? controller;

  const CustomTextField({
    super.key,
    required this.hint,
    required this.icon,
    this.isPassword = false,
    this.controller,
  });

  @override
  State<CustomTextField> createState() => _CustomTextFieldState();
}

class _CustomTextFieldState extends State<CustomTextField> {
  bool _ocultarTexto = true;

  @override
  void initState() {
    super.initState();
    _ocultarTexto = widget.isPassword;
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      obscureText: widget.isPassword ? _ocultarTexto : false,
      style: const TextStyle(
        color: AppColors.textMain,
        fontWeight: FontWeight.w500,
        fontSize: 16,
      ),
      decoration: InputDecoration(
        // Etiqueta flotante en el borde
        labelText: widget.hint,
        labelStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
        floatingLabelBehavior: FloatingLabelBehavior.always,

        // Texto de ejemplo sutil
        hintText: widget.hint == 'Correo Electrónico'
            ? 'ejemplo@correo.com'
            : '••••••••',
        hintStyle: TextStyle(
          color: AppColors.textMuted.withOpacity(0.5),
          fontSize: 15,
        ),

        // Íconos
        prefixIcon: Icon(widget.icon, color: AppColors.textMuted),
        suffixIcon: widget.isPassword
            ? IconButton(
                icon: Icon(
                  _ocultarTexto
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: AppColors.textMuted,
                ),
                onPressed: () {
                  setState(() {
                    _ocultarTexto = !_ocultarTexto;
                  });
                },
              )
            : null,

        contentPadding: const EdgeInsets.symmetric(
          horizontal: 24,
          vertical: 18,
        ),

        // Borde redondo inactivo (Gris)
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide(color: Colors.grey.shade400, width: 1.2),
        ),

        // Borde redondo activo (Turquesa)
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: const BorderSide(color: AppColors.primaryTeal, width: 2),
        ),
      ),
    );
  }
}

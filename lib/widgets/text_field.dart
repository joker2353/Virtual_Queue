import 'package:flutter/material.dart';

class TextFieldInput extends StatelessWidget {
  final TextEditingController textEditingController;
  final bool isPass;
  final String hintText;
  final TextInputType textInputType;
  final IconData icon;
  final String? errorText;
  final bool hasError;

  const TextFieldInput({
    super.key,
    required this.textEditingController,
    this.isPass = false,
    required this.hintText,
    required this.textInputType,
    required this.icon,
    this.errorText,
    this.hasError = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            border: Border.all(
              color: hasError ? Colors.red : Colors.grey,
              width: 1.0,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: TextField(
            controller: textEditingController,
            decoration: InputDecoration(
              prefixIcon: Icon(icon, color: hasError ? Colors.red : Colors.black),
              hintText: hintText,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(15),
            ),
            keyboardType: textInputType,
            obscureText: isPass,
          ),
        ),
        if (errorText != null && hasError)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 25),
            child: Text(
              errorText!,
              style: const TextStyle(
                color: Colors.red,
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }
}

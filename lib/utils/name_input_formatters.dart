import 'package:flutter/services.dart';

/// Formatea el texto de nombre y apellido al formato canónico de la app:
/// solo letras del español (incluidas tildes y la Ñ) y espacios como
/// separadores, en MAYÚSCULAS.
///
/// Se aplica a los `TextField` de `RegisterScreen` mediante `inputFormatters`.
class SpanishNameInputFormatter extends TextInputFormatter {
  SpanishNameInputFormatter({this.maxLength});

  /// Longitud máxima aceptada (20) para nombre y apellido.
  final int? maxLength;

  static final RegExp _allowedPattern = RegExp(r'^[A-Za-zÁÉÍÓÚÜÑáéíóúüñ ]+$');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final buffer = StringBuffer();
    for (final char in newValue.text.split('')) {
      if (_allowedPattern.hasMatch(char)) {
        buffer.write(char);
      }
    }
    var text = buffer.toString().toUpperCase();
    if (maxLength != null && text.length > maxLength!) {
      text = text.substring(0, maxLength!);
    }
    final clampedLength = text.length;
    final selection = newValue.selection;
    final isCollapsed = selection.start == selection.end;
    var start = _mapOffset(selection.start, newValue.text);
    var end = _mapOffset(selection.end, newValue.text);
    if (start < 0) start = 0;
    if (start > clampedLength) start = clampedLength;
    if (end < 0) end = 0;
    if (end > clampedLength) end = clampedLength;
    return TextEditingValue(
      text: text,
      selection: isCollapsed
          ? TextSelection.collapsed(offset: start)
          : TextSelection(baseOffset: start, extentOffset: end),
    );
  }

  /// Traduce un offset del texto editable al offset del texto filtrado.
  int _mapOffset(int position, String text) {
    var newIndex = 0;
    var index = 0;
    while (index < text.length && index < position) {
      if (_allowedPattern.hasMatch(text[index])) newIndex++;
      index++;
    }
    return newIndex;
  }
}

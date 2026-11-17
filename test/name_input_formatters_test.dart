import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:liztia/utils/name_input_formatters.dart';

void main() {
  final formatters = <TextInputFormatter>[
    SpanishNameInputFormatter(maxLength: 20),
  ];

  TextEditingValue valueOf(String text) => TextEditingValue(
    text: text,
    selection: TextSelection.collapsed(offset: text.length),
  );

  TextEditingValue applyFormatters(TextEditingValue value) {
    var current = value;
    var previous = value;
    for (final formatter in formatters) {
      current = formatter.formatEditUpdate(previous, current);
      previous = current;
    }
    return current;
  }

  group('SpanishNameInputFormatter', () {
    test('convierte el texto a MAYÚSCULAS mientras escribe', () {
      final result = applyFormatters(valueOf('pabLo'));
      expect(result.text, 'PABLO');
    });

    test('convierte nombres con tildes a mayúsculas', () {
      final result = applyFormatters(valueOf('josé'));
      expect(result.text, 'JOSÉ');
    });

    test('filtra dígitos y símbolos no permitidos', () {
      final result = applyFormatters(valueOf('Pablo1!'));
      expect(result.text, 'PABLO');
    });

    test('acepta letras con tildes y espacios como separadores', () {
      final result = applyFormatters(valueOf('ana maría'));
      expect(result.text, 'ANA MARÍA');
    });

    test('convierte la ñ minúscula a MAYÚSCULAS (Muñoz → MUÑOZ)', () {
      final result = applyFormatters(valueOf('Muñoz'));
      expect(result.text, 'MUÑOZ');
    });

    test('respeta el máximo de 20 caracteres', () {
      final result = applyFormatters(valueOf('a' * 25));
      expect(result.text.length, 20);
    });

    test('re-clampa el TextSelection tras truncar por maxLength', () {
      final result = applyFormatters(valueOf('a' * 25));
      expect(result.text.length, 20);
      expect(result.selection, TextSelection.collapsed(offset: 20));
    });
  });
}

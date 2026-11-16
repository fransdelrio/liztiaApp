import 'package:flutter_test/flutter_test.dart';

import 'package:liztia/utils/date_formats.dart';

void main() {
  group('fecha y timestamp usan formatos fijos', () {
    test('caso general', () {
      final date = DateTime(2026, 11, 5, 9, 8, 7);

      expect(DateFormats.fecha(date), '2026-11-05');
      expect(DateFormats.timestamp(date), '20261105090807');
      expect(
        DateFormats.displayTimestamp('20261105090807'),
        '05/11/2026 - 09:08:07',
      );
    });

    test('rellena con ceros mes, día, hora, minuto y segundo', () {
      final date = DateTime(2026, 1, 2, 3, 4, 5);

      expect(DateFormats.fecha(date), '2026-01-02');
      expect(DateFormats.timestamp(date), '20260102030405');
    });

    test('rellena con ceros un año de menos de cuatro dígitos', () {
      final date = DateTime(999, 1, 2, 3, 4, 5);

      expect(DateFormats.fecha(date), '0999-01-02');
      expect(DateFormats.timestamp(date), '09990102030405');
    });

    test('medianoche', () {
      final date = DateTime(2026, 1, 1, 0, 0, 0);

      expect(DateFormats.fecha(date), '2026-01-01');
      expect(DateFormats.timestamp(date), '20260101000000');
    });

    test('fin de año', () {
      final date = DateTime(2026, 12, 31, 23, 59, 59);

      expect(DateFormats.fecha(date), '2026-12-31');
      expect(DateFormats.timestamp(date), '20261231235959');
    });

    test('año bisiesto', () {
      final date = DateTime(2024, 2, 29, 12, 0, 0);

      expect(DateFormats.fecha(date), '2024-02-29');
      expect(DateFormats.timestamp(date), '20240229120000');
    });

    test('fecha y timestamp son consistentes para el mismo DateTime', () {
      final fechas = <DateTime>[
        DateTime(2026, 11, 5, 9, 8, 7),
        DateTime(2026, 1, 2, 3, 4, 5),
        DateTime(2026, 1, 1, 0, 0, 0),
        DateTime(2026, 12, 31, 23, 59, 59),
        DateTime(2024, 2, 29, 0, 0, 1),
      ];

      for (final date in fechas) {
        final fecha = DateFormats.fecha(date);
        final timestamp = DateFormats.timestamp(date);
        final hora = date.hour.toString().padLeft(2, '0');
        final minuto = date.minute.toString().padLeft(2, '0');
        final segundo = date.second.toString().padLeft(2, '0');

        expect(timestamp.length, 14);
        expect(timestamp.substring(0, 8), fecha.replaceAll('-', ''));
        expect(timestamp.substring(8), '$hora$minuto$segundo');
        final displayDate = fecha.split('-').reversed.join('/');
        expect(
          DateFormats.displayTimestamp(timestamp),
          '$displayDate - $hora:$minuto:$segundo',
        );
      }
    });
  });
}

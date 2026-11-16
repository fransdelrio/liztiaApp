import 'package:flutter_test/flutter_test.dart';

import 'package:liztia/models/history_record.dart';
import 'package:liztia/models/person.dart';

void main() {
  test('Person serializa y reconstruye sus campos', () {
    const person = Person(id: 42, nombre: 'Ada', apellido: 'Lovelace');

    final map = person.toMap();
    expect(map, {'id': 42, 'nombre': 'Ada', 'apellido': 'Lovelace'});

    final copy = Person.fromMap(map);
    expect(copy.id, 42);
    expect(copy.nombre, 'Ada');
    expect(copy.apellido, 'Lovelace');
  });

  test('HistoryRecord serializa con id nulo e id existente', () {
    final record = HistoryRecord(
      fecha: '2026-11-10',
      personaId: 42,
      apellido: 'Lovelace',
      nombre: 'Ada',
      timestamp: '20261110123045',
    );

    final map = record.toMap();
    expect(map['id'], isNull);
    expect(map['fecha'], '2026-11-10');
    expect(map['persona_id'], 42);
    expect(map['apellido'], 'Lovelace');
    expect(map['nombre'], 'Ada');
    expect(map['timestamp'], '20261110123045');

    final stored = HistoryRecord.fromMap({...map, 'id': 7});
    expect(stored.id, 7);
    expect(stored.personaId, 42);
    expect(stored.fecha, '2026-11-10');
    expect(stored.nombre, 'Ada');
    expect(stored.apellido, 'Lovelace');
    expect(stored.timestamp, '20261110123045');
  });
}

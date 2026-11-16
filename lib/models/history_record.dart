class HistoryRecord {
  final int? id;
  final String fecha;
  final int personaId;
  final String apellido;
  final String nombre;
  final String timestamp;

  HistoryRecord({
    this.id,
    required this.fecha,
    required this.personaId,
    required this.apellido,
    required this.nombre,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'fecha': fecha,
      'persona_id': personaId,
      'apellido': apellido,
      'nombre': nombre,
      'timestamp': timestamp,
    };
  }

  factory HistoryRecord.fromMap(Map<String, dynamic> map) {
    return HistoryRecord(
      id: map['id'],
      fecha: map['fecha'],
      personaId: map['persona_id'],
      apellido: map['apellido'],
      nombre: map['nombre'],
      timestamp: map['timestamp'],
    );
  }
}

class Person {
  final int id;
  final String nombre;
  final String apellido;

  const Person({
    required this.id,
    required this.nombre,
    required this.apellido,
  });

  Map<String, dynamic> toMap() {
    return {'id': id, 'nombre': nombre, 'apellido': apellido};
  }

  factory Person.fromMap(Map<String, dynamic> map) {
    return Person(
      id: map['id'] as int,
      nombre: map['nombre'] as String,
      apellido: map['apellido'] as String,
    );
  }
}

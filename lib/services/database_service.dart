import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/history_record.dart';
import '../models/person.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;

  static const _dbName = 'liztia.db';
  static const _dbVersion = 1;

  DatabaseService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB(_dbName);
    return _database!;
  }

  /// Fuerza la apertura para crear el esquema al arrancar si no existe.
  Future<Database> open() => database;

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(path, version: _dbVersion, onCreate: _createDB);
  }

  Future<void> _createDB(Database db, int version) async {
    await _createPersons(db);
    await _createHistory(db);
  }

  Future<void> _createPersons(Database db) async {
    await db.execute('''
CREATE TABLE IF NOT EXISTS persons (
  id INTEGER PRIMARY KEY,
  nombre TEXT NOT NULL,
  apellido TEXT NOT NULL
)
''');
  }

  Future<void> _createHistory(Database db) async {
    await db.execute('''
CREATE TABLE IF NOT EXISTS history (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  fecha TEXT NOT NULL,
  persona_id INTEGER NOT NULL,
  apellido TEXT NOT NULL,
  nombre TEXT NOT NULL,
  timestamp TEXT NOT NULL
)
''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_history_fecha ON history(fecha)',
    );
  }

  Future<Person?> getPersonById(int id) async {
    final db = await instance.database;
    final rows = await db.query(
      'persons',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Person.fromMap(rows.first);
  }

  Future<Set<int>> getAllPersonIds() async {
    final db = await instance.database;
    final rows = await db.query('persons', columns: ['id']);
    return rows.map((row) => row['id'] as int).toSet();
  }

  /// Inserta persona e historial de forma atómica.
  Future<void> saveRegistration({
    required Person person,
    required HistoryRecord history,
  }) async {
    final db = await instance.database;
    await db.transaction((txn) async {
      await txn.insert('persons', person.toMap());
      await txn.insert('history', history.toMap());
    });
  }

  Future<int> insertHistory(HistoryRecord record) async {
    final db = await instance.database;
    return await db.insert('history', record.toMap());
  }

  Future<List<HistoryRecord>> getHistoryByDate(String fecha) async {
    final db = await instance.database;
    final rows = await db.query(
      'history',
      where: 'fecha = ?',
      whereArgs: [fecha],
      orderBy: 'timestamp DESC',
    );
    return rows.map((row) => HistoryRecord.fromMap(row)).toList();
  }
}

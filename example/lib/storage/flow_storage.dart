import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

/// SQLite-based storage for saved workflows.
///
/// Stores serialized flow JSON along with metadata (name, timestamps).
class FlowStorage {
  FlowStorage._();
  static final FlowStorage instance = FlowStorage._();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = join(dir.path, 'flowcraft_flows.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE saved_flows (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            json_data TEXT NOT NULL,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
          )
        ''');
      },
    );
  }

  Future<int> saveFlow({
    required String name,
    required String jsonData,
  }) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();

    final existing = await db.query(
      'saved_flows',
      where: 'name = ?',
      whereArgs: [name],
    );

    if (existing.isNotEmpty) {
      await db.update(
        'saved_flows',
        {'json_data': jsonData, 'updated_at': now},
        where: 'name = ?',
        whereArgs: [name],
      );
      return existing.first['id'] as int;
    }

    return db.insert('saved_flows', {
      'name': name,
      'json_data': jsonData,
      'created_at': now,
      'updated_at': now,
    });
  }

  Future<List<Map<String, dynamic>>> listFlows() async {
    final db = await database;
    return db.query(
      'saved_flows',
      columns: ['id', 'name', 'created_at', 'updated_at'],
      orderBy: 'updated_at DESC',
    );
  }

  Future<String?> loadFlow(int id) async {
    final db = await database;
    final rows = await db.query(
      'saved_flows',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (rows.isEmpty) return null;
    return rows.first['json_data'] as String?;
  }

  Future<void> deleteFlow(int id) async {
    final db = await database;
    await db.delete('saved_flows', where: 'id = ?', whereArgs: [id]);
  }
}

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/student.dart';
import '../models/attendance.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('absensi_v4.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return await openDatabase(path, version: 4, onCreate: _createDB, onUpgrade: _upgradeDB);
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 4) {
      await db.execute("ALTER TABLE students ADD COLUMN level TEXT NOT NULL DEFAULT 'Lainnya'");
    }
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE students (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        level TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE attendances (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        studentId INTEGER NOT NULL,
        date TEXT NOT NULL,
        duration TEXT NOT NULL,
        type TEXT NOT NULL,
        FOREIGN KEY (studentId) REFERENCES students (id) ON DELETE CASCADE
      )
    ''');
  }

  Future<int> insertStudent(Student student) async {
    final db = await instance.database;
    return await db.insert('students', student.toMap());
  }

  Future<List<Student>> getStudents() async {
    final db = await instance.database;
    final maps = await db.query('students', orderBy: 'name ASC');
    return maps.map((map) => Student.fromMap(map)).toList();
  }

  // --- FITUR BARU: EDIT DATA MURID ---
  Future<int> updateStudent(Student student) async {
    final db = await instance.database;
    return await db.update('students', student.toMap(), where: 'id = ?', whereArgs: [student.id]);
  }

  Future<int> deleteStudent(int id) async {
    final db = await instance.database;
    return await db.delete('students', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteMultipleStudents(List<int> ids) async {
    final db = await instance.database;
    return await db.delete('students', where: 'id IN (${ids.join(',')})');
  }

  Future<int> insertAttendance(Attendance attendance) async {
    final db = await instance.database;
    return await db.insert('attendances', attendance.toMap());
  }

  Future<List<Attendance>> getAttendancesByStudent(int studentId) async {
    final db = await instance.database;
    final maps = await db.query('attendances', where: 'studentId = ?', whereArgs: [studentId], orderBy: 'date DESC');
    return maps.map((map) => Attendance.fromMap(map)).toList();
  }
  
  Future<int> updateAttendance(Attendance attendance) async {
    final db = await instance.database;
    return await db.update('attendances', attendance.toMap(), where: 'id = ?', whereArgs: [attendance.id]);
  }

  Future<int> deleteMultipleAttendances(List<int> ids) async {
    final db = await instance.database;
    return await db.delete('attendances', where: 'id IN (${ids.join(',')})');
  }
}
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// All persistence is local SQLite on the device — no cloud sync, no
/// network calls. Tables mirror section 19 of the spec.
class DatabaseHelper {
  DatabaseHelper._internal();
  static final DatabaseHelper instance = DatabaseHelper._internal();

  Database? _db;

  Future<Database> get database async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'uno_nearby.db');
    return openDatabase(path, version: 1, onCreate: _onCreate);
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE players (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE games (
        id TEXT PRIMARY KEY,
        room_code TEXT,
        started_at INTEGER NOT NULL,
        ended_at INTEGER,
        player_count INTEGER NOT NULL,
        mode TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE game_results (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        game_id TEXT NOT NULL,
        player_id TEXT NOT NULL,
        player_name TEXT NOT NULL,
        placement INTEGER NOT NULL,
        score INTEGER NOT NULL,
        won INTEGER NOT NULL,
        FOREIGN KEY(game_id) REFERENCES games(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE statistics (
        player_id TEXT PRIMARY KEY,
        games_played INTEGER NOT NULL DEFAULT 0,
        wins INTEGER NOT NULL DEFAULT 0,
        losses INTEGER NOT NULL DEFAULT 0,
        highest_score INTEGER NOT NULL DEFAULT 0,
        uno_calls INTEGER NOT NULL DEFAULT 0,
        cards_played INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
  }

  // ------------------------- Settings -------------------------
  Future<void> setSetting(String key, String value) async {
    final db = await database;
    await db.insert('settings', {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<String?> getSetting(String key) async {
    final db = await database;
    final rows = await db.query('settings', where: 'key = ?', whereArgs: [key]);
    return rows.isEmpty ? null : rows.first['value'] as String;
  }

  // ------------------------- Game results -------------------------
  Future<void> recordGameResult({
    required String gameId,
    required String roomCode,
    required List<Map<String, dynamic>> placements, // [{playerId, playerName, score, placement, won}]
    required String mode,
  }) async {
    final db = await database;
    await db.insert('games', {
      'id': gameId,
      'room_code': roomCode,
      'started_at': DateTime.now().millisecondsSinceEpoch,
      'ended_at': DateTime.now().millisecondsSinceEpoch,
      'player_count': placements.length,
      'mode': mode,
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    for (final p in placements) {
      await db.insert('game_results', {
        'game_id': gameId,
        'player_id': p['playerId'],
        'player_name': p['playerName'],
        'placement': p['placement'],
        'score': p['score'],
        'won': (p['won'] as bool) ? 1 : 0,
      });
      await _updateStatistics(
        playerId: p['playerId'] as String,
        score: p['score'] as int,
        won: p['won'] as bool,
        unoCalls: (p['unoCalls'] as int?) ?? 0,
        cardsPlayed: (p['cardsPlayed'] as int?) ?? 0,
      );
    }
  }

  Future<void> _updateStatistics({
    required String playerId,
    required int score,
    required bool won,
    required int unoCalls,
    required int cardsPlayed,
  }) async {
    final db = await database;
    final existing = await db.query('statistics', where: 'player_id = ?', whereArgs: [playerId]);
    if (existing.isEmpty) {
      await db.insert('statistics', {
        'player_id': playerId,
        'games_played': 1,
        'wins': won ? 1 : 0,
        'losses': won ? 0 : 1,
        'highest_score': score,
        'uno_calls': unoCalls,
        'cards_played': cardsPlayed,
      });
    } else {
      final row = existing.first;
      await db.update(
        'statistics',
        {
          'games_played': (row['games_played'] as int) + 1,
          'wins': (row['wins'] as int) + (won ? 1 : 0),
          'losses': (row['losses'] as int) + (won ? 0 : 1),
          'highest_score': [row['highest_score'] as int, score].reduce((a, b) => a > b ? a : b),
          'uno_calls': (row['uno_calls'] as int) + unoCalls,
          'cards_played': (row['cards_played'] as int) + cardsPlayed,
        },
        where: 'player_id = ?',
        whereArgs: [playerId],
      );
    }
  }

  Future<Map<String, dynamic>?> getStatistics(String playerId) async {
    final db = await database;
    final rows = await db.query('statistics', where: 'player_id = ?', whereArgs: [playerId]);
    return rows.isEmpty ? null : rows.first;
  }

  Future<void> resetStatistics(String playerId) async {
    final db = await database;
    await db.delete('statistics', where: 'player_id = ?', whereArgs: [playerId]);
  }
}

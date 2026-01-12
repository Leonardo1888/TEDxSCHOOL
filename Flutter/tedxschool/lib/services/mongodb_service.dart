import 'package:mongo_dart/mongo_dart.dart';
import 'constants.dart';

class MongoDBService {
  // Connessione persistente
  static Future<Db> connect() async {
    if (_db != null) return _db!;

    _db = await Db.create(Constants.MONGO_URI);
    await _db!.open();
    print('MongoDB connesso');
    return _db!;
  }

  static Db? _db;

  // Recupera talk assegnati alla classe e mail del prof che lo ha assegnato
  static Future<Map<String, Map<String, String>>> getAssignedTalks(
    String classroomId,
  ) async {
    try {
      print('Query per classroom: $classroomId');

      final db = await connect();
      final collection = db.collection('classrooms');

      final classroom = await collection.findOne({
        '_id': ObjectId.parse(classroomId),
      });

      if (classroom == null) {
        print('Classroom ID $classroomId non trovata');
        return {};
      }

      print('Classroom trovata: ${classroom['name']}');

      final assignments = classroom['assignments'] as List<dynamic>? ?? [];
      final Map<String, Map<String, String>> talksMap = {};

      for (var assignment in assignments) {
        final videoId = assignment['video_id']?.toString();
        final profEmail = assignment['prof_email']?.toString() ?? 'Sconosciuto';
        final date = assignment['date']?.toString() ?? '';

        if (videoId != null && videoId.isNotEmpty) {
          talksMap[videoId] = {'prof_email': profEmail, 'date': date};
          print('→ Talk $videoId da $profEmail');
        }
      }

      return talksMap;
    } catch (e) {
      print('ERRORE MongoDB: $e');
      return {};
    }
  }

  // PROFESSORE: Cerca talk per ID
  static Future<Map<String, dynamic>?> searchTalkById(String talkId) async {
    try {
      print('Cerca talk: $talkId');
      final db = await connect();
      final collection = db.collection('tedx_clean_data_2');

      final talk = await collection.findOne({'_id': talkId});

      if (talk == null) {
        print('Talk $talkId non trovato');
        return null;
      }

      print('Talk trovato: ${talk['title']}');
      return talk;
    } catch (e) {
      print('Search Error: $e');
      return null;
    }
  }

  //Recupera statistiche talk (voto medio, num voti)
  static Future<Map<String, dynamic>?> getTalkStats(String talkId) async {
    try {
      print('Fetch stats for talkId: $talkId');
      final db = await connect();
      final collection = db.collection('tedx_clean_data_2');

      final talkFull = await collection.findOne(where.eq('_id', talkId));

      if (talkFull == null) return null;

      final stats = {
        'num_votes': talkFull['num_votes'] ?? 0,
        'avg_rating': talkFull['avg_rating'] ?? 0.0,
      };
      print(
        'Stats: num_votes=${stats['num_votes']}, avg_rating=${stats['avg_rating']}',
      );
      return stats;
    } catch (e) {
      print('Stats error: $e');
      return null;
    }
  }
}

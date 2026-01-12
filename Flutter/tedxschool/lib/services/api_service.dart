import 'package:dio/dio.dart';
import '../models/talk.dart';
import 'constants.dart';

class ApiService {
  late Dio _dio;

  ApiService() {
    _dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 10)));
  }

  // Video correlati API
  Future<List<Talk>> getRelatedVideos(String talkId) async {
    try {
      print('Related videos for: $talkId');
      final response = await _dio.get(
        '${Constants.AWS_API_related}/watchnext',
        queryParameters: {'id': talkId},
      );

      final List<dynamic> data = response.data;
      return data.map((json) => Talk.fromJson(json)).toList();
    } catch (e) {
      print('Related error (403 OK): $e');
      return [];
    }
  }

  // Rate Video API (professore)
  Future<Map<String, dynamic>> submitRating(String talkId, int rating) async {
    try {
      print('📤 Submit rating: talk=$talkId, rating=$rating');

      final response = await _dio.post(
        '${Constants.AWS_API_rating}/Submit_Rating',
        data: {'id': talkId, 'rating': rating},
        options: Options(contentType: 'application/json'),
      );

      print('Rating response: ${response.data}');
      return response.data;
    } catch (e) {
      print('Rating error: $e');
      rethrow;
    }
  }

  // Assegna Talk API
  static Future<String> assignVideoToClass({
    required String className,
    required String profEmail,
    required String subject,
    required String videoId,
    required String date,
  }) async {
    try {
      final payload = {
        'class_name': className,
        'prof_email': profEmail,
        'subject': subject,
        'video_id': videoId,
        'date': date,
      };

      print(' ASSIGN DEBUG:');
      print('  class_name: $className');
      print('  prof_email: $profEmail');
      print('  subject: $subject');
      print('  video_id: $videoId');
      print('  date: $date');
      print(' URL: ${Constants.AWS_API_assign}/assign-video');

      final dio = Dio();
      final response = await dio.post(
        '${Constants.AWS_API_assign}/assign-video',
        data: payload,
        options: Options(
          contentType: 'application/json',
          headers: {'Accept': 'application/json'},
          validateStatus: (status) => status! < 500,
        ),
      );

      print('SUCCESS ${response.statusCode}: ${response.data}');
      return response.data.toString();
    } catch (e) {
      print('ASSIGN ERRORE COMPLETO:');
      print('  Tipo: ${e.runtimeType}');
      print('  Messaggio: $e');
      rethrow;
    }
  }

  // Cerca talk per subject API
  Future<List<Map<String, dynamic>>> searchTalksBySubject(
    String subject,
  ) async {
    try {
      print('API search subject: $subject');
      final response = await _dio.get(
        '${Constants.AWS_API_subject}/search-by-subject',
        queryParameters: {'subject': subject},
      );

      final List<dynamic> results = response.data;
      print('${results.length} talks trovati per "$subject"');
      return results.cast<Map<String, dynamic>>();
    } catch (e) {
      print('API subject error: $e');
      return [];
    }
  }
}

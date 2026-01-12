import 'package:flutter/material.dart';
import '../../services/mongodb_service.dart';
import '../../services/constants.dart';
import 'student_talk_detail.dart';

class StudentHome extends StatefulWidget {
  const StudentHome({super.key});

  @override
  State<StudentHome> createState() => _StudentHomeState();
}

class _StudentHomeState extends State<StudentHome> {
  Map<String, Map<String, String>> talksMap = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTalks();
  }

  Future<void> _loadTalks() async {
    try {
      print('🔍 Caricamento talks da MongoDB...');
      final talksData = await MongoDBService.getAssignedTalks(
        Constants.CLASSROOM_ID,
      );
      print('Talks ricevute: ${talksData.length}');

      setState(() {
        talksMap = talksData;
        isLoading = false;
      });
    } catch (e) {
      print('Errore MongoDB: $e');
      setState(() => isLoading = false);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Errore DB: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Talk Assegnati'),
        backgroundColor: Colors.blue.shade700,
        elevation: 0,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : talksMap.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.school, size: 80, color: Colors.grey),
                    SizedBox(height: 20),
                    Text(
                      'Nessun talk assegnato',
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                    Text(
                      'Contatta il professore',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadTalks,
              child: ListView.builder(
                padding: const EdgeInsets.all(10),
                itemCount: talksMap.length,
                itemBuilder: (context, index) {
                  final talkId = talksMap.keys.elementAt(index); // ✅ Estrai ID
                  final info = talksMap[talkId]!; // ✅ Prof info
                  final profEmail = info['prof_email'] ?? 'Sconosciuto';

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: ListTile(
                      leading: const Icon(
                        Icons.play_circle_fill,
                        color: Colors.blue,
                        size: 50,
                      ),
                      title: Text(
                        'Talk #$talkId', // ✅ Usa talkId
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      subtitle: Text(
                        'Assegnato da: $profEmail',
                      ), // ✅ Prof email
                      trailing: const Icon(Icons.arrow_forward_ios),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TalkDetail(talkId: talkId),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _loadTalks,
        backgroundColor: Colors.blue,
        child: const Icon(Icons.refresh, color: Colors.white),
      ),
    );
  }
}

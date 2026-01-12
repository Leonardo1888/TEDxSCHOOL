import 'package:flutter/material.dart';
import '../../services/mongodb_service.dart';
import '../../services/constants.dart';
import 'professor_talk_detail.dart';
import '../../services/api_service.dart';

class ProfessorHome extends StatefulWidget {
  const ProfessorHome({super.key});

  @override
  State<ProfessorHome> createState() => _ProfessorHomeState();
}

class _ProfessorHomeState extends State<ProfessorHome> {
  final TextEditingController _searchController = TextEditingController();
  final ApiService _apiService = ApiService();
  Map<String, Map<String, String>> assignedTalksMap = {};
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadAssignedTalks();
  }

  Future<void> _loadAssignedTalks() async {
    setState(() => isLoading = true);
    try {
      print('Professore: Caricamento talks da MongoDB...');
      final talksMap = await MongoDBService.getAssignedTalks(
        Constants.CLASSROOM_ID,
      );
      print('Professore: ${talksMap.length} talks caricate');

      setState(() {
        assignedTalksMap = talksMap;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Errore DB: $e')));
      }
    }
  }

  Future<void> _searchTalk() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Ricerca "$query" in corso...')));

    try {
      Map<String, dynamic>? talkData;
      String? talkId;

      if (RegExp(r'^\d+$').hasMatch(query)) {
        talkData = await MongoDBService.searchTalkById(query);
        talkId = query;

        if (talkData == null) throw Exception('Talk ID non trovato');

        _openTalkDetail(talkId, talkData);
      } else {
        final talksList = await _apiService.searchTalksBySubject(query);

        if (talksList.isEmpty) {
          if (context.mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('Nessun talk per "$query"')));
          }
          return;
        }

        _showTalksListDialog(query, talksList);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Errore: $e')));
      }
    }
    _searchController.clear();
  }

  /*
  Future<void> _searchTalk() async {
    final talkId = _searchController.text.trim();
    if (talkId.isEmpty) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Ricerca talk in corso...')));

    try {
      final talkData = await MongoDBService.searchTalkById(talkId);
      if (talkData != null && context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProfessorTalkDetail(
              talkId: talkId,
              title: talkData['title'] ?? 'Talk Sconosciuto',
              description: talkData['description'] ?? '',
              duration: talkData['duration']?.toString() ?? '',
              subjects: List<String>.from(talkData['subjects'] ?? []),
            ),
          ),
        );
      } else if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Talk non trovato')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Errore ricerca: $e')));
      }
    }
    _searchController.clear();
  }
  */
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Professore - 3A Liceo Classico'),
        backgroundColor: Colors.orange.shade700,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Barra di ricerca
          Container(
            color: Colors.orange.shade50,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Cerca Talk per ID o Materia',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Es: 118934 o matematica',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        keyboardType: TextInputType.text,
                        onSubmitted: (_) => _searchTalk(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _searchTalk,
                      icon: const Icon(Icons.search),
                      label: const Text('Cerca'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Talk Assegnati (MongoDB classrooms)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Talk Assegnati (${assignedTalksMap.length})',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Colors.orange,
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: _loadAssignedTalks,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Aggiorna'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  if (isLoading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(40),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (assignedTalksMap.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(40),
                      child: Column(
                        children: [
                          Icon(
                            Icons.assignment_outlined,
                            size: 80,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Nessun talk assegnato',
                            style: TextStyle(fontSize: 18, color: Colors.grey),
                          ),
                          Text(
                            'Usa la ricerca per assegnarne di nuovi',
                            style: TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  else
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _loadAssignedTalks,
                        child: ListView.builder(
                          itemCount: assignedTalksMap.length,
                          itemBuilder: (context, index) {
                            final talkId = assignedTalksMap.keys.elementAt(
                              index,
                            );

                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              elevation: 2,
                              child: ListTile(
                                leading: const Icon(
                                  Icons.assignment,
                                  color: Colors.orange,
                                  size: 40,
                                ),
                                title: Text(
                                  'Talk #$talkId',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                subtitle: const Text(
                                  'Assegnato alla classe 3A',
                                ),
                                trailing: const Icon(
                                  Icons.arrow_forward_ios,
                                  size: 20,
                                ),
                                onTap: () {
                                  MongoDBService.searchTalkById(talkId)
                                      .then((talkData) {
                                        if (talkData != null &&
                                            context.mounted) {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => ProfessorTalkDetail(
                                                talkId: talkId,
                                                title:
                                                    talkData['title'] ??
                                                    'Talk #$talkId',
                                                description:
                                                    talkData['description'] ??
                                                    'Descrizione non disponibile',
                                                duration:
                                                    talkData['duration']
                                                        ?.toString() ??
                                                    'Sconosciuta',
                                                subjects: List<String>.from(
                                                  talkData['subjects'] ?? [],
                                                ),
                                              ),
                                            ),
                                          );
                                        } else {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Dettagli Talk #$talkId non trovati',
                                              ),
                                            ),
                                          );
                                        }
                                      })
                                      .catchError((e) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(content: Text('Errore: $e')),
                                        );
                                      });
                                },
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openTalkDetail(String talkId, Map<String, dynamic> talkData) {
    if (!context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProfessorTalkDetail(
          talkId: talkId,
          title: talkData['title']?.toString() ?? 'Talk Sconosciuto',
          description: talkData['description']?.toString() ?? '',
          duration: talkData['duration']?.toString() ?? '',
          subjects: List<String>.from(talkData['subjects'] ?? []),
        ),
      ),
    );
  }

  void _showTalksListDialog(String query, List<Map<String, dynamic>> talks) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Risultati per "$query" (${talks.length})'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: ListView.builder(
            itemCount: talks.length,
            itemBuilder: (context, index) {
              final talk = talks[index];
              final id = talk['_id']?.toString() ?? 'N/A';
              return ListTile(
                leading: Icon(Icons.assignment, color: Colors.orange),
                title: Text(talk['title']?.toString() ?? 'Sconosciuto'),
                subtitle: Text('ID: $id'),
                onTap: () {
                  Navigator.pop(context);
                  _openTalkDetail(id, talk);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Chiudi'),
          ),
        ],
      ),
    );
  }
}

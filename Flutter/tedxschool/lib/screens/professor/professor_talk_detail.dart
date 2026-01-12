import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/mongodb_service.dart';
import '../../widgets/video_player_widget.dart';
import '../../widgets/assign_talk_modal.dart';

class ProfessorTalkDetail extends StatefulWidget {
  final String talkId;
  final String title;
  final String description;
  final String duration;
  final List<String> subjects;

  const ProfessorTalkDetail({
    super.key,
    required this.talkId,
    required this.title,
    required this.description,
    required this.duration,
    required this.subjects,
  });

  @override
  State<ProfessorTalkDetail> createState() => _ProfessorTalkDetailState();
}

class _ProfessorTalkDetailState extends State<ProfessorTalkDetail> {
  final ApiService _apiService = ApiService();
  late Future<Map<String, dynamic>?> statsFuture;
  int? userRating;
  bool isSubmitting = false;
  bool isAssigning = false;

  @override
  void initState() {
    super.initState();
    statsFuture = MongoDBService.getTalkStats(widget.talkId);
  }

  Future<void> _submitRating(int rating) async {
    setState(() => isSubmitting = true);
    try {
      await _apiService.submitRating(widget.talkId, rating);
      setState(() {
        userRating = rating;
        statsFuture = MongoDBService.getTalkStats(widget.talkId);
      });
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Voto registrato')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => isSubmitting = false);
    }
  }

  Future<void> _assignToClass() async {
    showDialog(
      context: context,
      builder: (_) =>
          AssignTalkModal(videoId: widget.talkId, talkTitle: widget.title),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Talk #${widget.talkId}'),
        backgroundColor: Colors.orange.shade700,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            VideoPlayerWidget(talkId: widget.talkId),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.description,
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  //TO-DO
                  // Conversione durata sec->min con parsing DA FARE
                  Text('Durata: ${widget.duration} sec'),
                  if (widget.subjects.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Materie:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: widget.subjects
                          .map(
                            (subject) => Chip(
                              label: Text(subject),
                              backgroundColor: Colors.blue.shade100,
                            ),
                          )
                          .toList(),
                    ),
                  ],
                  const SizedBox(height: 24),

                  // Rating
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Rating Database',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Statistiche
                          FutureBuilder<Map<String, dynamic>?>(
                            future: statsFuture,
                            builder: (context, statsSnapshot) {
                              if (statsSnapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return const Center(
                                  child: CircularProgressIndicator(),
                                );
                              }
                              final stats = statsSnapshot.data ?? {};
                              final avgRating = (stats['avg_rating'] ?? 0)
                                  .toDouble();
                              final numVotes = stats['num_votes'] ?? 0;
                              return Text(
                                '⭐ ${avgRating.toStringAsFixed(1)}/10 ($numVotes voti)',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange,
                                ),
                              );
                            },
                          ),

                          const SizedBox(height: 20),
                          const Divider(),
                          const SizedBox(height: 16),
                          const Text(
                            'Il tuo voto:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),

                          // Voto professore
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: List.generate(10, (index) {
                              final ratingValue = index + 1;
                              final isSelected = userRating == ratingValue;
                              return ElevatedButton(
                                onPressed: isSubmitting
                                    ? null
                                    : () => _submitRating(ratingValue),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isSelected
                                      ? Colors.orange
                                      : Colors.grey[300],
                                ),
                                child: Text(
                                  '$ratingValue',
                                  style: TextStyle(
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.black,
                                  ),
                                ),
                              );
                            }),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: isAssigning ? null : _assignToClass,
                      icon: const Icon(Icons.assignment),
                      label: isAssigning
                          ? const Text('Assegnando...')
                          : const Text('Assegna a 3A Liceo Classico'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

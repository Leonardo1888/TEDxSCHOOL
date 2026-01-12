import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../models/talk.dart';
import '../../widgets/video_player_widget.dart';

class TalkDetail extends StatefulWidget {
  final String talkId;
  const TalkDetail({super.key, required this.talkId});

  @override
  State<TalkDetail> createState() => _TalkDetailState();
}

class _TalkDetailState extends State<TalkDetail> {
  final ApiService _apiService = ApiService();
  late Future<List<Talk>> relatedVideosFuture;

  @override
  void initState() {
    super.initState();
    relatedVideosFuture = _apiService.getRelatedVideos(widget.talkId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Talk #${widget.talkId}'),
        backgroundColor: Colors.blue.shade700,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Video Player
            VideoPlayerWidget(talkId: widget.talkId),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Contenuto Assegnato',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 24),

                  // Video Correlati
                  const Text(
                    'Video Correlati',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),

                  FutureBuilder<List<Talk>>(
                    future: relatedVideosFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError ||
                          !snapshot.hasData ||
                          snapshot.data!.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.all(20),
                          child: Text('Nessun video correlato'),
                        );
                      }

                      return ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: snapshot.data!.length,
                        itemBuilder: (context, index) {
                          final talk = snapshot.data![index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              leading: talk.image != null
                                  ? Image.network(
                                      talk.image!,
                                      width: 60,
                                      height: 60,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          const Icon(Icons.video_library),
                                    )
                                  : const Icon(Icons.video_library),
                              title: Text(
                                talk.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(talk.id),
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => TalkDetail(talkId: talk.id),
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
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

import 'package:flutter/material.dart';
import '../services/api_service.dart';

class AssignTalkModal extends StatefulWidget {
  final String videoId;
  final String talkTitle;

  const AssignTalkModal({
    super.key,
    required this.videoId,
    required this.talkTitle,
  });

  @override
  State<AssignTalkModal> createState() => _AssignTalkModalState();
}

class _AssignTalkModalState extends State<AssignTalkModal> {
  final _profEmailController = TextEditingController();
  final _subjectController = TextEditingController();
  final _dateController = TextEditingController(text: '2026-01-08');

  bool isSubmitting = false;

  Future<void> _assignTalk() async {
    setState(() => isSubmitting = true);

    try {
      await ApiService.assignVideoToClass(
        className: '3A Liceo Classico',
        profEmail: _profEmailController.text.trim(),
        subject: _subjectController.text.trim(),
        videoId: widget.videoId,
        date: _dateController.text.trim(),
      );

      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Compito assegnato con successo!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      print('Assign errore: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Assegna "${widget.talkTitle}"'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Video ID: ${widget.videoId}',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _profEmailController,
              decoration: const InputDecoration(
                labelText: 'Email Professore',
                hintText: 'gentili.filosofia@scuola.it (opzionale)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _subjectController,
              decoration: const InputDecoration(
                labelText: 'Materia',
                hintText: 'filosofia (opzionale)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _dateController,
              decoration: const InputDecoration(
                labelText: 'Data',
                hintText: '2026-01-08 (opzionale)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: isSubmitting ? null : () => Navigator.pop(context),
          child: const Text('Annulla'),
        ),
        ElevatedButton(
          onPressed: isSubmitting ? null : _assignTalk,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
          child: isSubmitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(Colors.white),
                  ),
                )
              : const Text('Assegna'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _profEmailController.dispose();
    _subjectController.dispose();
    _dateController.dispose();
    super.dispose();
  }
}

class Talk {
  final String id;
  final String title;
  final String? image;
  final List<String>? subjects;

  Talk({required this.id, required this.title, this.image, this.subjects});

  factory Talk.fromJson(Map<String, dynamic> json) {
    return Talk(
      id: json['id']?.toString() ?? '',
      title: json['title'] ?? '',
      image: json['image'],
      subjects: List<String>.from(json['subjects'] ?? []),
    );
  }
}

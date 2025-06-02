class Task {
  String id;
  String title;
  bool isCompleted;

  Task({
    required this.id,
    required this.title,
    this.isCompleted = false,
  });

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: json['title'] ?? '',
      isCompleted: json['isCompleted'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'isCompleted': isCompleted,
    };
  }
}

class NoteData {
  String title;
  String content;
  String subject;
  List<Task> tasks;
  List<Map<String, dynamic>> attachments;
  List<String> imageIds;

  NoteData({
    required this.title,
    required this.content,
    required this.subject,
    required this.tasks,
    required this.attachments,
    required this.imageIds,
  });

  factory NoteData.fromFirestore(Map<String, dynamic> data) {
    return NoteData(
      title: data['title'] ?? '',
      content: data['content'] ?? '',
      subject: data['subject'] ?? '',
      tasks: ((data['tasks'] ?? []) as List)
          .map((taskData) => Task.fromJson(Map<String, dynamic>.from(taskData)))
          .toList(),
      attachments: List<Map<String, dynamic>>.from(data['attachments'] ?? []),
      imageIds: List<String>.from(data['imageIds'] ?? []),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'content': content,
      'subject': subject,
      'tasks': tasks.map((task) => task.toJson()).toList(),
      'attachments': attachments,
      'imageIds': imageIds,
    };
  }
}
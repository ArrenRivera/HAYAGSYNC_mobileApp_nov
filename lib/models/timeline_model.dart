class TimelineEvent {
  final String id;
  final String reportId;
  final String title;
  final String description;
  final String actorName;
  final String actorRole; // 'Parent', 'Adviser', 'Principal', 'OSD Officer', 'System'
  final DateTime timestamp;

  TimelineEvent({
    required this.id,
    required this.reportId,
    required this.title,
    required this.description,
    required this.actorName,
    required this.actorRole,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'reportId': reportId,
      'title': title,
      'description': description,
      'actorName': actorName,
      'actorRole': actorRole,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory TimelineEvent.fromJson(Map<String, dynamic> json) {
    return TimelineEvent(
      id: json['id'],
      reportId: json['reportId'],
      title: json['title'],
      description: json['description'],
      actorName: json['actorName'],
      actorRole: json['actorRole'],
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
}

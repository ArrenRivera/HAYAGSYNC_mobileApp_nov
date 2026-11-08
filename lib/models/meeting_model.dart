class MeetingModel {
  final String id;
  final String reportId;
  final String scheduledByUserId;
  final String scheduledByUserName;
  final String scheduledByUserRole; // 'Adviser', 'Principal', 'OSD Officer'
  final DateTime meetingDate;
  final String notes;
  final String meetingType; // 'Virtual', 'In-Person'
  final DateTime createdAt;

  MeetingModel({
    required this.id,
    required this.reportId,
    required this.scheduledByUserId,
    required this.scheduledByUserName,
    required this.scheduledByUserRole,
    required this.meetingDate,
    required this.notes,
    required this.meetingType,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'reportId': reportId,
      'scheduledByUserId': scheduledByUserId,
      'scheduledByUserName': scheduledByUserName,
      'scheduledByUserRole': scheduledByUserRole,
      'meetingDate': meetingDate.toIso8601String(),
      'notes': notes,
      'meetingType': meetingType,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory MeetingModel.fromJson(Map<String, dynamic> json) {
    return MeetingModel(
      id: json['id'],
      reportId: json['reportId'],
      scheduledByUserId: json['scheduledByUserId'],
      scheduledByUserName: json['scheduledByUserName'],
      scheduledByUserRole: json['scheduledByUserRole'],
      meetingDate: DateTime.parse(json['meetingDate']),
      notes: json['notes'],
      meetingType: json['meetingType'],
      createdAt: DateTime.parse(json['createdAt']),
    );
  }

  MeetingModel copyWith({
    DateTime? meetingDate,
    String? notes,
    String? meetingType,
  }) {
    return MeetingModel(
      id: id,
      reportId: reportId,
      scheduledByUserId: scheduledByUserId,
      scheduledByUserName: scheduledByUserName,
      scheduledByUserRole: scheduledByUserRole,
      meetingDate: meetingDate ?? this.meetingDate,
      notes: notes ?? this.notes,
      meetingType: meetingType ?? this.meetingType,
      createdAt: createdAt,
    );
  }
}

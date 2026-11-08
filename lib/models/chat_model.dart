class ChatMessage {
  final String id;
  final String meetingId;
  final String senderId;
  final String senderName;
  final String senderRole; // 'Parent', 'Adviser', 'Principal', 'OSD Officer'
  final String message;
  final DateTime timestamp;
  final bool isReadByReceiver;

  ChatMessage({
    required this.id,
    required this.meetingId,
    required this.senderId,
    required this.senderName,
    required this.senderRole,
    required this.message,
    required this.timestamp,
    this.isReadByReceiver = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'meetingId': meetingId,
      'senderId': senderId,
      'senderName': senderName,
      'senderRole': senderRole,
      'message': message,
      'timestamp': timestamp.toIso8601String(),
      'isReadByReceiver': isReadByReceiver,
    };
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'],
      meetingId: json['meetingId'],
      senderId: json['senderId'],
      senderName: json['senderName'],
      senderRole: json['senderRole'],
      message: json['message'],
      timestamp: DateTime.parse(json['timestamp']),
      isReadByReceiver: json['isReadByReceiver'] ?? false,
    );
  }

  ChatMessage copyWith({
    bool? isReadByReceiver,
  }) {
    return ChatMessage(
      id: id,
      meetingId: meetingId,
      senderId: senderId,
      senderName: senderName,
      senderRole: senderRole,
      message: message,
      timestamp: timestamp,
      isReadByReceiver: isReadByReceiver ?? this.isReadByReceiver,
    );
  }
}

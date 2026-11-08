import 'student_model.dart';

enum UserRole { parent, adviser, principal, ministrong_tagasubaybay, osd, board_of_discipline, school_president }

class UserModel {
  final String id;
  final String email;
  final String name;
  final UserRole role;
  final String? avatarUrl;
  
  // For advisers
  final String? assignedSection;
  
  // For verified parents
  final String? studentName;
  final String? studentGrade;
  final String? studentSection;
  final String? academicYear;
  final List<StudentModel>? students;

  UserModel({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    this.avatarUrl,
    this.assignedSection,
    this.studentName,
    this.studentGrade,
    this.studentSection,
    this.academicYear,
    this.students,
  });

  String get roleString {
    switch (role) {
      case UserRole.parent:
        return 'Parent';
      case UserRole.adviser:
        return 'Adviser';
      case UserRole.principal:
        return 'Principal';
      case UserRole.ministrong_tagasubaybay:
        return 'Ministrong Tagasubaybay';
      case UserRole.osd:
        return 'OSD Officer';
      case UserRole.board_of_discipline:
        return 'Board of Discipline';
      case UserRole.school_president:
        return 'School President';
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'role': role.toString().split('.').last,
      'avatarUrl': avatarUrl,
      'assignedSection': assignedSection,
      'studentName': studentName,
      'studentGrade': studentGrade,
      'studentSection': studentSection,
      'academicYear': academicYear,
      'students': students?.map((e) => e.toJson()).toList(),
    };
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'].toString(),
      email: json['email'],
      name: json['name'],
      role: UserRole.values.firstWhere(
        (e) => e.toString().split('.').last == json['role'],
        orElse: () => UserRole.parent,
      ),
      avatarUrl: json['avatarUrl'] ?? json['avatar_url'],
      assignedSection: json['assignedSection'] ?? json['assigned_section'],
      studentName: json['studentName'] ?? json['student_name'],
      studentGrade: json['studentGrade'] ?? json['student_grade'],
      studentSection: json['studentSection'] ?? json['student_section'],
      academicYear: json['academicYear'] ?? json['academic_year'],
      students: json['students'] != null
          ? (json['students'] as List).map((e) => StudentModel.fromJson(e)).toList()
          : null,
    );
  }

  UserModel copyWith({
    String? name,
    String? avatarUrl,
    String? studentName,
    String? studentGrade,
    String? studentSection,
    String? academicYear,
    List<StudentModel>? students,
  }) {
    return UserModel(
      id: id,
      email: email,
      name: name ?? this.name,
      role: role,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      assignedSection: assignedSection,
      studentName: studentName ?? this.studentName,
      studentGrade: studentGrade ?? this.studentGrade,
      studentSection: studentSection ?? this.studentSection,
      academicYear: academicYear ?? this.academicYear,
      students: students ?? this.students,
    );
  }
}

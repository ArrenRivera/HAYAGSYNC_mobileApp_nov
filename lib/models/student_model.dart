class StudentModel {
  final String id;
  final String parentId;
  final String name;
  final String grade;
  final String section;
  final String academicYear;
  final String? lrn;
  final String? status;

  StudentModel({
    required this.id,
    required this.parentId,
    required this.name,
    required this.grade,
    required this.section,
    required this.academicYear,
    this.lrn,
    this.status,
  });

  factory StudentModel.fromJson(Map<String, dynamic> json) {
    return StudentModel(
      id: json['id'].toString(),
      parentId: json['parent_id']?.toString() ?? '',
      name: json['name'] ?? '',
      grade: json['grade'] ?? '',
      section: json['section'] ?? '',
      academicYear: json['academic_year'] ?? '',
      lrn: json['lrn']?.toString(),
      status: json['status']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'parent_id': parentId,
      'name': name,
      'grade': grade,
      'section': section,
      'academic_year': academicYear,
      'lrn': lrn,
      'status': status,
    };
  }
}

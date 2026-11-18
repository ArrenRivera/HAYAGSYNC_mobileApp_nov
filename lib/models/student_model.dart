class StudentModel {
  final String id;
  final String parentId;
  final String name;
  final String grade;
  final String section;
  final String academicYear;
  final String? lrn;
  final String? status;
  final String? firstName;
  final String? lastName;
  final String? middleInitial;
  final String? gender;
  final String? parentFullName;

  StudentModel({
    required this.id,
    required this.parentId,
    required this.name,
    required this.grade,
    required this.section,
    required this.academicYear,
    this.lrn,
    this.status,
    this.firstName,
    this.lastName,
    this.middleInitial,
    this.gender,
    this.parentFullName,
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
      firstName: json['first_name']?.toString(),
      lastName: json['last_name']?.toString(),
      middleInitial: json['middle_initial']?.toString(),
      gender: json['gender']?.toString(),
      parentFullName: json['parent_fullname']?.toString(),
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
      'first_name': firstName,
      'last_name': lastName,
      'middle_initial': middleInitial,
      'gender': gender,
      'parent_fullname': parentFullName,
    };
  }
}

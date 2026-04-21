class AttendanceResponse {
  final String status;
  final List<String> recognizedStudents;
  final String message;

  AttendanceResponse({
    required this.status,
    required this.recognizedStudents,
    required this.message,
  });

  // JSON ko Dart object mein badalne ke liye
  factory AttendanceResponse.fromJson(Map<String, dynamic> json) {
    return AttendanceResponse(
      status: json['status'] ?? "Error",
      recognizedStudents: List<String>.from(json['recognized_students'] ?? []),
      message: json['message'] ?? "",
    );
  }
}

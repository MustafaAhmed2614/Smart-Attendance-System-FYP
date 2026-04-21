class AttendanceResponse {
  final String status;
  final String message;
  final List<String> recognizedStudents;

  AttendanceResponse({
    required this.status,
    required this.message,
    required this.recognizedStudents,
  });

  factory AttendanceResponse.fromJson(Map<String, dynamic> json) {
    return AttendanceResponse(
      // ?? "" ka matlab hai agar null aaye toh khali string rakho
      status: json['status'] ?? "Error",
      message: json['message'] ?? "No message from server",
      // Agar recognized_students null ho toh khali list bhej do
      recognizedStudents: json['recognized_students'] != null
          ? List<String>.from(json['recognized_students'])
          : [],
    );
  }
}

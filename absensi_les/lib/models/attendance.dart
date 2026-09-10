class Attendance {
  int? id;
  int studentId; // Relasi ke ID Murid
  String date;
  String duration;
  String type;

  Attendance({this.id, required this.studentId, required this.date, required this.duration, required this.type});

  Map<String, dynamic> toMap() {
    return {'id': id, 'studentId': studentId, 'date': date, 'duration': duration, 'type': type};
  }

  factory Attendance.fromMap(Map<String, dynamic> map) {
    return Attendance(
      id: map['id'],
      studentId: map['studentId'],
      date: map['date'],
      duration: map['duration'],
      type: map['type'],
    );
  }
}
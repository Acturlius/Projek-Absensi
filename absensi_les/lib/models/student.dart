class Student {
  int? id;
  String name;
  String level; 

  Student({this.id, required this.name, required this.level});

  Map<String, dynamic> toMap() => {
    'id': id, 
    'name': name, 
    'level': level
  };

  factory Student.fromMap(Map<String, dynamic> map) => Student(
    id: map['id'],
    name: map['name'],
    level: map['level'] ?? 'Lainnya', 
  );
}
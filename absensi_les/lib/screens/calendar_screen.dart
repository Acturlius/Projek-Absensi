import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../db/database_helper.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  // Menyimpan data gabungan
  List<Map<String, dynamic>> _allEvents = [];
  List<Map<String, dynamic>> _selectedEvents = [];

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadAllEvents();
  }

  Future<void> _loadAllEvents() async {
    final students = await DatabaseHelper.instance.getStudents();
    List<Map<String, dynamic>> tempEvents = [];

    // Mengambil semua riwayat absen
    for (var student in students) {
      final attendances = await DatabaseHelper.instance.getAttendancesByStudent(student.id!);
      for (var att in attendances) {
        tempEvents.add({
          'studentName': student.name,
          'level': student.level, 
          'date': att.date,
          'duration': att.duration,
          'type': att.type,
        });
      }
    }

    setState(() {
      _allEvents = tempEvents;
      _filterEvents(_selectedDay!);
    });
  }

  void _filterEvents(DateTime day) {
    final dateStr = DateFormat('yyyy-MM-dd').format(day);
    setState(() {
      _selectedEvents = _allEvents.where((e) => e['date'] == dateStr).toList();
    });
  }

  // --- LOGIKA MENGHITUNG TOTAL JAM & SESI ---
  double _parseDuration(String durationStr) {
    // Bersihkan huruf, ambil angkanya saja
    final cleanStr = durationStr.replaceAll(RegExp(r'[^0-9.]'), '');
    final value = double.tryParse(cleanStr) ?? 0.0;
    // Kalau ada kata "menit", ubah ke desimal jam (misal 30 menit = 0.5 jam)
    if (durationStr.toLowerCase().contains('menit')) return value / 60.0;
    return value;
  }

  Map<String, dynamic> get _monthlyStats {
    double totalHours = 0.0;
    int totalSessions = 0;

    for (var ev in _allEvents) {
      final date = DateTime.parse(ev['date']);
      // Cek apakah data ini ada di bulan dan tahun yang sedang dilihat di kalender
      if (date.year == _focusedDay.year && date.month == _focusedDay.month) {
        totalHours += _parseDuration(ev['duration']);
        totalSessions++;
      }
    }

    return {
      'totalHours': totalHours,
      'totalSessions': totalSessions,
    };
  }

  @override
  Widget build(BuildContext context) {
    final stats = _monthlyStats;
    // Format agar kalau angkanya genap (misal 10) tidak muncul .0 (10.0), tapi kalau ada desimal (10.5) tetap muncul
    final displayHours = stats['totalHours'].toStringAsFixed(stats['totalHours'].truncateToDouble() == stats['totalHours'] ? 0 : 1);

    return Scaffold(
      appBar: AppBar(title: const Text('Kalender Les')),
      body: Column(
        children: [
          // --- UI STATISTIK BULANAN ---
          Card(
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            color: Colors.amber[100], // Warna background card statistik
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Column(
                    children: [
                      const Text('Total Jam', style: TextStyle(color: Colors.black54, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text('$displayHours Jam', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.deepOrange)),
                    ],
                  ),
                  Container(width: 2, height: 40, color: Colors.white), // Garis pembatas
                  Column(
                    children: [
                      const Text('Total Sesi', style: TextStyle(color: Colors.black54, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text('${stats['totalSessions']} Sesi', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // --- END UI STATISTIK ---

          TableCalendar(
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            calendarFormat: _calendarFormat,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            eventLoader: (day) {
              final d = DateFormat('yyyy-MM-dd').format(day);
              return _allEvents.where((e) => e['date'] == d).toList();
            },
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
              _filterEvents(selectedDay);
            },
            // Update _focusedDay saat bulan digeser (swipe) biar statistik otomatis update
            onPageChanged: (focusedDay) {
              setState(() {
                _focusedDay = focusedDay;
              });
            },
            onFormatChanged: (format) => setState(() => _calendarFormat = format),
            calendarStyle: const CalendarStyle(
              todayDecoration: BoxDecoration(color: Colors.blueAccent, shape: BoxShape.circle),
              selectedDecoration: BoxDecoration(color: Colors.orange, shape: BoxShape.circle),
              markerDecoration: BoxDecoration(color: Colors.red, shape: BoxShape.circle),
              markersMaxCount: 1, 
            ),
          ),
          const Divider(thickness: 2),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              "Jadwal: ${DateFormat('dd MMMM yyyy').format(_selectedDay!)}",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          Expanded(
            child: _selectedEvents.isEmpty
                ? const Center(child: Text('Tidak ada murid les hari ini.'))
                : ListView.builder(
                    itemCount: _selectedEvents.length,
                    itemBuilder: (context, index) {
                      final ev = _selectedEvents[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Theme.of(context).colorScheme.primary.withAlpha(25),
                            child: Icon(Icons.person, color: Theme.of(context).colorScheme.primary),
                          ),
                          title: Text('${ev['studentName']} (${ev['level']})', style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('${ev['type']} | ${ev['duration']}'),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
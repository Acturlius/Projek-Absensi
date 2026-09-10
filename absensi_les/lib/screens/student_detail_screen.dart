import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../db/database_helper.dart';
import '../models/student.dart';
import '../models/attendance.dart';

class StudentDetailScreen extends StatefulWidget {
  final Student student;
  const StudentDetailScreen({super.key, required this.student});

  @override
  State<StudentDetailScreen> createState() => _StudentDetailScreenState();
}

class _StudentDetailScreenState extends State<StudentDetailScreen> {
  late Student _currentStudent; 
  List<Attendance> _allAttendances = [];
  DateTime _currentMonth = DateTime.now();
  Set<int> _selectedIds = {}; 

  // --- LOGIKA URUTAN TANGGAL ---
  bool _isDateAscending = false; // Default false (Terbaru di atas)

  bool get _isSelectionMode => _selectedIds.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _currentStudent = widget.student; 
    _loadAttendances();
  }

  Future<void> _loadAttendances() async {
    final data = await DatabaseHelper.instance.getAttendancesByStudent(_currentStudent.id!);
    setState(() {
      _allAttendances = data;
      _selectedIds.removeWhere((id) => !data.any((a) => a.id == id));
    });
  }

  void _changeMonth(int offset) {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + offset, 1);
      _selectedIds.clear(); 
    });
  }

  List<Attendance> get _filteredAttendances {
    var filtered = _allAttendances.where((att) {
      final date = DateTime.parse(att.date);
      return date.year == _currentMonth.year && date.month == _currentMonth.month;
    }).toList();

    // Terapkan Sorting
    filtered.sort((a, b) {
      final dateA = DateTime.parse(a.date);
      final dateB = DateTime.parse(b.date);
      if (_isDateAscending) {
        return dateA.compareTo(dateB); // Lama ke Baru
      } else {
        return dateB.compareTo(dateA); // Baru ke Lama
      }
    });

    return filtered;
  }

  double _parseDuration(String durationStr) {
    final cleanStr = durationStr.replaceAll(RegExp(r'[^0-9.]'), '');
    final value = double.tryParse(cleanStr) ?? 0.0;
    if (durationStr.toLowerCase().contains('menit')) return value / 60.0;
    return value;
  }

  Map<String, double> get _monthlySummary {
    final summary = <String, double>{};
    for (var att in _filteredAttendances) {
      final hours = _parseDuration(att.duration);
      summary[att.type] = (summary[att.type] ?? 0.0) + hours;
    }
    return summary;
  }

  void _shareMonthlyReport() {
    final summary = _monthlySummary;
    if (summary.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tidak ada data untuk dibagikan.')));
      return;
    }
    String monthName = DateFormat('MMMM yyyy').format(_currentMonth);
    String reportText = "📝 *Laporan Les Bulanan - $monthName*\n";
    reportText += "👤 *Murid:* ${_currentStudent.name} (${_currentStudent.level})\n\n";
    reportText += "📊 *Detail Durasi:*\n";
    summary.forEach((type, hours) {
      String displayHours = hours.toStringAsFixed(hours.truncateToDouble() == hours ? 0 : 1);
      reportText += "- $type: $displayHours Jam\n";
    });
    reportText += "\n_Terima kasih sudah belajar bersama kami!_";
    Share.share(reportText);
  }

  void _toggleSelection(int id) {
    setState(() {
      if (_selectedIds.contains(id)) _selectedIds.remove(id);
      else _selectedIds.add(id);
    });
  }

  void _selectAll() {
    setState(() {
      if (_selectedIds.length == _filteredAttendances.length) _selectedIds.clear();
      else _selectedIds = _filteredAttendances.map((a) => a.id!).toSet();
    });
  }

  Future<void> _deleteSelected() async {
    if (_selectedIds.isEmpty) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Hapus Sesi?'),
        content: Text('Yakin ingin menghapus ${_selectedIds.length} riwayat sesi les ini?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true), child: const Text('Hapus')),
        ],
      ),
    );

    if (confirm == true) {
      await DatabaseHelper.instance.deleteMultipleAttendances(_selectedIds.toList());
      setState(() => _selectedIds.clear());
      _loadAttendances();
    }
  }

  void _showEditStudentForm(BuildContext context) {
    final nameController = TextEditingController(text: _currentStudent.name);
    String selectedLevel = _currentStudent.level;
    
    final levels = ['TK', 'SD', 'SMP', 'SMA', 'Lainnya'];
    if (!levels.contains(selectedLevel)) selectedLevel = 'Lainnya';

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), 
            title: const Text('Edit Profil Murid', style: TextStyle(fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'Nama Lengkap',
                    prefixIcon: const Icon(Icons.person),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedLevel,
                  items: levels.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                  onChanged: (val) => setDialogState(() => selectedLevel = val!),
                  decoration: InputDecoration(
                    labelText: 'Jenjang / Kategori', 
                    prefixIcon: const Icon(Icons.school),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange[700],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () async {
                  if (nameController.text.isNotEmpty) {
                    final updatedStudent = Student(
                      id: _currentStudent.id,
                      name: nameController.text,
                      level: selectedLevel
                    );
                    
                    await DatabaseHelper.instance.updateStudent(updatedStudent);
                    
                    setState(() {
                      _currentStudent = updatedStudent;
                    });
                    
                    if (!context.mounted) return;
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profil murid berhasil diperbarui!')));
                  }
                },
                child: const Text('UPDATE'),
              ),
            ],
          );
        }
      ),
    );
  }

  void _showEditAttendanceForm(BuildContext context, Attendance attendance) {
    DateTime selectedDate = DateTime.parse(attendance.date);
    String selectedType = attendance.type;
    
    final types = ['Matematika', 'Bahasa Inggris', 'Mandarin', 'Calistung', 'Lainnya'];
    if (!types.contains(selectedType)) selectedType = 'Lainnya';
    
    final durations = ['30 Menit', '1 Jam', '1.5 Jam', '2 Jam', 'Lainnya'];
    String selectedDuration = durations.contains(attendance.duration) ? attendance.duration : 'Lainnya';
    
    String oldNumberOnly = attendance.duration.replaceAll(RegExp(r'[^0-9.]'), '');
    final customDurationController = TextEditingController(text: selectedDuration == 'Lainnya' ? oldNumberOnly : '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, top: 24, left: 24, right: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Edit Sesi Les', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
                const SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  value: selectedType,
                  items: types.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                  onChanged: (val) => setModalState(() => selectedType = val!),
                  decoration: InputDecoration(labelText: 'Mata Pelajaran', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedDuration,
                  items: durations.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                  onChanged: (val) => setModalState(() => selectedDuration = val!),
                  decoration: InputDecoration(labelText: 'Durasi', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                ),
                
                if (selectedDuration == 'Lainnya') ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: customDurationController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Ketik Angka Saja (Misal: 3 atau 2.5)', 
                      suffixText: 'Jam', 
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: Colors.amber.withAlpha(30),
                    ),
                  ),
                ],

                const SizedBox(height: 16),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(context: context, initialDate: selectedDate, firstDate: DateTime(2020), lastDate: DateTime(2030));
                    if (picked != null) setModalState(() => selectedDate = picked);
                  },
                  child: InputDecorator(
                    decoration: InputDecoration(labelText: 'Tanggal Les', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(DateFormat('dd MMMM yyyy').format(selectedDate)),
                        const Icon(Icons.calendar_today, color: Colors.grey),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.orange[700],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    String finalDuration = selectedDuration;

                    if (selectedDuration == 'Lainnya') {
                      String inputText = customDurationController.text.trim();
                      double? parsedValue = double.tryParse(inputText.replaceAll(',', '.'));
                      
                      if (parsedValue == null || parsedValue <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('⚠ Error: Masukkan durasi dengan angka yang benar!'), backgroundColor: Colors.red)
                        );
                        return; 
                      }
                      
                      String displayValue = parsedValue.truncateToDouble() == parsedValue 
                          ? parsedValue.toInt().toString() 
                          : parsedValue.toString();
                          
                      finalDuration = '$displayValue Jam';
                    }

                    final updatedAtt = Attendance(
                      id: attendance.id, 
                      studentId: attendance.studentId,
                      date: DateFormat('yyyy-MM-dd').format(selectedDate),
                      duration: finalDuration,
                      type: selectedType,
                    );
                    await DatabaseHelper.instance.updateAttendance(updatedAtt);
                    if (!context.mounted) return;
                    Navigator.pop(context);
                    _loadAttendances();
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sesi les berhasil diperbarui!')));
                  },
                  child: const Text('UPDATE SESI', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 24),
              ],
            ),
          );
        }
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final summary = _monthlySummary;
    final filteredList = _filteredAttendances;

    return Scaffold(
      appBar: _isSelectionMode
        ? AppBar(
            backgroundColor: Colors.indigo[800],
            leading: IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => _selectedIds.clear())),
            title: Text('${_selectedIds.length} Dipilih'),
            actions: [
              IconButton(icon: const Icon(Icons.select_all), onPressed: _selectAll),
              IconButton(icon: const Icon(Icons.delete), onPressed: _deleteSelected),
            ],
          )
        : AppBar(
            title: Text(_currentStudent.name), 
            actions: [
              IconButton(icon: const Icon(Icons.edit), onPressed: () => _showEditStudentForm(context), tooltip: 'Edit Profil Murid'),
              IconButton(icon: const Icon(Icons.share), onPressed: _shareMonthlyReport, tooltip: 'Kirim Laporan'),
            ],
          ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
            color: Colors.blue.withAlpha(25),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(icon: const Icon(Icons.arrow_back_ios, size: 20), onPressed: () => _changeMonth(-1)),
                Text(DateFormat('MMMM yyyy').format(_currentMonth), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                IconButton(icon: const Icon(Icons.arrow_forward_ios, size: 20), onPressed: () => _changeMonth(1)),
              ],
            ),
          ),
          
          // --- UI SORTING TANGGAL ---
          if (filteredList.isNotEmpty && !_isSelectionMode)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Text('Urutkan:', style: TextStyle(color: Colors.grey, fontSize: 13)),
                  TextButton.icon(
                    icon: Icon(_isDateAscending ? Icons.arrow_upward : Icons.arrow_downward, size: 16),
                    label: Text(_isDateAscending ? 'Lama ke Baru' : 'Baru ke Lama'),
                    onPressed: () {
                      setState(() {
                        _isDateAscending = !_isDateAscending;
                      });
                    },
                  ),
                ],
              ),
            ),
          // --- END UI SORTING ---

          if (summary.isNotEmpty && !_isSelectionMode)
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 12),
              color: Colors.blue[50],
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Total Jam Bulan Ini:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 10),
                    ...summary.entries.map((entry) {
                      String displayHours = entry.value.toStringAsFixed(entry.value.truncateToDouble() == entry.value ? 0 : 1);
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('- ${entry.key}', style: const TextStyle(fontSize: 15)),
                            Text('$displayHours Jam', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.blue)),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
          const Divider(thickness: 2),
          Expanded(
            child: filteredList.isEmpty
                ? const Center(child: Text('Tidak ada riwayat di bulan ini.'))
                : ListView.builder(
                    itemCount: filteredList.length,
                    itemBuilder: (context, index) {
                      final att = filteredList[index];
                      final isSelected = _selectedIds.contains(att.id);

                      return Card(
                        color: isSelected ? Colors.blue.withAlpha(50) : null,
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onLongPress: () => _toggleSelection(att.id!),
                          onTap: () {
                            if (_isSelectionMode) {
                              _toggleSelection(att.id!);
                            } else {
                              _showEditAttendanceForm(context, att);
                            }
                          },
                          child: ListTile(
                            leading: _isSelectionMode
                              ? Checkbox(value: isSelected, onChanged: (bool? val) => _toggleSelection(att.id!))
                              : const CircleAvatar(backgroundColor: Colors.blueAccent, child: Icon(Icons.history, color: Colors.white)),
                            title: Text('${att.type} • ${att.duration}', style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(DateFormat('EEEE, dd MMM yyyy').format(DateTime.parse(att.date))),
                            trailing: _isSelectionMode ? null : const Icon(Icons.edit, color: Colors.grey, size: 20),
                          ),
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
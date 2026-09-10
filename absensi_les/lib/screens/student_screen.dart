import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db/database_helper.dart';
import '../models/student.dart';
import '../models/attendance.dart';
import 'student_detail_screen.dart';

class StudentScreen extends StatefulWidget {
  const StudentScreen({super.key});

  @override
  State<StudentScreen> createState() => _StudentScreenState();
}

class _StudentScreenState extends State<StudentScreen> {
  List<Student> _students = [];
  List<Student> _filteredStudents = []; // Buat nampung hasil pencarian
  Set<int> _selectedIds = {}; 
  
  final TextEditingController _searchController = TextEditingController();
  bool _isAscending = true; // Default A-Z

  bool get _isSelectionMode => _selectedIds.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _refreshStudents();
  }

  Future<void> _refreshStudents() async {
    final data = await DatabaseHelper.instance.getStudents();
    setState(() {
      _students = data;
      _selectedIds.removeWhere((id) => !data.any((s) => s.id == id));
      _applySearchAndSort(); // Terapkan pencarian dan urutan
    });
  }

  // --- LOGIKA SEARCH & SORTING ---
  void _applySearchAndSort() {
    String keyword = _searchController.text.toLowerCase();
    
    // 1. Filter nama berdasarkan ketikan
    List<Student> result = _students.where((s) {
      return s.name.toLowerCase().contains(keyword);
    }).toList();

    // 2. Urutkan berdasarkan abjad (A-Z atau Z-A)
    result.sort((a, b) {
      if (_isAscending) {
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      } else {
        return b.name.toLowerCase().compareTo(a.name.toLowerCase());
      }
    });

    setState(() {
      _filteredStudents = result;
    });
  }

  void _toggleSort() {
    setState(() {
      _isAscending = !_isAscending;
      _applySearchAndSort();
    });
  }

  void _toggleSelection(int id) {
    setState(() {
      if (_selectedIds.contains(id)) _selectedIds.remove(id);
      else _selectedIds.add(id);
    });
  }

  void _selectAll() {
    setState(() {
      if (_selectedIds.length == _filteredStudents.length) _selectedIds.clear();
      else _selectedIds = _filteredStudents.map((s) => s.id!).toSet();
    });
  }

  Future<void> _deleteSelected() async {
    if (_selectedIds.isEmpty) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Hapus Murid?'),
        content: Text('Yakin ingin menghapus ${_selectedIds.length} murid beserta semua riwayat lesnya?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true), 
            child: const Text('Hapus')
          ),
        ],
      ),
    );

    if (confirm == true) {
      await DatabaseHelper.instance.deleteMultipleStudents(_selectedIds.toList());
      setState(() => _selectedIds.clear());
      _refreshStudents();
    }
  }

  void _showAddStudentForm(BuildContext context) {
    final nameController = TextEditingController();
    String selectedLevel = 'Lainnya'; 

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), 
            title: const Text('Tambah Murid Baru', style: TextStyle(fontWeight: FontWeight.bold)),
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
                  items: ['TK', 'SD', 'SMP', 'SMA', 'Lainnya'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
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
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () async {
                  if (nameController.text.isNotEmpty) {
                    await DatabaseHelper.instance.insertStudent(Student(name: nameController.text, level: selectedLevel));
                    _refreshStudents();
                    if (!context.mounted) return;
                    Navigator.pop(context);
                  }
                },
                child: const Text('Simpan'),
              ),
            ],
          );
        }
      ),
    );
  }

  void _showAddAttendanceForm(BuildContext context, Student student) {
    DateTime selectedDate = DateTime.now();
    String selectedType = 'Matematika';
    String selectedDuration = '1 Jam';
    final customDurationController = TextEditingController(); 

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              top: 24, left: 24, right: 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Tambah Sesi Les', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
                Text('Murid: ${student.name} (${student.level})', style: const TextStyle(fontSize: 16, color: Colors.grey)),
                const SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  value: selectedType,
                  items: ['Matematika', 'Bahasa Inggris', 'Mandarin', 'Calistung', 'Lainnya'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                  onChanged: (val) => setModalState(() => selectedType = val!),
                  decoration: InputDecoration(labelText: 'Mata Pelajaran', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedDuration,
                  items: ['30 Menit', '1 Jam', '1.5 Jam', '2 Jam', 'Lainnya'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
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
                    backgroundColor: Theme.of(context).colorScheme.primary,
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
                          const SnackBar(
                            content: Text('⚠ Error: Masukkan durasi dengan angka yang benar!'),
                            backgroundColor: Colors.red,
                          )
                        );
                        return; 
                      }
                      
                      String displayValue = parsedValue.truncateToDouble() == parsedValue 
                          ? parsedValue.toInt().toString() 
                          : parsedValue.toString();
                          
                      finalDuration = '$displayValue Jam';
                    }

                    final att = Attendance(
                      studentId: student.id!,
                      date: DateFormat('yyyy-MM-dd').format(selectedDate),
                      duration: finalDuration,
                      type: selectedType,
                    );
                    await DatabaseHelper.instance.insertAttendance(att);
                    if (!context.mounted) return;
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sesi les berhasil ditambahkan!', style: TextStyle(fontWeight: FontWeight.bold))));
                  },
                  child: const Text('SIMPAN SESI', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
          : AppBar(title: const Text('Daftar Murid')),
      body: Column(
        children: [
          // --- UI SEARCH BAR & TOMBOL SORTING ---
          if (!_isSelectionMode)
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: (value) => _applySearchAndSort(), // Langsung cari waktu ngetik
                      decoration: InputDecoration(
                        hintText: 'Cari nama murid...',
                        prefixIcon: const Icon(Icons.search),
                        filled: true,
                        fillColor: Colors.grey[200],
                        contentPadding: const EdgeInsets.symmetric(vertical: 0),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withAlpha(25),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: Icon(
                        _isAscending ? Icons.sort_by_alpha : Icons.sort_by_alpha_outlined,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      tooltip: _isAscending ? 'Urutkan Z-A' : 'Urutkan A-Z',
                      onPressed: _toggleSort,
                    ),
                  ),
                ],
              ),
            ),
          // --- END UI SEARCH BAR ---

          Expanded(
            child: _filteredStudents.isEmpty 
              ? const Center(child: Text('Data tidak ditemukan.\nSilakan tambah murid baru.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 16)))
              : ListView.builder(
                  padding: const EdgeInsets.only(top: 8, bottom: 80),
                  itemCount: _filteredStudents.length,
                  itemBuilder: (context, index) {
                    final s = _filteredStudents[index];
                    final isSelected = _selectedIds.contains(s.id);

                    return Card(
                      color: isSelected ? Colors.blue.withAlpha(50) : null,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onLongPress: () => _toggleSelection(s.id!),
                        onTap: () {
                          if (_isSelectionMode) {
                            _toggleSelection(s.id!);
                          } else {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => StudentDetailScreen(student: s))).then((_) => _refreshStudents());
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: ListTile(
                            leading: _isSelectionMode
                                ? Checkbox(value: isSelected, onChanged: (bool? val) => _toggleSelection(s.id!))
                                : CircleAvatar(
                                    radius: 24,
                                    backgroundColor: Theme.of(context).colorScheme.primary.withAlpha(25),
                                    child: Text(
                                      s.name.isNotEmpty ? s.name[0].toUpperCase() : '?',
                                      style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 20),
                                    ),
                                  ),
                            title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            subtitle: Text(s.level, style: const TextStyle(fontSize: 13, color: Colors.grey)),
                            trailing: _isSelectionMode ? null : IconButton(
                              tooltip: 'Tambah Sesi Les',
                              icon: const Icon(Icons.add_circle, color: Colors.green, size: 28),
                              onPressed: () => _showAddAttendanceForm(context, s),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
          ),
        ],
      ),
      floatingActionButton: _isSelectionMode ? null : FloatingActionButton(
        onPressed: () => _showAddStudentForm(context),
        child: const Icon(Icons.person_add),
      ),
    );
  }
}
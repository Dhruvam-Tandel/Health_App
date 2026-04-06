import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../models/health_record.dart';
import '../services/health_record_service.dart';
import 'add_health_record_screen.dart';
import 'edit_health_record_screen.dart';

class HealthRecordsListScreen extends StatefulWidget {
  final String? patientId; // For doctor/staff to view specific patient
  final String? patientName; // For display

  const HealthRecordsListScreen({
    super.key,
    this.patientId,
    this.patientName,
  });

  @override
  State<HealthRecordsListScreen> createState() =>
      _HealthRecordsListScreenState();
}

class _HealthRecordsListScreenState extends State<HealthRecordsListScreen> {
  final _healthRecordService = HealthRecordService();
  String _selectedCategory = 'All';
  String _searchQuery = '';
  String? _userRole;

  @override
  void initState() {
    super.initState();
    _loadUserRole();
  }

  Future<void> _loadUserRole() async {
    // Delegate to service (uses cache after first call)
    final role = await _healthRecordService.getCurrentUserRole();
    if (mounted) setState(() => _userRole = role);
  }

  String _getPatientId() {
    if (widget.patientId != null) return widget.patientId!;
    return FirebaseAuth.instance.currentUser?.uid ?? '';
  }

  Stream<List<HealthRecord>> _getRecordsStream() {
    final patientId = _getPatientId();
    if (_selectedCategory == 'All') {
      return _healthRecordService.getHealthRecords(patientId);
    } else {
      return _healthRecordService.getHealthRecordsByCategory(
          patientId, _selectedCategory);
    }
  }

  List<HealthRecord> _applySearch(List<HealthRecord> records) {
    if (_searchQuery.isEmpty) return records;
    final q = _searchQuery.toLowerCase();
    return records
        .where((r) =>
            r.title.toLowerCase().contains(q) ||
            r.description.toLowerCase().contains(q))
        .toList();
  }

  Future<void> _deleteRecord(String recordId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Record'),
        content: const Text(
            'Are you sure you want to delete this health record? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _healthRecordService.deleteHealthRecord(recordId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Record deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case RecordCategory.vitals:
        return Colors.red;
      case RecordCategory.labReports:
        return Colors.purple;
      case RecordCategory.imaging:
        return Colors.blue;
      case RecordCategory.prescriptions:
        return Colors.green;
      case RecordCategory.visits:
        return Colors.orange;
      case RecordCategory.vaccinations:
        return Colors.teal;
      case RecordCategory.allergies:
        return Colors.pink;
      case RecordCategory.procedures:
        return Colors.indigo;
      default:
        return Colors.grey;
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case RecordCategory.vitals:
        return Icons.favorite;
      case RecordCategory.labReports:
        return Icons.science;
      case RecordCategory.imaging:
        return Icons.medical_services;
      case RecordCategory.prescriptions:
        return Icons.medication;
      case RecordCategory.visits:
        return Icons.local_hospital;
      case RecordCategory.vaccinations:
        return Icons.vaccines;
      case RecordCategory.allergies:
        return Icons.warning;
      case RecordCategory.procedures:
        return Icons.healing;
      default:
        return Icons.description;
    }
  }

  Widget _buildRecordCard(HealthRecord record) {
    final categoryColor = _getCategoryColor(record.category);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EditHealthRecordScreen(record: record),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: categoryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _getCategoryIcon(record.category),
                      color: categoryColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          record.title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          DateFormat('MMM dd, yyyy').format(record.date),
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Category Chip
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: categoryColor,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      record.category,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Type
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  record.recordType,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Description
              Text(
                record.description,
                style: TextStyle(
                  color: Colors.grey[700],
                  fontSize: 14,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

              // Vitals Data Display
              if (record.category == RecordCategory.vitals &&
                  record.data.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      if (record.data['systolic'] != null) ...[
                        const Icon(Icons.favorite, color: Colors.red, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          '${record.data['systolic']}/${record.data['diastolic']} ${record.data['unit']}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ] else if (record.data['value'] != null) ...[
                        const Icon(Icons.analytics,
                            color: Colors.blue, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          '${record.data['value']} ${record.data['unit']}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ],
                  ),
                ),
              ],

              // Doctor/Hospital Info
              if (record.doctorName != null || record.hospital != null) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (record.doctorName != null) ...[
                      const Icon(Icons.person, size: 16, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        record.doctorName!,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                    if (record.doctorName != null && record.hospital != null)
                      Text(
                        ' • ',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    if (record.hospital != null) ...[
                      const Icon(Icons.local_hospital,
                          size: 16, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        record.hospital!,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ],

              // Added By Info
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getRoleColor(record.addedByRole)
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: _getRoleColor(record.addedByRole),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getRoleIcon(record.addedByRole),
                          size: 12,
                          color: _getRoleColor(record.addedByRole),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Added by ${record.addedByRole}',
                          style: TextStyle(
                            fontSize: 10,
                            color: _getRoleColor(record.addedByRole),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // Action Buttons
                  if (_userRole == 'patient' || _userRole == 'staff')
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deleteRecord(record.id),
                      tooltip: 'Delete',
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'doctor':
        return Colors.blue;
      case 'staff':
        return Colors.purple;
      default:
        return Colors.green;
    }
  }

  IconData _getRoleIcon(String role) {
    switch (role) {
      case 'doctor':
        return Icons.medical_services;
      case 'staff':
        return Icons.badge;
      default:
        return Icons.person;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.patientName != null
            ? '${widget.patientName}\'s Records'
            : 'Health Records'),
        backgroundColor: const Color(0xFF10B981),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                builder: (context) => _buildFilterSheet(),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search records…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(() => _searchQuery = ''),
                      )
                    : null,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),

          // Category Filter Chips
          Container(
            height: 56,
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildCategoryChip('All'),
                ...RecordCategory.all
                    .map((category) => _buildCategoryChip(category)),
              ],
            ),
          ),

          // Records List
          Expanded(
            child: StreamBuilder<List<HealthRecord>>(
              stream: _getRecordsStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error, size: 64, color: Colors.red),
                        const SizedBox(height: 16),
                        Text('Error: ${snapshot.error}'),
                      ],
                    ),
                  );
                }

                final records = _applySearch(snapshot.data ?? []);

                if (records.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.folder_open,
                            size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isNotEmpty
                              ? 'No records match your search'
                              : 'No health records found',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (_searchQuery.isEmpty)
                          Text(
                            'Tap + to add your first record',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[500],
                            ),
                          ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: records.length,
                  itemBuilder: (context, index) {
                    return _buildRecordCard(records[index]);
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddHealthRecordScreen(
                patientId: widget.patientId,
                patientName: widget.patientName,
              ),
            ),
          );
        },
        backgroundColor: const Color(0xFF10B981),
        icon: const Icon(Icons.add),
        label: const Text('Add Record'),
      ),
    );
  }

  Widget _buildCategoryChip(String category) {
    final isSelected = _selectedCategory == category;
    final color = category == 'All' ? Colors.grey : _getCategoryColor(category);

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(category),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            _selectedCategory = category;
          });
        },
        backgroundColor: Colors.grey[200],
        selectedColor: color.withValues(alpha: 0.2),
        checkmarkColor: color,
        labelStyle: TextStyle(
          color: isSelected ? color : Colors.grey[700],
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  Widget _buildFilterSheet() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Filter by Category',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildCategoryChip('All'),
              ...RecordCategory.all
                  .map((category) => _buildCategoryChip(category)),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

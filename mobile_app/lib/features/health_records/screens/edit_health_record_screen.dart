import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/health_record.dart';
import '../services/health_record_service.dart';
import 'attachment_viewer_screen.dart';

class EditHealthRecordScreen extends StatefulWidget {
  final HealthRecord record;

  const EditHealthRecordScreen({super.key, required this.record});

  @override
  State<EditHealthRecordScreen> createState() => _EditHealthRecordScreenState();
}

class _EditHealthRecordScreenState extends State<EditHealthRecordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _healthRecordService = HealthRecordService();

  // Form controllers
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _doctorNameController;
  late TextEditingController _hospitalController;
  late TextEditingController _notesController;

  // Form state
  late String _selectedCategory;
  late String _selectedType;
  late DateTime _selectedDate;
  bool _isLoading = false;

  // Vitals-specific fields
  final _systolicController = TextEditingController();
  final _diastolicController = TextEditingController();
  final _heartRateController = TextEditingController();
  final _temperatureController = TextEditingController();
  final _weightController = TextEditingController();
  final _heightController = TextEditingController();
  final _bloodSugarController = TextEditingController();
  final _oxygenController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _initializeControllers() {
    _titleController = TextEditingController(text: widget.record.title);
    _descriptionController =
        TextEditingController(text: widget.record.description);
    _doctorNameController =
        TextEditingController(text: widget.record.doctorName ?? '');
    _hospitalController =
        TextEditingController(text: widget.record.hospital ?? '');
    _notesController = TextEditingController(text: widget.record.notes ?? '');

    _selectedCategory = widget.record.category;
    _selectedType = widget.record.recordType;
    _selectedDate = widget.record.date;

    // Load vitals data
    if (widget.record.data.isNotEmpty) {
      if (widget.record.data['systolic'] != null) {
        _systolicController.text = widget.record.data['systolic'].toString();
        _diastolicController.text = widget.record.data['diastolic'].toString();
      } else if (widget.record.data['value'] != null) {
        switch (_selectedType) {
          case VitalsType.heartRate:
            _heartRateController.text = widget.record.data['value'].toString();
            break;
          case VitalsType.temperature:
            _temperatureController.text =
                widget.record.data['value'].toString();
            break;
          case VitalsType.weight:
            _weightController.text = widget.record.data['value'].toString();
            break;
          case VitalsType.height:
            _heightController.text = widget.record.data['value'].toString();
            break;
          case VitalsType.bloodSugar:
            _bloodSugarController.text = widget.record.data['value'].toString();
            break;
          case VitalsType.oxygenSaturation:
            _oxygenController.text = widget.record.data['value'].toString();
            break;
        }
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _doctorNameController.dispose();
    _hospitalController.dispose();
    _notesController.dispose();
    _systolicController.dispose();
    _diastolicController.dispose();
    _heartRateController.dispose();
    _temperatureController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    _bloodSugarController.dispose();
    _oxygenController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Map<String, dynamic> _getRecordData() {
    final Map<String, dynamic> data = {};

    if (_selectedCategory == RecordCategory.vitals) {
      switch (_selectedType) {
        case VitalsType.bloodPressure:
          data['systolic'] = _systolicController.text;
          data['diastolic'] = _diastolicController.text;
          data['unit'] = 'mmHg';
          break;
        case VitalsType.heartRate:
          data['value'] = _heartRateController.text;
          data['unit'] = 'bpm';
          break;
        case VitalsType.temperature:
          data['value'] = _temperatureController.text;
          data['unit'] = '°F';
          break;
        case VitalsType.weight:
          data['value'] = _weightController.text;
          data['unit'] = 'kg';
          break;
        case VitalsType.height:
          data['value'] = _heightController.text;
          data['unit'] = 'cm';
          break;
        case VitalsType.bloodSugar:
          data['value'] = _bloodSugarController.text;
          data['unit'] = 'mg/dL';
          break;
        case VitalsType.oxygenSaturation:
          data['value'] = _oxygenController.text;
          data['unit'] = '%';
          break;
      }
    }

    return data;
  }

  Future<void> _updateRecord() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await _healthRecordService.updateHealthRecord(
        recordId: widget.record.id,
        title: _titleController.text,
        description: _descriptionController.text,
        category: _selectedCategory,
        recordType: _selectedType,
        date: _selectedDate,
        doctorName: _doctorNameController.text.isEmpty
            ? null
            : _doctorNameController.text,
        hospital:
            _hospitalController.text.isEmpty ? null : _hospitalController.text,
        notes: _notesController.text.isEmpty ? null : _notesController.text,
        data: _getRecordData(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Health record updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
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
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildVitalsFields() {
    switch (_selectedType) {
      case VitalsType.bloodPressure:
        return Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _systolicController,
                decoration: const InputDecoration(
                  labelText: 'Systolic',
                  suffixText: 'mmHg',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: _diastolicController,
                decoration: const InputDecoration(
                  labelText: 'Diastolic',
                  suffixText: 'mmHg',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        );
      case VitalsType.heartRate:
        return TextFormField(
          controller: _heartRateController,
          decoration: const InputDecoration(
            labelText: 'Heart Rate',
            suffixText: 'bpm',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
        );
      case VitalsType.temperature:
        return TextFormField(
          controller: _temperatureController,
          decoration: const InputDecoration(
            labelText: 'Temperature',
            suffixText: '°F',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
        );
      case VitalsType.weight:
        return TextFormField(
          controller: _weightController,
          decoration: const InputDecoration(
            labelText: 'Weight',
            suffixText: 'kg',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
        );
      case VitalsType.height:
        return TextFormField(
          controller: _heightController,
          decoration: const InputDecoration(
            labelText: 'Height',
            suffixText: 'cm',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
        );
      case VitalsType.bloodSugar:
        return TextFormField(
          controller: _bloodSugarController,
          decoration: const InputDecoration(
            labelText: 'Blood Sugar',
            suffixText: 'mg/dL',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
        );
      case VitalsType.oxygenSaturation:
        return TextFormField(
          controller: _oxygenController,
          decoration: const InputDecoration(
            labelText: 'Oxygen Saturation',
            suffixText: '%',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
        );
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Health Record'),
        backgroundColor: const Color(0xFF10B981),
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Title
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.title),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Title is required';
                }
                if (value.length < 3) {
                  return 'Title must be at least 3 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Date
            InkWell(
              onTap: _selectDate,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Date',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.calendar_today),
                ),
                child: Text(
                  DateFormat('MMM dd, yyyy').format(_selectedDate),
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Vitals fields
            if (_selectedCategory == RecordCategory.vitals) ...[
              _buildVitalsFields(),
              const SizedBox(height: 16),
            ],

            // Description
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.description),
              ),
              maxLines: 3,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Description is required';
                }
                if (value.length < 10) {
                  return 'Description must be at least 10 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Doctor Name
            TextFormField(
              controller: _doctorNameController,
              decoration: const InputDecoration(
                labelText: 'Doctor Name (Optional)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 16),

            // Hospital
            TextFormField(
              controller: _hospitalController,
              decoration: const InputDecoration(
                labelText: 'Hospital/Clinic (Optional)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.local_hospital),
              ),
            ),
            const SizedBox(height: 16),

            // Notes
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Additional Notes (Optional)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.note),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),

            // Attachments Display
            if (widget.record.attachments.isNotEmpty) ...[
              const Text(
                'Attachments',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: widget.record.attachments.map((url) {
                  final isImage = url.toLowerCase().contains('.jpg') ||
                      url.toLowerCase().contains('.jpeg') ||
                      url.toLowerCase().contains('.png') ||
                      url.toLowerCase().contains('.webp');

                  if (isImage) {
                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AttachmentViewerScreen(url: url),
                          ),
                        );
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          url,
                          width: 120,
                          height: 120,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              width: 120,
                              height: 120,
                              color: Colors.grey[200],
                              child: const Center(child: CircularProgressIndicator()),
                            );
                          },
                          errorBuilder: (ctx, err, stack) => Container(
                            width: 120,
                            height: 120,
                            color: Colors.grey[300],
                            child: const Icon(Icons.broken_image, color: Colors.grey),
                          ),
                        ),
                      ),
                    );
                  }

                  return ActionChip(
                    avatar: const Icon(Icons.open_in_new, size: 16),
                    label: const Text('View Document'),
                    onPressed: () async {
                      final uri = Uri.parse(url);
                      try {
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Could not open file')),
                          );
                        }
                      }
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
            ],

            // Update Button
            ElevatedButton(
              onPressed: _isLoading ? null : _updateRecord,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      'Update Record',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

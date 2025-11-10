import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/reminder.dart';
import '../services/firebase_service.dart';
import 'page_tutorials.dart';

class AddReminderModal extends StatefulWidget {
  final DateTime selectedDate;
  final VoidCallback onReminderAdded;
  final Reminder? reminder; // For editing existing reminders

  const AddReminderModal({
    super.key,
    required this.selectedDate,
    required this.onReminderAdded,
    this.reminder,
  });

  @override
  State<AddReminderModal> createState() => _AddReminderModalState();
}

class _AddReminderModalState extends State<AddReminderModal> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _maxOccurrencesController = TextEditingController();
  
  ReminderType _selectedType = ReminderType.generalNote;
  RecurrenceType _selectedRecurrence = RecurrenceType.single;
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  
  // Duration controls for recurring reminders
  DateTime? _endDate;
  String _durationType = 'endDate'; // 'endDate' or 'occurrences'

  bool get _isEditing => widget.reminder != null;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.selectedDate;
    
    // If editing, populate fields with existing reminder data
    if (_isEditing) {
      final reminder = widget.reminder!;
      _titleController.text = reminder.title;
      _descriptionController.text = reminder.description;
      _selectedType = reminder.type;
      _selectedRecurrence = reminder.recurrence;
      _selectedDate = reminder.date;
      
      // Set duration settings for recurring reminders
      if (reminder.recurrence != RecurrenceType.single) {
        if (reminder.endDate != null) {
          _durationType = 'endDate';
          _endDate = reminder.endDate;
        } else if (reminder.maxOccurrences != null) {
          _durationType = 'occurrences';
          _maxOccurrencesController.text = reminder.maxOccurrences.toString();
        }
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _maxOccurrencesController.dispose();
    super.dispose();
  }

  Widget _buildReminderTypeCard(ReminderType type) {
    final isSelected = _selectedType == type;
    final typeInfo = _getReminderTypeInfo(type);
    final theme = Theme.of(context);
    
    return LayoutBuilder(
      builder: (context, constraints) {
        // Responsive sizing for reminder type cards matching transaction cards
        final cardWidth = constraints.maxWidth;
        final isExtremelyCompactCard = cardWidth < 100;
        final isCompactCard = cardWidth < 120;
        final iconSize = isExtremelyCompactCard ? 18.0 : isCompactCard ? 20.0 : 24.0;
        final fontSize = isExtremelyCompactCard ? 9.0 : isCompactCard ? 10.0 : 11.0;
        final verticalPadding = isExtremelyCompactCard ? 6.0 : isCompactCard ? 8.0 : 12.0;
        final horizontalPadding = isExtremelyCompactCard ? 1.0 : isCompactCard ? 2.0 : 4.0;

        return Card(
          elevation: isSelected ? 4 : 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: isSelected ? theme.colorScheme.primary : theme.dividerColor,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: InkWell(
            onTap: () => setState(() => _selectedType = type),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: EdgeInsets.symmetric(vertical: verticalPadding, horizontal: horizontalPadding),
              decoration: BoxDecoration(
                color: isSelected ? theme.colorScheme.primary.withValues(alpha: 0.1) : theme.cardTheme.color,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    typeInfo.icon,
                    style: TextStyle(fontSize: iconSize),
                  ),
                  SizedBox(height: isExtremelyCompactCard ? 1 : isCompactCard ? 2 : 4),
                  Text(
                    typeInfo.label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                      fontSize: fontSize,
                    ),
                    maxLines: isExtremelyCompactCard ? 1 : isCompactCard ? 2 : 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  ReminderTypeInfo _getReminderTypeInfo(ReminderType type) {
    switch (type) {
      case ReminderType.saveForToday:
        return const ReminderTypeInfo(
          icon: '💰',
          label: 'SAVE FOR TODAY',
        );
      case ReminderType.billPayment:
        return const ReminderTypeInfo(
          icon: '💡',
          label: 'BILL PAYMENT',
        );
      case ReminderType.debtPayment:
        return const ReminderTypeInfo(
          icon: '💳',
          label: 'DEBT PAYMENT',
        );
      case ReminderType.generalNote:
        return const ReminderTypeInfo(
          icon: '📝',
          label: 'GENERAL NOTE',
        );
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: Theme.of(context).colorScheme.primary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _saveReminder() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Validate duration settings for recurring reminders
    if (_selectedRecurrence != RecurrenceType.single) {
      if (_durationType == 'endDate' && _endDate == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select an end date for recurring reminders'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      if (_durationType == 'occurrences') {
        final number = int.tryParse(_maxOccurrencesController.text);
        if (number == null || number <= 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please enter a valid number of occurrences'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
      }
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final reminder = Reminder(
        id: _isEditing ? widget.reminder!.id : DateTime.now().millisecondsSinceEpoch.toString(),
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        date: _selectedDate,
        type: _selectedType,
        recurrence: _selectedRecurrence,
        createdAt: _isEditing ? widget.reminder!.createdAt : DateTime.now(),
        isCompleted: _isEditing ? widget.reminder!.isCompleted : false,
        completedAt: _isEditing ? widget.reminder!.completedAt : null,
        endDate: _selectedRecurrence != RecurrenceType.single && _durationType == 'endDate' ? _endDate : null,
        maxOccurrences: _selectedRecurrence != RecurrenceType.single && _durationType == 'occurrences' ? int.tryParse(_maxOccurrencesController.text) : null,
      );
      
      if (_isEditing) {
        await FirebaseService.updateReminder(reminder);
      } else {
        await FirebaseService.saveReminder(reminder);
      }

      if (mounted) {
        Navigator.of(context).pop();
        widget.onReminderAdded();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditing ? 'Reminder updated successfully!' : 'Reminder added successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error ${_isEditing ? 'updating' : 'adding'} reminder: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: LayoutBuilder(
          builder: (context, constraints) {
            final isNarrowScreen = MediaQuery.of(context).size.width < 600;
            final titleFontSize = isNarrowScreen ? 20.0 : 22.0; // Section Heading range (20–24sp)
            
            return Text(
              _isEditing ? 'Edit Reminder' : 'Add Reminder',
              style: TextStyle(
                color: theme.appBarTheme.foregroundColor, 
                fontWeight: FontWeight.bold,
                fontSize: titleFontSize,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            );
          },
        ),
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: 0,
        automaticallyImplyLeading: true,
        actions: [
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrowScreen = MediaQuery.of(context).size.width < 600;
              final actionTextFontSize = isNarrowScreen ? 14.0 : 16.0; // Body Text range
              
              return TextButton(
                onPressed: _isLoading ? null : _saveReminder,
                child: _isLoading
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(theme.appBarTheme.foregroundColor!),
                        ),
                      )
                    : Text(
                        _isEditing ? 'Update' : 'Save',
                        style: TextStyle(
                          color: theme.appBarTheme.foregroundColor,
                          fontSize: actionTextFontSize,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              );
            },
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Determine responsive layout parameters
          final isNarrowScreen = constraints.maxWidth < 600;
          final isVeryNarrowScreen = constraints.maxWidth < 400;
          final isExtremelyNarrowScreen = constraints.maxWidth < 320;
          final horizontalPadding = isExtremelyNarrowScreen ? 12.0 : isNarrowScreen ? 16.0 : 24.0;
          final gridCrossAxisCount = isExtremelyNarrowScreen ? 2 : isVeryNarrowScreen ? 2 : 4; // 4 types fit better in 2x2 grid
          final gridChildAspectRatio = isExtremelyNarrowScreen ? 1.4 : isVeryNarrowScreen ? 1.2 : 1.0;
          
          // Typography standards
          final sectionHeaderFontSize = isNarrowScreen ? 14.0 : 16.0; // Body Text range (14–16sp)
          final inputLabelFontSize = isNarrowScreen ? 14.0 : 16.0; // Body Text range
          final spacingBetweenSections = isNarrowScreen ? 16.0 : 24.0;
          final sectionSpacing = isNarrowScreen ? 8.0 : 12.0;
          
          return Form(
            key: _formKey,
            child: SingleChildScrollView(
              physics: PageTutorials.isRunning
                  ? const NeverScrollableScrollPhysics()
                  : const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.all(horizontalPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Reminder Type Selection
                  Text(
                    'Reminder Type',
                    style: TextStyle(
                      fontSize: sectionHeaderFontSize,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: sectionSpacing),
                  GridView.count(
                    crossAxisCount: gridCrossAxisCount,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: gridChildAspectRatio,
                    children: ReminderType.values
                        .map((type) => _buildReminderTypeCard(type))
                        .toList(),
                  ),
                  SizedBox(height: spacingBetweenSections),

                  // Title Input
                  Text(
                    'Title',
                    style: TextStyle(
                      fontSize: inputLabelFontSize,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: sectionSpacing),
                  TextFormField(
                    controller: _titleController,
                    decoration: InputDecoration(
                      hintText: 'Enter reminder title...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
                      ),
                    ),
                    style: TextStyle(
                      fontSize: isNarrowScreen ? 14.0 : 16.0, // Body Text range
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a title';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: spacingBetweenSections),

                  // Description Input
                  Text(
                    'Description/Note',
                    style: TextStyle(
                      fontSize: inputLabelFontSize,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: sectionSpacing),
                  TextFormField(
                    controller: _descriptionController,
                    decoration: InputDecoration(
                      hintText: 'Enter description or note...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
                      ),
                    ),
                    style: TextStyle(
                      fontSize: isNarrowScreen ? 14.0 : 16.0, // Body Text range
                    ),
                    maxLines: 3,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a description or note';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: spacingBetweenSections),

                  // Recurrence Selection
                  Text(
                    'Recurrence',
                    style: TextStyle(
                      fontSize: inputLabelFontSize,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: sectionSpacing),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                      border: Border.all(color: theme.dividerColor),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<RecurrenceType>(
                        value: _selectedRecurrence,
                        isExpanded: true,
                        icon: Icon(Icons.arrow_drop_down, color: theme.colorScheme.primary),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _selectedRecurrence = value;
                            });
                          }
                        },
                        items: RecurrenceType.values.map((recurrence) {
                          String displayName;
                          switch (recurrence) {
                            case RecurrenceType.single:
                              displayName = 'One-time';
                              break;
                            case RecurrenceType.daily:
                              displayName = 'Daily';
                              break;
                            case RecurrenceType.weekly:
                              displayName = 'Weekly';
                              break;
                            case RecurrenceType.monthly:
                              displayName = 'Monthly';
                              break;
                          }
                          return DropdownMenuItem<RecurrenceType>(
                            value: recurrence,
                            child: Text(
                              displayName,
                              style: TextStyle(
                                fontSize: isNarrowScreen ? 14.0 : 16.0, // Body Text range
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  SizedBox(height: spacingBetweenSections),

                  // Duration Controls for Recurring Reminders
                  if (_selectedRecurrence != RecurrenceType.single) ...[
                    Text(
                      'Duration',
                      style: TextStyle(
                        fontSize: inputLabelFontSize,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: sectionSpacing),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: theme.dividerColor),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          RadioListTile<String>(
                            title: Text(
                              'Until end date',
                              style: TextStyle(
                                fontSize: isNarrowScreen ? 14.0 : 16.0, // Body Text range
                              ),
                            ),
                            value: 'endDate',
                            groupValue: _durationType,
                            onChanged: (value) {
                              setState(() {
                                _durationType = value!;
                              });
                            },
                          ),
                          if (_durationType == 'endDate')
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              child: InkWell(
                                onTap: () async {
                                  final DateTime? picked = await showDatePicker(
                                    context: context,
                                    initialDate: _endDate ?? _selectedDate.add(const Duration(days: 30)),
                                    firstDate: _selectedDate.add(const Duration(days: 1)),
                                    lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                                  );
                                  if (picked != null) {
                                    setState(() {
                                      _endDate = picked;
                                    });
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).cardTheme.color,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Theme.of(context).dividerColor),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.date_range, color: Theme.of(context).colorScheme.primary, size: 20),
                                      const SizedBox(width: 8),
                                      Text(
                                        _endDate != null
                                            ? DateFormat('MMM dd, yyyy').format(_endDate!)
                                            : 'Select end date',
                                        style: TextStyle(
                                          fontSize: isNarrowScreen ? 14.0 : 16.0, // Body Text range
                                          color: _endDate != null
                                              ? Theme.of(context).colorScheme.onSurface
                                              : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          RadioListTile<String>(
                            title: Text(
                              'Number of occurrences',
                              style: TextStyle(
                                fontSize: isNarrowScreen ? 14.0 : 16.0, // Body Text range
                              ),
                            ),
                            value: 'occurrences',
                            groupValue: _durationType,
                            onChanged: (value) {
                              setState(() {
                                _durationType = value!;
                              });
                            },
                          ),
                          if (_durationType == 'occurrences')
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              child: TextFormField(
                                controller: _maxOccurrencesController,
                                decoration: InputDecoration(
                                  hintText: 'Enter number of times',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                                style: TextStyle(
                                  fontSize: isNarrowScreen ? 14.0 : 16.0, // Body Text range
                                ),
                                keyboardType: TextInputType.number,
                                validator: (value) {
                                  if (_durationType == 'occurrences') {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Please enter number of occurrences';
                                    }
                                    final number = int.tryParse(value);
                                    if (number == null || number <= 0) {
                                      return 'Please enter a valid positive number';
                                    }
                                  }
                                  return null;
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                    SizedBox(height: spacingBetweenSections),
                  ],

                  // Date Selection
                  Text(
                    'Start Date',
                    style: TextStyle(
                      fontSize: inputLabelFontSize,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: sectionSpacing),
                  InkWell(
                    onTap: _selectDate,
                    child: Container(
                      padding: EdgeInsets.all(isNarrowScreen ? 12 : 16),
                      decoration: BoxDecoration(
                        border: Border.all(color: theme.dividerColor),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today, color: theme.colorScheme.primary),
                          SizedBox(width: isNarrowScreen ? 8 : 12),
                          Expanded(
                            child: Text(
                              DateFormat('MMM dd, yyyy').format(_selectedDate),
                              style: TextStyle(
                                fontSize: isNarrowScreen ? 14.0 : 16.0, // Body Text range
                                color: theme.colorScheme.onSurface
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_ios, 
                            size: isNarrowScreen ? 14 : 16, 
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6)
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: spacingBetweenSections + 8.0), // Extra space before button

                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _saveReminder,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: theme.colorScheme.onPrimary,
                        padding: EdgeInsets.symmetric(vertical: isNarrowScreen ? 14 : 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.onPrimary),
                              ),
                            )
                          : Text(
                              _isEditing ? 'Update Reminder' : 'Add Reminder',
                              style: TextStyle(
                                fontSize: isNarrowScreen ? 16.0 : 18.0, // Subheading range for important buttons
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                  
                  // Add bottom padding to prevent overflow
                  SizedBox(height: isNarrowScreen ? 20.0 : 24.0),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class ReminderTypeInfo {
  final String icon;
  final String label;

  const ReminderTypeInfo({
    required this.icon,
    required this.label,
  });
}
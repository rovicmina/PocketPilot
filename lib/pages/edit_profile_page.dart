import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../models/user.dart' as user_models;
import '../models/transaction.dart';
import '../services/firebase_service.dart';
import '../services/user_notifier.dart';
import '../services/theme_service.dart';
import '../services/profile_sync_service.dart';
import '../services/transaction_service.dart';
import '../widgets/form_widgets.dart';
import '../utils/form_state_tracker.dart';
import '../widgets/unsaved_changes_dialog.dart';

class EditProfilePage extends StatefulWidget {
  final user_models.User user;

  const EditProfilePage({super.key, required this.user});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> with FormStateTracker {
  final _formKey = GlobalKey<FormState>();
  late final TrackedTextEditingController _nameController;
  late final TrackedTextEditingController _emailController;
  late final TrackedTextEditingController _cityController;
  late final TrackedTextEditingController _provinceController;
  late final TrackedTextEditingController _otherIncomeController;
  late final TrackedTextEditingController _monthlyNetController;
  late final TrackedTextEditingController _monthlyNetDecimalController;
  late final TrackedTextEditingController _emergencyFundController;
  late final TrackedTextEditingController _emergencyFundDecimalController;

  DateTime? _birthDate;
  user_models.Gender? _selectedGender;
  user_models.Profession? _selectedProfession;
  user_models.IncomeFrequency? _selectedIncomeFrequency;
  bool? _isWorkingStudent;
  bool? _isBusinessOwner;
  user_models.CivilStatus? _civilStatus;
  bool? _hasKids;
  int? _numberOfChildren;
  user_models.HouseholdSituation? _householdSituation;
  List<user_models.DebtStatus> _debtStatuses = [];
  List<user_models.SavingsInvestments> _savingsInvestments = [];
  List<user_models.IncomeSource> _incomeSources = [];

  bool _isLoading = false;
  
  // Image handling
  File? _selectedImage;
  final ImagePicker _imagePicker = ImagePicker();
  
  // User notifier for profile updates
  final UserNotifier _userNotifier = UserNotifier();

  @override
  void initState() {
    super.initState();

    // Initialize tracked controllers
    _nameController = createTrackedController('name', this, initialText: widget.user.name);
    _emailController = createTrackedController('email', this, initialText: widget.user.email);
    _cityController = createTrackedController('city', this, initialText: widget.user.city ?? '');
    _provinceController = createTrackedController('province', this, initialText: widget.user.province ?? '');
    _otherIncomeController = createTrackedController('otherIncome', this, initialText: widget.user.otherIncomeSource ?? '');
    _monthlyNetController = createTrackedController('monthlyNet', this, initialText: widget.user.monthlyNet != null ? widget.user.monthlyNet!.toStringAsFixed(0) : '');
    _monthlyNetDecimalController = createTrackedController('monthlyNetDecimal', this, initialText: widget.user.monthlyNet != null ? (widget.user.monthlyNet! % 1 * 100).toInt().toString().padLeft(2, '0') : '');
    _emergencyFundController = createTrackedController('emergencyFund', this, initialText: widget.user.emergencyFundAmount != null ? widget.user.emergencyFundAmount!.toStringAsFixed(0) : '');
    _emergencyFundDecimalController = createTrackedController('emergencyFundDecimal', this, initialText: widget.user.emergencyFundAmount != null ? (widget.user.emergencyFundAmount! % 1 * 100).toInt().toString().padLeft(2, '0') : '');

    _initializeFieldsAsync();
  }

  Future<void> _initializeFieldsAsync() async {
    await _initializeFields();
    if (mounted) {
      setState(() {}); // Trigger rebuild after async initialization
    }
  }

  Future<void> _initializeFields() async {

    _selectedGender = widget.user.gender;
    _selectedProfession = widget.user.profession;
    _selectedIncomeFrequency = widget.user.incomeFrequency;
    _isWorkingStudent = widget.user.isWorkingStudent;
    _isBusinessOwner = widget.user.isBusinessOwner;
    _civilStatus = widget.user.civilStatus;
    _hasKids = widget.user.hasKids;
    _numberOfChildren = widget.user.numberOfChildren;
    _householdSituation = widget.user.householdSituation;
    _debtStatuses = List.from(widget.user.debtStatuses);
    _savingsInvestments = List.from(widget.user.savingsInvestments);
    _incomeSources = List.from(widget.user.incomeSources);
    
    // Initialize birth date if available
    if (widget.user.birthYear != null && 
        widget.user.birthMonth != null && 
        widget.user.birthDay != null) {
      _birthDate = DateTime(
        widget.user.birthYear!,
        widget.user.birthMonth!,
        widget.user.birthDay!,
      );
    }
    
    // Initialize profile image if available
    if (widget.user.profileImagePath != null && widget.user.profileImagePath!.isNotEmpty) {
      final imageFile = File(widget.user.profileImagePath!);
      if (imageFile.existsSync()) {
        _selectedImage = imageFile;
      } else {
        // Image file doesn't exist, clear from user profile
        debugPrint('Profile image file not found: ${widget.user.profileImagePath}');
      }
    }

    // Check for emergency fund transactions and auto-select if necessary
    final emergencyFundTotal = await TransactionService.getTotalByType(TransactionType.emergencyFund);
    if (emergencyFundTotal > 0) {
      // If emergency fund transactions exist, ensure emergency fund is selected
      if (!_savingsInvestments.contains(user_models.SavingsInvestments.emergencyFund)) {
        _savingsInvestments.add(user_models.SavingsInvestments.emergencyFund);
      }
      // If noSavings was selected, remove it since emergency fund is now selected
      _savingsInvestments.remove(user_models.SavingsInvestments.noSavings);
      // Set the emergency fund amount to the transaction total only if not already set
      if (widget.user.emergencyFundAmount == null || widget.user.emergencyFundAmount == 0) {
        _emergencyFundController.text = emergencyFundTotal.toString();
      }
    }

    // Initialize form tracking with current values
    initializeFormTracking({
      'name': widget.user.name,
      'email': widget.user.email,
      'city': widget.user.city ?? '',
      'province': widget.user.province ?? '',
      'otherIncome': widget.user.otherIncomeSource ?? '',
      'monthlyNet': widget.user.monthlyNet != null ? widget.user.monthlyNet!.toStringAsFixed(0) : '',
      'monthlyNetDecimal': widget.user.monthlyNet != null ? (widget.user.monthlyNet! % 1 * 100).toInt().toString().padLeft(2, '0') : '',
      'emergencyFund': widget.user.emergencyFundAmount != null ? widget.user.emergencyFundAmount!.toStringAsFixed(0) : '',
      'emergencyFundDecimal': widget.user.emergencyFundAmount != null ? (widget.user.emergencyFundAmount! % 1 * 100).toInt().toString().padLeft(2, '0') : '',
      'birthDate': _birthDate,
      'gender': _selectedGender,
      'profession': _selectedProfession,
      'incomeFrequency': _selectedIncomeFrequency,
      'isWorkingStudent': _isWorkingStudent,
      'isBusinessOwner': _isBusinessOwner,
      'civilStatus': _civilStatus,
      'hasKids': _hasKids,
      'householdSituation': _householdSituation,
      'debtStatuses': _debtStatuses,
      'savingsInvestments': _savingsInvestments,
      'incomeSources': _incomeSources,
      'selectedImage': _selectedImage?.path,
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _cityController.dispose();
    _provinceController.dispose();
    _otherIncomeController.dispose();
    _monthlyNetController.dispose();
    _monthlyNetDecimalController.dispose();
    _emergencyFundController.dispose();
    _emergencyFundDecimalController.dispose();
    super.dispose();
  }


  Future<void> _pickImage() async {
    try {
      // Show options for camera or gallery
      final ImageSource? source = await showModalBottomSheet<ImageSource>(
        context: context,
        builder: (BuildContext context) {
          return SafeArea(
            child: Wrap(
              children: [
                ListTile(
                  leading: const Icon(Icons.photo_library),
                  title: Text('Gallery'),
                  onTap: () => Navigator.of(context).pop(ImageSource.gallery),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_camera),
                  title: Text('Camera'),
                  onTap: () => Navigator.of(context).pop(ImageSource.camera),
                ),
                ListTile(
                  leading: const Icon(Icons.cancel),
                  title: Text('Cancel'),
                  onTap: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          );
        },
      );

      if (source != null) {
        final XFile? pickedFile = await _imagePicker.pickImage(
          source: source,
          maxWidth: 512,
          maxHeight: 512,
          imageQuality: 85,
        );

        if (pickedFile != null) {
          // Show loading indicator
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 16),
                    Text('Saving profile picture...'),
                  ],
                ),
                duration: Duration(seconds: 3),
              ),
            );
          }

          // Save to local storage (FREE)
          final localPath = await ProfileSyncService.uploadProfilePicture(
            File(pickedFile.path),
            widget.user.id,
          );

          if (localPath != null) {
            setState(() {
              _selectedImage = File(localPath);
            });
            updateFormField('selectedImage', localPath);

            // Immediately notify profile updated since image changed
            _userNotifier.notifyProfileUpdated();
            
            if (mounted) {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Profile picture saved successfully!'),
                  backgroundColor: Colors.green,
                  duration: Duration(seconds: 2),
                ),
              );
            }
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Failed to save profile picture. Please try again.'),
                  backgroundColor: Colors.red,
                  duration: Duration(seconds: 3),
                ),
              );
            }
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error selecting image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Profile pictures are now stored locally only (FREE)



  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setSubmitting(true);
    setState(() {
      _isLoading = true;
    });

    try {
      final updatedUser = widget.user.copyWith(
        name: _nameController.text.trim(),
        city: _cityController.text.trim().isEmpty ? null : _cityController.text.trim(),
        province: _provinceController.text.trim().isEmpty ? null : _provinceController.text.trim(),
        otherIncomeSource: _otherIncomeController.text.trim().isEmpty ? null : _otherIncomeController.text.trim(),
        monthlyNet: _monthlyNetController.text.trim().isEmpty ? null : double.tryParse('${_monthlyNetController.text.trim()}.${_monthlyNetDecimalController.text.trim().padRight(2, '0').substring(0, 2)}'),
        emergencyFundAmount: _emergencyFundController.text.trim().isEmpty ? null : double.tryParse('${_emergencyFundController.text.trim()}.${_emergencyFundDecimalController.text.trim().padRight(2, '0').substring(0, 2)}'),
        gender: _selectedGender,
        profession: _selectedProfession,
        incomeFrequency: _selectedIncomeFrequency,
        isWorkingStudent: _isWorkingStudent,
        isBusinessOwner: _isBusinessOwner,
        civilStatus: _civilStatus,
        hasKids: _hasKids,
        numberOfChildren: _numberOfChildren,
        householdSituation: _householdSituation,
        debtStatuses: _debtStatuses,
        savingsInvestments: _savingsInvestments,
        incomeSources: _incomeSources,
        birthYear: _birthDate?.year,
        birthMonth: _birthDate?.month,
        birthDay: _birthDate?.day,
        // Include profile image path if it has been updated
        profileImagePath: _selectedImage?.path ?? widget.user.profileImagePath,
      );

      await FirebaseService.saveUser(updatedUser);

      // Check if emergency fund or monthly net changed and notify listeners
      final oldEmergencyFund = widget.user.emergencyFundAmount ?? 0.0;
      final newEmergencyFund = updatedUser.emergencyFundAmount ?? 0.0;
      final oldMonthlyNet = widget.user.monthlyNet ?? 0.0;
      final newMonthlyNet = updatedUser.monthlyNet ?? 0.0;
      final oldProfileImagePath = widget.user.profileImagePath;
      final newProfileImagePath = updatedUser.profileImagePath;
      
      if (oldEmergencyFund != newEmergencyFund) {
        _userNotifier.notifyEmergencyFundUpdated();
      }
      if (oldMonthlyNet != newMonthlyNet) {
        _userNotifier.notifyMonthlyNetUpdated();
      }
      if (oldEmergencyFund != newEmergencyFund || oldMonthlyNet != newMonthlyNet || oldProfileImagePath != newProfileImagePath) {
        _userNotifier.notifyProfileUpdated();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Profile updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(true); // Return true to indicate success
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating profile: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeService = ThemeService();

    // Define helper methods at the beginning to avoid "referenced before declaration" errors
    Widget _buildSectionTitle(String title) {
      final theme = Theme.of(context);
      
      return LayoutBuilder(
        builder: (context, constraints) {
          final isNarrowScreen = constraints.maxWidth < 600;
          final fontSize = isNarrowScreen ? 18.0 : 20.0; // Section Heading range (20–24sp)
          
          return Text(
            title,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          );
        },
      );
    }

    Widget _buildTextField({
      required TextEditingController controller,
      required String label,
      required IconData icon,
      TextInputType? keyboardType,
      String? Function(String?)? validator,
      bool readOnly = false,
    }) {
      final theme = Theme.of(context);
      
      return TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        validator: validator,
        readOnly: readOnly,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: readOnly ? theme.disabledColor : theme.colorScheme.primary),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: theme.dividerColor),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: theme.dividerColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: readOnly ? theme.disabledColor : theme.colorScheme.primary, width: 2),
          ),
          filled: true,
          fillColor: readOnly ? theme.disabledColor.withValues(alpha: 0.1) : theme.cardTheme.color,
        ),
      );
    }

    Widget _buildDropdownField<T>({
      required String label,
      required IconData icon,
      required T? value,
      required List<T> items,
      required String Function(T) itemBuilder,
      required String Function(T) displayBuilder,
      required void Function(T?) onChanged,
    }) {
      final theme = Theme.of(context);
      
      return DropdownButtonFormField<T>(
        value: value,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: theme.colorScheme.primary),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: theme.dividerColor),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: theme.dividerColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
          ),
          filled: true,
          fillColor: theme.cardTheme.color,
        ),
        items: items.map((item) {
          return DropdownMenuItem<T>(
            value: item,
            child: Text(displayBuilder(item)),
          );
        }).toList(),
        onChanged: onChanged,
      );
    }

    Widget _buildBooleanField(
      String label,
      bool? value,
      void Function(bool?) onChanged,
    ) {
      final theme = Theme.of(context);

      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: theme.dividerColor),
          borderRadius: BorderRadius.circular(12),
          color: theme.cardTheme.color,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
            Row(
              children: [
                Radio<bool>(
                  value: true,
                  groupValue: value,
                  onChanged: onChanged,
                  activeColor: theme.colorScheme.primary,
                ),
                Text(
                  'Yes',
                  style: TextStyle(color: theme.colorScheme.onSurface),
                ),
                const SizedBox(width: 16),
                Radio<bool>(
                  value: false,
                  groupValue: value,
                  onChanged: onChanged,
                  activeColor: theme.colorScheme.primary,
                ),
                Text(
                  'No',
                  style: TextStyle(color: theme.colorScheme.onSurface),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return AnimatedBuilder(
      animation: themeService,
      builder: (context, child) {
        final theme = Theme.of(context);

        return FormPageWrapper(
          hasUnsavedChanges: hasUnsavedChanges,
          warningTitle: 'Discard Changes?',
          warningMessage: 'You have unsaved changes to your profile. Are you sure you want to go back without saving?',
          child: Scaffold(
            backgroundColor: theme.scaffoldBackgroundColor,
            appBar: AppBar(
              title: LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrowScreen = MediaQuery.of(context).size.width < 600;
                  final titleFontSize = isNarrowScreen ? 20.0 : 22.0; // Section Heading range (20–24sp)
                  
                  return Text(
                    'Edit Profile',
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
              iconTheme: IconThemeData(color: theme.appBarTheme.foregroundColor),
              actions: [
                TextButton(
                  onPressed: _isLoading ? null : _saveProfile,
                  child: Text(
                    'Save',
                    style: TextStyle(
                      color: theme.appBarTheme.foregroundColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
            body: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Profile Picture Section
                          Center(
                            child: Column(
                              children: [
                                GestureDetector(
                                  onTap: _pickImage,
                                  child: Stack(
                                    children: [
                                      CircleAvatar(
                                        radius: 60,
                                        backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                                        backgroundImage: _selectedImage != null && _selectedImage!.existsSync()
                                            ? FileImage(_selectedImage!)
                                            : null,
                                        child: _selectedImage == null || !_selectedImage!.existsSync()
                                            ? Icon(
                                                Icons.person,
                                                size: 60,
                                                color: theme.colorScheme.primary,
                                              )
                                            : null,
                                      ),
                                      Positioned(
                                        bottom: 0,
                                        right: 0,
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                            color: theme.colorScheme.primary,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            Icons.camera_alt,
                                            size: 20,
                                            color: theme.colorScheme.onPrimary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextButton.icon(
                                  onPressed: _pickImage,
                                  icon: Icon(Icons.camera_alt, color: theme.colorScheme.primary),
                                  label: Text(
                                    'Change Photo',
                                    style: TextStyle(color: theme.colorScheme.primary),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 32),
                          
                          // Name Field
                          _buildTextField(
                            controller: _nameController,
                            label: 'Full Name',
                            icon: Icons.person_outline,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Name is required';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 32),

                    // Address Information Section
                    _buildSectionTitle('Address Information'),
                    const SizedBox(height: 16),

                    _buildTextField(
                      controller: _cityController,
                      label: 'City',
                      icon: Icons.location_city,
                      validator: (value) {
                        // City is optional, so no validation required
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    _buildTextField(
                      controller: _provinceController,
                      label: 'Province',
                      icon: Icons.map,
                      validator: (value) {
                        // Province is optional, so no validation required
                        return null;
                      },
                    ),
                    const SizedBox(height: 32),

                    // Professional Information Section
                    _buildSectionTitle('Professional Information'),
                    const SizedBox(height: 16),

                    _buildDropdownField<user_models.Profession>(
                      label: 'Status',
                      icon: Icons.work_outline,
                      value: _selectedProfession,
                      items: user_models.Profession.values,
                      itemBuilder: (profession) => profession.toString().split('.').last,
                      displayBuilder: (profession) {
                        switch (profession) {
                          case user_models.Profession.student:
                            return 'Student';
                          case user_models.Profession.employee:
                            return 'Employee';
                          case user_models.Profession.unemployed:
                            return 'Unemployed';
                          case user_models.Profession.retired:
                            return 'Retired';
                        }
                      },
                      onChanged: (value) {
                        setState(() {
                          _selectedProfession = value;
                        });
                        updateFormField('profession', value);
                      },
                    ),
                    const SizedBox(height: 16),

                    _buildDropdownField<user_models.IncomeFrequency>(
                      label: 'Income Frequency',
                      icon: Icons.schedule,
                      value: _selectedIncomeFrequency,
                      items: user_models.IncomeFrequency.values,
                      itemBuilder: (frequency) => frequency.toString().split('.').last,
                      displayBuilder: (frequency) {
                        switch (frequency) {
                          case user_models.IncomeFrequency.fixed:
                            return 'Fixed';
                          case user_models.IncomeFrequency.irregular:
                            return 'Irregular';
                        }
                      },
                      onChanged: (value) {
                        setState(() {
                          _selectedIncomeFrequency = value;
                        });
                        updateFormField('incomeFrequency', value);
                      },
                    ),
                    const SizedBox(height: 16),

                    // Gender Field
                    _buildDropdownField<user_models.Gender>(
                      label: 'Gender',
                      icon: Icons.person,
                      value: _selectedGender,
                      items: user_models.Gender.values,
                      itemBuilder: (gender) => gender.toString().split('.').last,
                      displayBuilder: (gender) {
                        switch (gender) {
                          case user_models.Gender.male:
                            return 'Male';
                          case user_models.Gender.female:
                            return 'Female';
                          case user_models.Gender.other:
                            return 'Other';
                          case user_models.Gender.preferNotToSay:
                            return 'Prefer not to say';
                        }
                      },
                      onChanged: (value) {
                        setState(() {
                          _selectedGender = value;
                        });
                        updateFormField('gender', value);
                      },
                    ),
                    const SizedBox(height: 32),

                    // Personal Details Section
                    _buildSectionTitle('Personal Details'),
                    const SizedBox(height: 16),

                    // Working Student
                    ...(_selectedProfession == user_models.Profession.student ? [
                      _buildBooleanField(
                        'Are you a working student?',
                        _isWorkingStudent,
                        (value) {
                          setState(() => _isWorkingStudent = value);
                          updateFormField('isWorkingStudent', value);
                        },
                      ),
                      const SizedBox(height: 16),
                    ] : []),

                    // Business Owner
                    _buildBooleanField(
                      'Do you own a business?',
                      _isBusinessOwner,
                      (value) {
                        setState(() => _isBusinessOwner = value);
                        updateFormField('isBusinessOwner', value);
                      },
                    ),
                    const SizedBox(height: 16),

                    // Civil Status
                    _buildDropdownField<user_models.CivilStatus>(
                      label: 'Civil Status',
                      icon: Icons.favorite,
                      value: _civilStatus,
                      items: user_models.CivilStatus.values,
                      itemBuilder: (status) => status.toString().split('.').last,
                      displayBuilder: (status) {
                        switch (status) {
                          case user_models.CivilStatus.single:
                            return 'Single';
                          case user_models.CivilStatus.married:
                            return 'Married';
                          case user_models.CivilStatus.livingWithPartner:
                            return 'Living with Partner';
                          case user_models.CivilStatus.widowed:
                            return 'Widowed';
                        }
                      },
                      onChanged: (value) {
                        setState(() {
                          _civilStatus = value;
                        });
                        updateFormField('civilStatus', value);
                      },
                    ),
                    const SizedBox(height: 16),

                    // Has Kids
                    _buildBooleanField(
                      'Do you have kids?',
                      _hasKids,
                      (value) {
                        setState(() {
                          _hasKids = value;
                          // Reset number of children if "no" is selected
                          if (value == false) {
                            _numberOfChildren = null;
                          }
                        });
                        updateFormField('hasKids', value);
                      },
                    ),
                    const SizedBox(height: 16),

                    // Number of Children (only show if has kids is true)
                    if (_hasKids == true) ...[
                      _buildDropdownField<String>(
                        label: 'Number of Children',
                        icon: Icons.child_care,
                        value: _numberOfChildren != null 
                            ? (_numberOfChildren! >= 6 ? '6+' : _numberOfChildren! >= 3 ? '3-5' : '1-2')
                            : null,
                        items: ['1-2', '3-5', '6+'],
                        itemBuilder: (item) => item,
                        displayBuilder: (item) => item,
                        onChanged: (value) {
                          setState(() {
                            if (value == '1-2') {
                              _numberOfChildren = 1;
                            } else if (value == '3-5') {
                              _numberOfChildren = 3;
                            } else if (value == '6+') {
                              _numberOfChildren = 6;
                            } else {
                              _numberOfChildren = null;
                            }
                          });
                          updateFormField('numberOfChildren', _numberOfChildren);
                        },
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Household Situation
                    _buildDropdownField<user_models.HouseholdSituation>(
                      label: 'Household Living Situation',
                      icon: Icons.home,
                      value: _householdSituation,
                      items: user_models.HouseholdSituation.values,
                      itemBuilder: (situation) => situation.toString().split('.').last,
                      displayBuilder: (situation) {
                        switch (situation) {
                          case user_models.HouseholdSituation.ownHouse:
                            return 'Own House';
                          case user_models.HouseholdSituation.renting:
                            return 'Renting';
                          case user_models.HouseholdSituation.mortgage:
                            return 'Mortgage';
                          case user_models.HouseholdSituation.livesWithParentsRelatives:
                            return 'Lives with Parents/Relatives';
                        }
                      },
                      onChanged: (value) {
                        setState(() {
                          _householdSituation = value;
                        });
                        updateFormField('householdSituation', value);
                      },
                    ),
                    const SizedBox(height: 32),

                    // Financial Information Section
                    _buildSectionTitle('Financial Information'),
                    const SizedBox(height: 16),

                    // Debt Status
                    MultiSelectChipField<user_models.DebtStatus>(
                      title: 'Debt Status',
                      options: user_models.DebtStatus.values,
                      selectedValues: _debtStatuses,
                      exclusiveOption: user_models.DebtStatus.noDebt,
                      onChanged: (selected) {
                        setState(() {
                          _debtStatuses = selected;
                        });
                        updateFormField('debtStatuses', selected);
                      },
                      getDisplayName: (status) {
                        switch (status) {
                          case user_models.DebtStatus.noDebt:
                            return 'No Debt';
                          case user_models.DebtStatus.creditCardDebt:
                            return 'Credit Card Debt';
                          case user_models.DebtStatus.loanDebt:
                            return 'Loan Debt';
                        }
                      },
                      isRequired: true,
                    ),
                    const SizedBox(height: 16),

                    // Savings and Investments
                    MultiSelectChipField<user_models.SavingsInvestments>(
                      title: 'Savings and Investments',
                      options: user_models.SavingsInvestments.values,
                      selectedValues: _savingsInvestments,
                      exclusiveOption: user_models.SavingsInvestments.noSavings,
                      onChanged: (selected) {
                        setState(() {
                          _savingsInvestments = selected;
                        });
                        updateFormField('savingsInvestments', selected);
                      },
                      getDisplayName: (savings) {
                        switch (savings) {
                          case user_models.SavingsInvestments.noSavings:
                            return 'No Savings';
                          case user_models.SavingsInvestments.smallSavings:
                            return 'Small Savings';
                          case user_models.SavingsInvestments.emergencyFund:
                            return 'Emergency Fund';
                          case user_models.SavingsInvestments.investments:
                            return 'Investments';
                        }
                      },
                      isRequired: true,
                    ),

                    // Emergency Fund Amount (only show if emergency fund is selected)
                    if (_savingsInvestments.contains(user_models.SavingsInvestments.emergencyFund)) ...[
                      const SizedBox(height: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Emergency Fund Amount',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              // Currency symbol
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 14,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(4),
                                    bottomLeft: Radius.circular(4),
                                  ),
                                  border: Border.all(color: theme.dividerColor),
                                ),
                                child: Text(
                                  '₱',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              ),
                              // Integer part input
                              Expanded(
                                flex: 3,
                                child: TextFormField(
                                  controller: _emergencyFundController,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    LengthLimitingTextInputFormatter(7), // 7-digit limit
                                  ],
                                  decoration: InputDecoration(
                                    hintText: '0',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.zero,
                                      borderSide: BorderSide(color: theme.dividerColor),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.zero,
                                      borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.zero,
                                      borderSide: BorderSide(color: theme.dividerColor),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 14,
                                    ),
                                  ),
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              // Decimal separator
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 14,
                                ),
                                decoration: BoxDecoration(
                                  border: Border.symmetric(
                                    vertical: BorderSide(color: theme.dividerColor),
                                  ),
                                ),
                                child: Text(
                                  '.',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                              ),
                              // Decimal part input
                              Expanded(
                                flex: 2,
                                child: TextFormField(
                                  controller: _emergencyFundDecimalController,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    LengthLimitingTextInputFormatter(2), // Max 2 decimal places
                                  ],
                                  decoration: InputDecoration(
                                    hintText: '00',
                                    border: OutlineInputBorder(
                                      borderRadius: const BorderRadius.only(
                                        topRight: Radius.circular(4),
                                        bottomRight: Radius.circular(4),
                                      ),
                                      borderSide: BorderSide(color: theme.dividerColor),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: const BorderRadius.only(
                                        topRight: Radius.circular(4),
                                        bottomRight: Radius.circular(4),
                                      ),
                                      borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: const BorderRadius.only(
                                        topRight: Radius.circular(4),
                                        bottomRight: Radius.circular(4),
                                      ),
                                      borderSide: BorderSide(color: theme.dividerColor),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 14,
                                    ),
                                  ),
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                          // Validation message
                          Builder(
                            builder: (context) {
                              final integerPart = _emergencyFundController.text.isEmpty ? '0' : _emergencyFundController.text;
                              final decimalPart = _emergencyFundDecimalController.text.padRight(2, '0').substring(0, 2);
                              final amountString = '$integerPart.$decimalPart';
                              final amount = double.tryParse(amountString) ?? 0.0;

                              if (amount < 0) {
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    'Please enter a valid emergency fund amount',
                                    style: TextStyle(
                                      color: theme.colorScheme.error,
                                      fontSize: 12,
                                    ),
                                  ),
                                );
                              }

                              return const SizedBox.shrink();
                            },
                          ),
                        ],
                      ),
                    ],

                    // Income Sources
                    MultiSelectChipField<user_models.IncomeSource>(
                      title: 'Income Sources',
                      options: user_models.IncomeSource.values,
                      selectedValues: _incomeSources,
                      onChanged: (selected) {
                        setState(() {
                          _incomeSources = selected;
                        });
                        updateFormField('incomeSources', selected);
                      },
                      getDisplayName: (source) {
                        switch (source) {
                          case user_models.IncomeSource.salaryWages:
                            return 'Salary/Wages';
                          case user_models.IncomeSource.businessSelfEmployed:
                            return 'Business/Self-employed';
                          case user_models.IncomeSource.allowance:
                            return 'Allowance';
                          case user_models.IncomeSource.pensionRetirement:
                            return 'Pension/Retirement';
                          case user_models.IncomeSource.investmentsPassive:
                            return 'Investments/Passive Income';
                          case user_models.IncomeSource.other:
                            return 'Other';
                        }
                      },
                      isRequired: true,
                    ),

                    // Other Income Source (only show if "Other" is selected)
                    // Conditional widgets removed for now
                    const SizedBox(height: 16),

                    const SizedBox(height: 16),

                    // Monthly Net (Projected Monthly Budget)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Monthly Net (Projected Monthly Budget)',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                            children: [
                              // Currency symbol
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 14,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(12),
                                    bottomLeft: Radius.circular(12),
                                  ),
                                  border: Border.all(color: theme.dividerColor),
                                ),
                                child: Text(
                                  '₱',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              ),
                              // Integer part input
                              Expanded(
                                flex: 3,
                                child: TextFormField(
                                  controller: _monthlyNetController,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    LengthLimitingTextInputFormatter(7), // 7-digit limit
                                  ],
                                  decoration: InputDecoration(
                                    hintText: '0',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.zero,
                                      borderSide: BorderSide(color: theme.dividerColor),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.zero,
                                      borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.zero,
                                      borderSide: BorderSide(color: theme.dividerColor),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 14,
                                    ),
                                  ),
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              // Decimal separator
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 14,
                                ),
                                decoration: BoxDecoration(
                                  border: Border.symmetric(
                                    vertical: BorderSide(color: theme.dividerColor),
                                  ),
                                ),
                                child: Text(
                                  '.',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                              ),
                              // Decimal part input
                              Expanded(
                                flex: 2,
                                child: TextFormField(
                                  controller: _monthlyNetDecimalController,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    LengthLimitingTextInputFormatter(2), // Max 2 decimal places
                                  ],
                                  decoration: InputDecoration(
                                    hintText: '00',
                                    border: OutlineInputBorder(
                                      borderRadius: const BorderRadius.only(
                                        topRight: Radius.circular(12),
                                        bottomRight: Radius.circular(12),
                                      ),
                                      borderSide: BorderSide(color: theme.dividerColor),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: const BorderRadius.only(
                                        topRight: Radius.circular(12),
                                        bottomRight: Radius.circular(12),
                                      ),
                                      borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: const BorderRadius.only(
                                        topRight: Radius.circular(12),
                                        bottomRight: Radius.circular(12),
                                      ),
                                      borderSide: BorderSide(color: theme.dividerColor),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 14,
                                    ),
                                  ),
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                        // Validation message
                        Builder(
                          builder: (context) {
                            final integerPart = _monthlyNetController.text.isEmpty ? '0' : _monthlyNetController.text;
                            final decimalPart = _monthlyNetDecimalController.text.padRight(2, '0').substring(0, 2);
                            final amountString = '$integerPart.$decimalPart';
                            final amount = double.tryParse(amountString) ?? 0.0;

                            if (amount <= 0) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  'Please enter a valid monthly net budget',
                                  style: TextStyle(
                                    color: theme.colorScheme.error,
                                    fontSize: 12,
                                  ),
                                ),
                              );
                            }

                            return const SizedBox.shrink();
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),

                    // Save Button
                    Container(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _saveProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: theme.colorScheme.onPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
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
                                'Save Changes',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onPrimary,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

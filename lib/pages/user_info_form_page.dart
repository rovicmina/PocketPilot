import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Add this import for FilteringTextInputFormatter
import '../main.dart' show LandingPage;
import '../models/user.dart' hide Theme;
import '../models/budget.dart';
import '../services/firebase_service.dart';
import '../widgets/form_widgets.dart';
import '../utils/form_state_tracker.dart';
import '../widgets/unsaved_changes_dialog.dart';
import '../widgets/tutorial_cleanup.dart';
import '../widgets/tutorial_hotfix.dart';
import 'main_navigation.dart';

class UserInfoFormPage extends StatefulWidget {
  const UserInfoFormPage({super.key});

  @override
  State<UserInfoFormPage> createState() => _UserInfoFormPageState();
}

class _UserInfoFormPageState extends State<UserInfoFormPage> with FormStateTracker {
  final _formKey = GlobalKey<FormState>();
  late final TrackedTextEditingController _cityController;
  late final TrackedTextEditingController _provinceController;
  late final TrackedTextEditingController _otherIncomeController;
  late final TrackedTextEditingController _monthlyNetController;
  late final TrackedTextEditingController _monthlyNetDecimalController;
  late final TrackedTextEditingController _emergencyFundController;
  late final TrackedTextEditingController _emergencyFundDecimalController;

  // Form field values
  DateTime? _selectedBirthDate;
  Gender? _selectedGender;
  Profession? _selectedProfession;
  IncomeFrequency? _selectedIncomeFrequency;
  bool? _isWorkingStudent;
  bool? _isBusinessOwner;
  CivilStatus? _civilStatus;
  bool? _hasKids;
  int? _numberOfChildren;
  HouseholdSituation? _householdSituation;
  List<DebtStatus> _debtStatuses = [];
  List<SavingsInvestments> _savingsInvestments = [];
  List<IncomeSource> _incomeSources = [];

  @override
  void initState() {
    super.initState();
    _cityController = createTrackedController('city', this);
    _provinceController = createTrackedController('province', this);
    _otherIncomeController = createTrackedController('otherIncome', this);
    _monthlyNetController = createTrackedController('monthlyNet', this);
    _monthlyNetDecimalController = createTrackedController('monthlyNetDecimal', this);
    _emergencyFundController = createTrackedController('emergencyFund', this);
    _emergencyFundDecimalController = createTrackedController('emergencyFundDecimal', this);

    // Initialize form tracking with empty values
    initializeFormTracking({
      'city': '',
      'province': '',
      'otherIncome': '',
      'monthlyNet': '',
      'monthlyNetDecimal': '',
      'emergencyFund': '',
      'emergencyFundDecimal': '',
      'birthDate': null,
      'gender': null,
      'profession': null,
      'incomeFrequency': null,
      'isWorkingStudent': null,
      'isBusinessOwner': null,
      'civilStatus': null,
      'hasKids': null,
      'numberOfChildren': null,
      'householdSituation': null,
      'debtStatuses': <DebtStatus>[],
      'savingsInvestments': <SavingsInvestments>[],
      'incomeSources': <IncomeSource>[],
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return TutorialHotfixWrapper(
      child: FormPageWrapper(
        hasUnsavedChanges: hasUnsavedChanges,
        warningTitle: 'Discard Profile Setup?',
        warningMessage: 'You have entered profile information. Are you sure you want to go back without completing your profile?',
        child: Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: false,
            title: LayoutBuilder(
              builder: (context, constraints) {
                final isNarrowScreen = MediaQuery.of(context).size.width < 600;
                final titleFontSize = isNarrowScreen ? 18.0 : 20.0; // Section Heading range
                
                return Text(
                  'Complete Your Profile',
                  style: TextStyle(
                    fontSize: titleFontSize,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                );
              },
            ),
            backgroundColor: theme.appBarTheme.backgroundColor,
            actions: [
              // Logout button
              IconButton(
                icon: const Icon(Icons.logout),
                onPressed: () async {
                  // Store context references before async operations
                  final navigator = Navigator.of(context);
                  final dialogContext = context;
                  
                  // Show confirmation dialog
                  final shouldLogout = await showDialog<bool>(
                    context: dialogContext,
                    builder: (context) => AlertDialog(
                      title: const Text('Logout'),
                      content: const Text('Are you sure you want to logout? Your progress will be lost and you\'ll need to complete your profile when you login again.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          child: Text(
                            'Logout',
                            style: TextStyle(color: Theme.of(context).colorScheme.error),
                          ),
                        ),
                      ],
                    ),
                  );
                  
                  if (shouldLogout == true) {
                    // Perform logout
                    await FirebaseService.logout();
                    if (mounted) {
                      // Navigate back to the landing page
                      navigator.pushAndRemoveUntil(
                        MaterialPageRoute(builder: (context) => const LandingPage()),
                        (route) => false,
                      );
                    }
                  }
                },
                tooltip: 'Logout',
              ),
            ],
          ),
          body: LayoutBuilder(
            builder: (context, constraints) {
              final isNarrowScreen = constraints.maxWidth < 600;
              final isVeryNarrowScreen = constraints.maxWidth < 400;
              final horizontalPadding = isVeryNarrowScreen ? 12.0 : 16.0;
              final verticalSpacing = isVeryNarrowScreen ? 12.0 : 16.0;
              
              return SingleChildScrollView(
                padding: EdgeInsets.all(horizontalPadding),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SectionHeader(title: 'Personal Information'),
                      
                      // Birth Date Section
                      Text(
                        'Birth Date',
                        style: TextStyle(
                          fontSize: isNarrowScreen ? 14.0 : 16.0,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      SizedBox(height: isVeryNarrowScreen ? 6.0 : 8.0),
                      InkWell(
                        onTap: () async {
                          final DateTime now = DateTime.now();
                          final DateTime maxDate = DateTime(now.year - 15, now.month, now.day);
                          final DateTime minDate = DateTime(now.year - 100, now.month, now.day);
                          
                          final DateTime? pickedDate = await showDatePicker(
                            context: context,
                            initialDate: _selectedBirthDate ?? DateTime(2000, 1, 1),
                            firstDate: minDate,
                            lastDate: maxDate,
                            helpText: 'Select your birth date',
                            cancelText: 'Cancel',
                            confirmText: 'Select',
                            builder: (context, child) {
                              return Theme(
                                data: Theme.of(context).copyWith(
                                  colorScheme: Theme.of(context).colorScheme.copyWith(
                                    primary: theme.colorScheme.primary,
                                  ),
                                ),
                                child: child!,
                              );
                            },
                          );
                          if (pickedDate != null) {
                            setState(() {
                              _selectedBirthDate = pickedDate;
                            });
                            updateFormField('birthDate', pickedDate);
                          }
                        },
                        child: Container(
                          padding: EdgeInsets.all(isNarrowScreen ? 12.0 : 16.0),
                          decoration: BoxDecoration(
                            border: Border.all(color: theme.dividerColor),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.calendar_today, color: theme.colorScheme.primary),
                              SizedBox(width: isNarrowScreen ? 8.0 : 12.0),
                              Expanded(
                                child: Text(
                                  _selectedBirthDate != null
                                      ? '${_selectedBirthDate!.day}/${_selectedBirthDate!.month}/${_selectedBirthDate!.year}'
                                      : 'Select your birth date',
                                  style: TextStyle(
                                    fontSize: isNarrowScreen ? 14.0 : 16.0,
                                    color: _selectedBirthDate != null
                                        ? theme.colorScheme.onSurface
                                        : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                  ),
                                ),
                              ),
                              Icon(Icons.arrow_drop_down, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                            ],
                          ),
                        ),
                      ),
                      if (_selectedBirthDate == null) ...[
                        SizedBox(height: isVeryNarrowScreen ? 6.0 : 8.0),
                        Text(
                          'Birth date is required',
                          style: TextStyle(
                            color: theme.colorScheme.error,
                            fontSize: isVeryNarrowScreen ? 10.0 : 12.0,
                          ),
                        ),
                      ],

                      SizedBox(height: verticalSpacing),

                      // Gender
                      DropdownButtonFormField<Gender>(
                        value: _selectedGender,
                        decoration: InputDecoration(
                          labelText: 'Gender',
                          border: OutlineInputBorder(
                            borderSide: BorderSide(color: theme.dividerColor),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: theme.dividerColor),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
                          ),
                          filled: true,
                          fillColor: theme.cardTheme.color,
                        ),
                        items: Gender.values.map((gender) {
                          String displayName = '';
                          switch (gender) {
                            case Gender.male:
                              displayName = 'Male';
                              break;
                            case Gender.female:
                              displayName = 'Female';
                              break;
                            case Gender.other:
                              displayName = 'Other';
                              break;
                            case Gender.preferNotToSay:
                              displayName = 'Prefer not to say';
                              break;
                          }
                          return DropdownMenuItem(
                            value: gender,
                            child: Text(displayName),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedGender = value;
                          });
                          updateFormField('gender', value);
                        },
                      ),

                      SizedBox(height: verticalSpacing),
                      
                      // Status
                      DropdownButtonFormField<Profession>(
                        value: _selectedProfession,
                        decoration: InputDecoration(
                          labelText: 'Status',
                          border: OutlineInputBorder(
                            borderSide: BorderSide(color: theme.dividerColor),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: theme.dividerColor),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
                          ),
                          filled: true,
                          fillColor: theme.cardTheme.color,
                        ),
                        items: Profession.values.map((profession) {
                          String displayName = '';
                          switch (profession) {
                            case Profession.student:
                              displayName = 'Student';
                              break;
                            case Profession.employee:
                              displayName = 'Employee';
                              break;
                            case Profession.retired:
                              displayName = 'Retired';
                              break;
                            case Profession.unemployed:
                              displayName = 'Unemployed';
                              break;
                          }
                          return DropdownMenuItem(
                            value: profession,
                            child: Text(displayName),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedProfession = value;
                            // Reset working student if not student
                            if (value != Profession.student) {
                              _isWorkingStudent = null;
                            }
                          });
                          updateFormField('profession', value);
                        },
                        validator: (value) {
                          if (value == null) {
                            return 'Status is required';
                          }
                          return null;
                        },
                      ),

                      SizedBox(height: verticalSpacing),

                      // Working Student (only show if student)
                      if (_selectedProfession == Profession.student) ...[
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Are you a working student?',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: ListTile(
                                    title: const Text('Yes'),
                                    leading: Radio<bool>(
                                      value: true,
                                      groupValue: _isWorkingStudent,
                                      onChanged: (value) {
                                        setState(() {
                                          _isWorkingStudent = value;
                                        });
                                        updateFormField('isWorkingStudent', value);
                                      },
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: ListTile(
                                    title: const Text('No'),
                                    leading: Radio<bool>(
                                      value: false,
                                      groupValue: _isWorkingStudent,
                                      onChanged: (value) {
                                        setState(() {
                                          _isWorkingStudent = value;
                                        });
                                        updateFormField('isWorkingStudent', value);
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (_isWorkingStudent == null) ...[
                              SizedBox(height: 8),
                              Text(
                                'This field is required',
                                style: TextStyle(
                                  color: theme.colorScheme.error,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ],
                        ),
                        SizedBox(height: verticalSpacing),
                      ],

                      // Business Owner
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Are you a business owner?',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: ListTile(
                                  title: const Text('Yes'),
                                  leading: Radio<bool>(
                                    value: true,
                                    groupValue: _isBusinessOwner,
                                    onChanged: (value) {
                                      setState(() {
                                        _isBusinessOwner = value;
                                      });
                                      updateFormField('isBusinessOwner', value);
                                    },
                                  ),
                                ),
                              ),
                              Expanded(
                                child: ListTile(
                                  title: const Text('No'),
                                  leading: Radio<bool>(
                                    value: false,
                                    groupValue: _isBusinessOwner,
                                    onChanged: (value) {
                                      setState(() {
                                        _isBusinessOwner = value;
                                      });
                                      updateFormField('isBusinessOwner', value);
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (_isBusinessOwner == null) ...[
                            SizedBox(height: 8),
                            Text(
                              'This field is required',
                              style: TextStyle(
                                color: theme.colorScheme.error,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),

                      SizedBox(height: verticalSpacing),

                      const SectionHeader(title: 'Financial Information'),

                      // Civil Status
                      DropdownButtonFormField<CivilStatus>(
                        value: _civilStatus,
                        decoration: InputDecoration(
                          labelText: 'Civil Status',
                          border: OutlineInputBorder(
                            borderSide: BorderSide(color: theme.dividerColor),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: theme.dividerColor),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
                          ),
                          filled: true,
                          fillColor: theme.cardTheme.color,
                        ),
                        items: CivilStatus.values.map((status) {
                          String displayName = '';
                          switch (status) {
                            case CivilStatus.single:
                              displayName = 'Single';
                              break;
                            case CivilStatus.married:
                              displayName = 'Married';
                              break;
                            case CivilStatus.livingWithPartner:
                              displayName = 'Living with Partner';
                              break;
                            case CivilStatus.widowed:
                              displayName = 'Widowed';
                              break;
                          }
                          return DropdownMenuItem(
                            value: status,
                            child: Text(displayName),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _civilStatus = value;
                          });
                          updateFormField('civilStatus', value);
                        },
                      ),

                      SizedBox(height: verticalSpacing),

                      // Kids
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Do you have kids?',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: ListTile(
                                  title: const Text('Yes'),
                                  leading: Radio<bool>(
                                    value: true,
                                    groupValue: _hasKids,
                                    onChanged: (value) {
                                      setState(() {
                                        _hasKids = value;
                                        // Reset number of children if no kids
                                        if (value == false) {
                                          _numberOfChildren = null;
                                        }
                                      });
                                      updateFormField('hasKids', value);
                                    },
                                  ),
                                ),
                              ),
                              Expanded(
                                child: ListTile(
                                  title: const Text('No'),
                                  leading: Radio<bool>(
                                    value: false,
                                    groupValue: _hasKids,
                                    onChanged: (value) {
                                      setState(() {
                                        _hasKids = value;
                                        // Reset number of children if no kids
                                        if (value == false) {
                                          _numberOfChildren = null;
                                        }
                                      });
                                      updateFormField('hasKids', value);
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (_hasKids == null) ...[
                            SizedBox(height: 8),
                            Text(
                              'This field is required',
                              style: TextStyle(
                                color: theme.colorScheme.error,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),

                      SizedBox(height: verticalSpacing),

                      // Number of Children (only show if has kids)
                      if (_hasKids == true) ...[
                        TextFormField(
                          decoration: const InputDecoration(
                            labelText: 'Number of Children',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          onChanged: (value) {
                            final number = int.tryParse(value);
                            setState(() {
                              _numberOfChildren = number;
                            });
                            updateFormField('numberOfChildren', number);
                          },
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Number of children is required';
                            }
                            final number = int.tryParse(value);
                            if (number == null || number <= 0) {
                              return 'Please enter a valid number';
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: verticalSpacing),
                      ],

                      // Household Situation
                      DropdownButtonFormField<HouseholdSituation>(
                        value: _householdSituation,
                        decoration: InputDecoration(
                          labelText: 'Household Situation',
                          border: OutlineInputBorder(
                            borderSide: BorderSide(color: theme.dividerColor),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: theme.dividerColor),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
                          ),
                          filled: true,
                          fillColor: theme.cardTheme.color,
                        ),
                        items: HouseholdSituation.values.map((situation) {
                          String displayName = '';
                          switch (situation) {
                            case HouseholdSituation.ownHouse:
                              displayName = 'Own House';
                              break;
                            case HouseholdSituation.renting:
                              displayName = 'Renting';
                              break;
                            case HouseholdSituation.mortgage:
                              displayName = 'Mortgage';
                              break;
                            case HouseholdSituation.livesWithParentsRelatives:
                              displayName = 'Lives with Parents / Relatives';
                              break;
                          }
                          return DropdownMenuItem(
                            value: situation,
                            child: Text(displayName),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _householdSituation = value;
                          });
                          updateFormField('householdSituation', value);
                        },
                      ),

                      SizedBox(height: verticalSpacing),

                      // Debt Status
                      MultiSelectChipField<DebtStatus>(
                        title: 'Debt Status',
                        options: DebtStatus.values,
                        selectedValues: _debtStatuses,
                        exclusiveOption: DebtStatus.noDebt,
                        onChanged: (selected) {
                          setState(() {
                            _debtStatuses = selected;
                          });
                          updateFormField('debtStatuses', selected);
                        },
                        getDisplayName: (status) {
                          switch (status) {
                            case DebtStatus.noDebt:
                              return 'No Debt';
                            case DebtStatus.creditCardDebt:
                              return 'Credit Card Debt';
                            case DebtStatus.loanDebt:
                              return 'Loan Debt';
                          }
                        },
                        isRequired: true,
                      ),

                      SizedBox(height: verticalSpacing),

                      // Savings & Investments
                      MultiSelectChipField<SavingsInvestments>(
                        title: 'Savings & Investments',
                        options: SavingsInvestments.values,
                        selectedValues: _savingsInvestments,
                        exclusiveOption: SavingsInvestments.noSavings,
                        onChanged: (selected) {
                          setState(() {
                            _savingsInvestments = selected;
                          });
                          updateFormField('savingsInvestments', selected);
                        },
                        getDisplayName: (investment) {
                          switch (investment) {
                            case SavingsInvestments.noSavings:
                              return 'No Savings';
                            case SavingsInvestments.smallSavings:
                              return 'Small Savings';
                            case SavingsInvestments.emergencyFund:
                              return 'Emergency Fund';
                            case SavingsInvestments.investments:
                              return 'Investments';
                          }
                        },
                        isRequired: true,
                      ),

                      SizedBox(height: verticalSpacing),

                      // Emergency Fund Amount (only show if emergency fund is selected)
                      if (_savingsInvestments.contains(SavingsInvestments.emergencyFund)) ...[
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Emergency Fund Amount (₱)',
                              style: TextStyle(
                                fontSize: isNarrowScreen ? 14.0 : 16.0,
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            SizedBox(height: isVeryNarrowScreen ? 6.0 : 8.0),
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final isVeryWideScreen = constraints.maxWidth > 800;
                                return Row(
                                  children: [
                                    Expanded(
                                      flex: isVeryWideScreen ? 4 : 3,
                                      child: TextFormField(
                                        controller: _emergencyFundController,
                                        decoration: InputDecoration(
                                          labelText: '₱',
                                          border: const OutlineInputBorder(),
                                          contentPadding: EdgeInsets.symmetric(
                                            horizontal: isNarrowScreen ? 10.0 : 12.0,
                                            vertical: isNarrowScreen ? 12.0 : 14.0,
                                          ),
                                        ),
                                        keyboardType: TextInputType.number,
                                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                        onChanged: (value) {
                                          updateFormField('emergencyFund', value);
                                        },
                                        validator: (value) {
                                          if (value == null || value.isEmpty) {
                                            return 'Emergency fund amount is required';
                                          }
                                          final number = double.tryParse(value);
                                          if (number == null || number <= 0) {
                                            return 'Please enter a valid amount';
                                          }
                                          return null;
                                        },
                                      ),
                                    ),
                                    SizedBox(width: isNarrowScreen ? 6.0 : 8.0),
                                    Expanded(
                                      flex: isVeryWideScreen ? 2 : 2,
                                      child: TextFormField(
                                        controller: _emergencyFundDecimalController,
                                        decoration: InputDecoration(
                                          labelText: 'cents',
                                          border: OutlineInputBorder(),
                                          contentPadding: EdgeInsets.symmetric(
                                            horizontal: isNarrowScreen ? 10.0 : 12.0,
                                            vertical: isNarrowScreen ? 12.0 : 14.0,
                                          ),
                                        ),
                                        keyboardType: TextInputType.number,
                                        inputFormatters: [
                                          FilteringTextInputFormatter.digitsOnly,
                                          LengthLimitingTextInputFormatter(2),
                                        ],
                                        onChanged: (value) {
                                          updateFormField('emergencyFundDecimal', value);
                                        },
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                        SizedBox(height: verticalSpacing),
                      ],

                      // Income Sources
                      MultiSelectChipField<IncomeSource>(
                        title: 'Income Sources',
                        options: IncomeSource.values,
                        selectedValues: _incomeSources,
                        onChanged: (selected) {
                          setState(() {
                            _incomeSources = selected;
                          });
                          updateFormField('incomeSources', selected);
                        },
                        getDisplayName: (source) {
                          switch (source) {
                            case IncomeSource.salaryWages:
                              return 'Salary/Wages';
                            case IncomeSource.businessSelfEmployed:
                              return 'Business/Self-Employed';
                            case IncomeSource.allowance:
                              return 'Allowance';
                            case IncomeSource.pensionRetirement:
                              return 'Pension/Retirement';
                            case IncomeSource.investmentsPassive:
                              return 'Investments/Passive Income';
                            case IncomeSource.other:
                              return 'Other';
                          }
                        },
                        isRequired: true,
                      ),

                      SizedBox(height: verticalSpacing),
                      // Other Income Source (only show if "Other" is selected in income sources)
                      if (_incomeSources.contains(IncomeSource.other)) ...[
                        TextFormField(
                          controller: _otherIncomeController,
                          decoration: const InputDecoration(
                            labelText: 'Other Income Source (if applicable)',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (value) {
                            updateFormField('otherIncome', value);
                          },
                        ),
                        SizedBox(height: verticalSpacing),
                      ],

                      // Income Frequency
                      DropdownButtonFormField<IncomeFrequency>(
                        value: _selectedIncomeFrequency,
                        decoration: InputDecoration(
                          labelText: 'Income Frequency',
                          border: OutlineInputBorder(
                            borderSide: BorderSide(color: theme.dividerColor),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: theme.dividerColor),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
                          ),
                          filled: true,
                          fillColor: theme.cardTheme.color,
                        ),
                        items: IncomeFrequency.values.map((frequency) {
                          String displayName = '';
                          switch (frequency) {
                            case IncomeFrequency.fixed:
                              displayName = 'Fixed';
                              break;
                            case IncomeFrequency.irregular:
                              displayName = 'Irregular';
                              break;
                          }
                          return DropdownMenuItem(
                            value: frequency,
                            child: Text(displayName),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedIncomeFrequency = value;
                          });
                          updateFormField('incomeFrequency', value);
                        },
                        validator: (value) {
                          if (value == null) {
                            return 'Income frequency is required';
                          }
                          return null;
                        },
                      ),

                      SizedBox(height: verticalSpacing),

                      // Monthly Net Income
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Monthly Net Income (₱)',
                            style: TextStyle(
                              fontSize: isNarrowScreen ? 14.0 : 16.0,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          SizedBox(height: isVeryNarrowScreen ? 6.0 : 8.0),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final isVeryWideScreen = constraints.maxWidth > 800;
                              return Row(
                                children: [
                                  Expanded(
                                    flex: isVeryWideScreen ? 4 : 3,
                                    child: TextFormField(
                                      controller: _monthlyNetController,
                                      decoration: InputDecoration(
                                        labelText: '₱',
                                        border: const OutlineInputBorder(),
                                        contentPadding: EdgeInsets.symmetric(
                                          horizontal: isNarrowScreen ? 10.0 : 12.0,
                                          vertical: isNarrowScreen ? 12.0 : 14.0,
                                        ),
                                      ),
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                      onChanged: (value) {
                                        updateFormField('monthlyNet', value);
                                      },
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Monthly net income is required';
                                        }
                                        final number = double.tryParse(value);
                                        if (number == null || number <= 0) {
                                          return 'Please enter a valid amount';
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                  SizedBox(width: isNarrowScreen ? 6.0 : 8.0),
                                  Expanded(
                                    flex: isVeryWideScreen ? 2 : 2,
                                    child: TextFormField(
                                      controller: _monthlyNetDecimalController,
                                      decoration: InputDecoration(
                                        labelText: 'cents',
                                        border: OutlineInputBorder(),
                                        contentPadding: EdgeInsets.symmetric(
                                          horizontal: isNarrowScreen ? 10.0 : 12.0,
                                          vertical: isNarrowScreen ? 12.0 : 14.0,
                                        ),
                                      ),
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                        LengthLimitingTextInputFormatter(2),
                                      ],
                                      onChanged: (value) {
                                        updateFormField('monthlyNetDecimal', value);
                                      },
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),

                      SizedBox(height: verticalSpacing),

                      SizedBox(height: verticalSpacing),

                      const SectionHeader(title: 'Address Information'),
                      
                      TextFormField(
                        controller: _cityController,
                        decoration: const InputDecoration(
                          labelText: 'City',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'City is required';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: verticalSpacing),
                      TextFormField(
                        controller: _provinceController,
                        decoration: const InputDecoration(
                          labelText: 'Province',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Province is required';
                          }
                          return null;
                        },
                      ),

                      SizedBox(height: 32),
                      ElevatedButton(
                        onPressed: () async {
                          if (_validateForm()) {
                            setSubmitting(true);
                            final navigator = Navigator.of(context);
                            final scaffoldMessenger = ScaffoldMessenger.of(context);
                            
                            // Check authentication status first
                            final authStatus = await FirebaseService.getAuthStatus();
                            
                            if (mounted) {
                              if (!authStatus['authenticated']) {
                                scaffoldMessenger.showSnackBar(
                                  SnackBar(
                                    content: Text('Authentication error: ${authStatus['message']}'),
                                    backgroundColor: Colors.red,
                                    duration: const Duration(seconds: 5),
                                  ),
                                );
                                setSubmitting(false);
                                return;
                              }
                              
                              final success = await _saveUserInfo();

                              if (mounted) {
                                if (success) {
                                  // Show tutorial information dialog before navigating to main app
                                  await showDialog(
                                    context: context,
                                    barrierDismissible: false,
                                    builder: (BuildContext context) {
                                      return AlertDialog(
                                        title: const Text('Welcome to PocketPilot!'),
                                        content: const Text(
                                          'For tutorials on each page, click the help button (❓) in the top right corner.',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () {
                                              Navigator.of(context).pop();
                                              // Navigate directly to main app without loading screen
                                              if (context.mounted) {
                                                Navigator.pushAndRemoveUntil(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) => const MainNavigation(),
                                                  ),
                                                  (route) => false,
                                                );
                                              }
                                            },
                                            child: const Text('Got it'),
                                          ),
                                        ],
                                      );
                                    },
                                  );
                                } else {
                                  scaffoldMessenger.showSnackBar(
                                    const SnackBar(
                                      content: Text('Failed to update profile. Please check your connection and try again.'),
                                      backgroundColor: Colors.red,
                                      duration: Duration(seconds: 5),
                                    ),
                                  );
                                  setSubmitting(false);
                                }
                              }
                            }
                          }
                        },
                        child: const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text(
                            'Complete Profile',
                            style: TextStyle(fontSize: 18),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  bool _validateForm() {
    bool isValid = _formKey.currentState!.validate();
    
    // Additional validations
    if (_selectedBirthDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select your birth date'),
          backgroundColor: Colors.red,
        ),
      );
      isValid = false;
    }
    
    if (_selectedIncomeFrequency == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select your income frequency'),
          backgroundColor: Colors.red,
        ),
      );
      isValid = false;
    }
    
    if (_isBusinessOwner == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please specify if you are a business owner'),
          backgroundColor: Colors.red,
        ),
      );
      isValid = false;
    }
    
    if (_hasKids == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please specify if you have kids'),
          backgroundColor: Colors.red,
        ),
      );
      isValid = false;
    }
    
    if (_debtStatuses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select your debt status'),
          backgroundColor: Colors.red,
        ),
      );
      isValid = false;
    }
    
    if (_savingsInvestments.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select your savings & investments status'),
          backgroundColor: Colors.red,
        ),
      );
      isValid = false;
    }
    
    if (_incomeSources.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select your income source(s)'),
          backgroundColor: Colors.red,
        ),
      );
      isValid = false;
    }
    

    
    return isValid;
  }

  Future<bool> _saveUserInfo() async {
    try {
      return await FirebaseService.updateUserInfo(
        birthMonth: _selectedBirthDate!.month,
        birthDay: _selectedBirthDate!.day,
        birthYear: _selectedBirthDate!.year,
        gender: _selectedGender?.toString(),
        profession: _selectedProfession.toString(),
        incomeFrequency: _selectedIncomeFrequency.toString(),
        isWorkingStudent: _isWorkingStudent,
        isBusinessOwner: _isBusinessOwner,
        civilStatus: _civilStatus?.toString(),
        hasKids: _hasKids,
        numberOfChildren: _numberOfChildren,
        householdSituation: _householdSituation?.toString(),
        debtStatuses: _debtStatuses.map((e) => e.toString()).toList(),
        savingsInvestments: _savingsInvestments.map((e) => e.toString()).toList(),
        incomeSources: _incomeSources.map((e) => e.toString()).toList(),
        otherIncomeSource: _otherIncomeController.text.isNotEmpty ? _otherIncomeController.text : null,
        city: _cityController.text,
        province: _provinceController.text,
        monthlyNet: _monthlyNetController.text.isNotEmpty ? double.tryParse('${_monthlyNetController.text}.${_monthlyNetDecimalController.text.padRight(2, '0').substring(0, 2)}') : null,
        emergencyFundAmount: _emergencyFundController.text.isNotEmpty ? double.tryParse('${_emergencyFundController.text}.${_emergencyFundDecimalController.text.padRight(2, '0').substring(0, 2)}') : null,
        selectedCategories: BudgetCategory.defaultCategories,
      );
    } catch (e) {
      // Error saving user info: $e
      return false;
    }
  }

  @override
  void dispose() {
    _cityController.dispose();
    _provinceController.dispose();
    _otherIncomeController.dispose();
    _monthlyNetController.dispose();
    _monthlyNetDecimalController.dispose();
    _emergencyFundController.dispose();
    _emergencyFundDecimalController.dispose();
    super.dispose();
  }
}
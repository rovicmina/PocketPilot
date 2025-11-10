enum IncomeFrequency { fixed, irregular }
enum Theme { light, dark }

extension ThemeExtension on Theme {
  String get name => toString().split('.').last;
}

enum Gender { male, female, other, preferNotToSay }
enum Profession { student, employee, retired, unemployed }

enum CivilStatus { single, married, livingWithPartner, widowed }

enum DebtStatus { 
  noDebt, 
  creditCardDebt, 
  loanDebt
}

enum SavingsInvestments { 
  noSavings, 
  smallSavings, 
  emergencyFund, 
  investments 
}

enum IncomeSource { 
  salaryWages, 
  businessSelfEmployed, 
  allowance, 
  pensionRetirement, 
  investmentsPassive, 
  other 
}

enum HouseholdSituation {
  ownHouse,
  renting,
  mortgage,
  livesWithParentsRelatives
}

class User {
  final String id;
  final String email;
  final String name;
  final String password;
  final double monthlyIncome;
  final String currency;
  final DateTime createdAt;
  
  // New demographic fields
  final int? birthMonth;
  final int? birthDay;
  final int? birthYear;
  final Gender? gender;
  final Profession? profession;
  final IncomeFrequency? incomeFrequency;
  final Theme theme;
  
  // Extended demographic fields
  final bool? isWorkingStudent;
  final bool? isBusinessOwner;
  final CivilStatus? civilStatus;
  final bool? hasKids;
  final int? numberOfChildren;
  final HouseholdSituation? householdSituation;
  final List<DebtStatus> debtStatuses;
  final List<SavingsInvestments> savingsInvestments;
  final List<IncomeSource> incomeSources;
  final String? otherIncomeSource;

  
  // Address field for Philippines
  final String? city;
  final String? province;
  
  // Profile image
  final String? profileImagePath;
  
  // Budget management
  final double initialBudget;
  final double? monthlyNet;  // Monthly Net (Projected Monthly Budget)
  final double? emergencyFundAmount;  // Emergency Fund Amount
  final double maxMonthlyExpense;  // Highest monthly expense total (for emergency fund calculation)
  final List<String> selectedCategories;
  
  // Profile completion tracking
  final bool profileComplete;
  final List<String> incompleteFields;
  final bool emailVerified;

  User({
    required this.id,
    required this.email,
    required this.name,
    required this.password,
    required this.monthlyIncome,
    this.currency = 'PHP',
    required this.createdAt,
    this.birthMonth,
    this.birthDay,
    this.birthYear,
    this.gender,
    this.profession,
    this.incomeFrequency,
    this.theme = Theme.light,
    this.isWorkingStudent,
    this.isBusinessOwner,
    this.civilStatus,
    this.hasKids,
    this.numberOfChildren,
    this.householdSituation,
    this.debtStatuses = const [],
    this.savingsInvestments = const [],
    this.incomeSources = const [],
    this.otherIncomeSource,
    this.city,
    this.province,
    this.profileImagePath,
    this.initialBudget = 0.0,
    this.monthlyNet,
    this.emergencyFundAmount,
    this.maxMonthlyExpense = 0.0,
    this.selectedCategories = const [],
    this.profileComplete = false,
    this.incompleteFields = const [],
    this.emailVerified = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'password': password,
      'monthlyIncome': monthlyIncome,
      'currency': currency,
      'createdAt': createdAt.toIso8601String(),
      'birthMonth': birthMonth,
      'birthDay': birthDay,
      'birthYear': birthYear,
      'gender': gender?.toString(),
      'profession': profession?.toString(),
      'incomeFrequency': incomeFrequency?.toString(),
      'theme': theme.toString(),
      'isWorkingStudent': isWorkingStudent,
      'isBusinessOwner': isBusinessOwner,
      'civilStatus': civilStatus?.toString(),
      'hasKids': hasKids,
      'numberOfChildren': numberOfChildren,
      'householdSituation': householdSituation?.toString(),
      'debtStatuses': debtStatuses.map((e) => e.toString()).toList(),
      'savingsInvestments': savingsInvestments.map((e) => e.toString()).toList(),
      'incomeSources': incomeSources.map((e) => e.toString()).toList(),
      'otherIncomeSource': otherIncomeSource,
      'city': city,
      'province': province,
      'profileImagePath': profileImagePath,
      'initialBudget': initialBudget,
      'monthlyNet': monthlyNet,
      'emergencyFundAmount': emergencyFundAmount,
      'maxMonthlyExpense': maxMonthlyExpense,
      'selectedCategories': selectedCategories,
      'profileComplete': profileComplete,
      'incompleteFields': incompleteFields,
      'emailVerified': emailVerified,
    };
  }

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String? ?? '',
      email: json['email'] as String? ?? '',
      name: json['name'] as String? ?? '',
      password: json['password'] as String? ?? '',
      monthlyIncome: (json['monthlyIncome'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency'] as String? ?? 'PHP',
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt']) 
          : DateTime.now(),
      birthMonth: json['birthMonth'] as int?,
      birthDay: json['birthDay'] as int?,
      birthYear: json['birthYear'] as int?,
      gender: json['gender'] != null 
          ? Gender.values.firstWhere(
              (e) => e.toString() == json['gender'],
              orElse: () => Gender.preferNotToSay,
            )
          : null,
      profession: json['profession'] != null
          ? Profession.values.firstWhere(
              (e) => e.toString() == json['profession'],
              orElse: () => Profession.unemployed,
            )
          : null,
      incomeFrequency: json['incomeFrequency'] != null
          ? IncomeFrequency.values.firstWhere(
              (e) => e.toString() == json['incomeFrequency'],
              orElse: () => IncomeFrequency.irregular,
            )
          : null,
      theme: json['theme'] != null
          ? Theme.values.firstWhere(
              (e) => e.toString() == json['theme'] || e.name == json['theme'],
              orElse: () => Theme.light,
            )
          : Theme.light,
      isWorkingStudent: json['isWorkingStudent'] as bool?,
      isBusinessOwner: json['isBusinessOwner'] as bool?,
      civilStatus: json['civilStatus'] != null
          ? CivilStatus.values.firstWhere(
              (e) => e.toString() == json['civilStatus'],
              orElse: () => CivilStatus.single,
            )
          : null,
      hasKids: json['hasKids'] as bool?,
      numberOfChildren: json['numberOfChildren'] as int?,
      householdSituation: json['householdSituation'] != null
          ? HouseholdSituation.values.firstWhere(
              (e) => e.toString() == json['householdSituation'],
              orElse: () => HouseholdSituation.ownHouse,
            )
          : null,
      debtStatuses: (json['debtStatuses'] as List<dynamic>?)
          ?.map((e) => DebtStatus.values.firstWhere(
              (status) => status.toString() == e,
              orElse: () => DebtStatus.noDebt,
            ))
          .toList() ?? [],
      savingsInvestments: (json['savingsInvestments'] as List<dynamic>?)
          ?.map((e) => SavingsInvestments.values.firstWhere(
              (status) => status.toString() == e,
              orElse: () => SavingsInvestments.noSavings,
            ))
          .toList() ?? [],
      incomeSources: (json['incomeSources'] as List<dynamic>?)
          ?.map((e) => IncomeSource.values.firstWhere(
              (source) => source.toString() == e,
              orElse: () => IncomeSource.salaryWages,
            ))
          .toList() ?? [],
      otherIncomeSource: json['otherIncomeSource'] as String?,
      city: json['city'] as String?,
      province: json['province'] as String?,
      profileImagePath: json['profileImagePath'] as String?,
      initialBudget: (json['initialBudget'] as num?)?.toDouble() ?? 0.0,
      monthlyNet: (json['monthlyNet'] as num?)?.toDouble(),
      emergencyFundAmount: (json['emergencyFundAmount'] as num?)?.toDouble(),
      maxMonthlyExpense: (json['maxMonthlyExpense'] as num?)?.toDouble() ?? 0.0,
      selectedCategories: (json['selectedCategories'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList() ?? [],
      profileComplete: json['profileComplete'] as bool? ?? false,
      incompleteFields: (json['incompleteFields'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList() ?? [],
      emailVerified: json['emailVerified'] as bool? ?? false,
    );
  }

  User copyWith({
    String? id,
    String? email,
    String? name,
    String? password,
    double? monthlyIncome,
    String? currency,
    DateTime? createdAt,
    int? birthMonth,
    int? birthDay,
    int? birthYear,
    Gender? gender,
    Profession? profession,
    IncomeFrequency? incomeFrequency,
    Theme? theme,
    bool? isWorkingStudent,
    bool? isBusinessOwner,
    CivilStatus? civilStatus,
    bool? hasKids,
    int? numberOfChildren,
    HouseholdSituation? householdSituation,
    List<DebtStatus>? debtStatuses,
    List<SavingsInvestments>? savingsInvestments,
    List<IncomeSource>? incomeSources,
    String? otherIncomeSource,
    String? city,
    String? province,
    String? profileImagePath,
    double? initialBudget,
    double? monthlyNet,
    double? emergencyFundAmount,
    double? maxMonthlyExpense,
    List<String>? selectedCategories,
    bool? profileComplete,
    List<String>? incompleteFields,
    bool? emailVerified,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      password: password ?? this.password,
      monthlyIncome: monthlyIncome ?? this.monthlyIncome,
      currency: currency ?? this.currency,
      createdAt: createdAt ?? this.createdAt,
      birthMonth: birthMonth ?? this.birthMonth,
      birthDay: birthDay ?? this.birthDay,
      birthYear: birthYear ?? this.birthYear,
      gender: gender ?? this.gender,
      profession: profession ?? this.profession,
      incomeFrequency: incomeFrequency ?? this.incomeFrequency,
      theme: theme ?? this.theme,
      isWorkingStudent: isWorkingStudent ?? this.isWorkingStudent,
      isBusinessOwner: isBusinessOwner ?? this.isBusinessOwner,
      civilStatus: civilStatus ?? this.civilStatus,
      hasKids: hasKids ?? this.hasKids,
      numberOfChildren: numberOfChildren ?? this.numberOfChildren,
      householdSituation: householdSituation ?? this.householdSituation,
      debtStatuses: debtStatuses ?? this.debtStatuses,
      savingsInvestments: savingsInvestments ?? this.savingsInvestments,
      incomeSources: incomeSources ?? this.incomeSources,
      otherIncomeSource: otherIncomeSource ?? this.otherIncomeSource,
      city: city ?? this.city,
      province: province ?? this.province,
      profileImagePath: profileImagePath ?? this.profileImagePath,
      initialBudget: initialBudget ?? this.initialBudget,
      monthlyNet: monthlyNet ?? this.monthlyNet,
      emergencyFundAmount: emergencyFundAmount ?? this.emergencyFundAmount,
      maxMonthlyExpense: maxMonthlyExpense ?? this.maxMonthlyExpense,
      selectedCategories: selectedCategories ?? this.selectedCategories,
      profileComplete: profileComplete ?? this.profileComplete,
      incompleteFields: incompleteFields ?? this.incompleteFields,
      emailVerified: emailVerified ?? this.emailVerified,
    );
  }

  // Helper methods
  String get genderDisplayName {
    switch (gender) {
      case Gender.male:
        return 'Male';
      case Gender.female:
        return 'Female';
      case Gender.other:
        return 'Other';
      case Gender.preferNotToSay:
        return 'Prefer not to say';
      default:
        return 'Not specified';
    }
  }

  String get statusDisplayName {
    switch (profession) {
      case Profession.student:
        return 'Student';
      case Profession.employee:
        return 'Employee';
      case Profession.unemployed:
        return 'Unemployed';
      case Profession.retired:
        return 'Retired';
      default:
        return 'Not specified';
    }
  }

  String get incomeFrequencyDisplayName {
    switch (incomeFrequency) {
      case IncomeFrequency.fixed:
        return 'Fixed';
      case IncomeFrequency.irregular:
        return 'Irregular';
      default:
        return 'Not specified';
    }
  }

  bool get isDarkTheme => theme == Theme.dark;

  String get ageGroup {
    if (birthYear == null) return 'Not specified';
    final age = DateTime.now().year - birthYear!;
    if (age <= 17) return '15–17';
    if (age <= 24) return '18–24';
    if (age <= 39) return '25–39';
    if (age <= 55) return '40–55';
    return '55+';
  }

  String get civilStatusDisplayName {
    switch (civilStatus) {
      case CivilStatus.single:
        return 'Single';
      case CivilStatus.married:
        return 'Married';
      case CivilStatus.livingWithPartner:
        return 'Living with Partner';
      case CivilStatus.widowed:
        return 'Widow / Widower';
      default:
        return 'Not specified';
    }
  }

  String get householdSituationDisplayName {
    switch (householdSituation) {
      case HouseholdSituation.ownHouse:
        return 'Own House';
      case HouseholdSituation.renting:
        return 'Renting';
      case HouseholdSituation.mortgage:
        return 'Mortgage';
      case HouseholdSituation.livesWithParentsRelatives:
        return 'Lives with Parents / Relative';
      default:
        return 'Not specified';
    }
  }

  String get numberOfChildrenDisplayName {
    if (numberOfChildren == null) return 'Not specified';
    if (numberOfChildren! >= 6) return '6+';
    if (numberOfChildren! >= 3) return '3-5';
    return '1-2';
  }

  List<String> getIncompleteFields() {
    List<String> incomplete = [];
    
    if (birthMonth == null) incomplete.add('birthMonth');
    if (birthDay == null) incomplete.add('birthDay');
    if (birthYear == null) incomplete.add('birthYear');
    if (gender == null) incomplete.add('gender');
    if (profession == null) incomplete.add('profession');
    if (incomeFrequency == null) incomplete.add('incomeFrequency');
    if (city == null || city!.isEmpty) incomplete.add('city');
    if (province == null || province!.isEmpty) incomplete.add('province');
    if (initialBudget <= 0) incomplete.add('initialBudget');
    if (selectedCategories.isEmpty) incomplete.add('selectedCategories');
    
    return incomplete;
  }

  bool get isProfileComplete {
    return getIncompleteFields().isEmpty;
  }

  User updateProfileCompletion() {
    final incomplete = getIncompleteFields();
    return copyWith(
      profileComplete: incomplete.isEmpty,
      incompleteFields: incomplete,
    );
  }

  // Check if user is newly registered (within last 7 days)
  bool get isNewUser => createdAt.isAfter(DateTime.now().subtract(const Duration(days: 7)));
}

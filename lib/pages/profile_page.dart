import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/user.dart' as user_models;
import '../models/notification_settings.dart';
import '../services/firebase_service.dart';
import '../services/theme_service.dart';
import '../services/profile_sync_service.dart';
import '../services/user_notifier.dart';
import '../widgets/app_logo.dart';
import '../main.dart';
import 'edit_profile_page.dart';
import 'security_page.dart';
import 'notification_settings_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  user_models.User? _user;
  bool _isLoading = true;
  bool _profileUpdated = false;
  bool _hasInitialized = false;
  File? _cachedProfileImage;
  final ThemeService _themeService = ThemeService();
  
  // User notifier for profile updates
  final UserNotifier _userNotifier = UserNotifier();

  @override
  void initState() {
    super.initState();
    
    // Listen for user profile changes
    _userNotifier.addListener(_onUserProfileChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hasInitialized) {
      _hasInitialized = true;
      _loadUserData();
    }
  }
  
  @override
  void dispose() {
    _userNotifier.removeListener(_onUserProfileChanged);
    super.dispose();
  }
  
  /// Called when user profile notifier signals a change
  void _onUserProfileChanged() {
    if (mounted) {
      // User profile change detected, refreshing data
      _loadUserData();
    }
  }

  Future<void> _loadUserData() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final user = await FirebaseService.getUser();
      if (mounted) {
        setState(() {
          _user = user;
        });
        
        // Load profile picture from cache/cloud
        if (user != null) {
          try {
            final profileImage = await ProfileSyncService.getProfilePicture(user);
            if (mounted) {
              setState(() {
                _cachedProfileImage = profileImage;
                _isLoading = false;
              });
            }
          } catch (e) {
            debugPrint('Error loading profile picture in profile page: $e');
            if (mounted) {
              setState(() {
                _cachedProfileImage = null;
                _isLoading = false;
              });
            }
          }
        } else {
          if (mounted) {
            setState(() {
              _cachedProfileImage = null;
              _isLoading = false;
            });
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error loading user data: $e')),
            );
          }
        });
      }
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _themeService.resetToLightTheme();
      await FirebaseService.logout();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const MyApp()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Profile',
          style: TextStyle(
            color: theme.appBarTheme.foregroundColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.appBarTheme.foregroundColor),
          onPressed: () {
            Navigator.of(context).pop(_profileUpdated);
          },
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: theme.appBarTheme.foregroundColor),
            onPressed: _loadUserData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadUserData,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Adjust padding based on screen width
                  final isNarrowScreen = constraints.maxWidth < 600;
                  final horizontalPadding = isNarrowScreen ? 16.0 : 20.0;
                  
                  return SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.all(horizontalPadding),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Enhanced Profile Header
                        _buildProfileHeader(),
                        const SizedBox(height: 32),

                        // Settings Section
                        _buildSettingsSection(),
                        const SizedBox(height: 40),
                      ],
                    ),
                  );
                },
              ),
            ),
    );
  }

  Widget _buildProfileHeader() {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        // Determine responsive layout parameters
        final isNarrowScreen = constraints.maxWidth < 600;
        final isVeryNarrowScreen = constraints.maxWidth < 400;
        final isExtremelyNarrowScreen = constraints.maxWidth < 320;
        final isUltraNarrowScreen = constraints.maxWidth < 280; // Added for ultra narrow screens
        final headerPadding = isUltraNarrowScreen ? 16.0 : isExtremelyNarrowScreen ? 18.0 : isNarrowScreen ? 20.0 : 24.0;
        
        return Container(
          width: double.infinity,
          padding: EdgeInsets.all(headerPadding),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                theme.colorScheme.primary.withValues(alpha: 0.1),
                theme.colorScheme.secondary.withValues(alpha: 0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: theme.shadowColor.withValues(alpha: 0.08),
                spreadRadius: 0,
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Check if we need to stack vertically for small screens
              final isNarrowScreen = constraints.maxWidth < 500;
              
              if (isNarrowScreen) {
                // Vertical layout for narrow screens
                return Column(
                  children: [
                    // Profile Picture and Email
                    _buildProfilePictureSection(theme, isNarrowScreen, isVeryNarrowScreen),
                    const SizedBox(height: 24),
                    // Name and Details
                    _buildProfileInfoSection(theme, isNarrowScreen, isVeryNarrowScreen),
                  ],
                );
              } else {
                // Horizontal layout for wider screens (preserve current layout)
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left side - Profile Picture and Email
                    _buildProfilePictureSection(theme, isNarrowScreen, isVeryNarrowScreen),
                    const SizedBox(width: 24),
                    // Right side - Name and Details
                    Expanded(
                      child: _buildProfileInfoSection(theme, isNarrowScreen, isVeryNarrowScreen),
                    ),
                  ],
                );
              }
            },
          ),
        );
      },
    );
  }

  Widget _buildProfilePictureSection(ThemeData theme, [bool isNarrowScreen = false, bool isVeryNarrowScreen = false]) {
    // Responsive sizing following typography standards
    final isExtremelyNarrowScreen = MediaQuery.of(context).size.width < 320;
    final isUltraNarrowScreen = MediaQuery.of(context).size.width < 280; // Added for ultra narrow screens
    final profileImageRadius = isUltraNarrowScreen ? 40.0 : isExtremelyNarrowScreen ? 45.0 : isNarrowScreen ? 50.0 : 55.0;
    final profileIconSize = isUltraNarrowScreen ? 40.0 : isExtremelyNarrowScreen ? 45.0 : isNarrowScreen ? 50.0 : 55.0;
    final nameFontSize = isUltraNarrowScreen ? 16.0 : isExtremelyNarrowScreen ? 18.0 : isNarrowScreen ? 20.0 : 22.0; // Display/Title range (16–22sp)
    final emailFontSize = isUltraNarrowScreen ? 10.0 : isExtremelyNarrowScreen ? 11.0 : isNarrowScreen ? 12.0 : 13.0; // Secondary Text range (10–13sp)
    final spacingAfterImage = isUltraNarrowScreen ? 10.0 : isExtremelyNarrowScreen ? 11.0 : isNarrowScreen ? 12.0 : 14.0;
    final spacingAfterName = isUltraNarrowScreen ? 4.0 : isExtremelyNarrowScreen ? 5.0 : isNarrowScreen ? 6.0 : 8.0;
    
    return Column(
      children: [
        // Profile Picture
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: theme.colorScheme.primary.withValues(alpha: 0.2),
              width: 3,
            ),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                spreadRadius: 2,
                blurRadius: 10,
              ),
            ],
          ),
          child: CircleAvatar(
            radius: profileImageRadius,
            backgroundColor: theme.brightness == Brightness.dark 
                ? theme.colorScheme.surface.withValues(alpha: 0.8)
                : theme.colorScheme.primary.withValues(alpha: 0.1),
            backgroundImage: _cachedProfileImage != null && _cachedProfileImage!.existsSync()
                ? FileImage(_cachedProfileImage!)
                : null,
            child: _cachedProfileImage == null || !_cachedProfileImage!.existsSync()
                ? Icon(
                    Icons.person,
                    size: profileIconSize,
                    color: theme.colorScheme.primary,
                  )
                : null,
          ),
        ),
        SizedBox(height: spacingAfterImage),
        // Name
        Text(
          _user?.name ?? 'Test User',
          style: TextStyle(
            fontSize: nameFontSize,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
            letterSpacing: -0.5,
          ),
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
          maxLines: 2,
        ),
        SizedBox(height: spacingAfterName),
        // Email
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: isNarrowScreen ? 10 : 12, 
            vertical: isNarrowScreen ? 5 : 6
          ),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            _user?.email ?? 'test@example.com',
            style: TextStyle(
              fontSize: emailFontSize,
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildProfileInfoSection(ThemeData theme, bool isNarrowScreen, [bool isVeryNarrowScreen = false]) {
    return Column(
      crossAxisAlignment: isNarrowScreen ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        // User Details
        _buildUserDetailsGrid(isNarrowScreen, isVeryNarrowScreen),
      ],
    );
  }

  Widget _buildUserDetailsGrid([bool isNarrowScreen = false, bool isVeryNarrowScreen = false]) {
    if (_user == null) return const SizedBox.shrink();
    
    final theme = Theme.of(context);
    final details = <Map<String, dynamic>>[];
    
    // Responsive sizing following typography standards
    final isExtremelyNarrowScreen = MediaQuery.of(context).size.width < 320;
    final isUltraNarrowScreen = MediaQuery.of(context).size.width < 280; // Added for ultra narrow screens
    final labelFontSize = isUltraNarrowScreen ? 10.0 : isExtremelyNarrowScreen ? 11.0 : isNarrowScreen ? 12.0 : 13.0; // Captions range (10–13sp)
    final valueFontSize = isUltraNarrowScreen ? 12.0 : isExtremelyNarrowScreen ? 13.0 : isNarrowScreen ? 14.0 : 15.0; // Secondary Text range (12–15sp)
    final iconSize = isUltraNarrowScreen ? 12.0 : isExtremelyNarrowScreen ? 13.0 : isNarrowScreen ? 14.0 : 15.0;
    final containerPadding = isUltraNarrowScreen ? 10.0 : isExtremelyNarrowScreen ? 11.0 : isNarrowScreen ? 12.0 : 14.0;
    final iconPadding = isUltraNarrowScreen ? 4.0 : isExtremelyNarrowScreen ? 4.5 : isNarrowScreen ? 5.0 : 6.0;
    final itemSpacing = isUltraNarrowScreen ? 8.0 : isExtremelyNarrowScreen ? 9.0 : isNarrowScreen ? 10.0 : 11.0;
    
    if (_user!.profession != null) {
      details.add({
        'icon': Icons.work_outline,
        'label': 'Status',
        'value': _user!.statusDisplayName,
      });
    }
    
    if (_user!.birthYear != null) {
      details.add({
        'icon': Icons.cake_outlined,
        'label': 'Age Group',
        'value': _user!.ageGroup,
      });
    }
    
    if (_user!.gender != null) {
      details.add({
        'icon': Icons.person_outline,
        'label': 'Gender',
        'value': _user!.genderDisplayName,
      });
    }
    
    // Add Monthly Net after Gender
    if (_user!.monthlyNet != null) {
      details.add({
        'icon': Icons.trending_up,
        'label': 'Monthly Net',
        'value': '₱${_user!.monthlyNet!.toStringAsFixed(0)}',
      });
    }
    
    // Add Number of Children if user has kids
    if (_user!.hasKids == true && _user!.numberOfChildren != null) {
      details.add({
        'icon': Icons.child_care,
        'label': 'Children',
        'value': _user!.numberOfChildrenDisplayName,
      });
    }
    
    if (details.isEmpty) return const SizedBox.shrink();
    
    return Container(
      padding: EdgeInsets.all(containerPadding),
      decoration: BoxDecoration(
        color: theme.cardTheme.color?.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: details.asMap().entries.map((entry) {
          final detail = entry.value;
          return Padding(
            padding: EdgeInsets.only(
              bottom: entry.key < details.length - 1 ? itemSpacing : 0,
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(iconPadding),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    detail['icon'],
                    size: iconSize,
                    color: theme.colorScheme.primary,
                  ),
                ),
                SizedBox(width: itemSpacing),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        detail['label'],
                        style: TextStyle(
                          fontSize: labelFontSize,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        detail['value'],
                        style: TextStyle(
                          fontSize: valueFontSize,
                          color: theme.colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSettingsSection() {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        // Determine responsive layout parameters
        final isNarrowScreen = constraints.maxWidth < 600;
        final isVeryNarrowScreen = constraints.maxWidth < 400;
        
        // Responsive sizing following typography standards
        final titleFontSize = isNarrowScreen ? 18.0 : 20.0; // Section Heading range (20–24sp)
        final spacingAfterTitle = isNarrowScreen ? 12.0 : 16.0;
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Settings & Account',
              style: TextStyle(
                fontSize: titleFontSize,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            SizedBox(height: spacingAfterTitle),
            Container(
              decoration: BoxDecoration(
                color: theme.cardTheme.color,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: theme.dividerColor.withValues(alpha: 0.3),
                ),
                boxShadow: [
                  BoxShadow(
                    color: theme.shadowColor.withValues(alpha: 0.05),
                    spreadRadius: 0,
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _buildSettingsItem(
                    icon: Icons.person_outline,
                    title: 'Edit Profile',
                    subtitle: 'Update your personal information',
                    color: Colors.blue,
                    isNarrowScreen: isNarrowScreen,
                    isVeryNarrowScreen: isVeryNarrowScreen,
                    onTap: () async {
                      if (_user != null) {
                        final result = await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => EditProfilePage(user: _user!),
                          ),
                        );
                        if (result == true) {
                          _profileUpdated = true;
                          _loadUserData();
                        }
                      }
                    },
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  _buildSettingsItem(
                    icon: Icons.security_outlined,
                    title: 'Security',
                    subtitle: 'Password and security settings',
                    color: Colors.green,
                    isNarrowScreen: isNarrowScreen,
                    isVeryNarrowScreen: isVeryNarrowScreen,
                    onTap: () {
                      if (_user != null) {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => SecurityPage(user: _user!),
                          ),
                        );
                      }
                    },
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  _buildThemeToggle(isNarrowScreen, isVeryNarrowScreen),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  _buildNotificationToggle(isNarrowScreen, isVeryNarrowScreen),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  _buildSettingsItem(
                    icon: Icons.info_outline,
                    title: 'About',
                    subtitle: 'App version and information',
                    color: Colors.purple,
                    isNarrowScreen: isNarrowScreen,
                    isVeryNarrowScreen: isVeryNarrowScreen,
                    onTap: () {
                      showAboutDialog(
                        context: context,
                        applicationName: 'PocketPilot',
                        applicationIcon: const AppLogo(
                          size: 48,
                        ),
                        children: [
                          const Text('Your Personal Financial Guide'),
                          const SizedBox(height: 16),
                          const Text('Track expenses, set goals, and build wealth smartly.'),
                          const SizedBox(height: 24),
                          const Text(
                            'About PocketPilot',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'PocketPilot is a mobile budgeting application that uses prescriptive analytics to provide personalized financial guidance. It helps users track expenses, plan budgets, and gain insights into their spending habits, empowering them to make informed financial decisions.',
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'Developed By:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text('Mina, Rovic'),
                          const Text('Nicolas, Kharylle'),
                          const Text('Pulido, Razheed'),
                          const Text('Guevarra, Camille'),
                          const SizedBox(height: 24),
                          const Text(
                            'Capstone Adviser:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text('Dr. Jennifer P. Solis'),
                          const SizedBox(height: 24),
                          const Text(
                            'Institution:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text('Bulacan State University – Bustos Campus'),
                          const Text('Bachelor of Science in Information Technology'),
                          const Text('Specialization: Business Analytics'),
                          const SizedBox(height: 24),
                          const Text(
                            'Purpose:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'This app was developed as part of a capstone project to promote financial literacy and responsible money management among users, combining practical budgeting tools with data-driven recommendations.',
                          ),
                        ],
                      );
                    },
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  _buildSettingsItem(
                    icon: Icons.logout,
                    title: 'Logout',
                    subtitle: 'Sign out of your account',
                    color: Colors.red,
                    isNarrowScreen: isNarrowScreen,
                    isVeryNarrowScreen: isVeryNarrowScreen,
                    onTap: _logout,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSettingsItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
    bool isNarrowScreen = false,
    bool isVeryNarrowScreen = false,
  }) {
    final theme = Theme.of(context);
    
    // Responsive sizing following typography standards
    final titleFontSize = isNarrowScreen ? 14.0 : 16.0; // Body Text range (14–16sp)
    final subtitleFontSize = isNarrowScreen ? 11.0 : 13.0; // Secondary Text range (12–14sp)
    final iconSize = isNarrowScreen ? 20.0 : 22.0;
    final iconPadding = isNarrowScreen ? 8.0 : 10.0;
    final trailingIconSize = isNarrowScreen ? 12.0 : 14.0;
    final horizontalPadding = isNarrowScreen ? 16.0 : 20.0;
    final verticalPadding = isNarrowScreen ? 6.0 : 8.0;
    
    return ListTile(
      contentPadding: EdgeInsets.symmetric(
        horizontal: horizontalPadding, 
        vertical: verticalPadding
      ),
      leading: Container(
        padding: EdgeInsets.all(iconPadding),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          color: color,
          size: iconSize,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: titleFontSize,
          fontWeight: FontWeight.w600,
          color: title == 'Logout' ? Colors.red : theme.colorScheme.onSurface,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: subtitleFontSize,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
        ),
        maxLines: isVeryNarrowScreen ? 2 : 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Icon(
        Icons.arrow_forward_ios,
        size: trailingIconSize,
        color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
      ),
      onTap: onTap,
    );
  }

  Widget _buildThemeToggle([bool isNarrowScreen = false, bool isVeryNarrowScreen = false]) {
    final theme = Theme.of(context);
    
    // Responsive sizing following typography standards
    final titleFontSize = isNarrowScreen ? 14.0 : 16.0; // Body Text range (14–16sp)
    final subtitleFontSize = isNarrowScreen ? 11.0 : 13.0; // Secondary Text range (12–14sp)
    final iconSize = isNarrowScreen ? 20.0 : 22.0;
    final iconPadding = isNarrowScreen ? 8.0 : 10.0;
    final horizontalPadding = isNarrowScreen ? 16.0 : 20.0;
    final verticalPadding = isNarrowScreen ? 6.0 : 8.0;
    
    return ListTile(
      contentPadding: EdgeInsets.symmetric(
        horizontal: horizontalPadding, 
        vertical: verticalPadding
      ),
      leading: Container(
        padding: EdgeInsets.all(iconPadding),
        decoration: BoxDecoration(
          color: Colors.indigo.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          _themeService.isDarkMode ? Icons.dark_mode : Icons.light_mode,
          color: Colors.indigo,
          size: iconSize,
        ),
      ),
      title: Text(
        'Dark Mode',
        style: TextStyle(
          fontSize: titleFontSize,
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.onSurface,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        isVeryNarrowScreen 
            ? 'Switch themes'
            : 'Switch between light and dark theme',
        style: TextStyle(
          fontSize: subtitleFontSize,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
        ),
        maxLines: isVeryNarrowScreen ? 2 : 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: AnimatedBuilder(
        animation: _themeService,
        builder: (context, child) {
          return Switch(
            value: _themeService.isDarkMode,
            onChanged: (value) async {
              final messenger = ScaffoldMessenger.of(context);
              try {
                await _themeService.toggleTheme();
              } catch (e) {
                if (mounted) {
                  messenger.showSnackBar(
                    SnackBar(content: Text('Failed to update theme: $e')),
                  );
                }
              }
            },
            activeColor: Colors.indigo,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          );
        },
      ),
    );
  }

  Widget _buildNotificationToggle([bool isNarrowScreen = false, bool isVeryNarrowScreen = false]) {
    final theme = Theme.of(context);
    final scaffoldContext = context; // Store context to avoid issues with FutureBuilder
    
    // Responsive sizing following typography standards
    final titleFontSize = isNarrowScreen ? 14.0 : 16.0; // Body Text range (14–16sp)
    final subtitleFontSize = isNarrowScreen ? 11.0 : 13.0; // Secondary Text range (12–14sp)
    final iconSize = isNarrowScreen ? 20.0 : 22.0;
    final iconPadding = isNarrowScreen ? 8.0 : 10.0;
    final horizontalPadding = isNarrowScreen ? 16.0 : 20.0;
    final verticalPadding = isNarrowScreen ? 6.0 : 8.0;
    
    return ListTile(
      contentPadding: EdgeInsets.symmetric(
        horizontal: horizontalPadding, 
        vertical: verticalPadding
      ),
      leading: Container(
        padding: EdgeInsets.all(iconPadding),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          Icons.notifications_outlined,
          color: Colors.orange,
          size: iconSize,
        ),
      ),
      title: Text(
        'App Notifications',
        style: TextStyle(
          fontSize: titleFontSize,
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.onSurface,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        isVeryNarrowScreen 
            ? 'Enable/disable all notifications'
            : 'Enable or disable all app notifications',
        style: TextStyle(
          fontSize: subtitleFontSize,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
        ),
        maxLines: isVeryNarrowScreen ? 2 : 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: FutureBuilder<bool>(
        future: _areNotificationsEnabled(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            );
          }
          
          final isEnabled = snapshot.data ?? true;
          
          return Switch(
            value: isEnabled,
            onChanged: (value) async {
              debugPrint('Notification toggle changed to: $value');
              // Show confirmation dialog before changing notification settings
              final confirmed = await _showNotificationConfirmationDialog(scaffoldContext, value);
              debugPrint('Dialog result: $confirmed');
              if (confirmed == true) {
                debugPrint('User confirmed notification change to: $value');
                await _setNotificationsEnabled(value);
                if (scaffoldContext.mounted) {
                  setState(() {}); // Refresh the widget
                }
              } else {
                debugPrint('User cancelled notification change or dialog was dismissed');
              }
            },
            activeColor: Colors.orange,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          );
        },
      ),
    );
  }

  /// Show confirmation dialog before changing notification settings
  Future<bool?> _showNotificationConfirmationDialog(BuildContext context, bool willEnable) async {
    try {
      // Add a small delay to ensure the UI is ready
      await Future.delayed(const Duration(milliseconds: 100));
      
      final result = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text(willEnable ? 'Enable Notifications' : 'Disable Notifications'),
            content: Text(
              willEnable
                  ? 'Are you sure you want to enable all app notifications?'
                  : 'Are you sure you want to disable all app notifications? This will stop all reminder and update notifications.'
            ),
            actions: [
              TextButton(
                onPressed: () {
                  debugPrint('User cancelled notification change');
                  Navigator.of(context).pop(false);
                },
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  debugPrint('User confirmed notification change to: $willEnable');
                  Navigator.of(context).pop(true);
                },
                child: Text(willEnable ? 'Enable' : 'Disable'),
              ),
            ],
          );
        },
      );
      
      debugPrint('Dialog returned result: $result');
      return result;
    } catch (e) {
      debugPrint('Error showing notification confirmation dialog: $e');
      // In case of error, we don't change the notification settings
      return false;
    }
  }

  /// Check if notifications are enabled
  Future<bool> _areNotificationsEnabled() async {
    try {
      final settings = await NotificationSettings.load();
      // Check if any notification is enabled
      return settings.budgetExceededEnabled ||
          settings.dailyReminderEnabled ||
          settings.budgetingTipsEnabled ||
          settings.goalProgressEnabled ||
          settings.weeklySummaryEnabled;
    } catch (e) {
      debugPrint('Error checking notification status: $e');
      return true; // Default to enabled if there's an error
    }
  }

  /// Enable or disable all notifications
  Future<void> _setNotificationsEnabled(bool enabled) async {
    try {
      if (enabled) {
        // Check if notification permissions have been granted
        final status = await Permission.notification.status;
        
        if (status.isDenied || status.isPermanentlyDenied) {
          // Show a dialog explaining why we need notification permissions
          if (mounted) {
            final shouldOpenSettings = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Notification Permission Required'),
                content: const Text(
                  'To receive notifications, you need to enable notification permissions in your device settings. '
                  'Would you like to go to settings now?'
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('Go to Settings'),
                  ),
                ],
              ),
            );
            
            if (shouldOpenSettings == true) {
              // Open device notification settings
              await openAppSettings();
            }
            
            // Don't enable notifications in the app settings if permissions aren't granted
            return;
          }
        }
      }
      
      final settings = enabled 
          ? const NotificationSettings() // All notifications enabled by default
          : NotificationSettings.none(); // All notifications disabled
      
      await settings.save();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              enabled 
                  ? 'Notifications enabled' 
                  : 'Notifications disabled'
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to ${enabled ? 'enable' : 'disable'} notifications: $e'
            ),
          ),
        );
      }
    }
  }
}
import 'package:flutter/material.dart';

class UserGuideDialog extends StatefulWidget {
  const UserGuideDialog({super.key});

  @override
  State<UserGuideDialog> createState() => _UserGuideDialogState();
}

class _UserGuideDialogState extends State<UserGuideDialog> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<UserGuidePage> _guidePages = [
    UserGuidePage(
      title: 'Dashboard',
      content: 'Your starting point when you open the app.\n'
          'Shows tailored budgeting tips based on your profile.\n'
          'Displays an overview of income, expenses, and savings.\n'
          'Provides quick insights to guide your financial decisions.',
    ),
    UserGuidePage(
      title: 'Calendar',
      content: 'Shows your financial actions by date.\n'
          'Lets you add reminders for bills, savings, or debts.\n'
          'Swipe between months to review past and upcoming entries.',
    ),
    UserGuidePage(
      title: 'Add Transaction',
      content: 'Record your financial activities in five steps:\n'
          '1. Select Category – Choose Income or Expense etc.\n'
          '2. If Expense, pick an Expense Category (food, bills, transport, etc.).\n'
          '3. Enter Amount – Type in the value.\n'
          '4. Write Notes – (Optional) Add details like "grocery," "salary," or "rent."\n'
          '5. Select Date – Choose when it happened.\n'
          '6. Save – The entry will appear in Calendar and Transactions.',
    ),
    UserGuidePage(
      title: 'Transactions',
      content: 'View all your logged financial actions in a list.\n'
          'Delete entries that you no longer need.',
    ),
    UserGuidePage(
      title: 'Budget',
      content: 'Your monthly budget allocation.\n'
          'Daily expenses tracker to monitor everyday spending.\n'
          'Monthly fixed expenses like rent, utilities, or subscriptions.\n'
          'Your emergency fund progress for the month.',
    ),
    UserGuidePage(
      title: 'Tips for Best Results',
      content: 'Log transactions daily for the most accurate insights.\n'
          'Use reminders to avoid missed bills or skipped savings.\n'
          'Review your Dashboard and Budget weekly.\n'
          'More complete data = smarter budgeting tips.',
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Responsive sizing based on screen width
          final isNarrowScreen = constraints.maxWidth < 600;
          final dialogWidth = isNarrowScreen 
              ? constraints.maxWidth * 0.95 
              : constraints.maxWidth * 0.8;
          final dialogHeight = isNarrowScreen 
              ? constraints.maxHeight * 0.8 
              : constraints.maxHeight * 0.7;
          
          // Typography sizing
          final titleFontSize = isNarrowScreen ? 18.0 : 20.0; // Section Heading range (more appropriate for dialog titles)
          final buttonTextFontSize = isNarrowScreen ? 14.0 : 16.0; // Button range
          final pageIndicatorSize = isNarrowScreen ? 8.0 : 10.0;
          
          return Container(
            width: dialogWidth,
            height: dialogHeight,
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                // Header with title and close button
                Container(
                  padding: EdgeInsets.all(isNarrowScreen ? 12 : 16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'PocketPilot User Guide',
                          style: TextStyle(
                            fontSize: titleFontSize,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.close,
                          color: theme.colorScheme.onPrimary,
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
                
                // Page content
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _guidePages.length,
                    onPageChanged: (index) {
                      setState(() {
                        _currentPage = index;
                      });
                    },
                    itemBuilder: (context, index) {
                      return _guidePages[index];
                    },
                  ),
                ),
                
                // Navigation controls
                Container(
                  padding: EdgeInsets.all(isNarrowScreen ? 12 : 16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    border: Border(
                      top: BorderSide(
                        color: theme.dividerColor,
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Previous button
                      if (_currentPage > 0)
                        TextButton(
                          onPressed: () {
                            _pageController.previousPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          },
                          child: Text(
                            'Previous',
                            style: TextStyle(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w600,
                              fontSize: buttonTextFontSize,
                            ),
                          ),
                        )
                      else
                        const SizedBox.shrink(),
                      
                      // Page indicators
                      Row(
                        children: List.generate(_guidePages.length, (index) {
                          return Container(
                            margin: EdgeInsets.symmetric(horizontal: isNarrowScreen ? 2 : 4),
                            width: pageIndicatorSize,
                            height: pageIndicatorSize,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _currentPage == index
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onSurface.withValues(alpha: 0.2),
                            ),
                          );
                        }),
                      ),
                      
                      // Next/Finish button
                      if (_currentPage < _guidePages.length - 1)
                        TextButton(
                          onPressed: () {
                            _pageController.nextPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          },
                          child: Text(
                            'Next',
                            style: TextStyle(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w600,
                              fontSize: buttonTextFontSize,
                            ),
                          ),
                        )
                      else
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text(
                            'Finish',
                            style: TextStyle(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w600,
                              fontSize: buttonTextFontSize,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class UserGuidePage extends StatelessWidget {
  final String title;
  final String content;

  const UserGuidePage({
    super.key,
    required this.title,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrowScreen = constraints.maxWidth < 600;
        final padding = isNarrowScreen ? 16.0 : 24.0;
        final titleFontSize = isNarrowScreen ? 20.0 : 24.0; // Section Heading range
        final contentFontSize = isNarrowScreen ? 14.0 : 16.0; // Body Text range
        final titleSpacing = isNarrowScreen ? 16.0 : 24.0;
        
        // Process content to remove unnecessary spaces while preserving line breaks
        final processedContent = content.replaceAll(RegExp(r'\n\s*\n'), '\n');
        
        return Padding(
          padding: EdgeInsets.all(padding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Page title
              Text(
                title,
                style: TextStyle(
                  fontSize: titleFontSize,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
              SizedBox(height: titleSpacing),
              
              // Content
              Expanded(
                child: SingleChildScrollView(
                  child: Text(
                    processedContent,
                    style: TextStyle(
                      fontSize: contentFontSize,
                      height: 1.5,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
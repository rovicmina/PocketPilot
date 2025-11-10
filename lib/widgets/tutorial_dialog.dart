import 'package:flutter/material.dart';

class TutorialDialog extends StatefulWidget {
  const TutorialDialog({super.key});

  @override
  State<TutorialDialog> createState() => _TutorialDialogState();
}

class _TutorialDialogState extends State<TutorialDialog> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<TutorialPage> _tutorialPages = [
    TutorialPage(
      question: 'What can I do on the Dashboard?',
      answer: 'The Dashboard is your home screen. It shows:\n'
          '• Budgeting tips designed for your profile.\n'
          '• A quick look at your income, expenses, and savings.\n'
          '• Insights on whether you\'re staying on track with your finances.',
    ),
    TutorialPage(
      question: 'What\'s in the Calendar?',
      answer: 'The Calendar helps organize your finances by date. You can:\n'
          '• See all transactions logged on specific days.\n'
          '• Add reminders for bills, savings goals, or debt payments.\n'
          '• Swipe across months to check past activity or prepare ahead.',
    ),
    TutorialPage(
      question: 'How do I add a transaction?',
      answer: 'To log a new transaction:\n'
          '1. Choose Category – Income or Expense etc.\n'
          '2. If Expense, pick a specific Expense Category.\n'
          '3. Enter Amount – Input the number.\n'
          '4. Add Notes – (Optional) Write details like "salary bonus" or "grocery shopping."\n'
          '5. Pick Date – Select when it happened.\n'
          '6. Save – The record shows up in your Calendar and Transactions list.',
    ),
    TutorialPage(
      question: 'Where can I see all my transactions?',
      answer: 'Go to the Transactions page. There, you can:\n'
          '• Review every financial action you\'ve added.\n'
          '• Delete transactions if you need to fix mistakes.',
    ),
    TutorialPage(
      question: 'What\'s on the Budget page?',
      answer: 'The Budget page is focused on the current month. It includes:\n'
          '• Your budget allocation (how much is set for different categories).\n'
          '• A daily expense tracker to monitor day-to-day spending.\n'
          '• Monthly fixed expenses such as rent, utilities, or subscriptions.\n'
          '• An emergency fund tracker to see how much you\'ve saved toward your safety net.',
    ),
    TutorialPage(
      question: 'How do I get the best results from PocketPilot?',
      answer: '• Log daily so your reports are accurate.\n'
          '• Set reminders to avoid late payments.\n'
          '• Review Dashboard and Budget weekly to stay on track.\n'
          '• The more data you enter, the more useful and personalized your tips will be.',
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
                          'PocketPilot Tutorial',
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
                    itemCount: _tutorialPages.length,
                    onPageChanged: (index) {
                      setState(() {
                        _currentPage = index;
                      });
                    },
                    itemBuilder: (context, index) {
                      return _tutorialPages[index];
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
                        children: List.generate(_tutorialPages.length, (index) {
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
                      if (_currentPage < _tutorialPages.length - 1)
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

class TutorialPage extends StatelessWidget {
  final String question;
  final String answer;

  const TutorialPage({
    super.key,
    required this.question,
    required this.answer,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrowScreen = constraints.maxWidth < 600;
        final padding = isNarrowScreen ? 16.0 : 24.0;
        final questionFontSize = isNarrowScreen ? 18.0 : 20.0; // Section Heading range
        final answerLabelFontSize = isNarrowScreen ? 16.0 : 18.0; // Subheading range
        final answerFontSize = isNarrowScreen ? 14.0 : 16.0; // Body Text range
        final questionSpacing = isNarrowScreen ? 12.0 : 16.0;
        final answerLabelSpacing = isNarrowScreen ? 6.0 : 8.0;
        
        // Process answer to remove unnecessary spaces while preserving line breaks
        final processedAnswer = answer.replaceAll(RegExp(r'\\n\\s*\\n'), '\\n');
        
        return Padding(
          padding: EdgeInsets.all(padding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Question
              Text(
                'Q: $question',
                style: TextStyle(
                  fontSize: questionFontSize,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
              SizedBox(height: questionSpacing),
              
              // Answer label
              Text(
                'A:',
                style: TextStyle(
                  fontSize: answerLabelFontSize,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              SizedBox(height: answerLabelSpacing),
              
              // Answer content
              Expanded(
                child: SingleChildScrollView(
                  child: Text(
                    processedAnswer,
                    style: TextStyle(
                      fontSize: answerFontSize,
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
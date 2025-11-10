import 'package:flutter/material.dart';

class TutorialFeedback extends StatefulWidget {
  final VoidCallback onSubmit;
  final Function(String feedback) onFeedbackSubmitted;

  const TutorialFeedback({
    super.key,
    required this.onSubmit,
    required this.onFeedbackSubmitted,
  });

  @override
  State<TutorialFeedback> createState() => _TutorialFeedbackState();
}

class _TutorialFeedbackState extends State<TutorialFeedback> {
  final TextEditingController _feedbackController = TextEditingController();
  double _rating = 0.0;

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('Tutorial Feedback'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('How would you rate this tutorial?'),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                return IconButton(
                  icon: Icon(
                    index < _rating ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                  ),
                  onPressed: () {
                    setState(() {
                      _rating = index + 1.0;
                    });
                  },
                );
              }),
            ),
            const SizedBox(height: 16),
            const Text('Additional feedback (optional):'),
            const SizedBox(height: 8),
            TextField(
              controller: _feedbackController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'What did you like? What could be improved?',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            widget.onSubmit();
          },
          child: const Text('Skip'),
        ),
        ElevatedButton(
          onPressed: () {
            widget.onFeedbackSubmitted(_feedbackController.text);
            Navigator.of(context).pop();
            widget.onSubmit();
          },
          child: const Text('Submit'),
        ),
      ],
    );
  }
}
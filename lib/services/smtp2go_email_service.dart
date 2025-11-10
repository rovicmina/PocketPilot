import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/user.dart';

/// SMTP2GO Email Service - No domain verification required
class SMTP2GOEmailService {
  // SMTP2GO Configuration
  static const String _apiKey = 'api-AD4C1926DF3D44D28ADCD3B2F9458075'; // Your actual API key
  static const String _apiUrl = 'https://api.smtp2go.com/v3/email/send';
  static const String _fromEmail = '2018200697@ms.bulsu.edu.ph'; // Your university email
  
  /// Send email using SMTP2GO
  static Future<bool> sendEmail({
    required String toEmail,
    required String toName,
    required String subject,
    required String htmlContent,
    String? textContent,
  }) async {
    final startTime = DateTime.now();
    debugPrint('📧 SMTP2GO: Sending email to $toEmail...');
    
    try {
      // Validate inputs
      if (toEmail.isEmpty || subject.isEmpty || htmlContent.isEmpty) {
        debugPrint('❌ SMTP2GO Error: Missing required email parameters');
        return false;
      }
      
      // Prepare email payload
      final emailData = {
        'api_key': _apiKey,
        'to': [toEmail],
        'sender': _fromEmail,
        'subject': subject,
        'html_body': htmlContent,
        'text_body': textContent ?? _htmlToText(htmlContent),
        'custom_headers': [],
        'attachments': [], // No attachments for now
        'template_id': null, // Using custom HTML
      };
      
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(emailData),
      ).timeout(const Duration(seconds: 15));
      
      final processingTime = DateTime.now().difference(startTime).inMilliseconds;
      
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        
        debugPrint('📧 SMTP2GO Response: $responseData');
        
        if (responseData['data']['succeeded'] > 0) {
          debugPrint('✅ SMTP2GO: Email sent successfully in ${processingTime}ms');
          debugPrint('📧 Email ID: ${responseData['data']['email_id']}');
          return true;
        } else {
          final errors = responseData['data']['failed'] ?? [];
          debugPrint('❌ SMTP2GO: Email failed to send: $errors');
          debugPrint('📧 Failed details: ${responseData['data']}');
          return false;
        }
      } else {
        final errorData = jsonDecode(response.body);
        debugPrint('❌ SMTP2GO API Error (${response.statusCode}): ${response.body}');
        
        // Handle specific error cases
        if (response.statusCode == 401) {
          debugPrint('🔑 API Key issue: Check your SMTP2GO API key');
        } else if (response.statusCode == 429) {
          debugPrint('⏱️ Rate limit exceeded: Please wait before sending more emails');
        } else if (response.statusCode == 400) {
          debugPrint('❌ Bad Request: ${errorData['errors'] ?? 'Invalid email data'}');
        }
        
        return false;
      }
      
    } catch (e) {
      final processingTime = DateTime.now().difference(startTime).inMilliseconds;
      debugPrint('❌ SMTP2GO Error after ${processingTime}ms: $e');
      return false;
    }
  }
  
  /// Send welcome email for new accounts
  static Future<bool> sendWelcomeEmail(User user) async {
    final htmlContent = _generateWelcomeEmailHTML(user);
    
    return await sendEmail(
      toEmail: user.email,
      toName: user.name.isNotEmpty ? user.name : 'New User',
      subject: 'Welcome to PocketPilot - Your Financial Journey Starts Here!',
      htmlContent: htmlContent,
    );
  }
  
  /// Send password reset email
  static Future<bool> sendPasswordResetEmail(String email) async {
    final htmlContent = _generatePasswordResetHTML(email);
    
    return await sendEmail(
      toEmail: email,
      toName: '',
      subject: 'Reset Your PocketPilot Password',
      htmlContent: htmlContent,
    );
  }
  

  
  /// Check if SMTP2GO is properly configured
  static bool get isConfigured {
    return _apiKey != 'api-your_smtp2go_api_key_here' && _apiKey.isNotEmpty;
  }
  
  /// Get current service status
  static String get status {
    if (!isConfigured) {
      return 'Configuration Required (API key not set)';
    }
    return 'SMTP2GO Service Ready (Domain-free)';
  }
  
  /// Print setup instructions
  static void printSetupInstructions() {
    debugPrint('\\n📧 SMTP2GO SETUP INSTRUCTIONS');
    debugPrint('==============================');
    debugPrint('SMTP2GO requires NO domain verification!');
    debugPrint('\\n1. Sign up at https://www.smtp2go.com');
    debugPrint('2. Verify your email address');
    debugPrint('3. Go to Settings > API Keys');
    debugPrint('4. Create a new API key');
    debugPrint('5. Copy the API key');
    debugPrint('6. Replace _apiKey in smtp2go_email_service.dart');
    debugPrint('\\nFree Tier: 1,000 emails/month');
    debugPrint('Paid Plans: Starting from \$10/month');
    debugPrint('\\nAdvantages:');
    debugPrint('✅ No domain verification required');
    debugPrint('✅ Immediate setup');
    debugPrint('✅ Good deliverability');
    debugPrint('✅ Professional service');
    debugPrint('\\nCurrent Status: $status');
    debugPrint('==============================\\n');
  }
  
  /// Test SMTP2GO service
  static Future<Map<String, dynamic>> testService() async {
    debugPrint('🧪 Testing SMTP2GO service...');
    
    final testResults = <String, dynamic>{};
    final startTime = DateTime.now();
    
    try {
      // Configuration check
      testResults['configured'] = isConfigured;
      testResults['api_key_set'] = _apiKey != 'api-your_smtp2go_api_key_here';
      
      if (!isConfigured) {
        testResults['success'] = false;
        testResults['error'] = 'API key not configured';
        return testResults;
      }
      
      // Test email sending
      final testUser = User(
        id: 'test-smtp2go',
        email: 'test@example.com',
        name: 'Test User',
        password: '',
        monthlyIncome: 0.0,
        createdAt: DateTime.now(),
      );
      
      final emailSent = await sendWelcomeEmail(testUser);
      
      testResults['email_sent'] = emailSent;
      testResults['processing_time_ms'] = DateTime.now().difference(startTime).inMilliseconds;
      testResults['success'] = emailSent;
      
      debugPrint('🧪 SMTP2GO Test Results:');
      debugPrint('✅ Configured: ${testResults['configured']}');
      debugPrint('✅ Email Sent: ${testResults['email_sent']}');
      debugPrint('⏱️ Processing Time: ${testResults['processing_time_ms']}ms');
      
    } catch (e) {
      testResults['success'] = false;
      testResults['error'] = e.toString();
      debugPrint('❌ SMTP2GO Test Failed: $e');
    }
    
    return testResults;
  }
  
  /// Convert HTML to plain text (basic implementation)
  static String _htmlToText(String html) {
    return html
        .replaceAll(RegExp(r'<[^>]*>'), '') // Remove HTML tags
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .trim();
  }
  
  /// Generate welcome email HTML
  static String _generateWelcomeEmailHTML(User user) {
    final userName = user.name.isNotEmpty ? user.name : 'New User';
    
    return '''
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Welcome to PocketPilot</title>
    <style>
      body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; margin: 0; padding: 20px; }
      .container { max-width: 600px; margin: 0 auto; }
      .header { text-align: center; margin-bottom: 30px; }
      .brand { color: #009688; font-size: 32px; font-weight: bold; }
      .content-box { background-color: #f5f5f5; padding: 20px; border-radius: 8px; margin-bottom: 20px; }
      .footer { text-align: center; margin-top: 30px; color: #666; font-size: 12px; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <img src="https://pocketpilot.app/logo.png" alt="PocketPilot Logo" style="width: 80px; height: 80px; margin-bottom: 10px;">
            <h1 class="brand">PocketPilot</h1>
            <h2 style="color: #666;">Welcome to Your Financial Journey!</h2>
        </div>
        
        <div class="content-box">
            <p>Dear $userName,</p>
            
            <p>Congratulations! Your PocketPilot account has been successfully created.</p>
            
            <p><strong>Your Account Details:</strong></p>
            <ul>
                <li>Email: ${user.email}</li>
                <li>Account Created: ${_formatDate(user.createdAt)}</li>
            </ul>
            
            <p>You can now start tracking your expenses, setting budgets, and achieving your financial goals!</p>
        </div>
        
        <div class="footer">
            <p><strong>The PocketPilot Team</strong></p>
            <p>© 2024 PocketPilot. All rights reserved.</p>
        </div>
    </div>
</body>
</html>
    ''';
  }
  
  /// Generate password reset email HTML
  static String _generatePasswordResetHTML(String email) {
    return '''
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Reset Your PocketPilot Password</title>
    <style>
      body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; margin: 0; padding: 20px; }
      .container { max-width: 600px; margin: 0 auto; }
      .header { text-align: center; margin-bottom: 30px; }
      .brand { color: #009688; font-size: 32px; font-weight: bold; }
      .content-box { background-color: #fff3cd; padding: 20px; border-radius: 8px; margin-bottom: 20px; border-left: 4px solid #ffc107; }
      .footer { text-align: center; margin-top: 30px; color: #666; font-size: 12px; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <img src="https://pocketpilot.app/logo.png" alt="PocketPilot Logo" style="width: 80px; height: 80px; margin-bottom: 10px;">
            <h1 class="brand">PocketPilot</h1>
            <h2 style="color: #666;">Password Reset Request</h2>
        </div>
        
        <div class="content-box">
            <p>Hello,</p>
            
            <p>We received a request to reset the password for your PocketPilot account associated with <strong>$email</strong>.</p>
            
            <p>If you made this request, you can reset your password using the forgot password feature in the app. For security reasons, password resets are handled through the app.</p>
            
            <p>If you didn't request a password reset, please ignore this email. Your account remains secure.</p>
            
            <p><strong>🔒 Security Tip:</strong> Never share your password with anyone.</p>
        </div>
        
        <div class="footer">
            <p><strong>The PocketPilot Team</strong></p>
            <p>© 2024 PocketPilot. All rights reserved.</p>
        </div>
    </div>
</body>
</html>
    ''';
  }
  

  
  /// Format date for display
  static String _formatDate(DateTime date) {
    final months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}
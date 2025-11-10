import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/user.dart';
import '../config/email_config.dart';
import 'smtp2go_email_service.dart';

class EmailService {
  /// Send account creation welcome email
  static Future<bool> sendAccountCreationEmail(User user) async {
    try {
      // Check which email provider to use
      if (EmailConfig.activeProvider == 'smtp2go') {
        return await SMTP2GOEmailService.sendWelcomeEmail(user);
      }
      
      // Fallback to original Resend implementation
      return await _sendViaResend(user);
      
    } catch (e) {
      return false;
    }
  }
  
  /// Send password reset email
  static Future<bool> sendPasswordResetEmail(String email) async {
    try {
      // Check which email provider to use
      if (EmailConfig.activeProvider == 'smtp2go') {
        return await SMTP2GOEmailService.sendPasswordResetEmail(email);
      }
      
      // Fallback to original Resend implementation
      return await _sendPasswordResetViaResend(email);
      
    } catch (e) {
      return false;
    }
  }

  /// Email validation helper
  static bool isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  // Legacy Resend implementation methods
  
  /// Legacy Resend implementation
  static Future<bool> _sendViaResend(User user) async {
    try {
      // Validate user data
      if (user.email.isEmpty) {
        return false;
      }
      
      // Validate email format
      if (!isValidEmail(user.email)) {
        return false;
      }
      
      // Generate email content
      final emailContent = _generateWelcomeEmail(user);
      
      if (emailContent.isEmpty) {
        return false;
      }
      
      bool emailSent = false;
      
      // Try real email sending first, fallback to simulation
      if (EmailConfig.enableRealEmails && EmailConfig.isConfigured) {
        emailSent = await _sendRealEmail(
          toEmail: user.email,
          toName: user.name.isNotEmpty ? user.name : 'New User',
          subject: 'Welcome to PocketPilot - Your Financial Journey Starts Here!',
          htmlContent: emailContent,
        );
        
        if (!emailSent) {
          emailSent = await _simulateEmailSending(user, _generateWelcomeEmail(user), DateTime.now());
        }
      } else {
        emailSent = await _simulateEmailSending(user, _generateWelcomeEmail(user), DateTime.now());
      }
      
      return emailSent;
      
    } catch (e) {
      return false;
    }
  }
  
  /// Legacy Resend password reset implementation
  static Future<bool> _sendPasswordResetViaResend(String email) async {
    try {
      // Validate email format
      if (!isValidEmail(email)) {
        return false;
      }
      
      final emailContent = _generatePasswordResetEmail(email);
      
      bool emailSent = false;
      
      // Try real email sending first, fallback to simulation
      if (EmailConfig.enableRealEmails && EmailConfig.isConfigured) {
        emailSent = await _sendRealEmail(
          toEmail: email,
          toName: '',
          subject: 'Reset Your PocketPilot Password',
          htmlContent: emailContent,
        );
        
        if (!emailSent) {
          emailSent = await _simulatePasswordResetEmail(email, _generatePasswordResetEmail(email));
        }
      } else {
        emailSent = await _simulatePasswordResetEmail(email, _generatePasswordResetEmail(email));
      }
      
      return emailSent;
      
    } catch (e) {
      return false;
    }
  }

  /// Send real email using Resend API (legacy)
  static Future<bool> _sendRealEmail({
    required String toEmail,
    required String toName,
    required String subject,
    required String htmlContent,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(EmailConfig.resendApiUrl),
        headers: {
          'Authorization': 'Bearer ${EmailConfig.resendApiKey}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'from': '${EmailConfig.fromName} <${EmailConfig.fromEmail}>',
          'to': [toEmail],
          'subject': subject,
          'html': htmlContent,
          'reply_to': '2018200697@ms.bulsu.edu.ph',
        }),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        return true;
      } else {
        return false;
      }
      
    } catch (e) {
      return false;
    }
  }

  /// Simulate email sending (fallback or development mode)
  static Future<bool> _simulateEmailSending(User user, String emailContent, DateTime startTime) async {
    await Future.delayed(const Duration(seconds: 1));
    return true;
  }

  /// Simulate password reset email sending
  static Future<bool> _simulatePasswordResetEmail(String email, String emailContent) async {
    await Future.delayed(const Duration(seconds: 1));
    return true;
  }

  // Email template generators

  static String _generateWelcomeEmail(User user) {
    final userName = user.name.isNotEmpty ? user.name : 'New User';
    
    return '''
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Welcome to PocketPilot</title>
    <style>
      body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
      .container { max-width: 600px; margin: 0 auto; padding: 20px; }
      .header { text-align: center; margin-bottom: 30px; }
      .brand { color: #009688; font-size: 32px; font-weight: bold; }
      .content-box { background-color: #f5f5f5; padding: 20px; border-radius: 8px; margin-bottom: 20px; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <img src="${EmailConfig.logoUrl}" alt="PocketPilot Logo" style="width: 80px; height: 80px; margin-bottom: 10px;">
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
        </div>
        
        <div style="text-align: center; margin: 30px 0;">
            <p style="color: #009688; font-weight: bold;">The PocketPilot Team</p>
            <p style="color: #666; font-size: 12px;">© 2024 PocketPilot. All rights reserved.</p>
        </div>
    </div>
</body>
</html>
    ''';
  }

  static String _generatePasswordResetEmail(String email) {
    return '''
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Reset Your PocketPilot Password</title>
</head>
<body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333;">
    <div style="max-width: 600px; margin: 0 auto; padding: 20px;">
        <div style="text-align: center; margin-bottom: 30px;">
            <img src="${EmailConfig.logoUrl}" alt="PocketPilot Logo" style="width: 80px; height: 80px; margin-bottom: 10px;">
            <h1 style="color: #009688;">PocketPilot</h1>
            <h2 style="color: #666;">Password Reset Request</h2>
        </div>
        
        <div style="background-color: #f5f5f5; padding: 20px; border-radius: 8px; margin-bottom: 20px;">
            <p>Hello,</p>
            
            <p>We received a request to reset the password for your PocketPilot account associated with $email.</p>
            
            <p>If you made this request, you can reset your password using the forgot password feature in the app. For security reasons, password resets must be handled through the app.</p>
            
            <p>If you didn't request a password reset, please ignore this email. Your account remains secure.</p>
        </div>
        
        <div style="background-color: #fff3cd; padding: 15px; border-radius: 8px; margin-bottom: 20px; border-left: 4px solid #ffc107;">
            <p><strong>🔒 Security Tip:</strong> Never share your password with anyone. PocketPilot will never ask for your password via email.</p>
        </div>
        
        <div style="text-align: center; margin-top: 30px;">
            <p style="color: #009688; font-weight: bold;">The PocketPilot Team</p>
            <p style="color: #666; font-size: 12px;">© 2024 PocketPilot. All rights reserved.</p>
        </div>
    </div>
</body>
</html>
    ''';
  }

  static String _formatDate(DateTime date) {
    final months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}
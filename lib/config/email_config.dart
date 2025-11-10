/// Email service configuration
class EmailConfig {
  // =============================================================================
  // EMAIL SERVICE PROVIDER OPTIONS (Choose one)
  // =============================================================================
  
  /// Current active provider: 'resend', 'emailjs', 'smtp2go', 'mailtrap'
  static const String activeProvider = 'smtp2go';
  
  // =============================================================================
  // CONFIGURATION SETTINGS - UPDATE THESE FOR PRODUCTION
  // =============================================================================
  
  /// Enable real email sending (set to true for production)
  static const bool enableRealEmails = true;
  
  /// Resend API Configuration (Domain-free option)
  static const String resendApiKey = 're_DoL3o6GK_3rtTLSySQoBDm26c1zZboHG3';
  static const String resendApiUrl = 'https://api.resend.com/emails';
  
  /// EmailJS Configuration (No domain required, browser-based)
  static const String emailJsServiceId = 'your_emailjs_service_id';
  static const String emailJsTemplateId = 'your_emailjs_template_id';
  static const String emailJsUserId = 'your_emailjs_user_id';
  
  /// SMTP2GO Configuration (No domain required)
  static const String smtp2goApiKey = 'api-AD4C1926DF3D44D28ADCD3B2F9458075'; // Actual API key
  static const String smtp2goApiUrl = 'https://api.smtp2go.com/v3/email/send';
  
  /// Mailtrap Configuration (Development/Testing)
  static const String mailtrapApiKey = 'your_mailtrap_api_key';
  static const String mailtrapApiUrl = 'https://send.api.mailtrap.io/api/send';
  
  /// Email sender information (domain-free option)
  static const String fromEmail = '2018200697@ms.bulsu.edu.ph'; // BulSU verified sender
  static const String fromName = 'PocketPilot Team';

  /// Logo URL for emails (hosted image for email compatibility)
  static const String logoUrl = 'https://pocketpilot.app/logo.png'; // Replace with actual hosted logo URL
  
  // =============================================================================
  // DOMAIN-FREE EMAIL PROVIDER CONFIGURATIONS
  // =============================================================================
  
  /// Get current provider configuration
  static Map<String, dynamic> get currentProviderConfig {
    switch (activeProvider) {
      case 'resend':
        return {
          'name': 'Resend',
          'api_url': resendApiUrl,
          'api_key': resendApiKey,
          'requires_domain': false, // Using test domain
          'from_email': fromEmail,
        };
      case 'emailjs':
        return {
          'name': 'EmailJS',
          'service_id': emailJsServiceId,
          'template_id': emailJsTemplateId,
          'user_id': emailJsUserId,
          'requires_domain': false,
          'from_email': 'noreply@emailjs.com',
        };
      case 'smtp2go':
        return {
          'name': 'SMTP2GO',
          'api_url': smtp2goApiUrl,
          'api_key': smtp2goApiKey,
          'requires_domain': false,
          'from_email': '2018200697@ms.bulsu.edu.ph',
        };
      case 'mailtrap':
        return {
          'name': 'Mailtrap',
          'api_url': mailtrapApiUrl,
          'api_key': mailtrapApiKey,
          'requires_domain': false,
          'from_email': 'noreply@mailtrap.io',
        };
      default:
        return {
          'name': 'Unknown',
          'requires_domain': true,
          'from_email': fromEmail,
        };
    }
  }
  
  // =============================================================================
  // HELPER METHODS
  // =============================================================================
  
  /// Check if email service is properly configured
  static bool get isConfigured {
    switch (activeProvider) {
      case 'smtp2go':
        return smtp2goApiKey != 'api-your_smtp2go_api_key_here' && 
               fromEmail.isNotEmpty && 
               fromName.isNotEmpty;
      case 'resend':
        return resendApiKey != 'YOUR_RESEND_API_KEY_HERE' && 
               fromEmail.isNotEmpty && 
               fromName.isNotEmpty;
      default:
        return fromEmail.isNotEmpty && fromName.isNotEmpty;
    }
  }
  
  /// Get current email service status
  static String get status {
    if (!enableRealEmails) {
      return 'Simulation Mode (Real emails disabled)';
    } else if (!isConfigured) {
      return 'Configuration Required (API key or domain not set)';
    } else {
      return 'Real Email Service Active';
    }
  }
}

/// Email template configuration
class EmailTemplateConfig {
  /// Default email styling
  static const String cssStyles = '''
    <style>
      body { 
        font-family: Arial, sans-serif; 
        line-height: 1.6; 
        color: #333; 
        margin: 0; 
        padding: 0; 
      }
      .container { 
        max-width: 600px; 
        margin: 0 auto; 
        padding: 20px; 
      }
      .header { 
        text-align: center; 
        margin-bottom: 30px; 
      }
      .brand { 
        color: #009688; 
        font-size: 32px; 
        font-weight: bold; 
      }
      .content-box { 
        background-color: #f5f5f5; 
        padding: 20px; 
        border-radius: 8px; 
        margin-bottom: 20px; 
      }
      .button { 
        background-color: #009688; 
        color: white; 
        padding: 12px 24px; 
        text-decoration: none; 
        border-radius: 5px; 
        display: inline-block; 
        font-weight: bold; 
      }
      .footer { 
        text-align: center; 
        margin-top: 20px; 
        padding-top: 20px; 
        border-top: 1px solid #ddd; 
        color: #999; 
        font-size: 12px; 
      }
    </style>
  ''';
  
  /// Common email footer
  static String get emailFooter {
    return '''
      <div class="footer">
        <p>This email was sent by PocketPilot - Your Personal Financial Guide</p>
        <p>© 2024 PocketPilot. All rights reserved.</p>
      </div>
    ''';
  }
}
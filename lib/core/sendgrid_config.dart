/// SendGrid Configuration
/// IMPORTANT: Store your API key securely
/// For production, use environment variables or secure storage
class SendGridConfig {
  // TODO: Replace with your SendGrid API key from environment
  // Get it from: https://app.sendgrid.com/settings/api_keys
  // Set via: --dart-define=SENDGRID_API_KEY=your_key
  static const String apiKey = String.fromEnvironment('SENDGRID_API_KEY', defaultValue: 'YOUR_API_KEY_HERE');
  
  // TODO: Replace with your verified sender email
  // Must be verified in SendGrid dashboard
  static const String fromEmail = 'your-verified-email@example.com';
  static const String fromName = 'HydroSentinel';
  
  // Email template
  static const String subject = 'Delete Verification Code - HydroSentinel';
}

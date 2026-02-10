class AppConstants {
  // SUPABASE CONFIGURATION
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL', defaultValue: 'https://fyumeticbeoxnbwajkmz.supabase.co');
  static const String supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: 'sb_publishable_Q-EO2CpoLY1j3HeiTN6oBQ_FiFOJ6fS');

  // GOOGLE DRIVE CONFIGURATION
  // The specific folder ID for factories
  static const String driveRootFolderId = String.fromEnvironment('DRIVE_ROOT_FOLDER_ID', defaultValue: '1LNVnYzOCOTYiYi6ERgB4VFfenNu8-Tpy');

  static bool get hasValidConfig => 
    supabaseUrl.isNotEmpty && 
    supabaseAnonKey.isNotEmpty && 
    driveRootFolderId.isNotEmpty;
}

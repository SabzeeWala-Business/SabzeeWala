class AppEnv {
  // Supabase Configuration
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://mhqyaqvnlurqamojelae.supabase.co',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1ocXlhcXZubHVycWFtb2plbGFlIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc5MTg4NTIwNiwiZXhwIjoyMTA3NDYxMjA2fQ.Nmb5WhS0INMzJtzJHUDVRF0rFulzD8qAEJ9Ngt8SzMI',
  );

  // Cashfree Payment Gateway Configuration
  static const String cashfreeLiveAppId = String.fromEnvironment(
    'CASHFREE_LIVE_APP_ID',
    defaultValue: '',
  );

  static const String cashfreeLiveSecretKey = String.fromEnvironment(
    'CASHFREE_LIVE_SECRET_KEY',
    defaultValue: '',
  );

  static const String cashfreeSandboxAppId = String.fromEnvironment(
    'CASHFREE_SANDBOX_APP_ID',
    defaultValue: '',
  );

  static const String cashfreeSandboxSecretKey = String.fromEnvironment(
    'CASHFREE_SANDBOX_SECRET_KEY',
    defaultValue: '',
  );

  static const bool cashfreeUseProduction = bool.fromEnvironment(
    'CASHFREE_USE_PRODUCTION',
    defaultValue: true,
  );

  // MSG91 OTP Configuration
  static const String msg91WidgetId = String.fromEnvironment(
    'MSG91_WIDGET_ID',
    defaultValue: '366a6c72486d383432333133',
  );

  static const String msg91AuthToken = String.fromEnvironment(
    'MSG91_AUTH_KEY',
    defaultValue: '581008TyjZUr05p26acd2169P1',
  );

  // Backend API URL
  static const String backendApiUrl = String.fromEnvironment(
    'BACKEND_API_URL',
    defaultValue: 'https://sabzeewala.onrender.com',
  );
}

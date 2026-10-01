// This project's public client settings. Access is controlled by Supabase RLS,
// not by hiding the publishable key. Other deployments can override both with
// --dart-define or --dart-define-from-file.
const supabaseUrl = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: 'https://svnkgzlizqoougirtdce.supabase.co',
);

const supabasePublishableKey = String.fromEnvironment(
  'SUPABASE_PUBLISHABLE_KEY',
  defaultValue: 'sb_publishable_xcyJs0aPT-8m_hkruFs_cQ_ZmmN6QdH',
);

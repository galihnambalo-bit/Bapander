import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  static const String supabaseUrl = 'https://hpbozzlqgkjvjouynihg.supabase.co';
  static const String supabaseAnonKey = 'sb_publishable_ndRIj_XkrGOxkL3fAS_TIg_H7bE7xcY';

  static SupabaseClient get client => Supabase.instance.client;
}

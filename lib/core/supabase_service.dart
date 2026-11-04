import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static late final SupabaseClient _client;

  // Credenciales encapsuladas e independientes del main
  static const String _url = 'https://oteixwzlphkutdxreozk.supabase.co';
  static const String _anonKey = 'sb_publishable_dKZpnSBKcYKfFPgCcZZ5PA_0pcRrqoh';

  /// Inicializa la conexión de forma interna y autónoma
  static Future<void> initialize() async {
    await Supabase.initialize(
      url: _url,
      publishableKey: _anonKey,
    );
    _client = Supabase.instance.client;
  }

  /// Acceso directo al cliente global de Supabase
  static SupabaseClient get client => _client;

  /// Acceso simplificado al Storage de Supabase
  static SupabaseStorageClient get storage => _client.storage;
}

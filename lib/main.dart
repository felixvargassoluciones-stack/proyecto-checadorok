import 'package:flutter/material.dart';
import 'core/supabase_service.dart';
import 'features/kiosco/kiosco_page.dart';
import 'features/admin/admin_page.dart';
import 'features/auth/vinculacion_page.dart';


void main() async {
  // Asegura que el motor de Flutter esté listo antes de inicializar servicios
  WidgetsFlutterBinding.ensureInitialized();

  // Arranca el backend de Supabase de forma totalmente aislada del main
  await SupabaseService.initialize();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sistema Reloj Checador',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      // Definimos la ruta de arranque inicial de la aplicación
      initialRoute: '/kiosco',
      
      // Catálogo de rutas del ecosistema Web / Multi-Sucursal
    routes: {
  '/kiosco': (context) => const KioscoPage(),
  '/admin': (context) => const AdminPage(),
  '/vincular': (context) => const VinculacionPage(), // Nueva ruta para el celular personal
},
    );
  }
}

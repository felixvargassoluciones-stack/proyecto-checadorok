import 'dart:js_interop'; // Interoperabilidad moderna estándar de Flutter
import 'package:flutter/material.dart';
import '../../core/supabase_service.dart';

// Definición externa de la función que guardamos en el index.html
@JS('solicitarPermisoWebPush')
external JSPromise<JSString> solicitarPermisoWebPushNativo();

class VinculacionPage extends StatefulWidget {
  const VinculacionPage({super.key});

  @override
  State<VinculacionPage> createState() => _VinculacionPageState();
}

class _VinculacionPageState extends State<VinculacionPage> {
  final TextEditingController _pinController = TextEditingController();
  bool _procesando = false;
  String _estadoNotificacion = "Desconectado";

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _solicitarPermisosYEnviarToken() async {
    final String pinIngresado = _pinController.text.trim();
    if (pinIngresado.length < 4) {
      _mostrarMensaje("Por favor ingresa tu PIN de 4 dígitos", Colors.orange);
      return;
    }

    setState(() => _procesando = true);

    try {
      // Invocamos la función del index.html y esperamos su respuesta como un Future de Dart común
      final respuestaJS = await solicitarPermisoWebPushNativo().toDart;
      final String estatus = respuestaJS.toDart.toString();

      if (estatus == 'granted') {
        final String endpointSimulado = "https://googleapis.com";
        final String authSimulado = "auth_key_segura_taller_gratis";
        final String p256dhSimulado = "p256dh_llave_publica_comprobante";

        await SupabaseService.client.from('tokens_notificaciones').upsert({
          'empleado_pin': pinIngresado,
          'endpoint': endpointSimulado,
          'auth_key': authSimulado,
          'p256dh_key': p256dhSimulado,
        }, onConflict: 'endpoint');

        if (mounted) {
          setState(() {
            _estadoNotificacion = "🔔 Alertas Activas en este Celular";
          });
          _mostrarMensaje("¡Suscripción Exitosa! Recibirás alertas.", Colors.green);
          _pinController.clear();
        }
      } else if (estatus == 'not_supported') {
        _mostrarMensaje("Tu navegador no soporta notificaciones", Colors.red);
      } else {
        _mostrarMensaje("Permiso de notificaciones denegado", Colors.red);
      }
    } catch (e) {
      _mostrarMensaje("Error de emparejamiento: $e", Colors.red);
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  void _mostrarMensaje(String texto, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(texto, style: const TextStyle(fontSize: 16)), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D5C46),
        title: const Text('VINCULAR MI CELULAR - ALERTAS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.phonelink_ring, size: 64, color: Color(0xFF0D5C46)),
                    const SizedBox(height: 16),
                    const Text('Recibe tu comprobante digital', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    const Text(
                      'Ingresa tu PIN para activar las notificaciones instantáneas de tus marcas directamente en este teléfono.',
                      style: TextStyle(color: Colors.grey, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _pinController,
                      keyboardType: TextInputType.number,
                      maxLength: 4,
                      obscureText: true,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 24, letterSpacing: 12, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        hintText: '••••',
                        hintStyle: const TextStyle(color: Colors.black26, letterSpacing: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Estatus: $_estadoNotificacion',
                      style: TextStyle(fontWeight: FontWeight.bold, color: _estadoNotificacion.contains("🔔") ? Colors.green : Colors.blueGrey),
                    ),
                    const SizedBox(height: 24),
                    _procesando
                        ? const CircularProgressIndicator(color: Color(0xFF0D5C46))
                        : ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0D5C46),
                              minimumSize: const Size(double.infinity, 50),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: _solicitarPermisosYEnviarToken,
                            child: const Text('Activar Alertas Gratis', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

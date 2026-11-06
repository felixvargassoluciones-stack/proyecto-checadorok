import 'dart:async';
import 'dart:js_interop';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // Soluciona los errores de RealtimeChannel, PostgresChangeEvent, etc.
import '../../core/supabase_service.dart';

// Interoperabilidad nativa moderna inmune a errores de WASM en Flutter Web
@JS('solicitarPermisoWebPush')
external JSPromise<JSString> solicitarPermisoWebPushNativo();

@JS('window.solicitarNotificacionNativaFlotante')
external void lanzarAlertaNativaVisual(JSString titulo, JSString cuerpo);

class VinculacionPage extends StatefulWidget {
  const VinculacionPage({super.key});

  @override
  State<VinculacionPage> createState() => _VinculacionPageState();
}

class _VinculacionPageState extends State<VinculacionPage> {
  final TextEditingController _pinController = TextEditingController();
  bool _procesando = false;
  String _estadoNotificacion = "Desconectado";
  
  RealtimeChannel? _canalAsistencia;

  @override
  void dispose() {
    _pinController.dispose();
    _desconectarCanalRealtime();
    super.dispose();
  }

  void _desconectarCanalRealtime() {
    if (_canalAsistencia != null) {
      SupabaseService.client.removeChannel(_canalAsistencia!);
    }
  }

  void _escucharMarcajesEnTiempoReal(String pin) {
    _desconectarCanalRealtime();

    _canalAsistencia = SupabaseService.client
        .channel('notificaciones_empleado_$pin')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'registros_asistencia',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'empleado_pin',
            value: pin,
          ),
          callback: (payload) {
            final record = payload.newRecord;
            final String tipoEvento = record['tipo_evento'] ?? 'MARCAJE';
            
            final ahora = DateTime.now();
            final String horaChecado = "${ahora.hour.toString().padLeft(2, '0')}:${ahora.minute.toString().padLeft(2, '0')}";

            // Dispara la ventana flotante nativa sin usar dart:js_util
            lanzarAlertaNativaVisual(
              "⏱️ Sistema Checador".toJS, 
              "Hola, se registró tu $tipoEvento con éxito a las $horaChecado hrs.".toJS
            );
          },
        );

    _canalAsistencia!.subscribe();
  }

  Future<void> _solicitarPermisosYEnviarToken() async {
    final String pinIngresado = _pinController.text.trim();
    if (pinIngresado.length < 4) {
      _mostrarMensaje("Por favor ingresa tu PIN de 4 dígitos", Colors.orange);
      return;
    }

    setState(() => _procesando = true);

    try {
      final respuestaJS = await solicitarPermisoWebPushNativo().toDart;
      final String estatus = respuestaJS.toDart.toString();

      if (estatus == 'granted') {
        _escucharMarcajesEnTiempoReal(pinIngresado);

        setState(() {
          _estadoNotificacion = "🔔 Alertas Activas en este Celular";
        });
        _mostrarMensaje("¡Celular Vinculado! Mantén la pestaña abierta en tu bolsillo.", Colors.green);
        _pinController.clear();
      } else if (estatus == 'not_supported') {
        _mostrarMensaje("Tu navegador no soporta notificaciones", Colors.red);
      } else {
        _mostrarMensaje("Permiso de notificaciones denegado", Colors.red);
      }
    } catch (e) {
      _mostrarMensaje("Error de vinculación: $e", Colors.red);
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

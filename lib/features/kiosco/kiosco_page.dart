import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase_service.dart';

class KioscoPage extends StatefulWidget {
  const KioscoPage({super.key});

  @override
  State<KioscoPage> createState() => _KioscoPageState();
}

class _KioscoPageState extends State<KioscoPage> {
  String _pinIngresado = '';
  CameraController? _cameraController;
  bool _camaraInicializada = false;

  @override
  void initState() {
    super.initState();
    _configurarCamara();
  }

  /// Inicializa la cámara frontal del dispositivo/tablet
  Future<void> _configurarCamara() async {
    try {
      final camaras = await availableCameras();
      if (camaras.isEmpty) return;

      final camaraFrontal = camaras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => camaras.first,
      );

      _cameraController = CameraController(
        camaraFrontal,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _cameraController!.initialize();
      if (mounted) {
        setState(() {
          _camaraInicializada = true;
        });
      }
    } catch (e) {
      debugPrint('Error al inicializar la cámara: $e');
    }
  }

  void _presionarTecla(String texto) {
    if (_pinIngresado.length < 6) {
      setState(() => _pinIngresado += texto);
    }
  }

  void _borrarTecla() {
    if (_pinIngresado.isNotEmpty) {
      setState(() => _pinIngresado = _pinIngresado.substring(0, _pinIngresado.length - 1));
    }
  }
  /// Procesa el checado real subiendo la selfie e insertando en Supabase
  void _procesarChecado(String tipoEvento) async {
    if (_pinIngresado.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, ingresa tu número de empleado')),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator(color: Colors.white)),
    );

    try {
      final datosEmpleado = await SupabaseService.client
          .from('empleados')
          .select('id, pin_acceso, nombre_completo, sucursal_id')
          .eq('numero_empleado', _pinIngresado)
          .eq('activo', true)
          .maybeSingle();

      if (datosEmpleado == null) {
        if (!mounted) return;
        Navigator.pop(context);
        _mostrarAlerta('Error', 'El número de empleado no existe o está inactivo.');
        return;
      }

      if (_cameraController == null || !_cameraController!.value.isInitialized) {
        if (!mounted) return;
        Navigator.pop(context);
        _mostrarAlerta('Error de Hardware', 'La cámara no está lista. Inténtalo de nuevo.');
        return;
      }

      final XFile file = await _cameraController!.takePicture();
      final Uint8List bytesFoto = await file.readAsBytes();

      final String nombreArchivo = '${DateTime.now().millisecondsSinceEpoch}_${datosEmpleado['id']}.jpg';
      final String rutaStorage = 'asistencias/$nombreArchivo';

      await SupabaseService.storage.from('asistencias_selfies').uploadBinary(
            rutaStorage,
            bytesFoto,
            fileOptions: const FileOptions(contentType: 'image/jpeg'),
          );

      final String urlPublicaSelfie = SupabaseService.storage
          .from('asistencias_selfies')
          .getPublicUrl(rutaStorage);

      await SupabaseService.client.from('registros_asistencia').insert({
        'empleado_id': datosEmpleado['id'],
        'sucursal_id': datosEmpleado['sucursal_id'],
        'tipo_evento': tipoEvento,
        'selfie_url': urlPublicaSelfie,
        'dispositivo_info': 'Kiosco Web (Tablet Corporativa)',
      });

      if (!mounted) return;
      Navigator.pop(context);

      _mostrarAlerta(
        '¡Registro Exitoso!',
        'Hola ${datosEmpleado['nombre_completo']},\nse ha registrado tu $tipoEvento con éxito.',
        limpiarPin: true,
      );

    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      _mostrarAlerta('Error de Conexión', 'No se pudo guardar el registro: $e');
    }
  }

  void _mostrarAlerta(String titulo, String mensaje, {bool limpiarPin = false}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
        content: Text(mensaje, style: const TextStyle(fontSize: 16)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (limpiarPin) {
                setState(() => _pinIngresado = '');
              }
            },
            child: const Text('Aceptar', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Row(
        children: [
          Expanded(
            flex: 4,
            child: Container(
              color: Colors.teal,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'VALIDACIÓN VISUAL',
                    style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 2),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    width: 280,
                    height: 280,
                    decoration: BoxDecoration(
                      color: Colors.black12,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: _camaraInicializada
                        ? CameraPreview(_cameraController!)
                        : const Center(child: CircularProgressIndicator(color: Colors.white)),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Asegúrate de que tu rostro sea visible',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            flex: 5,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 20.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _pinIngresado.isEmpty ? '--- ---' : _pinIngresado,
                    style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.teal),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      SizedBox(
                        width: 240,
                        child: GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                          ),
                          itemCount: 12,
                          itemBuilder: (context, index) {
                            String textoBoton = '';
                            if (index < 9) textoBoton = '${index + 1}';
                            if (index == 9) textoBoton = 'C'; 
                            if (index == 10) textoBoton = '0';
                            if (index == 11) textoBoton = '⌫'; 
                            
                            return ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: textoBoton == 'C' || textoBoton == '⌫' ? Colors.grey : Colors.white,
                                foregroundColor: Colors.teal,
                                elevation: 1,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: () {
                                if (textoBoton == 'C') {
                                  setState(() => _pinIngresado = '');
                                } else if (textoBoton == '⌫') {
                                  _borrarTecla();
                                } else {
                                  _presionarTecla(textoBoton);
                                }
                              },
                              child: Text(textoBoton, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                            );
                          },
                        ),
                      ),
                      Column(
                        children: [
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, fixedSize: const Size(180, 50)),
                            onPressed: () => _procesarChecado('ENTRADA'),
                            icon: const Icon(Icons.login),
                            label: const Text('ENTRADA'),
                          ),
                          const SizedBox(height: 10),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white, fixedSize: const Size(180, 50)),
                            onPressed: () => _procesarChecado('SALIDA_COMER'),
                            icon: const Icon(Icons.restaurant),
                            label: const Text('SALIDA COMER'),
                          ),
                          const SizedBox(height: 10),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.white, fixedSize: const Size(180, 50)),
                            onPressed: () => _procesarChecado('REGRESO_COMER'),
                            icon: const Icon(Icons.restaurant_menu),
                            label: const Text('REGRESO COMER'),
                          ),
                          const SizedBox(height: 10),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, fixedSize: const Size(180, 50)),
                            onPressed: () => _procesarChecado('SALIDA'),
                            icon: const Icon(Icons.logout),
                            label: const Text('SALIDA FINAL'),
                          ),
                        ],
                      )
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

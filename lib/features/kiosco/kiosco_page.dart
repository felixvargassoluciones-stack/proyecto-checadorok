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
        'dispositivo_info': 'Kiosco Web (Tablet/Móvil Responsivo)',
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
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Detectamos si la pantalla es pequeña (Móvil) o grande (Tablet/PC)
          final bool esMovil = constraints.maxWidth < 750;

          if (esMovil) {
            return SafeArea(
              child: Column(
                children: [
                  // La sección visual de la cámara permanece totalmente estática arriba
                  _buildSeccionVisual(esMovil: true),
                  
                  // Únicamente la sección de controles tiene scroll independiente por debajo
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
                      child: _buildSeccionControles(esMovil: true),
                    ),
                  ),
                ],
              ),
            );
          }

          // Distribución horizontal tradicional para pantallas grandes (Tablets/Monitores)
          return Row(
            children: [
              Expanded(
                flex: 4,
                child: _buildSeccionVisual(esMovil: false),
              ),
              Expanded(
                flex: 5,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 20.0),
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: _buildSeccionControles(esMovil: false),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
  /// Construye el panel de la cámara y el indicador visual de rostro
  Widget _buildSeccionVisual({required bool esMovil}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: esMovil ? 16.0 : 40.0, horizontal: 16.0),
      color: Colors.teal,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'VALIDACIÓN VISUAL',
            style: TextStyle(
              color: Colors.white, 
              fontSize: esMovil ? 16 : 22, 
              fontWeight: FontWeight.bold, 
              letterSpacing: 2
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: esMovil ? 150 : 280,
            height: esMovil ? 150 : 280,
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
          const SizedBox(height: 10),
          Text(
            'Asegúrate de que tu rostro sea visible',
            style: TextStyle(color: Colors.white70, fontSize: esMovil ? 11 : 14),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
  /// Orquesta la visualización del PIN, el teclado y los botones de acción
  Widget _buildSeccionControles({required bool esMovil}) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          _pinIngresado.isEmpty ? '--- ---' : _pinIngresado,
          style: TextStyle(
            fontSize: esMovil ? 28 : 36, 
            fontWeight: FontWeight.bold, 
            color: Colors.teal
          ),
        ),
        const SizedBox(height: 20),
        esMovil
            ? Column(
                children: [
                  _buildTecladoNumerico(tamanoReducido: true),
                  const SizedBox(height: 20),
                  _buildBotonesAccion(esMovil: true),
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(child: _buildTecladoNumerico(tamanoReducido: false)),
                  const SizedBox(width: 20),
                  _buildBotonesAccion(esMovil: false),
                ],
              ),
      ],
    );
  }

  /// Construye la cuadrícula del teclado numérico
  Widget _buildTecladoNumerico({required bool tamanoReducido}) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: tamanoReducido ? 280 : 240),
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
              padding: EdgeInsets.zero,
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
            child: Text(
              textoBoton, 
              style: TextStyle(fontSize: tamanoReducido ? 18 : 20, fontWeight: FontWeight.bold)
            ),
          );
        },
      ),
    );
  }
  /// Construye los botones laterales o inferiores para registrar eventos en Supabase
  Widget _buildBotonesAccion({required bool esMovil}) {
    final double anchoBoton = esMovil ? double.infinity : 180.0;

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: esMovil ? double.infinity : 180.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green, 
              foregroundColor: Colors.white, 
              minimumSize: Size(anchoBoton, 50)
            ),
            onPressed: () => _procesarChecado('ENTRADA'),
            icon: const Icon(Icons.login),
            label: const Text('ENTRADA'),
          ),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange, 
              foregroundColor: Colors.white, 
              minimumSize: Size(anchoBoton, 50)
            ),
            onPressed: () => _procesarChecado('SALIDA_COMER'),
            icon: const Icon(Icons.restaurant),
            label: const Text('SALIDA COMER'),
          ),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber, 
              foregroundColor: Colors.white, 
              minimumSize: Size(anchoBoton, 50)
            ),
            onPressed: () => _procesarChecado('REGRESO_COMER'),
            icon: const Icon(Icons.restaurant_menu),
            label: const Text('REGRESO COMER'),
          ),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red, 
              foregroundColor: Colors.white, 
              minimumSize: Size(anchoBoton, 50)
            ),
            onPressed: () => _procesarChecado('SALIDA'),
            icon: const Icon(Icons.logout),
            label: const Text('SALIDA FINAL'),
          ),
        ],
      ),
    );
  }
}

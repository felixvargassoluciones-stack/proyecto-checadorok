import 'dart:async';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../../core/supabase_service.dart';
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';

class KioscoPage extends StatefulWidget {
  const KioscoPage({super.key});

  @override
  State<KioscoPage> createState() => _KioscoPageState();
}

class _KioscoPageState extends State<KioscoPage> {
  CameraController? _cameraController;
  final TextEditingController _pinController = TextEditingController();
  bool _estaProcesando = false;
  bool _inicializandoCamara = false;
  String _pinActual = "";
  Timer? _relojTimer;
  String _horaDigital = "00:00:00";
  
  // 🌟 NUEVA VARIABLE: Controla si el PIN se muestra o se oculta como asteriscos
  bool _ocultarPin = true;

  @override
  void initState() {
    super.initState();
    _iniciarReloj();
  }

  @override
  void dispose() {
    _relojTimer?.cancel();
    _pinController.dispose();
    _cameraController?.dispose();
    super.dispose();
  }

  void _iniciarReloj() {
    _relojTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final ahora = DateTime.now();
      if (mounted) {
        setState(() {
          _horaDigital = "${ahora.hour.toString().padLeft(2, '0')}:${ahora.minute.toString().padLeft(2, '0')}:${ahora.second.toString().padLeft(2, '0')}";
        });
      }
    });
  }

  Future<void> _inicializarCamaraFrontal() async {
    if (_cameraController != null || _inicializandoCamara) return;
    setState(() => _inicializandoCamara = true);
    try {
      final camaras = await availableCameras();
      if (camaras.isEmpty) return;
      final camaraFrontal = camaras.firstWhere(
        (camara) => camara.lensDirection == CameraLensDirection.front,
        orElse: () => camaras.first,
      );
      _cameraController = CameraController(
        camaraFrontal, 
        ResolutionPreset.medium, 
        enableAudio: false
      );
      await _cameraController!.initialize();
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint("Error al encender la cámara: $e");
    } finally {
      if (mounted) setState(() => _inicializandoCamara = false);
    }
  }

  void _apagarCamara() {
    if (_cameraController != null) {
      _cameraController!.dispose();
      _cameraController = null;
      if (mounted) setState(() {});
    }
  }

  void _agregarDigito(String digito) {
    if (_pinActual.length >= 4 || _estaProcesando) return;
    setState(() {
      _pinActual += digito;
      _pinController.text = _pinActual;
    });
    if (_pinActual.length == 1) {
      _inicializarCamaraFrontal();
    }
    // ✅ SE REMOVIÓ EL DISPARO AUTOMÁTICO INMEDIATO PARA ESPERAR EL BOTÓN SEGURO
  }

  void _limpiarPin() {
    setState(() {
      _pinActual = "";
      _pinController.text = "";
    });
    _apagarCamara();
  }
    Future<void> _procesarMarcajeAsistencia() async {
    if (_pinActual.length != 4 || _estaProcesando) return;

    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ Sensor de cámara no listo. Espera un momento.'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _estaProcesando = true);
    
    try {
      final ahora = DateTime.now();
      String urlPublicaSelfie = 'EMPTY';

      // 📷 1. CAPTURA Y SUBIDA SEGURA DE LA FOTO ANTES DE LLAMAR AL PROCEDIMIENTO
      try {
        final XFile file = await _cameraController!.takePicture();
        final Uint8List bytesFoto = await file.readAsBytes();
        
        final String nombreArchivo = '${ahora.millisecondsSinceEpoch}_$_pinActual.jpg';
        final String rutaStorage = 'asistencias/$nombreArchivo';

        await SupabaseService.storage.from('asistencias_selfies').uploadBinary(
              rutaStorage,
              bytesFoto,
              fileOptions: const FileOptions(contentType: 'image/jpeg'),
            );

        urlPublicaSelfie = SupabaseService.storage
            .from('asistencias_selfies')
            .getPublicUrl(rutaStorage);

      } catch (eCamera) {
        debugPrint("Advertencia en captura de evidencia visual: $eCamera");
        urlPublicaSelfie = 'FALLO_FOTO';
      }

      // 🧠 2. CONEXIÓN AL CEREBRO DE SUPABASE (Invocación RPC de la Receta Global)
      final List<dynamic> respuestaRpc = await SupabaseService.client.rpc(
        'registrar_marcaje_inteligente',
        params: {
          'p_pin_acceso': _pinActual,
          'p_selfie_url': urlPublicaSelfie,
          'p_dispositivo_info': 'Kiosco con Receta Global Automatizada (Web Móvil)',
        },
      );

      if (respuestaRpc.isEmpty) throw 'No se recibió respuesta del servidor de asistencia.';
      
      final Map<String, dynamic> resultado = Map<String, dynamic>.from(respuestaRpc.first);
      final String status = resultado['status_operacion'] ?? 'ERROR';
      final String mensaje = resultado['mensaje_pantalla'] ?? 'Error desconocido';
      final String evento = resultado['evento_detectado'] ?? 'ENTRADA';

      if (!mounted) return;

      // 📝 3. EVALUACIÓN DE RESPUESTA PARA LA INTERFAZ GRÁFICA
      if (status == 'SUCCESS') {
        _mostrarDialogoExito(
          nombreEmpleado: mensaje, // Muestra el nombre devuelto por el procedimiento SQL
          tipoEvento: evento,      // Muestra 'ENTRADA' o 'SALIDA' calculado por la tarjeta perforada
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(mensaje), backgroundColor: Colors.orange.shade800),
        );
      }

      _limpiarPin();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error de comunicación con la Receta Global: $e'), backgroundColor: Colors.red),
      );
      _apagarCamara();
    } finally {
      if (mounted) {
        setState(() => _estaProcesando = false);
      }
    }
  }


  void _mostrarDialogoExito({required String nombreEmpleado, required String tipoEvento}) {
    final ahora = DateTime.now();
    final horaChecado = "${ahora.hour.toString().padLeft(2, '0')}:${ahora.minute.toString().padLeft(2, '0')}";
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(children: [Icon(Icons.check_circle, color: Colors.teal, size: 34), SizedBox(width: 12), Text('¡Registro Exitoso!', style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold, fontSize: 24))]),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Hola $nombreEmpleado,', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF2D3748))),
              const SizedBox(height: 14),
              RichText(text: TextSpan(style: const TextStyle(fontSize: 18, color: Colors.black87, height: 1.5), children: [const TextSpan(text: 'se ha registrado tu '), TextSpan(text: tipoEvento, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)), const TextSpan(text: ' con éxito a las '), TextSpan(text: '$horaChecado hrs.', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2D3748)))]))
            ],
          ),
          actions: [TextButton(onPressed: () { Navigator.of(context).pop(); _apagarCamara(); }, child: const Text('Aceptar', style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold, fontSize: 18)))],
        );
      },
    );
  }
  Widget _buildSeccionVisual() {
    return Container(
      color: const Color(0xFF0D5C46), width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 16.0),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('VALIDACIÓN VISUAL', style: TextStyle(color: Colors.white70, fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
        const SizedBox(height: 8),
        Text(_horaDigital, style: const TextStyle(fontSize: 42, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 2)),
        const SizedBox(height: 12),
        Container(width: 150, height: 150, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: _cameraController != null ? Colors.tealAccent : Colors.white24, width: 4)), child: ClipOval(child: _estaProcesando || _inicializandoCamara ? const Padding(padding: EdgeInsets.all(45.0), child: CircularProgressIndicator(color: Colors.white)) : (_cameraController != null && _cameraController!.value.isInitialized ? CameraPreview(_cameraController!) : Container(color: const Color(0xFF114232), child: const Icon(Icons.photo_camera_front_outlined, color: Colors.white38, size: 55))))),
        const SizedBox(height: 10),
        Text(_cameraController != null ? '📷 Cámara Activa' : '💤 Sensor en reposo.', style: TextStyle(color: _cameraController != null ? Colors.tealAccent : Colors.white60, fontSize: 13, fontStyle: FontStyle.italic))
      ]),
    );
  }

  Widget _buildTecladoNumerico() {
    final List<String> botones = ['1', '2', '3', '4', '5', '6', '7', '8', '9', 'C', '0', '⌫'];
    return GridView.builder(
      shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: botones.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, childAspectRatio: 1.5, crossAxisSpacing: 12, mainAxisSpacing: 12),
      itemBuilder: (context, index) {
        final boton = botones[index]; final bool esEspecial = boton == 'C' || boton == '⌫';
        return ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: esEspecial ? Colors.blueGrey : Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.grey))),
          onPressed: () {
            if (boton == 'C') { _limpiarPin(); }
            else if (boton == '⌫') { 
              if (_pinActual.isNotEmpty) { 
                setState(() { 
                  _pinActual = _pinActual.substring(0, _pinActual.length - 1); 
                  _pinController.text = _pinActual; 
                }); 
                if (_pinActual.isEmpty) { _apagarCamara(); } 
              } 
            }
            else { _agregarDigito(boton); }
          },
          child: Text(boton, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: esEspecial ? Colors.white : const Color(0xFF2D3748))),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // 🌟 VALIDACIÓN DE CANDADO CRÍTICA:
    // El botón solo se activa si el PIN tiene 4 dígitos Y la cámara ya está 100% lista en pantalla
    final bool camaraLista = _cameraController != null && _cameraController!.value.isInitialized;
    final bool sePuedeRegistrar = _pinActual.length == 4 && camaraLista && !_estaProcesando;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: _estaProcesando
            ? const Center(child: CircularProgressIndicator(color: Colors.teal))
            : LayoutBuilder(builder: (context, constraints) {
                return Column(children: [
                  _buildSeccionVisual(),
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(), 
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0), 
                        child: Column(
                          mainAxisSize: MainAxisSize.min, 
                          children: [
                            // 🌟 CAJA DE TEXTO DEL PIN CON ICONO DE OJO INTERACTIVO
                            TextField(
                              controller: _pinController, 
                              readOnly: true, 
                              obscureText: _ocultarPin, // Alterna entre asteriscos o números claros
                              textAlign: TextAlign.center, 
                              style: TextStyle(fontSize: 28, letterSpacing: _ocultarPin ? 16 : 6, fontWeight: FontWeight.bold), 
                              decoration: InputDecoration(
                                hintText: '••••', 
                                hintStyle: const TextStyle(color: Colors.black26, letterSpacing: 16), 
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), 
                                filled: true, 
                                fillColor: Colors.white, 
                                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                                suffixIcon: IconButton(
                                  icon: Icon(_ocultarPin ? Icons.visibility_off : Icons.visibility, color: Colors.blueGrey),
                                  onPressed: () => setState(() => _ocultarPin = !_ocultarPin),
                                ),
                              ),
                            ), 
                            const SizedBox(height: 16), 
                            _buildTecladoNumerico(),
                            const SizedBox(height: 20),
                            
                            // 🌟 NUEVO BOTÓN CORPORATIVO AUTOMATIZADO CON VALIDACIÓN DE HARDWARE
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.teal.shade700,
                                  disabledBackgroundColor: Colors.grey.shade300,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  elevation: sePuedeRegistrar ? 2 : 0,
                                ),
                                icon: Icon(Icons.fingerprint, color: sePuedeRegistrar ? Colors.white : Colors.grey),
                                label: Text(
                                  camaraLista ? 'REGISTRAR ASISTENCIA' : '⚡ ESPERANDO SENSOR CÁMARA...',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: sePuedeRegistrar ? Colors.white : Colors.grey.shade500),
                                ),
                                onPressed: sePuedeRegistrar ? _procesarMarcajeAsistencia : null,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                ]);
              }),
      ),
    );
  }
}

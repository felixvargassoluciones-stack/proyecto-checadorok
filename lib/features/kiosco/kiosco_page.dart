import 'dart:async';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

class KioscoPage extends StatefulWidget {
  const KioscoPage({super.key});

  @override
  State<KioscoPage> createState() => _KioscoPageState();
}

class _KioscoPageState extends State<KioscoPage> {
  // CONTROLADORES EXISTENTES: Cámara frontal, campo de captura del PIN e indicadores
  CameraController? _cameraController;
  final TextEditingController _pinController = TextEditingController();
  bool _estaProcesando = false;
  String _pinActual = "";

  // VARIABLES INYECTADAS: Soporte para el reloj digital en tiempo real en la tablet
  Timer? _relojTimer;
  String _horaDigital = "00:00:00";
  @override
  void initState() {
    super.initState();
    _iniciarReloj();
    _inicializarCamaraFrontal();
  }

  Future<void> _inicializarCamaraFrontal() async {
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
        enableAudio: false,
      );

      await _cameraController!.initialize();
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint("Error al inicializar la cámara: $e");
    }
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
  void _solicitarConfirmacionMarcaje(String tipoEvento) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            '⚠️ Confirmar Registro',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey, fontSize: 22),
          ),
          content: Text(
            '¿Estás seguro de que deseas registrar tu $tipoEvento en este momento?',
            style: const TextStyle(fontSize: 18, color: Colors.black87),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
              onPressed: () {
                Navigator.of(context).pop();
                _procesarMarcajeAsistencia(tipoEvento);
              },
              child: const Text('Sí, Registrar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ],
        );
      },
    );
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
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.teal, size: 34),
              SizedBox(width: 12),
              Text(
                '¡Registro Exitoso!',
                style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold, fontSize: 24),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hola $nombreEmpleado,',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF2D3748)),
              ),
              const SizedBox(height: 14),
              RichText(
                text: TextSpan(
                  style: const TextStyle(fontSize: 18, color: Colors.black87, height: 1.5),
                  children: [
                    const TextSpan(text: 'se ha registrado tu '),
                    TextSpan(text: tipoEvento, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
                    const TextSpan(text: ' con éxito a las '),
                    TextSpan(text: '$horaChecado hrs.', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2D3748))),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Aceptar', style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold, fontSize: 18)),
            ),
          ],
        );
      },
    );
  }
  Widget _buildSeccionVisual() {
    return Container(
      color: const Color(0xFF0D5C46),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'VALIDACIÓN VISUAL',
            style: TextStyle(color: Colors.white70, fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 1.5),
          ),
          const SizedBox(height: 8),
          Text(
            _horaDigital,
            style: const TextStyle(fontSize: 42, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 2),
          ),
          const SizedBox(height: 12),
          Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white24, width: 4),
            ),
            child: ClipOval(
              child: (_cameraController != null && _cameraController!.value.isInitialized)
                  ? CameraPreview(_cameraController!)
                  : Container(
                      color: const Color(0xFF114232),
                      child: const Icon(Icons.camera_front, color: Colors.white38, size: 55),
                    ),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Asegúrate de que tu rostro sea visible en el círculo',
            style: TextStyle(color: Colors.white60, fontSize: 13, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }
  Future<void> _procesarMarcajeAsistencia(String tipoEvento) async {
    if (_pinActual.isEmpty || _estaProcesando) return;

    setState(() => _estaProcesando = true);
    
    try {
      final String nombreTrabajador = "Juan Pérez Modesto";

      _mostrarDialogoExito(
        nombreEmpleado: nombreTrabajador,
        tipoEvento: tipoEvento,
      );

      _limpiarPin();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error de validación: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _estaProcesando = false);
    }
  }

  void _agregarDigito(String digito) {
    if (_pinActual.length >= 4) return;
    setState(() {
      _pinActual += digito;
      _pinController.text = _pinActual;
    });
  }

  void _limpiarPin() {
    setState(() {
      _pinActual = "";
      _pinController.text = "";
    });
  }
  Widget _buildTecladoNumerico() {
    final List<String> botones = ['1', '2', '3', '4', '5', '6', '7', '8', '9', 'C', '0', '⌫'];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: botones.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1.5,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemBuilder: (context, index) {
        final boton = botones[index];
        final bool esEspecial = boton == 'C' || boton == '⌫';

        return ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: esEspecial ? Colors.blueGrey[50] : Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey[200]!),
            ),
          ),
          onPressed: () {
            if (boton == 'C') {
              _limpiarPin();
            } else if (boton == '⌫') {
              if (_pinActual.isNotEmpty) {
                setState(() {
                  _pinActual = _pinActual.substring(0, _pinActual.length - 1);
                  _pinController.text = _pinActual;
                });
              }
            } else {
              _agregarDigito(boton);
            }
          },
          child: Text(
            boton,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: esEspecial ? Colors.blueGrey[700] : const Color(0xFF2D3748),
            ),
          ),
        );
      },
    );
  }
  Widget _buildBotonIncidencia(String titulo, Color color, String tipo) {
    return SizedBox(
      width: double.infinity, // Hace que el botón ocupe todo el ancho disponible
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          padding: const EdgeInsets.symmetric(vertical: 18), // Botones más altos y cómodos
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 2,
        ),
        onPressed: _pinActual.length < 4 ? null : () => _solicitarConfirmacionMarcaje(tipo),
        child: Text(
          titulo,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.5),
        ),
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: _estaProcesando
            ? const Center(child: CircularProgressIndicator(color: Colors.teal))
            : LayoutBuilder(
                builder: (context, constraints) {
                  return Column(
                    children: [
                      _buildSeccionVisual(), // Sección de la cámara fija arriba
                      Expanded(
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                TextField(
                                  controller: _pinController,
                                  readOnly: true,
                                  obscureText: true,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 28, letterSpacing: 16, fontWeight: FontWeight.bold),
                                  decoration: InputDecoration(
                                    hintText: '••••',
                                    hintStyle: const TextStyle(color: Colors.black26, letterSpacing: 16),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                    filled: true,
                                    fillColor: Colors.white,
                                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                _buildTecladoNumerico(),
                                const SizedBox(height: 24),
                                
                                // BOTONERA CORREGIDA: Apilada en formato vertical uno debajo del otro
                                Column(
                                  children: [
                                    _buildBotonIncidencia('-> ENTRADA', const Color(0xFF2E7D32), 'ENTRADA'),
                                    const SizedBox(height: 12),
                                    _buildBotonIncidencia('SALIDA COMER', const Color(0xFFE65100), 'SALIDA A COMER'),
                                    const SizedBox(height: 12),
                                    _buildBotonIncidencia('REGRESO COMER', const Color(0xFF1565C0), 'REGRESO DE COMER'),
                                    const SizedBox(height: 12),
                                    _buildBotonIncidencia('-> SALIDA', const Color(0xFFC62828), 'SALIDA FIN DE TURNO'),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
      ),
    );
  }
}

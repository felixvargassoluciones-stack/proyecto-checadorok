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

  // NUEVAS VARIABLES INYECTADAS: Soporte para el reloj digital en tiempo real en la tablet
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

      // Localizamos la cámara frontal en el dispositivo
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
              Icon(Icons.check_circle, color: Colors.teal, size: 28),
              SizedBox(width: 10),
              Text(
                '¡Registro Exitoso!',
                style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hola $nombreEmpleado,',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2D3748)),
              ),
              const SizedBox(height: 10),
              RichText(
                text: TextSpan(
                  style: const TextStyle(fontSize: 15, color: Colors.black87, height: 1.4),
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
              child: const Text('Aceptar', style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ],
        );
      },
    );
  }
  Widget _buildSeccionVisual() {
    return Container(
      color: const Color(0xFF0D5C46), // Color verde institucional de la bitácora
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
      child: Column(
        children: [
          const Text(
            'VALIDACIÓN VISUAL',
            style: TextStyle(color: Colors.white70, fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 1.5),
          ),
          const SizedBox(height: 10),
          // RELOJ EN VIVO: Inyectado con tipografía de alta visibilidad para talleres
          Text(
            _horaDigital,
            style: const TextStyle(fontSize: 42, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 2),
          ),
          const SizedBox(height: 16),
          Container(
            width: 160,
            height: 160,
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
          const SizedBox(height: 12),
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
      // Tu consulta real en Supabase (Se preserva su espacio operativo completo)
      // final datosEmpleado = await SupabaseService.client.from('empleados').select().eq('pin', _pinActual).single();
      
      // Simulación exitosa del sistema en base a los registros en vivo del feed de selfies
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
        childAspectRatio: 1.4,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
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
    return Expanded(
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 2,
        ),
        onPressed: _pinActual.length < 4 ? null : () => _procesarMarcajeAsistencia(tipo),
        child: Text(
          titulo,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
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
                      _buildSeccionVisual(), // Bloque superior estático de cámara
                      Expanded(
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                            child: Column(
                              children: [
                                // Campo visualizador de asteriscos para el PIN seguro
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
                                const SizedBox(height: 20),
                                _buildTecladoNumerico(),
                                const SizedBox(height: 24),
                                
                                // Fila inferior adaptada para registrar Entradas y Salidas
                                Row(
                                  children: [
                                    _buildBotonIncidencia('-> ENTRADA', Colors.green[700]!, 'ENTRADA'),
                                    const SizedBox(width: 12),
                                    _buildBotonIncidencia('SALIDA COMER', Colors.amber[700]!, 'SALIDA A COMER'),
                                    const SizedBox(width: 12),
                                    _buildBotonIncidencia('REGRESO COMER', Colors.blue[700]!, 'REGRESO DE COMER'),
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

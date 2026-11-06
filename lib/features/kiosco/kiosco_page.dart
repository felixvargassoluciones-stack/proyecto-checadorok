import 'dart:async';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../../core/supabase_service.dart';


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
  final List<Map<String, String>> _historialPruebas = [];

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
      _cameraController = CameraController(camaraFrontal, ResolutionPreset.medium, enableAudio: false);
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
      Future<void> _procesarMarcajeAsistencia(String tipoEvento) async {
    if (_pinActual.isEmpty || _estaProcesando) return;

    setState(() => _estaProcesando = true);
    
    try {
      final ahora = DateTime.now();
      final horaFormateada = "${ahora.hour.toString().padLeft(2, '0')}:${ahora.minute.toString().padLeft(2, '0')} hrs";

      // 1. TRADUCCIÓN EXACTA: Buscamos al empleado usando los nombres de columna reales de tu captura
      final empleadoData = await SupabaseService.client
          .from('empleados')
          .select('id, nombre_completo, sucursal_id') // Columnas reales verificadas
          .eq('pin_acceso', _pinActual) // Nombre de columna real verificado
          .maybeSingle();

      if (empleadoData == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ PIN de acceso incorrecto. Trabajador no encontrado.'),
            backgroundColor: Colors.orange,
          ),
        );
        _limpiarPin();
        return;
      }

      final String empleadoUuid = empleadoData['id'].toString();
      final String nombreTrabajador = empleadoData['nombre_completo'] ?? "Empleado";
      // Si el empleado no tiene sucursal asignada en la tabla, usamos por defecto la Matriz de tu captura
      final String sucursalUuid = empleadoData['sucursal_id'] ?? '91995ded-ff29-41b7-8198-08ca6cb94fb3';

      // 2. INSERCIÓN REAL: Guardamos en registros_asistencia respetando todas las claves foráneas obligatorias
      await SupabaseService.client.from('registros_asistencia').insert({
        'empleado_id': empleadoUuid,
        'sucursal_id': sucursalUuid, // Inyectamos el ID de la sucursal para que la base de datos lo acepte
        'tipo_evento': tipoEvento,
        'fecha_hora_servidor': ahora.toIso8601String(), // Estampa de tiempo exacta
        'dispositivo_info': 'Kiosco Web (Tablet/Móvil Responsivo)',
        'estatus_asistencia': 'TURNO_NO_PROGRAMADO', // Estatus por defecto inicial que maneja tu tabla
        'selfie_url': 'https://supabase.co', // Tu ruta base de storage
      });

      if (!mounted) return;

      setState(() {
        _historialPruebas.insert(0, {
          'evento': tipoEvento,
          'hora': horaFormateada,
        });
      });

      // Muestra el nombre real del empleado en letras grandes
      _mostrarDialogoExito(
        nombreEmpleado: nombreTrabajador,
        tipoEvento: tipoEvento,
      );

      _limpiarPin();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error de conexión con Supabase: $e'), backgroundColor: Colors.red),
      );
      _apagarCamara();
    } finally {
      if (mounted) {
        setState(() => _estaProcesando = false);
      }
    }
  }



  void _agregarDigito(String digito) {
    if (_pinActual.length >= 4) return;
    setState(() {
      _pinActual += digito;
      _pinController.text = _pinActual;
    });
    if (_pinActual.length == 1) {
      _inicializarCamaraFrontal();
    }
  }

  void _limpiarPin() {
    setState(() {
      _pinActual = "";
      _pinController.text = "";
    });
    _apagarCamara();
  }
  void _solicitarConfirmacionMarcaje(String tipoEvento) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('⚠️ Confirmar Registro', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey, fontSize: 22)),
          content: Text('¿Estás seguro de que deseas registrar tu $tipoEvento en este momento?', style: const TextStyle(fontSize: 18, color: Colors.black87)),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 16))),
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
  void _mostrarHistorialUsuario() {
    if (_pinActual.length < 4) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('📊 Tus Marcas de Hoy', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.teal)),
              const SizedBox(height: 15),
              _historialPruebas.isEmpty
                  ? const Padding(padding: EdgeInsets.symmetric(vertical: 20.0), child: Center(child: Text('No tienes registros guardados.', style: TextStyle(fontSize: 16, color: Colors.grey))))
                  : Container(
                      constraints: const BoxConstraints(maxHeight: 250),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _historialPruebas.length,
                        itemBuilder: (context, index) {
                          final item = _historialPruebas[index];
                          final String ev = item['evento'] ?? 'MARCAJE';
                          IconData icono = Icons.alarm; Color colorIcono = Colors.teal;
                          if (ev.contains('ENTRADA')) { icono = Icons.login; colorIcono = Colors.green; }
                          if (ev.contains('SALIDA')) { icono = Icons.logout; colorIcono = Colors.red; }
                          if (ev.contains('COMER')) { icono = Icons.restaurant; colorIcono = Colors.amber; }
                          return Column(children: [ListTile(leading: Icon(icono, color: colorIcono, size: 28), title: Text('$ev REGISTRADA', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)), trailing: Text(item['hora'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.blueGrey))), if (index < _historialPruebas.length - 1) const Divider()]);
                        },
                      ),
                    ),
              const SizedBox(height: 15),
              Center(child: TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar Historial', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.teal))))
            ],
          ),
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
            else if (boton == '⌫') { if (_pinActual.isNotEmpty) { setState(() { _pinActual = _pinActual.substring(0, _pinActual.length - 1); _pinController.text = _pinActual; }); if (_pinActual.isEmpty) { _apagarCamara(); } } }
            else { _agregarDigito(boton); }
          },
          child: Text(boton, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: esEspecial ? Colors.white : const Color(0xFF2D3748))),
        );
      },
    );
  }

  Widget _buildBotonIncidencia(String titulo, Color color, String tipo) {
    return SizedBox(width: double.infinity, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: color, padding: const EdgeInsets.symmetric(vertical: 18), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 2), onPressed: _pinActual.length < 4 ? null : () => _solicitarConfirmacionMarcaje(tipo), child: Text(titulo, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.5))));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: _estaProcesando
            ? const Center(child: CircularProgressIndicator(color: Colors.teal))
            : LayoutBuilder(builder: (context, constraints) {
                return Column(children: [
                  _buildSeccionVisual(),
                  Expanded(child: SingleChildScrollView(physics: const AlwaysScrollableScrollPhysics(), child: Padding(padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0), child: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: _pinController, readOnly: true, obscureText: true, textAlign: TextAlign.center, style: const TextStyle(fontSize: 28, letterSpacing: 16, fontWeight: FontWeight.bold), decoration: InputDecoration(hintText: '••••', hintStyle: const TextStyle(color: Colors.black26, letterSpacing: 16), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: Colors.white, contentPadding: const EdgeInsets.symmetric(vertical: 12))), const SizedBox(height: 16), _buildTecladoNumerico(), const SizedBox(height: 24), Column(children: [_buildBotonIncidencia('-> ENTRADA', const Color(0xFF2E7D32), 'ENTRADA'), const SizedBox(height: 12), _buildBotonIncidencia('SALIDA COMER', const Color(0xFFE65100), 'SALIDA A COMER'), const SizedBox(height: 12), _buildBotonIncidencia('REGRESO COMER', const Color(0xFF1565C0), 'REGRESO DE COMER'), const SizedBox(height: 12), _buildBotonIncidencia('-> SALIDA', const Color(0xFFC62828), 'SALIDA FIN DE TURNO'), const SizedBox(height: 15), OutlinedButton.icon(style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 50), side: const BorderSide(color: Colors.teal), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), onPressed: _pinActual.length < 4 ? null : _mostrarHistorialUsuario, icon: const Icon(Icons.history, color: Colors.teal), label: const Text('Verificar mis registros de hoy', style: TextStyle(color: Colors.teal, fontSize: 15, fontWeight: FontWeight.bold)))])]))))
                ]);
              }),
      ),
    );
  }
}

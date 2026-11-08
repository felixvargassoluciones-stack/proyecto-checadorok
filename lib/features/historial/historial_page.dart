import 'package:flutter/material.dart';
import '../../core/supabase_service.dart';


class HistorialPage extends StatefulWidget {
  const HistorialPage({super.key});

  @override
  State<HistorialPage> createState() => _HistorialPageState();
}

class _HistorialPageState extends State<HistorialPage> {
  final TextEditingController _pinController = TextEditingController();
  String _pinActual = "";
  bool _estaCargando = false;
  
  // Variables del Empleado Autenticado por PIN
  Map<String, dynamic>? _empleadoAutenticado;
  List<Map<String, dynamic>> _registrosAsistencia = [];

  // Rango de fechas por defecto: Últimos 7 días para consulta autónoma
  DateTimeRange _rangoFechas = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 7)),
    end: DateTime.now(),
  );
  Future<void> _validarAccesoYConsultar() async {
    if (_pinActual.length < 4 || _estaCargando) return;

    setState(() => _estaCargando = true);

    try {
      // 1. Validar existencia del empleado por PIN (Nombres de columna reales)
      final empleadoData = await SupabaseService.client
          .from('empleados')
          .select('id, nombre_completo, pin_acceso')
          .eq('pin_acceso', _pinActual)
          .maybeSingle();

      if (empleadoData == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ PIN incorrecto. No se encontró el trabajador.'),
            backgroundColor: Colors.orange,
          ),
        );
        _limpiarTodo();
        return;
      }

      _empleadoAutenticado = empleadoData;
      await _cargarHistorialFiltrado();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error de comunicación: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _estaCargando = false);
    }
  }

  Future<void> _cargarHistorialFiltrado() async {
    if (_empleadoAutenticado == null) return;

    // Configurar límites de tiempo exactos para el rango seleccionado
    final inicioIso = DateTime(_rangoFechas.start.year, _rangoFechas.start.month, _rangoFechas.start.day, 0, 0, 0).toIso8601String();
    final finIso = DateTime(_rangoFechas.end.year, _rangoFechas.end.month, _rangoFechas.end.day, 23, 59, 59).toIso8601String();

    final response = await SupabaseService.client
        .from('registros_asistencia')
        .select('*')
        .eq('empleado_id', _empleadoAutenticado!['id'])
        .gte('fecha_hora_servidor', inicioIso)
        .lte('fecha_hora_servidor', finIso)
        .order('fecha_hora_servidor', ascending: false);

    if (mounted) {
      setState(() {
        _registrosAsistencia = List<Map<String, dynamic>>.from(response);
      });
    }
  }

  Future<void> _seleccionarRangoFechas() async {
    final DateTimeRange? nuevoRango = await showDateRangePicker(
      context: context,
      initialDateRange: _rangoFechas,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.teal,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black87,
            ),
          ),
          child: child!,
        );
      },
    );

    if (nuevoRango != null && mounted) {
      setState(() => _rangoFechas = nuevoRango);
      if (_empleadoAutenticado != null) {
        setState(() => _estaCargando = true);
        await _cargarHistorialFiltrado();
        setState(() => _estaCargando = false);
      }
    }
  }

  void _agregarDigito(String digito) {
    if (_pinActual.length >= 4) return;
    setState(() {
      _pinActual += digito;
      _pinController.text = _pinActual;
    });
    if (_pinActual.length == 4) {
      _validarAccesoYConsultar();
    }
  }

  void _limpiarTodo() {
    setState(() {
      _pinActual = "";
      _pinController.text = "";
      _empleadoAutenticado = null;
      _registrosAsistencia.clear();
    });
  }
  Widget _buildTeclado() {
    final List<String> botones = ['1', '2', '3', '4', '5', '6', '7', '8', '9', 'C', '0', '⌫'];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: botones.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3, childAspectRatio: 1.6, crossAxisSpacing: 12, mainAxisSpacing: 12
      ),
      itemBuilder: (context, index) {
        final boton = botones[index];
        final bool esEspecial = boton == 'C' || boton == '⌫';
        return ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: esEspecial ? Colors.blueGrey : Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Color(0xFFCBD5E1))
            )
          ),
          onPressed: () {
            if (boton == 'C') { _limpiarTodo(); }
            else if (boton == '⌫') {
              if (_pinActual.isNotEmpty) {
                setState(() {
                  _pinActual = _pinActual.substring(0, _pinActual.length - 1);
                  _pinController.text = _pinActual;
                });
              }
            } else { _agregarDigito(boton); }
          },
          child: Text(boton, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: esEspecial ? Colors.white : const Color(0xFF1E293B))),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.teal,
        elevation: 0,
        title: const Text('CONSULTA DE ASISTENCIA PERSONAL', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        actions: _empleadoAutenticado != null ? [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            tooltip: 'Cerrar Consulta',
            onPressed: _limpiarTodo,
          ),
          const SizedBox(width: 10),
        ] : null,
      ),
      body: SafeArea(
        child: _estaCargando
            ? const Center(child: CircularProgressIndicator(color: Colors.teal))
            : Center(
               child: Container(
  constraints: const BoxConstraints(maxWidth: 600), //  Solución cambiando a 'constraints'
  padding: const EdgeInsets.all(24.0),

                  child: _empleadoAutenticado == null
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.badge, size: 64, color: Colors.teal),
                            const SizedBox(height: 16),
                            const Text('Ingresa tu PIN de Acceso', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                            const SizedBox(height: 8),
                            const Text('Para consultar tus marcas y asistencias, introduce tus 4 números.', style: TextStyle(color: Colors.grey, fontSize: 14), textAlign: TextAlign.center),
                            const SizedBox(height: 24),
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
                              ),
                            ),
                            const SizedBox(height: 24),
                            _buildTeclado(),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Card(
                              color: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFE2E8F0))),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Row(
                                  children: [
                                    const CircleAvatar(backgroundColor: Colors.teal, child: Icon(Icons.person, color: Colors.white)),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(_empleadoAutenticado!['nombre_completo'] ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                                          const Text('Trabajador Activo', style: TextStyle(color: Colors.grey, fontSize: 13)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('HISTORIAL DE MARCAS', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blueGrey, letterSpacing: 0.5)),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                                  onPressed: _seleccionarRangoFechas,
                                  icon: const Icon(Icons.date_range, size: 16, color: Colors.white),
                                  label: Text('${_rangoFechas.start.day}/${_rangoFechas.start.month} al ${_rangoFechas.end.day}/${_rangoFechas.end.month}', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Expanded(
                              child: _registrosAsistencia.isEmpty
                                  ? const Center(child: Text('No se encontraron marcas de asistencia en este rango de fechas.', style: TextStyle(color: Colors.grey), textAlign: TextAlign.center))
                                  : ListView.builder(
                                      itemCount: _registrosAsistencia.length,
                                      itemBuilder: (context, index) {
                                        final registro = _registrosAsistencia[index];
                                        final f = DateTime.parse(registro['fecha_hora_servidor']);
                                        final hFormateada = "${f.hour.toString().padLeft(2, '0')}:${f.minute.toString().padLeft(2, '0')}";
                                        final fFormateada = "${f.day}/${f.month}/${f.year}";

                                        return Card(
                                          margin: const EdgeInsets.only(bottom: 10),
                                          elevation: 0,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: const BorderSide(color: Color(0xFFE2E8F0))),
                                          child: ListTile(
                                            leading: Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(color: Colors.teal.withAlpha(25), shape: BoxShape.circle),
                                              child: const Icon(Icons.access_time, color: Colors.teal),
                                            ),
                                            title: Text(registro['tipo_evento'] ?? 'MARCAJE', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1E293B))),
                                            subtitle: Text('Fecha: $fFormateada • Dispositivo: Kiosco', style: const TextStyle(fontSize: 12)),
                                            trailing: Text('$hFormateada hrs', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.blueGrey)),
                                          ),
                                        );
                                      },
                                    ),
                            ),
                          ],
                        ),
                ),
              ),
      ),
    );
  }
}

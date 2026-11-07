import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/supabase_service.dart';

class RelojDigitalIndependiente extends StatefulWidget {
  const RelojDigitalIndependiente({super.key});

  @override
  State<RelojDigitalIndependiente> createState() => _RelojDigitalIndependienteState();
}

class _RelojDigitalIndependienteState extends State<RelojDigitalIndependiente> {
  Timer? _timer;
  String _horaDigital = "00:00:00";

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final ahora = DateTime.now();
      if (mounted) {
        setState(() {
          _horaDigital = "${ahora.hour.toString().padLeft(2, '0')}:${ahora.minute.toString().padLeft(2, '0')}:${ahora.second.toString().padLeft(2, '0')}";
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        _horaDigital,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1),
      ),
    );
  }
}
class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  final DateTimeRange _rangoFechas = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 7)),
    end: DateTime.now(),
  );

  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nombreController = TextEditingController();
  final TextEditingController _pinAltaController = TextEditingController();
  final TextEditingController _numeroEmpleadoController = TextEditingController();
  final TextEditingController _nuevaSucursalController = TextEditingController();
  final TextEditingController _nuevaEmpresaController = TextEditingController();
  final TextEditingController _correoController = TextEditingController(); // <-- NUEVO

  bool _guardandoEmpleado = false;

  List<Map<String, dynamic>> _empresasDisponibles = [];
  List<Map<String, dynamic>> _sucursalesDisponibles = [];
  
  String? _empresaSeleccionadaUuid;
  String? _sucursalSeleccionadaUuid;
  String _rolSeleccionado = 'TRABAJADOR';

  bool _cargandoDatos = true;
  bool _crearNuevaSucursalManualmente = false;
  bool _crearNuevaEmpresaManualmente = false;

  @override
  void initState() {
    super.initState();
    _cargarEstructuraCorporativa();
  }
  Future<void> _cargarEstructuraCorporativa() async {
    try {
      final datosEmpresas = await SupabaseService.client
          .from('empresas')
          .select('id, nombre')
          .order('nombre');

      final datosSucursales = await SupabaseService.client
          .from('sucursales')
          .select('id, nombre, empresa_id')
          .order('nombre');
      
      if (mounted) {
        setState(() {
          _empresasDisponibles = List<Map<String, dynamic>>.from(datosEmpresas);
          _sucursalesDisponibles = List<Map<String, dynamic>>.from(datosSucursales);

          if (_empresasDisponibles.isNotEmpty) {
            _empresaSeleccionadaUuid = _empresasDisponibles.first['id'].toString();
            _crearNuevaEmpresaManualmente = false;
          } else {
            _empresaSeleccionadaUuid = null;
            _crearNuevaEmpresaManualmente = true;
          }

          if (_sucursalesDisponibles.isNotEmpty) {
            _sucursalSeleccionadaUuid = _sucursalesDisponibles.first['id'].toString();
            _crearNuevaSucursalManualmente = false;
          } else {
            _sucursalSeleccionadaUuid = null;
            _crearNuevaSucursalManualmente = true;
          }

          _cargandoDatos = false;
        });
      }
    } catch (e) {
      debugPrint("Error al cargar datos corporativos: $e");
      if (mounted) setState(() => _cargandoDatos = false);
    }
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _pinAltaController.dispose();
    _numeroEmpleadoController.dispose();
    _nuevaSucursalController.dispose();
    _nuevaEmpresaController.dispose();
    _correoController.dispose(); // <-- NUEVO
    super.dispose();
  }
  Future<void> _registrarNuevoEmpleado() async {
    if (!_formKey.currentState!.validate() || _guardandoEmpleado) return;

    String? empresaIdFinal = _empresaSeleccionadaUuid;
    String? sucursalIdFinal = _sucursalSeleccionadaUuid;

    setState(() => _guardandoEmpleado = true);

    try {
      final String nombre = _nombreController.text.trim();
      final String pin = _pinAltaController.text.trim();
      final String numEmpleadoStr = _numeroEmpleadoController.text.trim();
      final String correo = _correoController.text.trim(); // <-- NUEVO
      final int? numeroEmpleado = int.tryParse(numEmpleadoStr);

      if (numeroEmpleado == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('⚠️ Número numérico no válido.'), backgroundColor: Colors.orange),
        );
        return;
      }

      // 1. Crear Empresa si está en modo manual
      if (_crearNuevaEmpresaManualmente) {
        final String nombreNuevaEmpresa = _nuevaEmpresaController.text.trim();
        final nuevaEmpresaData = await SupabaseService.client
            .from('empresas')
            .insert({'nombre': nombreNuevaEmpresa})
            .select('id')
            .single();
        empresaIdFinal = nuevaEmpresaData['id'].toString();
      }

      if (empresaIdFinal == null) {
        throw 'No se determinó la empresa.';
      }
      // 2. Crear Sucursal si está en modo manual o si la empresa es nueva
      if (_crearNuevaSucursalManualmente || _crearNuevaEmpresaManualmente) {
        final String nombreNuevaSucursal = _nuevaSucursalController.text.trim();
        final nuevaSucursalData = await SupabaseService.client
            .from('sucursales')
            .insert({
              'nombre': nombreNuevaSucursal,
              'empresa_id': empresaIdFinal,
              'pin_kiosco': '0000',
            })
            .select('id')
            .single();
        sucursalIdFinal = nuevaSucursalData['id'].toString();
      }

      if (sucursalIdFinal == null) {
        throw 'No se determinó la sucursal.';
      }

      // 3. Registrar al Empleado o Administrador incluyendo su Correo Electrónico
      await SupabaseService.client.from('empleados').insert({
        'nombre_completo': nombre,
        'pin_acceso': pin,
        'numero_empleado': numeroEmpleado,
        'sucursal_id': sucursalIdFinal,
        'rol': _rolSeleccionado,
        'correo_electronico': correo.isEmpty ? null : correo, // <-- NUEVO MAPPING
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('🎉 ¡Registrado con éxito como $_rolSeleccionado!'), backgroundColor: Colors.teal),
      );

      _nombreController.clear();
      _pinAltaController.clear();
      _numeroEmpleadoController.clear();
      _nuevaSucursalController.clear();
      _nuevaEmpresaController.clear();
      _correoController.clear(); // <-- NUEVO
      
      await _cargarEstructuraCorporativa();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _guardandoEmpleado = false);
    }
  }
  void _descargarExcel() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('📥 Generando archivo CSV...'), backgroundColor: Colors.teal),
    );
  }

  void _imprimirPDF() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('📄 Compilando reporte en PDF...'), backgroundColor: Colors.blueGrey),
    );
  }

  Widget _buildCardMetrica(String titulo, String valor, IconData icono, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xffe2e8f0)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.5)),
                const SizedBox(height: 4),
                Text(valor, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF2D3748))),
              ],
            ),
            Icon(icono, size: 28, color: color),
          ],
        ),
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.teal,
        title: const Row(
          children: [
            Text('ADMINISTRACIÓN', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            SizedBox(width: 12),
            RelojDigitalIndependiente(),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.download_for_offline, color: Colors.white), onPressed: _descargarExcel),
          IconButton(icon: const Icon(Icons.print, color: Colors.white), onPressed: _imprimirPDF),
          const SizedBox(width: 10),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [_buildCardMetrica('PRESENTES', '0', Icons.people, Colors.green), const SizedBox(width: 10), _buildCardMetrica('RETARDOS', '0', Icons.timer, Colors.amber), const SizedBox(width: 10), _buildCardMetrica('AUSENTES', '0', Icons.person_off, Colors.red)]),
            const SizedBox(height: 16),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final bool esMovil = constraints.maxWidth < 750;
                  final Widget formularioAlta = Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xffe2e8f0))),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Row(children: [Icon(Icons.person_add, color: Colors.teal, size: 20), SizedBox(width: 8), Text('ALTA CORPORATIVA DE PERSONAL', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.blueGrey))]),
                          const Divider(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Empresa:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              if (_empresasDisponibles.isNotEmpty)
                                TextButton.icon(style: TextButton.styleFrom(padding: EdgeInsets.zero), onPressed: () => setState(() => _crearNuevaEmpresaManualmente = !_crearNuevaEmpresaManualmente), icon: Icon(_crearNuevaEmpresaManualmente ? Icons.list : Icons.add, size: 14, color: Colors.teal), label: Text(_crearNuevaEmpresaManualmente ? "Ver lista" : "Nueva manual", style: const TextStyle(fontSize: 11, color: Colors.teal))),
                            ],
                          ),
                          const SizedBox(height: 6),
                          _cargandoDatos ? const LinearProgressIndicator(color: Colors.teal) : (_crearNuevaEmpresaManualmente ? TextFormField(controller: _nuevaEmpresaController, textCapitalization: TextCapitalization.words, style: const TextStyle(fontSize: 14), decoration: InputDecoration(hintText: 'Nombre de la empresa', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), filled: true, fillColor: Colors.teal.withValues(alpha: 0.02)), validator: (val) => val == null || val.trim().isEmpty ? 'Requerido' : null) : DropdownButtonFormField<String>(initialValue: _empresaSeleccionadaUuid, decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), filled: true, fillColor: Colors.grey.shade50), style: const TextStyle(fontSize: 14, color: Colors.black87), items: _empresasDisponibles.map((e) => DropdownMenuItem(value: e['id'].toString(), child: Text(e['nombre'] ?? ''))).toList(), onChanged: (v) => setState(() => _empresaSeleccionadaUuid = v), validator: (v) => v == null ? 'Requerido' : null)),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Sucursal:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              if (_sucursalesDisponibles.isNotEmpty && !_crearNuevaEmpresaManualmente)
                                TextButton.icon(style: TextButton.styleFrom(padding: EdgeInsets.zero), onPressed: () => setState(() => _crearNuevaSucursalManualmente = !_crearNuevaSucursalManualmente), icon: Icon(_crearNuevaSucursalManualmente ? Icons.list : Icons.add_business, size: 14, color: Colors.teal), label: Text(_crearNuevaSucursalManualmente ? "Ver lista" : "Nueva manual", style: const TextStyle(fontSize: 11, color: Colors.teal))),
                            ],
                          ),
                          const SizedBox(height: 6),
                          _cargandoDatos ? const LinearProgressIndicator(color: Colors.teal) : (_crearNuevaSucursalManualmente || _crearNuevaEmpresaManualmente ? TextFormField(controller: _nuevaSucursalController, textCapitalization: TextCapitalization.words, style: const TextStyle(fontSize: 14), decoration: InputDecoration(hintText: 'Nombre de la sucursal', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), filled: true, fillColor: Colors.teal.withValues(alpha: 0.02)), validator: (val) => val == null || val.trim().isEmpty ? 'Requerido' : null) : DropdownButtonFormField<String>(initialValue: _sucursalSeleccionadaUuid, decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), filled: true, fillColor: Colors.grey.shade50), style: const TextStyle(fontSize: 14, color: Colors.black87), items: _sucursalesDisponibles.map((s) => DropdownMenuItem(value: s['id'].toString(), child: Text(s['nombre'] ?? ''))).toList(), onChanged: (v) => setState(() => _sucursalSeleccionadaUuid = v), validator: (v) => v == null ? 'Requerido' : null)),
                          const SizedBox(height: 12),
                          const Text('Asignar Rol en el Sistema:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            initialValue: _rolSeleccionado,
                            decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), filled: true, fillColor: Colors.grey.shade50),
                            items: const [DropdownMenuItem(value: 'TRABAJADOR', child: Text('👤 TRABAJADOR / OPERARIO')), DropdownMenuItem(value: 'ADMINISTRADOR', child: Text('🔑 ADMINISTRADOR / SUPERVISOR'))],
                            onChanged: (v) => setState(() => _rolSeleccionado = v ?? 'TRABAJADOR'),
                          ),
                          const SizedBox(height: 12),
                          const Text('Número de Empleado / Nómina:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          const SizedBox(height: 6),
                          TextFormField(controller: _numeroEmpleadoController, keyboardType: TextInputType.number, style: const TextStyle(fontSize: 14), decoration: InputDecoration(hintText: 'Ej. 1024', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)), validator: (val) => val == null || val.trim().isEmpty ? 'Requerido' : (int.tryParse(val.trim()) == null ? 'Solo enteros' : null)),
                          const SizedBox(height: 12),
                          
                          // --- INICIO NUEVO CAMPO VISUAL: CORREO ELECTRÓNICO ---
                          const Text('Correo Electrónico (Para envío de credenciales):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _correoController,
                            keyboardType: TextInputType.emailAddress,
                            style: const TextStyle(fontSize: 14),
                            decoration: InputDecoration(hintText: 'ejemplo@empresa.com', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                            validator: (val) {
                              if (val != null && val.trim().isNotEmpty) {
                                final RegExp emailRegExp = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                                if (!emailRegExp.hasMatch(val.trim())) {
                                  return 'Introduce un formato de correo válido';
                                }
                              }
                              return null; // Es opcional para trabajadores sin correo
                            },
                          ),
                          const SizedBox(height: 12),
                          // --- FIN NUEVO CAMPO VISUAL ---

                          const Text('Nombre Completo:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          const SizedBox(height: 6),
                          TextFormField(controller: _nombreController, textCapitalization: TextCapitalization.words, style: const TextStyle(fontSize: 14), decoration: InputDecoration(hintText: 'Ej. Juan Pérez López', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)), validator: (val) => val == null || val.trim().isEmpty ? 'Requerido' : null),
                          const SizedBox(height: 12),
                          const Text('Asignar PIN de Acceso (4 dígitos):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          const SizedBox(height: 6),
                          TextFormField(controller: _pinAltaController, keyboardType: TextInputType.visiblePassword, autofillHints: null, maxLength: 4, obscureText: true, style: const TextStyle(fontSize: 14), decoration: InputDecoration(hintText: '••••', counterText: '', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)), validator: (val) => val == null || val.trim().length != 4 ? 'Deben ser 4 números' : null),
                          const SizedBox(height: 16),
                          _guardandoEmpleado
                              ? const Center(child: CircularProgressIndicator(color: Colors.teal))
                              : ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, minimumSize: const Size(double.infinity, 45), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))), onPressed: _registrarNuevoEmpleado, icon: const Icon(Icons.save, color: Colors.white, size: 16), label: const Text('Registrar en Supabase', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                        ],
                      ),
                    ),
                  );
                  final Widget seccionFeed = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('MONITOREO DE ASISTENCIAS EN TIEMPO REAL', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                      const SizedBox(height: 8),
                      Expanded(
                        child: StreamBuilder<List<Map<String, dynamic>>>(
                          stream: SupabaseService.client
                              .from('registros_asistencia')
                              .stream(primaryKey: ['id'])
                              .order('fecha_hora_servidor', ascending: false)
                              .map((maps) {
                                final listaFiltrada = maps.where((registro) {
                                  final fServidor = DateTime.parse(registro['fecha_hora_servidor']);
                                  return fServidor.isAfter(_rangoFechas.start.subtract(const Duration(days: 1))) && 
                                         fServidor.isBefore(_rangoFechas.end.add(const Duration(days: 1)));
                                }).toList();
                                return List<Map<String, dynamic>>.from(listaFiltrada);
                              }),
                          builder: (context, snapshot) {
                            if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(fontSize: 12)));
                            if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Colors.teal));
                            final registros = snapshot.data ?? [];
                            if (registros.isEmpty) return const Center(child: Text('Sin checadas registradas el día de hoy.', style: TextStyle(fontSize: 13)));
                            return ListView.builder(
                              itemCount: registros.length,
                              itemBuilder: (context, index) {
                                final r = registros[index];
                                final f = DateTime.parse(r['fecha_hora_servidor']);
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 8.0),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    side: const BorderSide(color: Color(0xffe2e8f0)),
                                  ),
                                  child: ListTile(
                                    leading: const CircleAvatar(backgroundColor: Colors.teal, child: Icon(Icons.person, color: Colors.white, size: 18)),
                                    title: Text('Evento: ${r['tipo_evento']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                    subtitle: Text('Hora: ${f.hour.toString().padLeft(2, '0')}:${f.minute.toString().padLeft(2, '0')}', style: const TextStyle(fontSize: 11)),
                                    trailing: Chip(label: Text(r['estatus_asistencia'] ?? 'OK', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  );

                  return esMovil
                      ? SingleChildScrollView(child: Column(children: [formularioAlta, const SizedBox(height: 20), SizedBox(height: 400, child: seccionFeed)]))
                      : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [SizedBox(width: 320, child: formularioAlta), const SizedBox(width: 20), Expanded(child: seccionFeed)]);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

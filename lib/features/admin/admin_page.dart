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
  final TextEditingController _correoController = TextEditingController();

  bool _guardandoEmpleado = false;

  List<Map<String, dynamic>> _empresasDisponibles = [];
  List<Map<String, dynamic>> _sucursalesDisponibles = [];
  List<Map<String, dynamic>> _empleadosRegistrados = []; // Para la tabla Excel
  
  String? _empresaSeleccionadaUuid;
  String? _sucursalSeleccionadaUuid;
  String _rolSeleccionado = 'TRABAJADOR';

  bool _cargandoDatos = true;
  bool _crearNuevaSucursalManualmente = false;
  bool _crearNuevaEmpresaManualmente = false;

  // CONTROL DE MENÚ LATERAL: 'INICIO', 'REGISTRO', 'MONITOREO'
  String _seccionActivaSidebar = 'INICIO';

  @override
  void initState() {
    super.initState();
    _cargarEstructuraCorporativa();
    _cargarListaEmpleadosExcel();
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
        });
      }
    } catch (e) {
      debugPrint("Error al cargar datos corporativos: $e");
    }
  }

  Future<void> _cargarListaEmpleadosExcel() async {
    try {
      final datos = await SupabaseService.client
          .from('empleados')
          .select('id, numero_empleado, nombre_completo, pin_acceso, rol, sucursal_id, sucursales(nombre)')
          .order('numero_empleado');
      if (mounted) {
        setState(() {
          _empleadosRegistrados = List<Map<String, dynamic>>.from(datos);
          _cargandoDatos = false;
        });
      }
    } catch (e) {
      debugPrint("Error al cargar empleados para Excel: $e");
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
    _correoController.dispose();
    super.dispose();
  }
  Future<void> _registrarNuevoEmpleado() async {
    if (!_formKey.currentState!.validate() || _guardandoEmpleado) return;

    String? empresaIdFinal = _empresaSeleccionadaUuid;
    String? sucursalIdFinal = _sucursalSeleccionadaUuid;

    final String nombre = _nombreController.text.trim();
    final String pin = _pinAltaController.text.trim();
    final String numEmpleadoStr = _numeroEmpleadoController.text.trim();
    final String correo = _correoController.text.trim();
    final int? numeroEmpleado = int.tryParse(numEmpleadoStr);

    if (numeroEmpleado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ Número de empleado no válido.'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _guardandoEmpleado = true);

    try {
      // 1. VALIDACIÓN PREVENTIVA DE DUPLICADOS EN FLUTTER (Evita error Postgres)
      final existeNumero = await SupabaseService.client
          .from('empleados')
          .select('id')
          .eq('numero_empleado', numeroEmpleado)
          .maybeSingle();

      if (existeNumero != null) {
        throw 'El número de empleado/nómina ya está registrado en el sistema.';
      }

      if (correo.isNotEmpty) {
        final existeCorreo = await SupabaseService.client
            .from('empleados')
            .select('id')
            .eq('correo_electronico', correo)
            .maybeSingle();

        if (existeCorreo != null) {
          throw 'El correo electrónico ingresado ya está asignado a otro registro.';
        }
      }

      final existePin = await SupabaseService.client
          .from('empleados')
          .select('id')
          .eq('pin_acceso', pin)
          .maybeSingle();

      if (existePin != null) {
        throw 'El PIN de acceso ingresado ya está en uso. Por seguridad, asigna uno único.';
      }
      // 2. Crear Empresa si está en modo manual
      if (_crearNuevaEmpresaManualmente) {
        final String nombreNuevaEmpresa = _nuevaEmpresaController.text.trim();
        final nuevaEmpresaData = await SupabaseService.client
            .from('empresas')
            .insert({'nombre': nombreNuevaEmpresa})
            .select('id')
            .single();
        empresaIdFinal = nuevaEmpresaData['id'].toString();
      }

      if (empresaIdFinal == null) throw 'No se determinó la empresa.';

      // 3. Crear Sucursal si está en modo manual
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

      if (sucursalIdFinal == null) throw 'No se determinó la sucursal.';

      // 4. Inserción Limpia del Personal
      await SupabaseService.client.from('empleados').insert({
        'nombre_completo': nombre,
        'pin_acceso': pin,
        'numero_empleado': numeroEmpleado,
        'sucursal_id': sucursalIdFinal,
        'rol': _rolSeleccionado,
        'correo_electronico': correo.isEmpty ? null : correo,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('🎉 ¡$nombre registrado con éxito como $_rolSeleccionado!'), backgroundColor: Colors.teal),
      );

      _nombreController.clear();
      _pinAltaController.clear();
      _numeroEmpleadoController.clear();
      _nuevaSucursalController.clear();
      _nuevaEmpresaController.clear();
      _correoController.clear();
      
      await _cargarEstructuraCorporativa();
      await _cargarListaEmpleadosExcel();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('⚠️ $e'), backgroundColor: Colors.orange.shade800, duration: const Duration(seconds: 4)),
      );
    } finally {
      if (mounted) setState(() => _guardandoEmpleado = false);
    }
  }

  void _descargarExcel() {}
  void _imprimirPDF() {}

  Widget _buildCardMetrica(String titulo, String valor, IconData icono, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xffe2e8f0))),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(titulo, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.5)), const SizedBox(height: 4), Text(valor, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF2D3748)))]),
            Icon(icono, size: 28, color: color),
          ],
        ),
      ),
    );
  }
  Widget _buildSidebarMenu() {
    return Container(
      width: 240,
      color: const Color(0xFF1E293B), // Gris Oxford Corporativo
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            color: const Color(0xFF0F172A),
            child: const Row(
              children: [
                Icon(Icons.lock_clock, color: Colors.tealAccent, size: 24),
                SizedBox(width: 12),
                Text('CONTROL PANEL', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildItemSidebar(id: 'INICIO', titulo: 'Inicio / Dashboard', icono: Icons.dashboard),
          _buildItemSidebar(id: 'REGISTRO', titulo: 'Registro de Personal', icono: Icons.person_add_alt_1),
          _buildItemSidebar(id: 'MONITOREO', titulo: 'Monitoreo Asistencias', icono: Icons.playlist_add_check_circle),
          const Spacer(),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('v2.1.0 - Estructura Pura', style: TextStyle(color: Colors.white30, fontSize: 11)),
          )
        ],
      ),
    );
  }

  Widget _buildItemSidebar({required String id, required String titulo, required IconData icono}) {
    final bool esActivo = _seccionActivaSidebar == id;
    return Material(
      color: Colors.transparent,
      child: ListTile(
        onTap: () => setState(() => _seccionActivaSidebar = id),
        leading: Icon(icono, color: esActivo ? Colors.tealAccent : Colors.white60, size: 20),
        title: Text(titulo, style: TextStyle(color: esActivo ? Colors.white : Colors.white70, fontWeight: esActivo ? FontWeight.bold : FontWeight.normal, fontSize: 13)),
        selected: esActivo,
        selectedTileColor: Colors.white.withValues(alpha: 0.05),
      ),
    );
  }
  Widget _buildTablaEmpleadosExcel() {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xffe2e8f0))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.grey.shade50,
            child: const Row(children: [Icon(Icons.table_chart, color: Colors.blueGrey, size: 16), SizedBox(width: 8), Text('CATÁLOGO DE EMPLEADOS REGISTRADOS (ESTILO EXCEL)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueGrey))]),
          ),
          const Divider(height: 1),
          Expanded(
            child: _cargandoDatos
                ? const Center(child: CircularProgressIndicator(color: Colors.teal))
                : SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(Colors.grey.shade100),
                        dataRowMinHeight: 38, dataRowMaxHeight: 42,
                        columns: const [
                          DataColumn(label: Text('NÓMINA', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                          DataColumn(label: Text('NOMBRE COMPLETO', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                          DataColumn(label: Text('ROL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                          DataColumn(label: Text('SUCURSAL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                          DataColumn(label: Text('PIN DE ACCESO', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                        ],
                        rows: _empleadosRegistrados.map((emp) {
                          final sucData = emp['sucursales'] as Map<String, dynamic>?;
                          final String nombreSucursal = sucData != null ? (sucData['nombre'] ?? 'Sin asignar') : 'Sin asignar';
                          return DataRow(cells: [
                            DataCell(Text(emp['numero_empleado'].toString(), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold))),
                            DataCell(Text(emp['nombre_completo'] ?? '', style: const TextStyle(fontSize: 13))),
                            DataCell(Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: emp['rol'] == 'ADMINISTRADOR' ? Colors.purple.shade50 : Colors.blue.shade50, borderRadius: BorderRadius.circular(4)), child: Text(emp['rol'] ?? '', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: emp['rol'] == 'ADMINISTRADOR' ? Colors.purple.shade700 : Colors.blue.shade700)))),
                            DataCell(Text(nombreSucursal, style: const TextStyle(fontSize: 13))),
                            DataCell(Text('••••', style: TextStyle(color: Colors.grey.shade400, fontSize: 13, letterSpacing: 2))),
                          ]);
                        }).toList(),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
  Widget _buildFormularioAltaPersonal() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xffe2e8f0))),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Row(children: [Icon(Icons.person_add, color: Colors.teal, size: 20), SizedBox(width: 8), Text('ALTA CORPORATIVA DE PERSONAL', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.blueGrey))]),
              const Divider(height: 20),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Empresa:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)), if (_empresasDisponibles.isNotEmpty) TextButton.icon(style: TextButton.styleFrom(padding: EdgeInsets.zero), onPressed: () => setState(() => _crearNuevaEmpresaManualmente = !_crearNuevaEmpresaManualmente), icon: Icon(_crearNuevaEmpresaManualmente ? Icons.list : Icons.add, size: 14, color: Colors.teal), label: Text(_crearNuevaEmpresaManualmente ? "Ver lista" : "Nueva manual", style: const TextStyle(fontSize: 11, color: Colors.teal)))]),
              const SizedBox(height: 6),
              _cargandoDatos ? const LinearProgressIndicator(color: Colors.teal) : (_crearNuevaEmpresaManualmente ? TextFormField(controller: _nuevaEmpresaController, textCapitalization: TextCapitalization.words, style: const TextStyle(fontSize: 14), decoration: InputDecoration(hintText: 'Nombre de la empresa', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), filled: true, fillColor: Colors.teal.withValues(alpha: 0.02)), validator: (val) => val == null || val.trim().isEmpty ? 'Requerido' : null) : DropdownButtonFormField<String>(initialValue: _empresaSeleccionadaUuid, decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), filled: true, fillColor: Colors.grey.shade50), style: const TextStyle(fontSize: 14, color: Colors.black87), items: _empresasDisponibles.map((e) => DropdownMenuItem(value: e['id'].toString(), child: Text(e['nombre'] ?? ''))).toList(), onChanged: (v) => setState(() => _empresaSeleccionadaUuid = v), validator: (v) => v == null ? 'Requerido' : null)),
              const SizedBox(height: 12),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Sucursal:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)), if (_sucursalesDisponibles.isNotEmpty && !_crearNuevaEmpresaManualmente) TextButton.icon(style: TextButton.styleFrom(padding: EdgeInsets.zero), onPressed: () => setState(() => _crearNuevaSucursalManualmente = !_crearNuevaSucursalManualmente), icon: Icon(_crearNuevaSucursalManualmente ? Icons.list : Icons.add_business, size: 14, color: Colors.teal), label: Text(_crearNuevaSucursalManualmente ? "Ver lista" : "Nueva manual", style: const TextStyle(fontSize: 11, color: Colors.teal)))]),
              const SizedBox(height: 6),
              _cargandoDatos ? const LinearProgressIndicator(color: Colors.teal) : (_crearNuevaSucursalManualmente || _crearNuevaEmpresaManualmente ? TextFormField(controller: _nuevaSucursalController, textCapitalization: TextCapitalization.words, style: const TextStyle(fontSize: 14), decoration: InputDecoration(hintText: 'Nombre de la sucursal', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), filled: true, fillColor: Colors.teal.withValues(alpha: 0.02)), validator: (val) => val == null || val.trim().isEmpty ? 'Requerido' : null) : DropdownButtonFormField<String>(initialValue: _sucursalSeleccionadaUuid, decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), filled: true, fillColor: Colors.grey.shade50), style: const TextStyle(fontSize: 14, color: Colors.black87), items: _sucursalesDisponibles.map((s) => DropdownMenuItem(value: s['id'].toString(), child: Text(s['nombre'] ?? ''))).toList(), onChanged: (v) => setState(() => _sucursalSeleccionadaUuid = v), validator: (v) => v == null ? 'Requerido' : null)),
              const SizedBox(height: 12),
              const Text('Asignar Rol en el Sistema:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(initialValue: _rolSeleccionado, decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), filled: true, fillColor: Colors.grey.shade50), items: const [DropdownMenuItem(value: 'TRABAJADOR', child: Text('👤 TRABAJADOR / OPERARIO')), DropdownMenuItem(value: 'ADMINISTRADOR', child: Text('🔑 ADMINISTRADOR / SUPERVISOR'))], onChanged: (v) => setState(() => _rolSeleccionado = v ?? 'TRABAJADOR')),
              const SizedBox(height: 12),
              const Text('Número de Empleado / Nómina:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(height: 6),
              TextFormField(controller: _numeroEmpleadoController, keyboardType: TextInputType.number, style: const TextStyle(fontSize: 14), decoration: InputDecoration(hintText: 'Ej. 1024', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)), validator: (val) => val == null || val.trim().isEmpty ? 'Requerido' : (int.tryParse(val.trim()) == null ? 'Solo enteros' : null)),
              const SizedBox(height: 12),
              const Text('Correo Electrónico:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(height: 6),
              TextFormField(controller: _correoController, keyboardType: TextInputType.emailAddress, style: const TextStyle(fontSize: 14), decoration: InputDecoration(hintText: 'ejemplo@empresa.com', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)), validator: (val) { if (val != null && val.trim().isNotEmpty) { final RegExp r = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$'); if (!r.hasMatch(val.trim())) return 'Formato inválido'; } return null; }),
              const SizedBox(height: 12),
              const Text('Nombre Completo:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(height: 6),
              TextFormField(controller: _nombreController, textCapitalization: TextCapitalization.words, style: const TextStyle(fontSize: 14), decoration: InputDecoration(hintText: 'Ej. Juan Pérez López', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)), validator: (val) => val == null || val.trim().isEmpty ? 'Requerido' : null),
              const SizedBox(height: 12),
              const Text('Asignar PIN de Acceso (4 dígitos):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(height: 6),
              TextFormField(controller: _pinAltaController, keyboardType: TextInputType.visiblePassword, autofillHints: null, maxLength: 4, obscureText: true, style: const TextStyle(fontSize: 14), decoration: InputDecoration(hintText: '••••', counterText: '', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)), validator: (val) => val == null || val.trim().length != 4 ? 'Deben ser 4 números' : null),
              const SizedBox(height: 16),
              _guardandoEmpleado ? const Center(child: CircularProgressIndicator(color: Colors.teal)) : ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, minimumSize: const Size(double.infinity, 45), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))), onPressed: _registrarNuevoEmpleado, icon: const Icon(Icons.save, color: Colors.white, size: 16), label: const Text('Registrar en Supabase', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
            ],
          ),
        ),
      ),
    );
  }
  Widget _buildSeccionFeedMonitoreo() {
    return Column(
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
                                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: const BorderSide(color: Color(0xffe2e8f0))),

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
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.teal,
        title: const Row(children: [Text('ADMINISTRACIÓN CENTRAL', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)), SizedBox(width: 12), RelojDigitalIndependiente()]),
        actions: [IconButton(icon: const Icon(Icons.download_for_offline, color: Colors.white), onPressed: _descargarExcel), IconButton(icon: const Icon(Icons.print, color: Colors.white), onPressed: _imprimirPDF), const SizedBox(width: 10)],
      ),
      body: Row(
        children: [
          _buildSidebarMenu(), // Menú de Navegación Izquierdo Fijo
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [_buildCardMetrica('PRESENTES', '0', Icons.people, Colors.green), const SizedBox(width: 10), _buildCardMetrica('RETARDOS', '0', Icons.timer, Colors.amber), const SizedBox(width: 10), _buildCardMetrica('AUSENTES', '0', Icons.person_off, Colors.red)]),
                  const SizedBox(height: 16),
                  Expanded(
                    child: LayoutBuilder(builder: (context, constraints) {
                      final bool esMovil = constraints.maxWidth < 750;
                      
                      // ENRUTADOR DINÁMICO DEL PANEL DERECHO SEGÚN EL SECCIÓN SELECCIONADA
                      if (_seccionActivaSidebar == 'INICIO') {
                        return Container(
                          width: double.infinity, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xffe2e8f0))),
                          child: const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.dashboard_customize, size: 65, color: Colors.teal), SizedBox(height: 16), Text('¡Bienvenido al Panel de Control de Asistencia!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey)), SizedBox(height: 6), Text('Selecciona una opción del menú de la izquierda para comenzar.', style: TextStyle(fontSize: 13, color: Colors.grey))])),
                        );
                      } else if (_seccionActivaSidebar == 'REGISTRO') {
                        return esMovil
                            ? SingleChildScrollView(child: Column(children: [SizedBox(height: 550, child: _buildFormularioAltaPersonal()), const SizedBox(height: 20), SizedBox(height: 400, child: _buildTablaEmpleadosExcel())]))
                            : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [SizedBox(width: 320, child: _buildFormularioAltaPersonal()), const SizedBox(width: 16), Expanded(child: _buildTablaEmpleadosExcel())]);
                      } else {
                        return _buildSeccionFeedMonitoreo();
                      }
                    }),
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

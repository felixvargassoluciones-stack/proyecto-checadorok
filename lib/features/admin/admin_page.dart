import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/supabase_service.dart';
import 'package:web/web.dart' as web; // 👈 NUEVA IMPORTACIÓN OFICIAL QUE ELIMINA LAS ADVERTENCIAS



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
  final _formKey = GlobalKey<FormState>();
  final DateTimeRange _rangoFechas = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 7)),
    end: DateTime.now(),
  );

  // Controladores de Texto del Formulario
  final TextEditingController _nombreController = TextEditingController();
  final TextEditingController _pinAltaController = TextEditingController();
  final TextEditingController _numeroEmpleadoController = TextEditingController();
  final TextEditingController _nuevaSucursalController = TextEditingController();
  final TextEditingController _nuevaEmpresaController = TextEditingController();
  final TextEditingController _correoController = TextEditingController();
  final TextEditingController _nuevoPuestoController = TextEditingController(); 
  final TextEditingController _buscarExcelController = TextEditingController(); 

  bool _guardandoEmpleado = false;

  // Listas de Catálogos e Historiales
  List<Map<String, dynamic>> _empresasDisponibles = [];
  List<Map<String, dynamic>> _sucursalesDisponibles = [];
  List<Map<String, dynamic>> _puestosDisponibles = []; 
  List<Map<String, dynamic>> _empleadosRegistrados = []; 
  
  String? _empresaSeleccionadaUuid;
  String? _sucursalSeleccionadaUuid;
  String? _puestoSeleccionadoUuid; 

  // Variables de control de vistas híbridas
  bool _cargandoDatos = true;
  bool _crearNuevaSucursalManualmente = false;
  bool _crearNuevaEmpresaManualmente = false;
  bool _crearNuevoPuestoManualmente = false; 

  String _seccionActivaSidebar = 'INICIO';
  String? _empleadoIdEdicion;
  DateTime? _fechaIngresoSeleccionada; 

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

      final datosPuestos = await SupabaseService.client
          .from('puestos')
          .select('id, nombre')
          .order('nombre');
      
      if (mounted) {
        setState(() {
          _empresasDisponibles = List<Map<String, dynamic>>.from(datosEmpresas);
          _sucursalesDisponibles = List<Map<String, dynamic>>.from(datosSucursales);
          _puestosDisponibles = List<Map<String, dynamic>>.from(datosPuestos);

          if (_empresasDisponibles.isNotEmpty && (_empresaSeleccionadaUuid == null || !_empresasDisponibles.any((e) => e['id'].toString() == _empresaSeleccionadaUuid))) {
            _empresaSeleccionadaUuid = _empresasDisponibles.first['id'].toString();
            _crearNuevaEmpresaManualmente = false;
          }
          if (_sucursalesDisponibles.isNotEmpty && (_sucursalSeleccionadaUuid == null || !_sucursalesDisponibles.any((s) => s['id'].toString() == _sucursalSeleccionadaUuid))) {
            _sucursalSeleccionadaUuid = _sucursalesDisponibles.first['id'].toString();
            _crearNuevaSucursalManualmente = false;
          }
          if (_puestosDisponibles.isNotEmpty && (_puestoSeleccionadoUuid == null || !_puestosDisponibles.any((p) => p['id'].toString() == _puestoSeleccionadoUuid))) {
            _puestoSeleccionadoUuid = _puestosDisponibles.first['id'].toString();
            _crearNuevoPuestoManualmente = false;
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
          .select('id, numero_empleado, nombre_completo, pin_acceso, puesto_id, sucursal_id, correo_electronico, fecha_ingreso, sucursales(nombre), puestos(nombre)')
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
    _nuevoPuestoController.dispose();
    _buscarExcelController.dispose();
    super.dispose();
  }
    Future<void> _modificarEmpresaDialog() async {
    if (_empresaSeleccionadaUuid == null) return;
    final empresaActual = _empresasDisponibles.firstWhere((e) => e['id'].toString() == _empresaSeleccionadaUuid);
    final editController = TextEditingController(text: empresaActual['nombre']);
    
    final nuevoNombre = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Modificar Nombre de Empresa', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        // ✅ Forzar mayúsculas en teclado
        content: TextFormField(controller: editController, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(border: OutlineInputBorder())),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
          // ✅ Forzar mayúsculas en el string al guardar
          ElevatedButton(onPressed: () => Navigator.pop(context, editController.text.trim().toUpperCase()), style: ElevatedButton.styleFrom(backgroundColor: Colors.teal), child: const Text('Guardar', style: TextStyle(color: Colors.white))),
        ],
      ),
    );

    if (nuevoNombre != null && nuevoNombre.isNotEmpty) {
      try {
        await SupabaseService.client.from('empresas').update({'nombre': nuevoNombre}).eq('id', _empresaSeleccionadaUuid!);
        await _cargarEstructuraCorporativa();
        await _cargarListaEmpleadosExcel();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }


  Future<void> _eliminarEmpresaDialog() async {
    if (_empresaSeleccionadaUuid == null) return;
    final bool? confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ ¿Eliminar Empresa?', style: TextStyle(color: Colors.red)),
        content: const Text('Esto eliminará todas sus sucursales y trabajadores vinculados permanentemente. ¿Proceder?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text('Eliminar', style: TextStyle(color: Colors.white))),
        ],
      ),
    );

    if (confirmar == true) {
      try {
        await SupabaseService.client.from('empresas').delete().eq('id', _empresaSeleccionadaUuid!);
        setState(() { _empresaSeleccionadaUuid = null; _sucursalSeleccionadaUuid = null; });
        await _cargarEstructuraCorporativa();
        await _cargarListaEmpleadosExcel();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

   Future<void> _modificarSucursalDialog() async {
    if (_sucursalSeleccionadaUuid == null) return;
    final sucursalActual = _sucursalesDisponibles.firstWhere((s) => s['id'].toString() == _sucursalSeleccionadaUuid);
    final editController = TextEditingController(text: sucursalActual['nombre']);
    
    final nuevoNombre = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Modificar Nombre de Sucursal', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        // ✅ Forzar mayúsculas en teclado
        content: TextFormField(controller: editController, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(border: OutlineInputBorder())),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
          // ✅ Forzar mayúsculas en el string al guardar
          ElevatedButton(onPressed: () => Navigator.pop(context, editController.text.trim().toUpperCase()), style: ElevatedButton.styleFrom(backgroundColor: Colors.teal), child: const Text('Guardar', style: TextStyle(color: Colors.white))),
        ],
      ),
    );

    if (nuevoNombre != null && nuevoNombre.isNotEmpty) {
      try {
        await SupabaseService.client.from('sucursales').update({'nombre': nuevoNombre}).eq('id', _sucursalSeleccionadaUuid!);
        await _cargarEstructuraCorporativa();
        await _cargarListaEmpleadosExcel();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }


  Future<void> _eliminarSucursalDialog() async {
    if (_sucursalSeleccionadaUuid == null) return;
    final bool? confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ ¿Eliminar Sucursal?', style: TextStyle(color: Colors.red)),
        content: const Text('Esto eliminará de forma irreversible la sucursal y todos los empleados en ella. ¿Proceder?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text('Eliminar', style: TextStyle(color: Colors.white))),
        ],
      ),
    );

    if (confirmar == true) {
      try {
        await SupabaseService.client.from('sucursales').delete().eq('id', _sucursalSeleccionadaUuid!);
        setState(() { _sucursalSeleccionadaUuid = null; });
        await _cargarEstructuraCorporativa();
        await _cargarListaEmpleadosExcel();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }
   Future<void> _modificarPuestoDialog() async {
    if (_puestoSeleccionadoUuid == null) return;
    final puestoActual = _puestosDisponibles.firstWhere((p) => p['id'].toString() == _puestoSeleccionadoUuid);
    final editController = TextEditingController(text: puestoActual['nombre']);
    
    final nuevoNombre = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Modificar Nombre del Puesto', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        // ✅ Forzar mayúsculas en teclado
        content: TextFormField(controller: editController, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(border: OutlineInputBorder())),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
          // ✅ Forzar mayúsculas en el string al guardar
          ElevatedButton(onPressed: () => Navigator.pop(context, editController.text.trim().toUpperCase()), style: ElevatedButton.styleFrom(backgroundColor: Colors.teal), child: const Text('Guardar', style: TextStyle(color: Colors.white))),
        ],
      ),
    );

    if (nuevoNombre != null && nuevoNombre.isNotEmpty) {
      try {
        await SupabaseService.client.from('puestos').update({'nombre': nuevoNombre}).eq('id', _puestoSeleccionadoUuid!);
        await _cargarEstructuraCorporativa();
        await _cargarListaEmpleadosExcel();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }


  Future<void> _eliminarPuestoDialog() async {
    if (_puestoSeleccionadoUuid == null) return;
    final bool? confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ ¿Eliminar Puesto?', style: TextStyle(color: Colors.red)),
        content: const Text('Esto desvinculará este cargo de todos sus empleados. ¿Proceder?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text('Eliminar', style: TextStyle(color: Colors.white))),
        ],
      ),
    );

    if (confirmar == true) {
      try {
        await SupabaseService.client.from('puestos').delete().eq('id', _puestoSeleccionadoUuid!);
        setState(() { _puestoSeleccionadoUuid = null; });
        await _cargarEstructuraCorporativa();
        await _cargarListaEmpleadosExcel();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _seleccionarFechaIngreso(BuildContext context) async {
    final DateTime? seleccionado = await showDatePicker(
      context: context,
      initialDate: _fechaIngresoSeleccionada ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(colorScheme: const ColorScheme.light(primary: Colors.teal, onPrimary: Colors.white, onSurface: Colors.black87)),
        child: child!,
      ),
    );
    if (seleccionado != null && seleccionado != _fechaIngresoSeleccionada) {
      setState(() {
        _fechaIngresoSeleccionada = seleccionado;
      });
    }
  }
  Future<void> _registrarNuevoEmpleado() async {
    if (!_formKey.currentState!.validate() || _guardandoEmpleado) return;
    if (_fechaIngresoSeleccionada == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('⚠️ Por favor selecciona la fecha de ingreso.'), backgroundColor: Colors.orange));
      return;
    }

    String? empresaIdFinal = _empresaSeleccionadaUuid;
    String? sucursalIdFinal = _sucursalSeleccionadaUuid;
    String? puestoIdFinal = _puestoSeleccionadoUuid;

    final String nombre = _nombreController.text.trim();
    final String pin = _pinAltaController.text.trim();
    final String numEmpleadoStr = _numeroEmpleadoController.text.trim();
    final String correo = _correoController.text.trim();
    final int? numeroEmpleado = int.tryParse(numEmpleadoStr);

    if (numeroEmpleado == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('⚠️ Número de empleado no válido.'), backgroundColor: Colors.orange));
      return;
    }

    setState(() => _guardandoEmpleado = true);

    try {
      final existeNumero = await SupabaseService.client.from('empleados').select('id').eq('numero_empleado', numeroEmpleado).maybeSingle();
      if (existeNumero != null && (_empleadoIdEdicion == null || existeNumero['id'].toString() != _empleadoIdEdicion)) {
        throw 'El número de empleado/nómina ya está registrado.';
      }

      if (correo.isNotEmpty) {
        final existeCorreo = await SupabaseService.client.from('empleados').select('id').eq('correo_electronico', correo).maybeSingle();
        if (existeCorreo != null && (_empleadoIdEdicion == null || existeCorreo['id'].toString() != _empleadoIdEdicion)) {
          throw 'El correo electrónico ya está asignado a otro registro.';
        }
      }

      final existePin = await SupabaseService.client.from('empleados').select('id').eq('pin_acceso', pin).maybeSingle();
      if (existePin != null && (_empleadoIdEdicion == null || existePin['id'].toString() != _empleadoIdEdicion)) {
        throw 'El PIN de acceso ya está en uso por otro trabajador.';
      }

           if (_crearNuevaEmpresaManualmente) {
        // ✅ Forzar transformación a Mayúsculas
        final String nombreNuevaEmpresa = _nuevaEmpresaController.text.trim().toUpperCase();
        final nuevaEmpresaData = await SupabaseService.client.from('empresas').insert({'nombre': nombreNuevaEmpresa}).select('id').single();
        empresaIdFinal = nuevaEmpresaData['id'].toString();
      }
      if (empresaIdFinal == null) throw 'No se determinó la empresa.';

      if (_crearNuevaSucursalManualmente || _crearNuevaEmpresaManualmente) {
        // ✅ Forzar transformación a Mayúsculas
        final String nombreNuevaSucursal = _nuevaSucursalController.text.trim().toUpperCase();
        final nuevaSucursalData = await SupabaseService.client.from('sucursales').insert({'nombre': nombreNuevaSucursal, 'empresa_id': empresaIdFinal, 'pin_kiosco': '0000'}).select('id').single();
        sucursalIdFinal = nuevaSucursalData['id'].toString();
      }
      if (sucursalIdFinal == null) throw 'No se determinó la sucursal.';

      if (_crearNuevoPuestoManualmente) {
        // ✅ Forzar transformación a Mayúsculas
        final String nombreNuevoPuesto = _nuevoPuestoController.text.trim().toUpperCase();
        final nuevoPuestoData = await SupabaseService.client.from('puestos').insert({'nombre': nombreNuevoPuesto}).select('id').single();
        puestoIdFinal = nuevoPuestoData['id'].toString();
      }
      if (puestoIdFinal == null) throw 'No se determinó el puesto de trabajo.';


      final Map<String, dynamic> datosEmpleado = {
        'nombre_completo': nombre,
        'pin_acceso': pin,
        'numero_empleado': numeroEmpleado,
        'sucursal_id': sucursalIdFinal,
        'puesto_id': puestoIdFinal,
        'correo_electronico': correo.isEmpty ? null : correo,
        'fecha_ingreso': _fechaIngresoSeleccionada!.toIso8601String().substring(0, 10),
      };

      if (_empleadoIdEdicion == null) {
        await SupabaseService.client.from('empleados').insert(datosEmpleado);

          // ✅ CONEXIÓN SENIOR: Disparar correo automático de bienvenida al guardar con éxito
        // Solo se envía si el administrador capturó un correo válido para el trabajador
        if (correo.isNotEmpty) {
          _enviarCorreoBrevo(
            destinatario: correo,
            nombreEmpleado: nombre,
            nomina: numEmpleadoStr,
            pin: pin,
          );
        }

        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('🎉 ¡Personal registrado correctamente!'), backgroundColor: Colors.teal));
      } else {
        await SupabaseService.client.from('empleados').update(datosEmpleado).eq('id', _empleadoIdEdicion!);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✏️ ¡Datos actualizados con éxito!'), backgroundColor: Colors.amber));
      }

      _cancelarEdicion();
      await _cargarEstructuraCorporativa();
      await _cargarListaEmpleadosExcel();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('⚠️ $e'), backgroundColor: Colors.orange.shade800));
    } finally {
      if (mounted) setState(() => _guardandoEmpleado = false);
    }
  }
  Future<void> _eliminarEmpleado(String id, String nombre) async {
    final bool? confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Row(children: [Icon(Icons.warning_amber_rounded, color: Colors.red), SizedBox(width: 8), Text('¿Eliminar Personal?')]),
        content: Text('¿Estás seguro de que deseas eliminar permanentemente a "$nombre"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red), onPressed: () => Navigator.pop(context, true), child: const Text('Sí, Eliminar', style: TextStyle(color: Colors.white))),
        ],
      ),
    );
    if (confirmar != true) return;
    try {
      await SupabaseService.client.from('empleados').delete().eq('id', id);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('🗑️ Registro de "$nombre" eliminado.'), backgroundColor: Colors.red.shade800));
      if (_empleadoIdEdicion == id) _cancelarEdicion();
      await _cargarListaEmpleadosExcel();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  void _activarModoEdicion(Map<String, dynamic> emp) {
    setState(() {
      _empleadoIdEdicion = emp['id'].toString();
      _nombreController.text = emp['nombre_completo'] ?? '';
      _numeroEmpleadoController.text = emp['numero_empleado']?.toString() ?? '';
      _correoController.text = emp['correo_electronico'] ?? '';
      _pinAltaController.text = emp['pin_acceso'] ?? '';
      _puestoSeleccionadoUuid = emp['puesto_id']?.toString();
      _sucursalSeleccionadaUuid = emp['sucursal_id']?.toString();
      if (emp['fecha_ingreso'] != null) {
        _fechaIngresoSeleccionada = DateTime.parse(emp['fecha_ingreso']);
      } else {
        _fechaIngresoSeleccionada = null;
      }
    });
  }

  void _cancelarEdicion() {
    setState(() {
      _empleadoIdEdicion = null;
      _nombreController.clear();
      _numeroEmpleadoController.clear();
      _correoController.clear();
      _pinAltaController.clear();
      _nuevoPuestoController.clear();
      _fechaIngresoSeleccionada = null;
    });
  }

  Widget _buildSidebarMenu() {
    return Container(
      width: 240,
      color: const Color(0xFF1E293B), 
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
          const Padding(padding: EdgeInsets.all(16.0), child: Text('v2.4.0 - Buscador & Ingreso', style: TextStyle(color: Colors.white30, fontSize: 11)))
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
    final String busqueda = _buscarExcelController.text.trim().toLowerCase();
    
    final listaFiltrada = _empleadosRegistrados.where((emp) {
      final String nomina = emp['numero_empleado']?.toString().toLowerCase() ?? '';
      final String nombre = emp['nombre_completo']?.toString().toLowerCase() ?? '';
      final String correo = emp['correo_electronico']?.toString().toLowerCase() ?? '';
      final String fIngreso = emp['fecha_ingreso']?.toString().toLowerCase() ?? '';
      
      final sucData = emp['sucursales'] as Map<String, dynamic>?;
      final String sucursal = sucData != null ? (sucData['nombre'] ?? '').toString().toLowerCase() : '';
      
      final puestoData = emp['puestos'] as Map<String, dynamic>?;
      final String puesto = puestoData != null ? (puestoData['nombre'] ?? '').toString().toLowerCase() : '';

      return nomina.contains(busqueda) || nombre.contains(busqueda) || correo.contains(busqueda) || sucursal.contains(busqueda) || puesto.contains(busqueda) || fIngreso.contains(busqueda);
    }).toList();

    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xffe2e8f0))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _buscarExcelController,
                    onChanged: (value) => setState(() {}), 
                    decoration: InputDecoration(
                      hintText: '🔍 Buscar por Nómina, Nombre, Cargo, Correo, Sucursal o Fecha...',
                      hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
                      prefixIcon: const Icon(Icons.search, size: 18, color: Colors.grey),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                  ),
                ),
              ],
            ),
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
                          DataColumn(label: Text('CARGO / PUESTO', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                          DataColumn(label: Text('FECHA INGRESO', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))), 
                          DataColumn(label: Text('CORREO ELECTRÓNICO', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                          DataColumn(label: Text('SUCURSAL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                          DataColumn(label: Text('PIN DE ACCESO', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                          DataColumn(label: Text('ACCIONES', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                        ],
                        rows: listaFiltrada.map((emp) {
                          final sucData = emp['sucursales'] as Map<String, dynamic>?;
                          final String nombreSucursal = sucData != null ? (sucData['nombre'] ?? 'Sin asignar') : 'Sin asignar';
                          final puestoData = emp['puestos'] as Map<String, dynamic>?;
                          final String nombrePuesto = puestoData != null ? (puestoData['nombre'] ?? 'GENERAL') : 'GENERAL';
                          final String fIngreso = emp['fecha_ingreso'] ?? 'No registrada';

                          return DataRow(cells: [
                            DataCell(Text(emp['numero_empleado'].toString(), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold))),
                            DataCell(Text(emp['nombre_completo'] ?? '', style: const TextStyle(fontSize: 13))),
                            DataCell(Text(nombrePuesto, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.indigo))),
                            DataCell(Text(fIngreso, style: const TextStyle(fontSize: 13, color: Colors.blueGrey))),
                            DataCell(Text(emp['correo_electronico'] ?? 'Sin correo', style: const TextStyle(fontSize: 13))),
                            DataCell(Text(nombreSucursal, style: const TextStyle(fontSize: 13))),
                            DataCell(Text(emp['pin_acceso'] ?? '----', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.teal))),
                            DataCell(Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(icon: const Icon(Icons.edit, color: Colors.amber, size: 16), padding: EdgeInsets.zero, constraints: const BoxConstraints(), onPressed: () => _activarModoEdicion(emp)),
                                const SizedBox(width: 8),
                                IconButton(icon: const Icon(Icons.delete, color: Colors.red, size: 16), padding: EdgeInsets.zero, constraints: const BoxConstraints(), onPressed: () => _eliminarEmpleado(emp['id'].toString(), emp['nombre_completo'] ?? '')),
                              ],
                            )),
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
    final String txtFecha = _fechaIngresoSeleccionada == null 
        ? 'Seleccionar Fecha' 
        : '${_fechaIngresoSeleccionada!.day}/${_fechaIngresoSeleccionada!.month}/${_fechaIngresoSeleccionada!.year}';

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
              Row(children: [Icon(_empleadoIdEdicion == null ? Icons.person_add : Icons.edit_note, color: Colors.teal, size: 20), const SizedBox(width: 8), Text(_empleadoIdEdicion == null ? 'ALTA CORPORATIVA DE PERSONAL' : 'MODIFICAR DATOS DE PERSONAL', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.blueGrey))]),
              const Divider(height: 20),
              
              // SECCIÓN EMPRESA
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Empresa:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                Row(children: [
                  if (_empresaSeleccionadaUuid != null && !_crearNuevaEmpresaManualmente) ...[
                    IconButton(icon: const Icon(Icons.edit, size: 14, color: Colors.amber), padding: EdgeInsets.zero, constraints: const BoxConstraints(), onPressed: _modificarEmpresaDialog),
                    const SizedBox(width: 6),
                    IconButton(icon: const Icon(Icons.delete_forever, size: 14, color: Colors.red), padding: EdgeInsets.zero, constraints: const BoxConstraints(), onPressed: _eliminarEmpresaDialog),
                    const SizedBox(width: 12),
                  ],
                  if (_empresasDisponibles.isNotEmpty && _empleadoIdEdicion == null) TextButton.icon(style: TextButton.styleFrom(padding: EdgeInsets.zero), onPressed: () => setState(() => _crearNuevaEmpresaManualmente = !_crearNuevaEmpresaManualmente), icon: Icon(_crearNuevaEmpresaManualmente ? Icons.list : Icons.add, size: 14, color: Colors.teal), label: Text(_crearNuevaEmpresaManualmente ? "Ver lista" : "Nueva manual", style: const TextStyle(fontSize: 11, color: Colors.teal))),
                ])
              ]),
              const SizedBox(height: 6),
              _cargandoDatos ? const LinearProgressIndicator(color: Colors.teal) : (_crearNuevaEmpresaManualmente ? TextFormField(controller: _nuevaEmpresaController, textCapitalization: TextCapitalization.characters, style: const TextStyle(fontSize: 14), decoration: InputDecoration(hintText: 'Nombre de la empresa', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), filled: true, fillColor: Colors.teal.withValues(alpha: 0.02)), validator: (val) => val == null || val.trim().isEmpty ? 'Requerido' : null) : DropdownButtonFormField<String>(initialValue: _empresaSeleccionadaUuid, decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), filled: true, fillColor: Colors.grey.shade50), style: const TextStyle(fontSize: 14, color: Colors.black87), items: _empresasDisponibles.map((e) => DropdownMenuItem(value: e['id'].toString(), child: Text(e['nombre'] ?? ''))).toList(), onChanged: (v) => setState(() { _empresaSeleccionadaUuid = v; _sucursalSeleccionadaUuid = null; }), validator: (v) => v == null ? 'Requerido' : null)),
              const SizedBox(height: 12),
              
              // SECCIÓN SUCURSAL
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Sucursal:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                Row(children: [
                  if (_sucursalSeleccionadaUuid != null && !_crearNuevaSucursalManualmente && _empleadoIdEdicion == null) ...[
                    IconButton(icon: const Icon(Icons.edit, size: 14, color: Colors.amber), padding: EdgeInsets.zero, constraints: const BoxConstraints(), onPressed: _modificarSucursalDialog),
                    const SizedBox(width: 6),
                    IconButton(icon: const Icon(Icons.delete_forever, size: 14, color: Colors.red), padding: EdgeInsets.zero, constraints: const BoxConstraints(), onPressed: _eliminarSucursalDialog),
                    const SizedBox(width: 12),
                  ],
                  if (_sucursalesDisponibles.isNotEmpty && !_crearNuevaEmpresaManualmente && _empleadoIdEdicion == null) TextButton.icon(style: TextButton.styleFrom(padding: EdgeInsets.zero), onPressed: () => setState(() => _crearNuevaSucursalManualmente = !_crearNuevaSucursalManualmente), icon: Icon(_crearNuevaSucursalManualmente ? Icons.list : Icons.add_business, size: 14, color: Colors.teal), label: Text(_crearNuevaSucursalManualmente ? "Ver lista" : "Nueva manual", style: const TextStyle(fontSize: 11, color: Colors.teal))),
                ])
              ]),
              const SizedBox(height: 6),
              _cargandoDatos ? const LinearProgressIndicator(color: Colors.teal) : (_crearNuevaSucursalManualmente || _crearNuevaEmpresaManualmente ? TextFormField(controller: _nuevaSucursalController, textCapitalization: TextCapitalization.characters, style: const TextStyle(fontSize: 14), decoration: InputDecoration(hintText: 'Nombre de la sucursal', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), filled: true, fillColor: Colors.teal.withValues(alpha: 0.02)), validator: (val) => val == null || val.trim().isEmpty ? 'Requerido' : null) : DropdownButtonFormField<String>(initialValue: _sucursalSeleccionadaUuid, decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), filled: true, fillColor: Colors.grey.shade50), items: _sucursalesDisponibles.where((s) => s['empresa_id'].toString() == _empresaSeleccionadaUuid).map((s) => DropdownMenuItem(value: s['id'].toString(), child: Text(s['nombre'] ?? ''))).toList(), onChanged: (v) => setState(() => _sucursalSeleccionadaUuid = v), validator: (v) => v == null ? 'Requerido' : null)),
              const SizedBox(height: 12),
              // SECCIÓN CARGO / PUESTO
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween, 
                children: [
                  const Text('Cargo / Puesto de Trabajo:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  Row(
                    children: [
                      if (_puestoSeleccionadoUuid != null && !_crearNuevoPuestoManualmente) ...[
                        IconButton(icon: const Icon(Icons.edit, size: 14, color: Colors.amber), padding: EdgeInsets.zero, constraints: const BoxConstraints(), onPressed: _modificarPuestoDialog),
                        const SizedBox(width: 6),
                        IconButton(icon: const Icon(Icons.delete_forever, size: 14, color: Colors.red), padding: EdgeInsets.zero, constraints: const BoxConstraints(), onPressed: _eliminarPuestoDialog),
                        const SizedBox(width: 12),
                      ],
                      if (_empleadoIdEdicion == null) 
                        TextButton.icon(
                          style: TextButton.styleFrom(padding: EdgeInsets.zero), 
                          onPressed: () => setState(() => _crearNuevoPuestoManualmente = !_crearNuevoPuestoManualmente), 
                          icon: Icon(_crearNuevoPuestoManualmente ? Icons.list : Icons.add_circle_outline, size: 14, color: Colors.teal), 
                          label: Text(_crearNuevoPuestoManualmente ? "Ver lista" : "Nuevo manual", style: const TextStyle(fontSize: 11, color: Colors.teal))
                        ),
                    ],
                  )
                ]
              ),
              const SizedBox(height: 6),
              _cargandoDatos ? const LinearProgressIndicator(color: Colors.teal) : (_crearNuevoPuestoManualmente ? TextFormField(controller: _nuevoPuestoController, textCapitalization: TextCapitalization.characters, style: const TextStyle(fontSize: 14), decoration: InputDecoration(hintText: 'Ej. Mecánico, Supervisor', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), filled: true, fillColor: Colors.teal.withValues(alpha: 0.02)), validator: (val) => val == null || val.trim().isEmpty ? 'Requerido' : null) : DropdownButtonFormField<String>(initialValue: _puestoSeleccionadoUuid, decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), filled: true, fillColor: Colors.grey.shade50), style: const TextStyle(fontSize: 14, color: Colors.black87), items: _puestosDisponibles.map((p) => DropdownMenuItem(value: p['id'].toString(), child: Text(p['nombre'] ?? ''))).toList(), onChanged: (v) => setState(() => _puestoSeleccionadoUuid = v), validator: (v) => v == null ? 'Requerido' : null)),
              const SizedBox(height: 12),
              
              // SECCIÓN FECHA DE INGRESO
              const Text('Fecha de Ingreso de Nómina:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(height: 6),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 44), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), side: BorderSide(color: _fechaIngresoSeleccionada == null ? Colors.grey.shade400 : Colors.teal)),
                onPressed: () => _seleccionarFechaIngreso(context),
                icon: Icon(Icons.calendar_month, color: _fechaIngresoSeleccionada == null ? Colors.grey : Colors.teal, size: 16),
                label: Text(txtFecha, style: TextStyle(color: _fechaIngresoSeleccionada == null ? Colors.black54 : Colors.teal.shade900, fontWeight: FontWeight.bold, fontSize: 13)),
              ),
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
              TextFormField(controller: _nombreController, textCapitalization: TextCapitalization.words, style: const TextStyle(fontSize: 14), decoration: InputDecoration(hintText: 'Ej. Juan Pérez López', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)), validator: (val) => val == null || val.trim().isEmpty ? 'Requerido' : null) ,
              const SizedBox(height: 12),
              const Text('PIN de Acceso (4 dígitos):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(height: 6),
              TextFormField(controller: _pinAltaController, keyboardType: TextInputType.number, autofillHints: null, maxLength: 4, obscureText: false, style: const TextStyle(fontSize: 14), decoration: InputDecoration(hintText: 'Ej. 4321', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)), validator: (val) => val == null || val.trim().length != 4 ? 'Deben ser 4 números' : null),
              const SizedBox(height: 16),
              _guardandoEmpleado ? const Center(child: CircularProgressIndicator(color: Colors.teal)) : Column(children: [ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: _empleadoIdEdicion == null ? Colors.teal : Colors.amber.shade800, minimumSize: const Size(double.infinity, 45), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))), onPressed: _registrarNuevoEmpleado, icon: Icon(_empleadoIdEdicion == null ? Icons.save : Icons.edit_note, color: Colors.white, size: 16), label: Text(_empleadoIdEdicion == null ? 'Registrar en Supabase' : 'Actualizar Cambios', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))), if (_empleadoIdEdicion != null) ...[const SizedBox(height: 8), TextButton(onPressed: _cancelarEdicion, child: const Text('Cancelar Edición', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)))]]),
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
            stream: SupabaseService.client.from('registros_asistencia').stream(primaryKey: ['id']).order('fecha_hora_servidor', ascending: false).map((maps) {
              final listaFiltrada = maps.where((registro) {
                final fServidor = DateTime.parse(registro['fecha_hora_servidor']);
                return fServidor.isAfter(_rangoFechas.start.subtract(const Duration(days: 1))) && fServidor.isBefore(_rangoFechas.end.add(const Duration(days: 1)));
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
                    elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: const BorderSide(color: Color(0xffe2e8f0))),
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

  void _descargarExcel() {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('📥 Generando archivo CSV...'), backgroundColor: Colors.teal));
    }
  }

  void _imprimirPDF() {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('📄 Compilando reporte en PDF...'), backgroundColor: Colors.blueGrey));
    }
  }

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
          _buildSidebarMenu(), 
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
                      if (_seccionActivaSidebar == 'INICIO') {
                        return Container(
                          width: double.infinity, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xffe2e8f0))),
                          child: const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.dashboard_customize, size: 65, color: Colors.teal), SizedBox(height: 16), Text('¡Bienvenido al Panel de Control de Asistencia!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey)), SizedBox(height: 6), Text('Selecciona una opción del menú de la izquierda para comenzar.', style: TextStyle(fontSize: 13, color: Colors.grey))])),
                        );
                      } else if (_seccionActivaSidebar == 'REGISTRO') {
                        return esMovil
                            ? SingleChildScrollView(child: Column(children: [SizedBox(height: 600, child: _buildFormularioAltaPersonal()), const SizedBox(height: 20), SizedBox(height: 400, child: _buildTablaEmpleadosExcel())]))
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

     // ✅ ENFOQUE GMAIL WEB: Abre directamente la pestaña de redacción de Google con datos precargados
  void _enviarCorreoBrevo({
    required String destinatario,
    required String nombreEmpleado,
    required String nomina,
    required String pin,
  }) {
    // 1. Estructuramos el asunto y el cuerpo del mensaje
    final String asunto = Uri.encodeComponent("🔑 CREDENCIALES DE ACCESO - RELOJ CHECADOR");
    final String cuerpo = Uri.encodeComponent(
      "¡Hola, $nombreEmpleado!\n\n"
      "Se ha generado tu alta en el sistema de asistencia.\n"
      "A continuación, se detallan tus credenciales oficiales para registrar tus entradas y salidas en el Kiosco:\n\n"
      "----------------------------------------\n"
      "  NÚMERO DE NÓMINA: $nomina\n"
      "  PIN DE ACCESO:    $pin\n"
      "----------------------------------------\n\n"
      "Por seguridad, memoriza tu PIN de 4 dígitos y evita compartirlo."
    );

    // 2. Usamos el enlace universal de redacción de Gmail Web (en lugar de mailto)
    final String gmailUrl = "https://mail.google.com/mail/?view=cm&fs=1&to=$destinatario&su=$asunto&body=$cuerpo";

    // 3. Abrimos Gmail en una nueva pestaña limpia del navegador de forma segura
    web.window.open(gmailUrl, '_blank');
  }






}

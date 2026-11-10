import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/supabase_service.dart';
import 'package:web/web.dart' as web; // 👈 NUEVA IMPORTACIÓN OFICIAL QUE ELIMINA LAS ADVERTENCIAS
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';




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
   DateTimeRange _rangoFechas = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 7)),
    end: DateTime.now(),
  );

   // Controladores de Texto del Formulario Existentes
  final TextEditingController _nombreController = TextEditingController();
  final TextEditingController _pinAltaController = TextEditingController();
  final TextEditingController _numeroEmpleadoController = TextEditingController();
  final TextEditingController _nuevaSucursalController = TextEditingController();
  final TextEditingController _nuevaEmpresaController = TextEditingController();
  final TextEditingController _correoController = TextEditingController();
  final TextEditingController _nuevoPuestoController = TextEditingController(); 
  final TextEditingController _buscarExcelController = TextEditingController(); 

  // 🌟 PEGAR AQUÍ LOS NUEVOS CONTROLADORES PARA EL MÓDULO DE TURNOS:
  final TextEditingController _nombreTurnoController = TextEditingController();
  final TextEditingController _horaEntradaController = TextEditingController();
  final TextEditingController _horaSalidaController = TextEditingController();
  final TextEditingController _toleranciaController = TextEditingController(text: '15');
  


  bool _guardandoEmpleado = false; // Continúa el código original de variables...

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
          .select('id, numero_empleado, nombre_completo, pin_acceso, puesto_id, sucursal_id, correo_electronico, fecha_ingreso, sucursales(nombre), puestos(nombre), turnos(nombre_turno, hora_entrada, hora_salida, tolerancia_minutos)')
          .order('numero_empleado');
      if (mounted) {
        setState(() {
          _empleadosRegistrados = List<Map<String, dynamic>>.from(datos);
          _cargandoDatos = false;
        });
      }
    } catch (e) {
      debugPrint("Error al cargar empleados para Excel relacional: $e");
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
    
    // 🌟 NUEVAS LÍNEAS DE LIMPIEZA A AGREGAR:
    _nombreTurnoController.dispose();
    _horaEntradaController.dispose();
    _horaSalidaController.dispose();
    _toleranciaController.dispose();
    
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
  } // 👈 Esta es la línea 391 (Llenera de cierre de _eliminarEmpleado)


  // 🌟 COPIA Y PEGA ESTE BLOQUE AQUÍ EN ESTE ESPACIO EN BLANCO:
  Future<void> _registrarNuevoTurno() async {
    final String nombre = _nombreTurnoController.text.trim();
    final String entrada = _horaEntradaController.text.trim();
    final String salida = _horaSalidaController.text.trim();
    final int tolerancia = int.tryParse(_toleranciaController.text.trim()) ?? 0;

    if (nombre.isEmpty || entrada.isEmpty || salida.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ Por favor, llena todos los campos obligatorios del turno.'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _cargandoDatos = true);

    try {
      await SupabaseService.client.from('turnos').insert({
        'nombre_turno': nombre.toUpperCase(),
        'hora_entrada': entrada.contains(':') && entrada.split(':').length == 2 ? '$entrada:00' : entrada,
        'hora_salida': salida.contains(':') && salida.split(':').length == 2 ? '$salida:00' : salida,
        'tolerancia_minutos': tolerancia,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Turno guardado con éxito en la Receta Global.'), backgroundColor: Colors.green),
      );

      _nombreTurnoController.clear();
      _horaEntradaController.clear();
      _horaSalidaController.clear();
      _toleranciaController.text = '15';
      
      _cargarEstructuraCorporativa();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar el turno: $e'), backgroundColor: Colors.red),
        );
      }
      setState(() => _cargandoDatos = false);
    }
  }


  // 🌟 Aquí abajo continúa tu función existente (Línea 395 aprox):
  // 🌟 PEGAR AQUÍ LA NUEVA FUNCIÓN DE ASISTENCIA INDIVIDUAL:
  Future<void> _eliminarRegistroAsistencia(String id, String nombreEmpleado, String tipo) async {

    final bool? confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('⚠️ ¿Eliminar Registro?', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text('¿Estás seguro de que deseas eliminar permanentemente el registro de $tipo para "$nombreEmpleado"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sí, Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    try {
      await SupabaseService.client.from('registros_asistencia').delete().eq('id', id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('🗑️ Registro de asistencia eliminado con éxito.'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al eliminar registro: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _activarModoEdicion(Map<String, dynamic> emp) { // 👈 Aquí inicia la siguiente función original (Línea 395)
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
          // 🌟 NUEVO BOTÓN LATERAL: Módulo de Receta de Turnos
          _buildItemSidebar(id: 'TURNOS', titulo: 'Configuración de Turnos', icono: Icons.more_time_rounded),
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
        // 🔍 BARRA DE FILTRADO SUPERIOR COMPACTA OPTIMIZADA PARA WEB
        Container(
          padding: const EdgeInsets.all(10),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xffe2e8f0)),
          ),
          child: Row(
            children: [
              // Filtro por Nombre o Nómina
              Expanded(
                flex: 3,
                child: TextFormField(
                  controller: _buscarExcelController,
                  onChanged: (value) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: '🔍 Buscar por Nombre o Nómina de empleado...',
                    hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
                    prefixIcon: const Icon(Icons.search, size: 16, color: Colors.grey),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Selector de Fecha Inicial Seguro para Escritorio
              Expanded(
                flex: 2,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: Color(0xffcbd5e1)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  icon: const Icon(Icons.calendar_today, size: 14, color: Colors.blueGrey),
                  label: Text(
                    'Inicio: ${_rangoFechas.start.day}/${_rangoFechas.start.month}/${_rangoFechas.start.year}',
                    style: const TextStyle(fontSize: 12, color: Colors.black87),
                  ),
                  onPressed: () async {
                    final DateTime? fInicio = await showDatePicker(
                      context: context,
                      initialDate: _rangoFechas.start,
                      firstDate: DateTime(2020),
                      lastDate: _rangoFechas.end,
                    );
                    if (fInicio != null) {
                      setState(() {
                        _rangoFechas = DateTimeRange(start: fInicio, end: _rangoFechas.end);
                      });
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              // Selector de Fecha Final Seguro para Escritorio
              Expanded(
                flex: 2,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: Color(0xffcbd5e1)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  icon: const Icon(Icons.calendar_today, size: 14, color: Colors.blueGrey),
                  label: Text(
                    'Fin: ${_rangoFechas.end.day}/${_rangoFechas.end.month}/${_rangoFechas.end.year}',
                    style: const TextStyle(fontSize: 12, color: Colors.black87),
                  ),
                  onPressed: () async {
                    final DateTime? fFin = await showDatePicker(
                      context: context,
                      initialDate: _rangoFechas.end,
                      firstDate: _rangoFechas.start,
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (fFin != null) {
                      setState(() {
                        _rangoFechas = DateTimeRange(start: _rangoFechas.start, end: fFin);
                      });
                    }
                  },
                ),
              ),
            ],
          ),
        ),
        const Text(
          'MONITOREO DE ASISTENCIAS EN TIEMPO REAL - VISTA CORPORATIVA', 
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey, letterSpacing: 0.5)
        ),
        const SizedBox(height: 12),
        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: SupabaseService.client
                .from('registros_asistencia')
                .stream(primaryKey: ['id'])
                .order('fecha_hora_servidor', ascending: false)
                .map((maps) {
                  final String busqueda = _buscarExcelController.text.trim().toLowerCase();
                  
                  return maps.where((registro) {
                    final fServidor = DateTime.parse(registro['fecha_hora_servidor']);
                    final String empleadoId = registro['empleado_id']?.toString() ?? '';

                    // Filtrado estricto por rango de fechas guardado en el estado
                    final bool dentroDeFecha = fServidor.isAfter(_rangoFechas.start.subtract(const Duration(days: 1))) && 
                                               fServidor.isBefore(_rangoFechas.end.add(const Duration(days: 1)));
                    
                    if (!dentroDeFecha) return false;
                    if (busqueda.isEmpty) return true;

                    Map<String, dynamic>? emp;
                    try {
                      emp = _empleadosRegistrados.firstWhere((e) => e['id'].toString() == empleadoId);
                    } catch (_) {
                      emp = null;
                    }

                    if (emp == null) return false;
                    final String nombre = (emp['nombre_completo'] ?? '').toString().toLowerCase();
                    final String nomina = (emp['numero_empleado'] ?? '').toString().toLowerCase();

                    return nombre.contains(busqueda) || nomina.contains(busqueda);
                  }).toList();
                }),
            builder: (context, snapshot) {
              if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(fontSize: 12)));
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Colors.teal));
              
              final registros = snapshot.data ?? [];
              if (registros.isEmpty) return const Center(child: Text('Sin checadas registradas en el rango seleccionado o coincidencia.', style: TextStyle(fontSize: 13)));
              
              return Container(
                decoration: BoxDecoration(
                  color: Colors.white, 
                  borderRadius: BorderRadius.circular(12), 
                  border: Border.all(color: const Color(0xffe2e8f0))
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(Colors.blueGrey.shade50),
                      dataRowMinHeight: 46,
                      dataRowMaxHeight: 52,
                      horizontalMargin: 16,
                      columnSpacing: 24,
                                         columns: const [
                        DataColumn(label: Text('NÓMINA', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                        DataColumn(label: Text('FOTO', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                        DataColumn(label: Text('TRABAJADOR', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                        DataColumn(label: Text('CARGO / PUESTO', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                        DataColumn(label: Text('FECHA', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                        DataColumn(label: Text('HORA REAL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                        DataColumn(label: Text('TURNO HORARIO', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                        DataColumn(label: Text('MIN RETARDO', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                        DataColumn(label: Text('INCIDENCIA', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                        DataColumn(label: Text('ESTATUS LEY', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                        DataColumn(label: Text('ACCIONES', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                      ],


                                        rows: registros.map((r) {
                        final f = DateTime.parse(r['fecha_hora_servidor']);
                        final String empleadoId = r['empleado_id']?.toString() ?? '';
                        final String selfieUrlCampo = r['selfie_url']?.toString() ?? 'EMPTY';
                        final String incidenciaDetectada = r['tipo_evento'] ?? 'ENTRADA';
                        
                        // 🌟 CONEXIÓN DIRECTA CON EL ESTADO DEL SERVIDOR:
                        // Jalamos el estatus de ley calculado de forma exacta por el RPC en Supabase
                        final String estatusLeyServidor = r['estatus_asistencia'] ?? 'ASISTENCIA';

                        // Cruce relacional básico en memoria para nombres y puestos
                        Map<String, dynamic>? empEncontrado;
                        try {
                          empEncontrado = _empleadosRegistrados.firstWhere((e) => e['id'].toString() == empleadoId);
                        } catch (_) {
                          empEncontrado = null;
                        }

                        final String nombreTrabajador = empEncontrado != null ? (empEncontrado['nombre_completo'] ?? 'Desconocido') : 'Desconocido';
                        final String nominaTrabajador = empEncontrado != null ? (empEncontrado['numero_empleado']?.toString() ?? '----') : '----';
                        
                        final puestoData = empEncontrado != null ? empEncontrado['puestos'] as Map<String, dynamic>? : null;
                        final String cargoTrabajador = puestoData != null ? (puestoData['nombre'] ?? 'GENERAL') : 'GENERAL';

                        // Mapeo visual del horario del turno para información estática en la celda
                        final turnoData = empEncontrado != null ? empEncontrado['turnos'] as Map<String, dynamic>? : null;
                        final String tEntrada = turnoData != null ? (turnoData['hora_entrada'] ?? '08:00:00') : '08:00:00';
                        final String tSalida = turnoData != null ? (turnoData['hora_salida'] ?? '17:00:00') : '17:00:00';

                        String? urlFinalFoto;
                        if (selfieUrlCampo != 'EMPTY' && selfieUrlCampo.isNotEmpty && selfieUrlCampo.startsWith('http')) {
                          urlFinalFoto = selfieUrlCampo;
                        }

                        final String fechaLegible = "${f.day.toString().padLeft(2, '0')}/${f.month.toString().padLeft(2, '0')}/${f.year}";
                        final String horaLegible = "${f.hour.toString().padLeft(2, '0')}:${f.minute.toString().padLeft(2, '0')}:${f.second.toString().padLeft(2, '0')}";

                        // Definición de colores corporativos dinámicos según el dictamen de Supabase
                        Color colorEstatus = Colors.green.shade700;
                        if (estatusLeyServidor == 'RETARDO') colorEstatus = Colors.amber.shade800;
                        if (estatusLeyServidor == 'FALTA') colorEstatus = Colors.red.shade700;
                        if (estatusLeyServidor == 'SOBRETIEMPO') colorEstatus = Colors.purple.shade700;

                        return DataRow(cells: [
                          DataCell(Text(nominaTrabajador, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold))),
                          DataCell(
                            GestureDetector(
                              onTap: urlFinalFoto == null ? null : () {
                                showDialog(
                                  context: context,
                                  builder: (context) => Dialog(
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    clipBehavior: Clip.antiAlias,
                                    elevation: 8,
                                    child: Container(
                                      constraints: const BoxConstraints(maxWidth: 420),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          AppBar(
                                            backgroundColor: const Color(0xFF0F172A),
                                            title: Text('VERIFICACIÓN: $nombreTrabajador', style: const TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.bold)),
                                            centerTitle: true,
                                            automaticallyImplyLeading: false,
                                            elevation: 0,
                                            actions: [IconButton(icon: const Icon(Icons.close, color: Colors.white70), onPressed: () => Navigator.pop(context))],
                                          ),
                                          Container(
                                            width: double.infinity,
                                            color: const Color(0xFFF1F5F9),
                                            child: Image.network(
                                              urlFinalFoto!,
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, error, stackTrace) => const Center(child: Padding(padding: EdgeInsets.all(32.0), child: Text('⚠️ Error al renderizar.', style: TextStyle(color: Colors.grey)))),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                              child: Container(
                                width: 34,
                                height: 34,
                                decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.teal),
                                child: ClipOval(
                                  child: urlFinalFoto != null
                                      ? Image.network(urlFinalFoto, fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => const Icon(Icons.person, color: Colors.white, size: 16))
                                      : const Icon(Icons.person, color: Colors.white, size: 16),
                                ),
                              ),
                            ),
                          ),
                          DataCell(Text(nombreTrabajador, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
                          DataCell(Text(cargoTrabajador, style: const TextStyle(fontSize: 13, color: Colors.black54))),
                          DataCell(Text(fechaLegible, style: const TextStyle(fontSize: 13, color: Colors.blueGrey))),
                          DataCell(Text(horaLegible, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.teal.shade700))),
                          DataCell(Text('${tEntrada.substring(0,5)} - ${tSalida.substring(0,5)}', style: const TextStyle(fontSize: 13, color: Colors.black87))),
                          // Columna de minutos informativos simplificados
                          DataCell(Text(estatusLeyServidor == 'RETARDO' ? 'Retardo' : '0 min', style: TextStyle(fontSize: 13, color: estatusLeyServidor == 'RETARDO' ? Colors.amber.shade900 : Colors.black54))),
                          DataCell(
                            Chip(
                              label: Text(incidenciaDetectada, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                              padding: EdgeInsets.zero,
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                          // Celda de Estatus real sincronizada con Supabase
                          DataCell(Text(estatusLeyServidor, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: colorEstatus))),
                          DataCell(
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () => _eliminarRegistroAsistencia(
                                r['id'].toString(), 
                                nombreTrabajador, 
                                incidenciaDetectada
                              ),
                            ),
                          ),
                        ]);
                      }).toList(),


                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  


 

     void _imprimirPDF() async {
    final pdfDocument = pw.Document();
    final String busqueda = _buscarExcelController.text.trim().toLowerCase();
    
    List<Map<String, dynamic>> registrosFiltrados = [];
    try {
      final marcasData = await SupabaseService.client
          .from('registros_asistencia')
          .select()
          .order('fecha_hora_servidor', ascending: false);
          
      registrosFiltrados = List<Map<String, dynamic>>.from(marcasData).where((registro) {
        final fServidor = DateTime.parse(registro['fecha_hora_servidor']);
        final String empleadoId = registro['empleado_id']?.toString() ?? '';

        final bool dentroDeFecha = fServidor.isAfter(_rangoFechas.start.subtract(const Duration(days: 1))) && 
                                   fServidor.isBefore(_rangoFechas.end.add(const Duration(days: 1)));
        
        if (!dentroDeFecha) return false;
        if (busqueda.isEmpty) return true;

        Map<String, dynamic>? emp;
        try {
          emp = _empleadosRegistrados.firstWhere((e) => e['id'].toString() == empleadoId);
        } catch (_) {
          emp = null;
        }

        if (emp == null) return false;
        final String nombre = (emp['nombre_completo'] ?? '').toString().toLowerCase();
        final String nomina = (emp['numero_empleado'] ?? '').toString().toLowerCase();

        return nombre.contains(busqueda) || nomina.contains(busqueda);
      }).toList();
    } catch (e) {
      debugPrint("Error al recopilar datos para el PDF: $e");
      return;
    }

    if (registrosFiltrados.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('⚠️ No hay registros en pantalla para exportar.'), backgroundColor: Colors.orange),
        );
      }
      return;
    }

    pdfDocument.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.letter.copyWith(
          marginBottom: 30, marginTop: 30, marginLeft: 30, marginRight: 30
        ),
        header: (pw.Context context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(bottom: 20.0),
          child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start, // 👈 Corrección: Se agregó 'Alignment:' y los dos puntos ':'

            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('ADMINISTRACIÓN CENTRAL - REPORTE DE ASISTENCIAS', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12, color: PdfColors.teal)),
                  pw.Text('Generado: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                ],
              ),
              pw.SizedBox(height: 4),
              pw.Text('Rango: ${_rangoFechas.start.day}/${_rangoFechas.start.month}/${_rangoFechas.start.year} al ${_rangoFechas.end.day}/${_rangoFechas.end.month}/${_rangoFechas.end.year}', style: const pw.TextStyle(fontSize: 10, color: PdfColors.blueGrey)),
              pw.Container(height: 1, margin: const pw.EdgeInsets.only(top: 6), color: PdfColors.teal300),
            ],
          ),
        ),
        footer: (pw.Context context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 20.0),
          child: pw.Text('Página ${context.pageNumber} de ${context.pagesCount}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
        ),
        build: (pw.Context context) => [
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                children: [
                  pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('NÓMINA', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
                  pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('TRABAJADOR', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
                  pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('CARGO / PUESTO', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
                  pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('FECHA', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
                  pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('HORA REAL', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
                  pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('INCIDENCIA', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
                  pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('ESTATUS LEY', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
                ],
              ),
                            ...registrosFiltrados.map((r) {
                final f = DateTime.parse(r['fecha_hora_servidor']);
                final String empleadoId = r['empleado_id']?.toString() ?? '';
                final String incidenciaDetectada = r['tipo_evento'] ?? 'ENTRADA';
                final String estatusLeyServidor = r['estatus_asistencia'] ?? 'ASISTENCIA';

                Map<String, dynamic>? empEncontrado;
                try {
                  empEncontrado = _empleadosRegistrados.firstWhere((e) => e['id'].toString() == empleadoId);
                } catch (_) {
                  empEncontrado = null;
                }

                final String nombreTrabajador = empEncontrado != null ? (empEncontrado['nombre_completo'] ?? 'Desconocido') : 'Desconocido';
                final String nominaTrabajador = empEncontrado != null ? (empEncontrado['numero_empleado']?.toString() ?? '----') : '----';
                
                final puestoData = empEncontrado != null ? empEncontrado['puestos'] as Map<String, dynamic>? : null;
                final String cargoTrabajador = puestoData != null ? (puestoData['nombre'] ?? 'GENERAL') : 'GENERAL';

                final String fechaLegible = "${f.day.toString().padLeft(2, '0')}/${f.month.toString().padLeft(2, '0')}/${f.year}";
                final String horaLegible = "${f.hour.toString().padLeft(2, '0')}:${f.minute.toString().padLeft(2, '0')}:${f.second.toString().padLeft(2, '0')}";

                return pw.TableRow(
                  children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(nominaTrabajador, style: const pw.TextStyle(fontSize: 8))),
                    pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(nombreTrabajador, style: const pw.TextStyle(fontSize: 8))),
                    pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(cargoTrabajador, style: const pw.TextStyle(fontSize: 8))),
                    pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(fechaLegible, style: const pw.TextStyle(fontSize: 8))),
                    pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(horaLegible, style: const pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
                    pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(incidenciaDetectada, style: const pw.TextStyle(fontSize: 8))),
                    pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(estatusLeyServidor, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: estatusLeyServidor == 'RETARDO' || estatusLeyServidor == 'FALTA' ? PdfColors.red : PdfColors.green))),
                  ],
                );
              }),


            ],
          ),
        ],
      ),
    );

    try {
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdfDocument.save(),
        name: 'Reporte_Asistencias_${_rangoFechas.start.day}_al_${_rangoFechas.end.day}',
      );
    } catch (e) {
      debugPrint("Error al desplegar layout de impresión: $e");
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
        actions: [
           IconButton(icon: const Icon(Icons.print, color: Colors.white), onPressed: _imprimirPDF), const SizedBox(width: 10)],
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
                } else if (_seccionActivaSidebar == 'MONITOREO') {
                  return _buildSeccionFeedMonitoreo();
                } else {
                  // 🌟 INTERFAZ COMPLETA DE TURNOS: FORMULARIO Y HOJA DE CÁLCULO DERECHA REACTIVA
                  return Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 320,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xffe2e8f0))),
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(children: [Icon(Icons.more_time, color: Colors.teal, size: 20), SizedBox(width: 8), Text('PROGRAMACIÓN DE TURNOS', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.blueGrey))]),
                                const Divider(height: 20),
                                const Text('Nombre del Turno:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                const SizedBox(height: 6),
                                TextFormField(controller: _nombreTurnoController, textCapitalization: TextCapitalization.characters, decoration: InputDecoration(hintText: 'Ej: PRIMER TURNO', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10))),
                                const SizedBox(height: 12),
                                const Text('Hora de Entrada (24 hrs):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                const SizedBox(height: 6),
                                TextFormField(controller: _horaEntradaController, decoration: InputDecoration(hintText: 'Ej: 06:00', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10))),
                                const SizedBox(height: 12),
                                const Text('Hora de Salida (24 hrs):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                const SizedBox(height: 6),
                                TextFormField(controller: _horaSalidaController, decoration: InputDecoration(hintText: 'Ej: 14:00', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10))),
                                const SizedBox(height: 12),
                                const Text('Tolerancia (Minutos):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                const SizedBox(height: 6),
                                TextFormField(controller: _toleranciaController, keyboardType: TextInputType.number, decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10))),
                                const SizedBox(height: 20),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                                    onPressed: _registrarNuevoTurno,
                                    icon: const Icon(Icons.save, color: Colors.white, size: 16),
                                    label: const Text('Guardar Turno en Receta', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xffe2e8f0))),
                            child: StreamBuilder<List<Map<String, dynamic>>>(
                              stream: SupabaseService.client.from('turnos').stream(primaryKey: ['id']).order('nombre_turno'),
                              builder: (context, snapshot) {
                                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.teal));
                                final tLista = snapshot.data!;
                                return SingleChildScrollView(
                                  scrollDirection: Axis.vertical,
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: DataTable(
                                      headingRowColor: WidgetStateProperty.all(Colors.grey.shade100),
                                      dataRowMinHeight: 38, dataRowMaxHeight: 42,
                                      columns: const [
                                        DataColumn(label: Text('NOMBRE DEL TURNO', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                                        DataColumn(label: Text('HORA ENTRADA', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                                        DataColumn(label: Text('HORA SALIDA', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                                        DataColumn(label: Text('TOLERANCIA', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                                      ],
                                      rows: tLista.map((t) {
                                        return DataRow(cells: [
                                          DataCell(Text(t['nombre_turnos']?.toString() ?? t['nombre_turno']?.toString() ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold))),
                                          DataCell(Text(t['hora_entrada']?.toString() ?? '', style: const TextStyle(fontSize: 13))),
                                          DataCell(Text(t['hora_salida']?.toString() ?? '', style: const TextStyle(fontSize: 13))),
                                          DataCell(Text('${t['tolerancia_minutos']} min', style: const TextStyle(fontSize: 13, color: Colors.blueGrey))),
                                        ]);
                                      }).toList(),
                                    ),
                                  ),
                                );
                              }
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
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

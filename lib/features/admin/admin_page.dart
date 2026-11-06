import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/supabase_service.dart';

// COMPONENTE AISLADO: Evita que el segundero redibuje el feed completo de Supabase
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
        color: Colors.white.withAlpha(40),
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
  bool _guardandoEmpleado = false;

  @override
  void dispose() {
    _nombreController.dispose();
    _pinAltaController.dispose();
    super.dispose();
  }
  Future<void> _registrarNuevoEmpleado() async {
    if (!_formKey.currentState!.validate() || _guardandoEmpleado) return;

    setState(() => _guardandoEmpleado = true);

    try {
      final String nombre = _nombreController.text.trim();
      final String pin = _pinAltaController.text.trim();
      const String sucursalMatrizUuid = '91995ded-ff29-41b7-8198-08ca6cb94fb3';

      final pinDuplicado = await SupabaseService.client
          .from('empleados')
          .select('id')
          .eq('pin_acceso', pin)
          .maybeSingle();

      if (pinDuplicado != null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ El PIN digitado ya pertenece a otro trabajador. Elige otro.'),
            backgroundColor: Colors.amber,
          ),
        );
        return;
      }

      await SupabaseService.client.from('empleados').insert({
        'nombre_completo': nombre,
        'pin_acceso': pin,
        'sucursal_id': sucursalMatrizUuid,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('🎉 ¡Trabajador "$nombre" dado de alta con éxito!'), backgroundColor: Colors.teal),
      );

      _nombreController.clear();
      _pinAltaController.clear();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al dar de alta: $e'), backgroundColor: Colors.red),
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
            Text(
              'ADMINISTRACIÓN', 
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)
            ),
            SizedBox(width: 12),
            RelojDigitalIndependiente(),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.download_for_offline, color: Colors.white),
            tooltip: 'Exportar Excel',
            onPressed: _descargarExcel,
          ),
          IconButton(
            icon: const Icon(Icons.print, color: Colors.white),
            tooltip: 'Imprimir PDF',
            onPressed: _imprimirPDF,
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildCardMetrica('PRESENTES', '12', Icons.people, Colors.green),
                const SizedBox(width: 10),
                _buildCardMetrica('RETARDOS', '2', Icons.timer, Colors.amber),
                const SizedBox(width: 10),
                _buildCardMetrica('AUSENTES', '1', Icons.person_off, Colors.red),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final bool esMovil = constraints.maxWidth < 750;
                                    final Widget formularioAlta = Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xffe2e8f0)),
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.person_add, color: Colors.teal, size: 20),
                              SizedBox(width: 8),
                              Text('ALTA MANUAL DE TRABAJADOR', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                            ],
                          ),
                          const Divider(height: 20),
                          const Text('Nombre Completo:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _nombreController,
                            textCapitalization: TextCapitalization.words,
                            style: const TextStyle(fontSize: 14),
                            decoration: InputDecoration(
                              hintText: 'Ej. Juan Pérez López',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                            validator: (val) => val == null || val.trim().isEmpty ? 'Requerido' : null,
                          ),
                          const SizedBox(height: 12),
                          const Text('Asignar PIN (4 dígitos):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _pinAltaController,
                            keyboardType: TextInputType.number,
                            maxLength: 4,
                            obscureText: true,
                            style: const TextStyle(fontSize: 14),
                            decoration: InputDecoration(
                              hintText: '••••',
                              counterText: '',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                            validator: (val) {
                              if (val == null || val.trim().length != 4) return 'Deben ser 4 números';
                              if (int.tryParse(val) == null) return 'Solo números';
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          _guardandoEmpleado
                              ? const Center(child: CircularProgressIndicator(color: Colors.teal))
                              : ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.teal,
                                    minimumSize: const Size(double.infinity, 45),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  onPressed: _registrarNuevoEmpleado,
                                  icon: const Icon(Icons.save, color: Colors.white, size: 16),
                                  label: const Text('Registrar en Supabase', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                ),
                        ],
                      ),
                    ),
                  );
                  final Widget seccionFeed = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AUDITORÍA: ${_rangoFechas.start.day}/${_rangoFechas.start.month} AL ${_rangoFechas.end.day}/${_rangoFechas.end.month}',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
                      ),
                      const SizedBox(height: 4),
                      const Text('MONITOREO EN TIEMPO REAL', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                      const SizedBox(height: 8),
                      Expanded(
                        child: StreamBuilder<List<Map<String, dynamic>>>(
                          stream: SupabaseService.client
                              .from('registros_asistencia')
                              .stream(primaryKey: ['id'])
                              .order('fecha_hora_servidor', ascending: false)
                              .map((maps) => List<Map<String, dynamic>>.from(maps)),
                          builder: (context, snapshot) {
                            if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(fontSize: 12)));
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const Center(child: CircularProgressIndicator(color: Colors.teal));
                            }
                            final registros = snapshot.data ?? [];
                            if (registros.isEmpty) {
                              return const Center(child: Text('Sin registros capturados hoy.', style: TextStyle(fontSize: 13)));
                            }

                            return ListView.builder(
                              itemCount: registros.length,
                              itemBuilder: (context, index) {
                                final registro = registros[index];
                                final fServidor = DateTime.parse(registro['fecha_hora_servidor']);
                                final horaFormateada = "${fServidor.hour.toString().padLeft(2, '0')}:${fServidor.minute.toString().padLeft(2, '0')}";
                                final bool esRetardo = registro['estatus_asistencia'] == 'RETARDO';
                                final String selfieUrl = registro['selfie_url'] ?? '';

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 8.0),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    side: const BorderSide(color: Color(0xffe2e8f0)),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(10.0),
                                    child: Row(
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(6),
                                          child: selfieUrl.isEmpty || !selfieUrl.startsWith('http')
                                              ? Container(
                                                  width: 40,
                                                  height: 40,
                                                  color: Colors.grey.shade300,
                                                  child: const Icon(Icons.person, color: Colors.grey, size: 20),
                                                )
                                              : Image.network(
                                                  selfieUrl,
                                                  width: 40,
                                                  height: 40,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (context, error, stackTrace) => Container(
                                                    width: 40,
                                                    height: 40,
                                                    color: Colors.grey.shade300,
                                                    child: const Icon(Icons.person, color: Colors.grey, size: 20),
                                                  ),
                                                ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text('Evento: ${registro['tipo_evento']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.teal)),
                                              const SizedBox(height: 2),
                                              Text('Hora: $horaFormateada', style: const TextStyle(color: Colors.grey, fontSize: 11)),
                                            ],
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: esRetardo ? Colors.amber.withValues(alpha: 0.2) : Colors.green.withValues(alpha: 0.2),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            registro['estatus_asistencia'] ?? 'PROCESANDO',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold, 
                                              color: esRetardo ? Colors.amber.shade900 : Colors.green.shade900, 
                                              fontSize: 10
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  );

                  if (esMovil) {
                    return SingleChildScrollView(
                      child: Column(
                        children: [
                          formularioAlta,
                          const SizedBox(height: 20),
                          SizedBox(height: 400, child: seccionFeed),
                        ],
                      ),
                    );
                  } else {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(width: 320, child: formularioAlta),
                        const SizedBox(width: 20),
                        Expanded(child: seccionFeed),
                      ],
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/supabase_service.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  // Rango de fechas seleccionado por defecto para auditoría
  final DateTimeRange _rangoFechas = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 7)),
    end: DateTime.now(),
  );

  // NUEVAS VARIABLES INYECTADAS: Soporte para el reloj digital en tiempo real en el panel
  Timer? _relojTimer;
  String _horaDigital = "00:00:00";
  @override
  void initState() {
    super.initState();
    _iniciarReloj();
  }

  @override
  void dispose() {
    _relojTimer?.cancel();
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
  /// Función simulada para descargar el archivo Excel limpio
  void _descargarExcel() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('📥 Generando archivo Excel (XLSX/CSV) con la nómina quincenal...'),
        backgroundColor: Colors.teal,
      ),
    );
  }

  /// Función simulada para generar el reporte de auditoría e imprimir
  void _imprimirPDF() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('📄 Compilando reporte en PDF con hoja de firmas legales...'),
        backgroundColor: Colors.blueGrey,
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.teal,
        title: Row(
          children: [
            const Text(
              'PANEL DE ADMINISTRACIÓN - REGLAS DE ASISTENCIA', 
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
            ),
            const SizedBox(width: 20),
            // RELOJ DIGITAL: Visible en la barra superior al lado del título
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(40),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _horaDigital,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1),
              ),
            ),
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
          const SizedBox(width: 15),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // FILA SUPERIOR: Métricas e Indicadores de Asistencia del Taller
            Row(
              children: [
                _buildCardMetrica('PRESENTES', '12', Icons.people, Colors.green),
                const SizedBox(width: 20),
                _buildCardMetrica('RETARDOS HOY', '2', Icons.timer, Colors.amber),
                const SizedBox(width: 20),
                _buildCardMetrica('AUSENTES', '1', Icons.person_off, Colors.red),
              ],
            ),
            const SizedBox(height: 30),
            
            Text(
              'RANGO ACTUAL DE AUDITORÍA: ${_rangoFechas.start.day}/${_rangoFechas.start.month} AL ${_rangoFechas.end.day}/${_rangoFechas.end.month}',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            const SizedBox(height: 15),
            const Text(
              'MONITOREO DE ASISTENCIAS EN TIEMPO REAL (FEED DE SELFIES)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey, letterSpacing: 1),
            ),
            const SizedBox(height: 15),

            // FEED EN TIEMPO REAL: Conexión reactiva mediante StreamBuilder
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: SupabaseService.client
                    .from('registros_asistencia')
                    .stream(primaryKey: ['id'])
                    .order('fecha_hora_servidor', ascending: false)
                    .map((maps) => List<Map<String, dynamic>>.from(maps)),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(child: Text('Error al cargar el feed: ${snapshot.error}'));
                  }
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: Colors.teal));
                  }
                  final registros = snapshot.data ?? [];
                  if (registros.isEmpty) {
                    return const Center(
                      child: Text('No hay registros de asistencia capturados el día de hoy.'),
                    );
                  }

                  return ListView.builder(
                    itemCount: registros.length,
                    itemBuilder: (context, index) {
                      final registro = registros[index];
                      final fechaServidor = DateTime.parse(registro['fecha_hora_servidor']);
                      final horaFormateada = "${fechaServidor.hour.toString().padLeft(2, '0')}:${fechaServidor.minute.toString().padLeft(2, '0')}";

                      final bool esRetardo = registro['estatus_asistencia'] == 'RETARDO';

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12.0),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: Color(0xffe2e8f0)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  registro['selfie_url'] ?? '',
                                  width: 60,
                                  height: 60,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => Container(
                                    width: 60,
                                    height: 60,
                                    color: Colors.grey[300],
                                    child: const Icon(Icons.person, color: Colors.grey),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Evento: ${registro['tipo_evento']}',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.teal),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Registrado a las $horaFormateada - Dispositivo: ${registro['dispositivo_info']}',
                                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: esRetardo ? Colors.amber[100] : Colors.green[100],
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  registro['estatus_asistencia'] ?? 'PROCESANDO',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: esRetardo ? Colors.amber[900] : Colors.green[900],
                                    fontSize: 12,
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
        ),
      ),
    );
  }
  /// Constructor auxiliar para las tarjetas de métricas del encabezado (Reparado)
  Widget _buildCardMetrica(String titulo, String valor, IconData icono, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
               color: Colors.black.withAlpha(13), // Corregido el color inexistente
              blurRadius: 10, 
              offset: const Offset(0, 4)
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.5)),
                const SizedBox(height: 8),
                Text(valor, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF2D3748))),
              ],
            ),
            Icon(icono, size: 36, color: color),
          ],
        ),
      ),
    );
  }
}

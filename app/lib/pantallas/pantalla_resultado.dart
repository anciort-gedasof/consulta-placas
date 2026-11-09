import 'package:flutter/material.dart';

import '../datos/servicio_consulta.dart';
import '../dominio/resultado_consulta.dart';

/// Pantalla 3 de la especificación: resultado por colores.
///
/// Si hubo coincidencia con una lista de interés, solo se muestra
/// "Aviso enviado a una entidad" (regla 2 de CLAUDE.md).
class PantallaResultado extends StatelessWidget {
  const PantallaResultado({super.key, required this.resultado, required this.servicio});

  final ResultadoConsulta resultado;
  final ServicioConsulta servicio;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(resultado.placa)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (!resultado.registrado)
              const _Aviso(
                titulo: 'Sin registro en la base',
                texto: 'Use la consulta oficial (plan B) y guarde el resultado.',
              ),
            if (resultado.avisoEnviado) _AvisoEntidad(alAgente: resultado.avisoAlAgente),
            _TarjetaDocumento(nombre: 'SOAT', estado: resultado.soat),
            _TarjetaDocumento(nombre: 'Revisión técnico-mecánica', estado: resultado.rtm),
            const SizedBox(height: 12),
            if (resultado.requierePlanB)
              OutlinedButton(
                onPressed: null, // Módulo plan B: pendiente
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                child: const Text('Verificar en consulta oficial (plan B)'),
              ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: null, // Módulo registro de cliente: pendiente
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              child: const Text('Ofrecer venta y registrar cliente'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Colores {
  const _Colores(this.fondo, this.texto, this.etiqueta);
  final Color fondo;
  final Color texto;
  final String etiqueta;
}

_Colores _coloresDe(EstadoDocumento e) => switch (e) {
      EstadoDocumento.alDia => const _Colores(Color(0xFFE7F4EC), Color(0xFF1B6B3C), 'Al día'),
      EstadoDocumento.vencePronto => const _Colores(Color(0xFFFFF3DD), Color(0xFF8A4A00), 'Vence pronto'),
      EstadoDocumento.posibleVencido => const _Colores(Color(0xFFFDEBE9), Color(0xFFA3221A), 'Posible vencido'),
      EstadoDocumento.sinDato => const _Colores(Color(0xFFEEF0F3), Color(0xFF46505E), 'Sin dato'),
    };

String _fecha(DateTime d) {
  const meses = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
  return '${d.day} ${meses[d.month - 1]} ${d.year}';
}

class _TarjetaDocumento extends StatelessWidget {
  const _TarjetaDocumento({required this.nombre, required this.estado});

  final String nombre;
  final EstadoDeDocumento estado;

  @override
  Widget build(BuildContext context) {
    final c = _coloresDe(estado.estado);
    final venc = estado.vencimiento;
    final dias = estado.dias;
    final detalle = venc == null
        ? 'Fecha no registrada'
        : (dias != null && dias < 0)
            ? 'Venció el ${_fecha(venc)} según la base. Pudo renovar en otro lado: verifique.'
            : 'Vence el ${_fecha(venc)}${dias == null ? '' : ' · faltan $dias días'}';
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(nombre, style: Theme.of(context).textTheme.titleMedium)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: c.fondo, borderRadius: BorderRadius.circular(999)),
                  child: Text(c.etiqueta, style: TextStyle(color: c.texto, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(detalle),
          ],
        ),
      ),
    );
  }
}

class _Aviso extends StatelessWidget {
  const _Aviso({required this.titulo, required this.texto});
  final String titulo;
  final String texto;

  @override
  Widget build(BuildContext context) => Card(
        color: const Color(0xFFEEF0F3),
        margin: const EdgeInsets.only(bottom: 12),
        child: ListTile(title: Text(titulo), subtitle: Text(texto)),
      );
}

/// Regla 9 de CLAUDE.md: solo el uniformado aborda al conductor.
class _AvisoEntidad extends StatelessWidget {
  const _AvisoEntidad({required this.alAgente});

  final bool alAgente;

  @override
  Widget build(BuildContext context) => Card(
        color: const Color(0xFF14213D),
        margin: const EdgeInsets.only(bottom: 12),
        child: ListTile(
          leading: const Icon(Icons.send_outlined, color: Color(0xFFF2B33D)),
          title: Text(
            alAgente ? 'Aviso enviado al agente a cargo' : 'Aviso enviado a una entidad',
            style: const TextStyle(color: Color(0xFFF7F6F2)),
          ),
          subtitle: Text(
            alAgente
                ? 'Continúe con normalidad. El agente decide si aborda al conductor.'
                : 'Continúe con normalidad. No intervenga el vehículo.',
            style: const TextStyle(color: Color(0xFFC9D3E6)),
          ),
        ),
      );
}

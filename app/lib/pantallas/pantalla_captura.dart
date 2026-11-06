import 'package:flutter/material.dart';

import '../datos/servicio_consulta.dart';
import '../dominio/placa.dart';
import 'pantalla_resultado.dart';

/// Pantalla 2 de la especificación: captura de placa.
///
/// La lectura con cámara (ML Kit) se agrega en su propio módulo; por ahora
/// el botón queda deshabilitado y la placa se digita.
class PantallaCaptura extends StatefulWidget {
  const PantallaCaptura({super.key, required this.servicio});

  final ServicioConsulta servicio;

  @override
  State<PantallaCaptura> createState() => _PantallaCapturaState();
}

class _PantallaCapturaState extends State<PantallaCaptura> {
  final _controlador = TextEditingController();
  bool _consultando = false;

  String get _placa => normalizarPlaca(_controlador.text);
  bool get _valida => placaValida(_placa);
  bool get _formatoErrado => _placa.length == 6 && !_valida;

  @override
  void dispose() {
    _controlador.dispose();
    super.dispose();
  }

  Future<void> _consultar() async {
    if (!_valida || _consultando) return;
    setState(() => _consultando = true);
    try {
      final resultado = await widget.servicio.consultar(_placa);
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => PantallaResultado(resultado: resultado, servicio: widget.servicio),
      ));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo consultar. Revise la conexión e intente de nuevo.')),
      );
    } finally {
      if (mounted) setState(() => _consultando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Consulta Placa')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('Consultar vehículo', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: null, // Módulo de cámara: pendiente
              icon: const Icon(Icons.photo_camera_outlined),
              label: const Text('Leer placa con la cámara (próximamente)'),
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            ),
            const SizedBox(height: 24),
            TextField(
              key: const Key('campo_placa'),
              controller: _controlador,
              textCapitalization: TextCapitalization.characters,
              maxLength: 7,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w600, letterSpacing: 4),
              decoration: InputDecoration(
                labelText: 'Placa',
                hintText: 'ABC123',
                helperText: 'Carro: ABC123 · Moto: ABC12D',
                errorText: _formatoErrado ? 'Formato no válido. Carro: ABC123 · Moto: ABC12D' : null,
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _consultar(),
            ),
            const SizedBox(height: 8),
            FilledButton(
              key: const Key('boton_consultar'),
              onPressed: _valida && !_consultando ? _consultar : null,
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              child: _consultando
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Consultar'),
            ),
          ],
        ),
      ),
    );
  }
}

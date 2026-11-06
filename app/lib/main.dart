import 'package:flutter/material.dart';

import 'datos/servicio_consulta.dart';
import 'pantallas/pantalla_captura.dart';

void main() {
  runApp(AppConsultaPlacas(servicio: ServicioConsultaDemo()));
}

class AppConsultaPlacas extends StatelessWidget {
  const AppConsultaPlacas({super.key, required this.servicio});

  final ServicioConsulta servicio;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Consulta Placa',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF1F5FD1),
        useMaterial3: true,
      ),
      home: PantallaCaptura(servicio: servicio),
    );
  }
}

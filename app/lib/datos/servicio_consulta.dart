import '../dominio/resultado_consulta.dart';

/// Contrato para consultar una placa en el backend.
///
/// La implementación real llamará a la función `consultar_placa` del
/// backend (Supabase RPC) en el módulo de integración. Mientras tanto,
/// [ServicioConsultaDemo] permite construir y probar las pantallas.
abstract class ServicioConsulta {
  Future<ResultadoConsulta> consultar(
    String placa, {
    double? latitud,
    double? longitud,
  });

  Future<void> registrarConsultaOficial(
    String placa, {
    DateTime? vencimientoSoat,
    DateTime? vencimientoRtm,
  });
}

/// Datos ficticios, iguales a los del prototipo de diseño.
class ServicioConsultaDemo implements ServicioConsulta {
  ServicioConsultaDemo({DateTime? hoy}) : _hoy = hoy ?? DateTime.now();

  final DateTime _hoy;
  final Map<String, (DateTime?, DateTime?)> _base = {
    'ABC123': (DateTime(2027, 3, 14), DateTime(2027, 1, 20)),
    'MNO45E': (DateTime(2026, 11, 12), DateTime(2026, 12, 1)),
    'XYZ789': (DateTime(2026, 10, 2), DateTime(2027, 5, 30)),
  };
  static const Set<String> _listas = {'EMB417', 'KRT58D'};

  @override
  Future<ResultadoConsulta> consultar(String placa, {double? latitud, double? longitud}) async {
    final registro = _base[placa];
    return ResultadoConsulta(
      placa: placa,
      registrado: registro != null,
      soat: _estado(registro?.$1),
      rtm: _estado(registro?.$2),
      avisoEnviado: _listas.contains(placa),
    );
  }

  @override
  Future<void> registrarConsultaOficial(String placa,
      {DateTime? vencimientoSoat, DateTime? vencimientoRtm}) async {
    final previo = _base[placa];
    _base[placa] = (vencimientoSoat ?? previo?.$1, vencimientoRtm ?? previo?.$2);
  }

  EstadoDeDocumento _estado(DateTime? venc) {
    if (venc == null) return const EstadoDeDocumento(estado: EstadoDocumento.sinDato);
    final hoy = DateTime(_hoy.year, _hoy.month, _hoy.day);
    final dias = venc.difference(hoy).inDays;
    final estado = dias < 0
        ? EstadoDocumento.posibleVencido
        : dias <= 30
            ? EstadoDocumento.vencePronto
            : EstadoDocumento.alDia;
    return EstadoDeDocumento(estado: estado, vencimiento: venc, dias: dias);
  }
}

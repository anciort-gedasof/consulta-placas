import 'package:consulta_placas/datos/servicio_consulta.dart';
import 'package:consulta_placas/dominio/resultado_consulta.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('lee la respuesta del backend', () {
    final r = ResultadoConsulta.desdeJson({
      'placa': 'BBB222',
      'registrado': true,
      'tipo': 'carro',
      'soat': {'estado': 'sin_dato', 'vencimiento': null, 'dias': null},
      'rtm': {'estado': 'vence_pronto', 'vencimiento': '2026-11-20', 'dias': 15},
      'aviso_enviado': false,
    });
    expect(r.rtm.estado, EstadoDocumento.vencePronto);
    expect(r.rtm.dias, 15);
    expect(r.rtm.vencimiento, DateTime(2026, 11, 20));
    expect(r.soat.estado, EstadoDocumento.sinDato);
    expect(r.requierePlanB, isTrue, reason: 'SOAT sin dato');
  });

  test('lee el aviso al agente en un operativo', () {
    final r = ResultadoConsulta.desdeJson({
      'placa': 'OPE123',
      'registrado': false,
      'soat': {'estado': 'sin_dato'},
      'rtm': {'estado': 'sin_dato'},
      'aviso_enviado': true,
      'aviso_al_agente': true,
    });
    expect(r.avisoEnviado, isTrue);
    expect(r.avisoAlAgente, isTrue);
  });

  test('el servicio demo replica los estados del prototipo', () async {
    final s = ServicioConsultaDemo(hoy: DateTime(2026, 11, 5));
    expect((await s.consultar('ABC123')).soat.estado, EstadoDocumento.alDia);
    expect((await s.consultar('MNO45E')).soat.estado, EstadoDocumento.vencePronto);
    expect((await s.consultar('XYZ789')).soat.estado, EstadoDocumento.posibleVencido);
    expect((await s.consultar('QWE321')).registrado, isFalse);
    expect((await s.consultar('EMB417')).avisoEnviado, isTrue);
  });

  test('el plan B actualiza la base', () async {
    final s = ServicioConsultaDemo(hoy: DateTime(2026, 11, 5));
    await s.registrarConsultaOficial('QWE321', vencimientoSoat: DateTime(2027, 2, 1));
    final r = await s.consultar('QWE321');
    expect(r.registrado, isTrue);
    expect(r.soat.estado, EstadoDocumento.alDia);
  });
}

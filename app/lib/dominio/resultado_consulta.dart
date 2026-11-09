/// Respuesta de `consultar_placa` en el backend.
///
/// Por diseño NO trae motivo, entidad ni proceso de una coincidencia:
/// solo `avisoEnviado` (regla 2 de CLAUDE.md).
library;

enum EstadoDocumento { alDia, vencePronto, posibleVencido, sinDato }

EstadoDocumento estadoDesdeTexto(String? valor) {
  switch (valor) {
    case 'al_dia':
      return EstadoDocumento.alDia;
    case 'vence_pronto':
      return EstadoDocumento.vencePronto;
    case 'posible_vencido':
      return EstadoDocumento.posibleVencido;
    default:
      return EstadoDocumento.sinDato;
  }
}

class EstadoDeDocumento {
  const EstadoDeDocumento({required this.estado, this.vencimiento, this.dias});

  final EstadoDocumento estado;
  final DateTime? vencimiento;
  final int? dias;

  factory EstadoDeDocumento.desdeJson(Map<String, dynamic>? json) {
    if (json == null) return const EstadoDeDocumento(estado: EstadoDocumento.sinDato);
    final venc = json['vencimiento'] as String?;
    return EstadoDeDocumento(
      estado: estadoDesdeTexto(json['estado'] as String?),
      vencimiento: venc == null ? null : DateTime.parse(venc),
      dias: (json['dias'] as num?)?.toInt(),
    );
  }

  /// true si conviene verificar en la consulta oficial (plan B).
  bool get requiereVerificar =>
      estado == EstadoDocumento.posibleVencido || estado == EstadoDocumento.sinDato;
}

class ResultadoConsulta {
  const ResultadoConsulta({
    required this.placa,
    required this.registrado,
    required this.soat,
    required this.rtm,
    required this.avisoEnviado,
    this.avisoAlAgente = false,
  });

  final String placa;
  final bool registrado;
  final EstadoDeDocumento soat;
  final EstadoDeDocumento rtm;
  final bool avisoEnviado;

  /// true si, en un operativo, el detalle se envió al agente a cargo.
  /// El operador tampoco ve el motivo en este caso.
  final bool avisoAlAgente;

  factory ResultadoConsulta.desdeJson(Map<String, dynamic> json) => ResultadoConsulta(
        placa: json['placa'] as String,
        registrado: json['registrado'] as bool? ?? false,
        soat: EstadoDeDocumento.desdeJson(json['soat'] as Map<String, dynamic>?),
        rtm: EstadoDeDocumento.desdeJson(json['rtm'] as Map<String, dynamic>?),
        avisoEnviado: json['aviso_enviado'] as bool? ?? false,
        avisoAlAgente: json['aviso_al_agente'] as bool? ?? false,
      );

  bool get requierePlanB => !registrado || soat.requiereVerificar || rtm.requiereVerificar;
}

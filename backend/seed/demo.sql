-- Datos de DEMOSTRACIÓN. Todo es ficticio: entidades, personas, placas y
-- procesos. Nunca cargar datos reales en este archivo (regla 8).

insert into entidades (id, nombre, nit) values
  ('11111111-1111-1111-1111-111111111111', 'Movilidad (demo)', '000000000-1'),
  ('22222222-2222-2222-2222-222222222222', 'Hacienda departamental (demo)', '000000000-2');

insert into operadores (id, nombre, rol, entidad_id, identificacion_oficial) values
  ('0e000000-0000-0000-0000-000000000001', 'Operador demo 1', 'operador_comercial', null, null),
  ('0e000000-0000-0000-0000-000000000002', 'Operador demo 2', 'operador_comercial', null, null),
  ('a9000000-0000-0000-0000-000000000001', 'Agente demo Movilidad', 'agente_autoridad', '11111111-1111-1111-1111-111111111111', 'AT-1001');

insert into listas_interes (id, entidad_id, nombre, finalidad, vigente_hasta) values
  ('1a000000-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111',
   'Vehículos embargados (demo)', 'Prueba de prototipo: ubicar vehículos con embargo en cobro coactivo', current_date + 90),
  ('2a000000-0000-0000-0000-000000000002', '22222222-2222-2222-2222-222222222222',
   'Impuesto vehicular embargados (demo)', 'Prueba de prototipo: cobro de impuesto vehicular', current_date + 90);

insert into items_lista (lista_id, placa, tipo_medida, referencia_proceso, fecha_medida) values
  ('1a000000-0000-0000-0000-000000000001', 'EMB417', 'embargo', 'CC-DEMO-0417', current_date - 200),
  ('1a000000-0000-0000-0000-000000000001', 'KRT58D', 'embargo', 'CC-DEMO-0058', current_date - 150),
  ('1a000000-0000-0000-0000-000000000001', 'HJN302', 'embargo', 'CC-DEMO-0302', current_date - 90),
  ('1a000000-0000-0000-0000-000000000001', 'PLM71F', 'embargo', 'CC-DEMO-0071', current_date - 60),
  ('2a000000-0000-0000-0000-000000000002', 'GTR845', 'embargo', 'IV-DEMO-0845', current_date - 120),
  ('2a000000-0000-0000-0000-000000000002', 'EMB417', 'embargo', 'IV-DEMO-0417', current_date - 30);

insert into operativos (id, entidad_id, agente_responsable, lugar, latitud, longitud, soporte, inicio, fin) values
  ('0b000000-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111',
   'a9000000-0000-0000-0000-000000000001', 'Av. 30 de Agosto con calle 50 (demo)', 4.8133, -75.7341,
   'Orden de operativo DEMO-001', now() - interval '2 hours', now() + interval '30 days');

-- Vehículos y documentos de ejemplo para la consulta comercial.
insert into vehiculos (placa, tipo, servicio, fecha_matricula) values
  ('ABC123', 'carro', 'particular', '2019-03-14'),
  ('MNO45E', 'moto',  'particular', '2023-12-01'),
  ('XYZ789', 'carro', 'particular', '2017-05-30');
insert into soat (placa, inicio_vigencia, fecha_vencimiento, fuente) values
  ('ABC123', current_date - 240, current_date + 125, 'venta_propia'),
  ('MNO45E', current_date - 358, current_date + 7,   'venta_propia'),
  ('XYZ789', current_date - 400, current_date - 35,  'carga_masiva');
insert into rtm (placa, fecha_revision, fecha_vencimiento, fuente) values
  ('ABC123', current_date - 290, current_date + 75,  'venta_propia'),
  ('XYZ789', current_date - 160, current_date + 205, 'carga_masiva');

-- Lecturas que generan coincidencias (crean radicado y bitácora).
select consultar_placa('EMB417', '0e000000-0000-0000-0000-000000000001', 4.8087, -75.6906);
select consultar_placa('GTR845', '0e000000-0000-0000-0000-000000000002', 4.8302, -75.6853);
select consultar_placa('KRT58D', '0e000000-0000-0000-0000-000000000001', 4.8133, -75.7341,
                       current_date, '0b000000-0000-0000-0000-000000000001');
select consultar_placa('HJN302', '0e000000-0000-0000-0000-000000000002', 4.8140, -75.7338,
                       current_date, '0b000000-0000-0000-0000-000000000001');
select consultar_placa('ABC123', '0e000000-0000-0000-0000-000000000001');
select consultar_placa('MNO45E', '0e000000-0000-0000-0000-000000000002');

-- Una actuación ya registrada por el agente.
select registrar_actuacion('a9000000-0000-0000-0000-000000000001',
  (select id from coincidencias where placa = 'KRT58D' limit 1),
  'medida_ejecutada', 'Vehículo inmovilizado y trasladado a patios (demo)');

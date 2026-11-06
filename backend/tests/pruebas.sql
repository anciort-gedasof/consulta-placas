-- Pruebas del backend. Todos los datos son ficticios.
-- Fecha de referencia fija: 2026-11-05.
\set ON_ERROR_STOP on

-- ---------------------------------------------------------------------------
-- Datos de prueba
-- ---------------------------------------------------------------------------

insert into operadores (id, nombre) values ('00000000-0000-0000-0000-000000000001', 'Operador de prueba');

insert into vehiculos (placa, tipo, servicio, fecha_matricula) values
  ('AAA111', 'carro', 'particular', '2022-03-10'),  -- sin RTM: primera a los 5 años -> 2027-03-10
  ('BBB222', 'carro', 'particular', '2018-01-15'),  -- con RTM registrada
  ('CCC33D', 'moto',  'particular', '2025-01-20'),  -- moto: primera a los 2 años -> 2027-01-20
  ('DDD444', 'carro', 'publico',    '2025-11-20'),  -- público: 2 años -> 2027-11-20
  ('EEE555', 'otro',  'particular', '2020-01-01');  -- tipo desconocido: sin dato de RTM

insert into rtm (placa, fecha_revision, fecha_vencimiento, fuente) values
  ('BBB222', '2025-11-20', '2026-11-20', 'venta_propia');

-- ---------------------------------------------------------------------------
-- Vencimiento de RTM
-- ---------------------------------------------------------------------------

do $$
begin
  assert vencimiento_rtm('AAA111') = '2027-03-10', 'Particular: primera RTM a los 5 años';
  assert vencimiento_rtm('BBB222') = '2026-11-20', 'Con RTM registrada se usa la última';
  assert vencimiento_rtm('CCC33D') = '2027-01-20', 'Moto: primera RTM a los 2 años';
  assert vencimiento_rtm('DDD444') = '2027-11-20', 'Servicio público: primera RTM a los 2 años';
  assert vencimiento_rtm('EEE555') is null,        'Tipo desconocido: no se adivina';
  assert vencimiento_rtm('ZZZ999') is null,        'Placa inexistente: sin dato';
  raise notice 'OK vencimiento_rtm';
end $$;

-- Los plazos son parámetros: si cambia la norma, cambia el cálculo.
do $$
begin
  update parametros set valor = '6' where clave = 'rtm_primera_particular_anios';
  assert vencimiento_rtm('AAA111') = '2028-03-10', 'El plazo debe leerse de parametros';
  update parametros set valor = '5' where clave = 'rtm_primera_particular_anios';
  raise notice 'OK parámetros editables';
end $$;

-- ---------------------------------------------------------------------------
-- Estados
-- ---------------------------------------------------------------------------

do $$
declare h date := '2026-11-05';
begin
  assert estado_por_vencimiento(null, h)         = 'sin_dato';
  assert estado_por_vencimiento('2026-11-04', h) = 'posible_vencido';
  assert estado_por_vencimiento('2026-11-05', h) = 'vence_pronto', 'Vence hoy = vence pronto';
  assert estado_por_vencimiento('2026-12-05', h) = 'vence_pronto', '30 días = vence pronto';
  assert estado_por_vencimiento('2026-12-06', h) = 'al_dia',       '31 días = al día';
  raise notice 'OK estados';
end $$;

-- ---------------------------------------------------------------------------
-- SOAT: venta propia calcula 1 año
-- ---------------------------------------------------------------------------

do $$
begin
  assert registrar_venta_soat('aaa-111', '2026-03-14') = '2027-03-14', 'SOAT vence 1 año después';
  assert vencimiento_soat('AAA111') = '2027-03-14';
  raise notice 'OK SOAT';
end $$;

-- ---------------------------------------------------------------------------
-- Consulta por placa
-- ---------------------------------------------------------------------------

do $$
declare r jsonb;
begin
  r := consultar_placa(' aaa 111 ', null, null, null, '2026-11-05');
  assert r->>'placa' = 'AAA111', 'Normaliza la placa';
  assert (r->>'registrado')::boolean;
  assert r->'soat'->>'estado' = 'al_dia';
  assert r->'rtm'->>'estado' = 'al_dia';
  assert (r->>'aviso_enviado')::boolean = false;

  r := consultar_placa('BBB222', null, null, null, '2026-11-05');
  assert r->'rtm'->>'estado' = 'vence_pronto';
  assert (r->'rtm'->>'dias')::int = 15;
  assert r->'soat'->>'estado' = 'sin_dato';

  r := consultar_placa('QWE321', null, null, null, '2026-11-05');
  assert (r->>'registrado')::boolean = false, 'Placa no registrada';
  assert r->'soat'->>'estado' = 'sin_dato' and r->'rtm'->>'estado' = 'sin_dato';
  raise notice 'OK consultar_placa';
end $$;

-- Placa con formato inválido: error
do $$
begin
  begin
    perform consultar_placa('12ABC');
    assert false, 'Debió fallar';
  exception when sqlstate '22023' then
    raise notice 'OK placa inválida rechazada';
  end;
end $$;

-- ---------------------------------------------------------------------------
-- Plan B
-- ---------------------------------------------------------------------------

do $$
declare r jsonb;
begin
  perform registrar_consulta_oficial('QWE321', '2027-02-01', '2026-10-01');
  r := consultar_placa('QWE321', null, null, null, '2026-11-05');
  assert (r->>'registrado')::boolean, 'El plan B crea el vehículo';
  assert r->'soat'->>'estado' = 'al_dia';
  assert r->'rtm'->>'estado' = 'posible_vencido';
  assert (select fuente from soat where placa = 'QWE321') = 'consulta_oficial';
  raise notice 'OK plan B';
end $$;

-- ---------------------------------------------------------------------------
-- Listas de interés: privacidad y separación entre entidades
-- ---------------------------------------------------------------------------

insert into entidades (id, nombre) values
  ('10000000-0000-0000-0000-000000000001', 'Entidad A (ficticia)'),
  ('20000000-0000-0000-0000-000000000002', 'Entidad B (ficticia)');

insert into listas_interes (id, entidad_id, nombre, finalidad, vigente_hasta) values
  ('a0000000-0000-0000-0000-00000000000a', '10000000-0000-0000-0000-000000000001', 'Embargos A', 'Prueba de prototipo', '2026-12-31'),
  ('b0000000-0000-0000-0000-00000000000b', '20000000-0000-0000-0000-000000000002', 'Embargos B', 'Prueba de prototipo', '2026-10-31');  -- vencida

insert into items_lista (lista_id, placa, tipo_medida, referencia_proceso) values
  ('a0000000-0000-0000-0000-00000000000a', 'EMB417', 'embargo', 'CC-0001'),
  ('a0000000-0000-0000-0000-00000000000a', 'KRT58D', 'embargo', 'CC-0002'),
  ('b0000000-0000-0000-0000-00000000000b', 'EMB417', 'embargo', 'X-9');

do $$
declare r jsonb;
begin
  -- Consulta sin coincidencia: no guarda ubicación en ningún lado.
  r := consultar_placa('AAA111', '00000000-0000-0000-0000-000000000001', 4.8133, -75.6961, '2026-11-05');
  assert (r->>'aviso_enviado')::boolean = false;
  assert (select count(*) from coincidencias) = 0, 'Sin coincidencia no se guarda nada con ubicación';

  -- Consulta con coincidencia
  r := consultar_placa('EMB417', '00000000-0000-0000-0000-000000000001', 4.8133, -75.6961, '2026-11-05');
  assert (r->>'aviso_enviado')::boolean, 'Debe avisar';

  -- La respuesta al operador no revela motivo, entidad ni proceso.
  assert r::text not ilike '%embargo%',  'No revela el motivo';
  assert r::text not ilike '%entidad%',  'No revela la entidad';
  assert r::text not ilike '%CC-0001%',  'No revela el proceso';

  -- Solo la lista vigente genera coincidencia (la de B venció el 31 oct).
  assert (select count(*) from coincidencias where placa = 'EMB417') = 1;
  assert (select entidad_id from coincidencias where placa = 'EMB417') = '10000000-0000-0000-0000-000000000001';
  assert (select latitud from coincidencias where placa = 'EMB417') = 4.8133, 'La coincidencia guarda ubicación';

  -- El registro de consultas no tiene columna de ubicación.
  assert not exists (
    select 1 from information_schema.columns
    where table_name = 'consultas' and column_name in ('latitud', 'longitud')
  ), 'consultas no debe guardar ubicación';
  raise notice 'OK listas de interés';
end $$;

-- Retirar una placa de la lista: deja de avisar de inmediato.
do $$
declare r jsonb;
begin
  update items_lista set activo = false where placa = 'KRT58D';
  r := consultar_placa('KRT58D', null, null, null, '2026-11-05');
  assert (r->>'aviso_enviado')::boolean = false, 'Placa retirada no avisa';
  raise notice 'OK retiro de placa';
end $$;

-- Auditoría
do $$
begin
  assert (select count(*) from auditoria where accion = 'item_cargado') = 3;
  assert (select count(*) from auditoria where accion = 'item_actualizado') = 1;
  assert (select count(*) from auditoria where accion = 'coincidencia_detectada') = 1;
  update coincidencias set estado = 'en_gestion' where placa = 'EMB417';
  assert (select count(*) from auditoria where accion = 'coincidencia_estado') = 1;
  raise notice 'OK auditoría';
end $$;

-- ---------------------------------------------------------------------------
-- Propietarios y alertas
-- ---------------------------------------------------------------------------

-- Sin autorización no se puede guardar contacto.
do $$
begin
  begin
    insert into propietarios (placa, nombre, celular) values ('AAA111', 'Sin permiso', '3000000000');
    assert false, 'Debió rechazar contacto sin autorización';
  exception when check_violation then
    raise notice 'OK contacto sin autorización rechazado';
  end;
end $$;

insert into propietarios (placa, nombre, celular, autoriza_datos, autorizacion_fecha, autorizacion_canal)
values ('BBB222', 'Propietario ficticio', '3000000001', true, '2026-11-01', 'app');

do $$
declare n integer;
begin
  -- BBB222: RTM vence 2026-11-20. Desde el 5 nov: alerta de 7 días (13 nov) y 1 día (19 nov).
  -- La de 30 días (21 oct) ya pasó. Sin SOAT: no hay alertas de SOAT.
  n := programar_alertas('2026-11-05');
  assert n = 2, format('Se esperaban 2 alertas, hubo %s', n);
  assert exists (select 1 from alertas where placa = 'BBB222' and fecha_programada = '2026-11-13');
  assert exists (select 1 from alertas where placa = 'BBB222' and fecha_programada = '2026-11-19');

  -- Idempotente
  n := programar_alertas('2026-11-05');
  assert n = 0, 'No debe duplicar alertas';

  -- AAA111 no tiene propietario autorizado: no recibe alertas.
  assert not exists (select 1 from alertas where placa = 'AAA111');
  raise notice 'OK alertas';
end $$;

\echo 'Todas las pruebas pasaron.'

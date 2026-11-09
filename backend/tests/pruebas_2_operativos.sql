-- Pruebas del modo operativo. Corre después de pruebas.sql (usa sus datos).
-- Todos los datos son ficticios.
\set ON_ERROR_STOP on

-- Entidad C: autoridad sin acceso a la lista A.
insert into entidades (id, nombre) values
  ('30000000-0000-0000-0000-000000000003', 'Autoridad C (ficticia)');

insert into operadores (id, nombre, rol, entidad_id, identificacion_oficial) values
  ('a1000000-0000-0000-0000-000000000001', 'Agente A (ficticio)', 'agente_autoridad', '10000000-0000-0000-0000-000000000001', 'AG-001'),
  ('c1000000-0000-0000-0000-000000000001', 'Agente C (ficticio)', 'agente_autoridad', '30000000-0000-0000-0000-000000000003', 'AG-301');

-- Un agente necesita entidad e identificación oficial.
do $$
begin
  begin
    insert into operadores (nombre, rol) values ('Agente sin datos', 'agente_autoridad');
    assert false, 'Debió rechazar agente sin entidad';
  exception when check_violation then
    raise notice 'OK agente requiere entidad e identificación';
  end;
end $$;

-- El responsable de un operativo debe ser agente de la misma entidad.
do $$
begin
  begin
    insert into operativos (entidad_id, agente_responsable, lugar, soporte, inicio)
    values ('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001',
            'Calle ficticia', 'Orden 001', now() - interval '1 hour');
    assert false, 'Un operador comercial no puede ser responsable';
  exception when check_violation then
    raise notice 'OK responsable debe ser agente';
  end;
  begin
    insert into operativos (entidad_id, agente_responsable, lugar, soporte, inicio)
    values ('10000000-0000-0000-0000-000000000001', 'c1000000-0000-0000-0000-000000000001',
            'Calle ficticia', 'Orden 001', now() - interval '1 hour');
    assert false, 'Agente de otra entidad no puede ser responsable';
  exception when check_violation then
    raise notice 'OK agente de la misma entidad';
  end;
end $$;

insert into operativos (id, entidad_id, agente_responsable, lugar, soporte, inicio, fin) values
  ('0a000000-0000-0000-0000-00000000000a', '10000000-0000-0000-0000-000000000001',
   'a1000000-0000-0000-0000-000000000001', 'Av. ficticia con calle 1', 'Orden 001',
   now() - interval '1 hour', now() + interval '3 hours'),
  ('0c000000-0000-0000-0000-00000000000c', '30000000-0000-0000-0000-000000000003',
   'c1000000-0000-0000-0000-000000000001', 'Carrera ficticia 2', 'Orden 301',
   now() - interval '1 hour', null),
  ('0f000000-0000-0000-0000-00000000000f', '10000000-0000-0000-0000-000000000001',
   'a1000000-0000-0000-0000-000000000001', 'Operativo terminado', 'Orden 000',
   now() - interval '5 hours', now() - interval '2 hours');

-- Nueva placa en la lista A para estas pruebas.
insert into items_lista (lista_id, placa, tipo_medida, referencia_proceso)
values ('a0000000-0000-0000-0000-00000000000a', 'OPE123', 'embargo', 'CC-0100');

do $$
declare
  r jsonb;
  n integer;
begin
  -- Operativo de la entidad dueña: aviso al agente, sin motivo para el operador.
  r := consultar_placa('OPE123', '00000000-0000-0000-0000-000000000001', 4.81, -75.69,
                       current_date, '0a000000-0000-0000-0000-00000000000a');
  assert (r->>'aviso_enviado')::boolean;
  assert (r->>'aviso_al_agente')::boolean, 'Debe ir al agente del operativo';
  assert r::text not ilike '%embargo%' and r::text not ilike '%CC-0100%', 'El operador no ve el motivo';

  -- El agente responsable ve el detalle.
  select count(*) into n
  from coincidencias_para_agente('a1000000-0000-0000-0000-000000000001', '0a000000-0000-0000-0000-00000000000a')
  where placa = 'OPE123' and tipo_medida = 'embargo' and referencia_proceso = 'CC-0100';
  assert n = 1, 'El agente debe ver el detalle';

  -- El detalle siempre trae la advertencia de verificar en sistemas oficiales.
  assert (select advertencia from coincidencias_para_agente('a1000000-0000-0000-0000-000000000001',
          '0a000000-0000-0000-0000-00000000000a') limit 1) ilike '%sistemas oficiales%';
  raise notice 'OK aviso al agente de la entidad dueña';
end $$;

-- Otro agente no puede ver el operativo ajeno.
do $$
begin
  begin
    perform * from coincidencias_para_agente('c1000000-0000-0000-0000-000000000001', '0a000000-0000-0000-0000-00000000000a');
    assert false, 'Debió negar acceso';
  exception when insufficient_privilege then
    raise notice 'OK agente ajeno sin acceso';
  end;
end $$;

-- Autoridad sin acceso a la lista: la coincidencia va a la entidad dueña, no al agente.
do $$
declare r jsonb;
begin
  r := consultar_placa('OPE123', null, null, null, current_date, '0c000000-0000-0000-0000-00000000000c');
  assert (r->>'aviso_enviado')::boolean, 'La entidad dueña igual recibe el aviso';
  assert (r->>'aviso_al_agente')::boolean = false, 'Autoridad C no tiene acceso a la lista A';
  assert not exists (
    select 1 from coincidencias_para_agente('c1000000-0000-0000-0000-000000000001', '0c000000-0000-0000-0000-00000000000c')
  ), 'Agente C no ve nada';
  raise notice 'OK autoridad sin acceso no ve el detalle';
end $$;

-- Con acceso pactado, la autoridad C sí recibe el detalle.
insert into accesos_lista (lista_id, entidad_id, soporte)
values ('a0000000-0000-0000-0000-00000000000a', '30000000-0000-0000-0000-000000000003', 'Convenio ficticio 01');

do $$
declare r jsonb;
begin
  r := consultar_placa('OPE123', null, null, null, current_date, '0c000000-0000-0000-0000-00000000000c');
  assert (r->>'aviso_al_agente')::boolean, 'Con convenio, va al agente C';
  raise notice 'OK acceso pactado';
end $$;

-- Operativo terminado: no se puede usar.
do $$
begin
  begin
    perform consultar_placa('OPE123', null, null, null, current_date, '0f000000-0000-0000-0000-00000000000f');
    assert false, 'Debió rechazar operativo terminado';
  exception when sqlstate '22023' then
    raise notice 'OK operativo terminado rechazado';
  end;
end $$;

-- Actuación del agente
do $$
declare v_id bigint;
begin
  select coincidencia_id into v_id
  from coincidencias_para_agente('a1000000-0000-0000-0000-000000000001', '0a000000-0000-0000-0000-00000000000a')
  limit 1;

  -- Otro agente no puede registrar actuación.
  begin
    perform registrar_actuacion('c1000000-0000-0000-0000-000000000001', v_id, 'abordado');
    assert false, 'Debió negar';
  exception when insufficient_privilege then
    null;
  end;

  perform registrar_actuacion('a1000000-0000-0000-0000-000000000001', v_id, 'medida_ejecutada', 'Vehículo inmovilizado');
  assert (select estado from coincidencias where id = v_id) = 'cerrado';
  assert (select actuacion from coincidencias where id = v_id) = 'medida_ejecutada';
  assert exists (select 1 from auditoria where accion = 'actuacion_registrada');
  assert exists (select 1 from auditoria where accion = 'agente_consulta_detalle');
  raise notice 'OK actuación del agente';
end $$;

-- Sin operativo, todo sigue como antes: no hay aviso al agente.
do $$
declare r jsonb;
begin
  r := consultar_placa('OPE123');
  assert (r->>'aviso_enviado')::boolean;
  assert (r->>'aviso_al_agente')::boolean = false;
  raise notice 'OK consulta comercial sin operativo';
end $$;

\echo 'Pruebas de operativos pasaron.'

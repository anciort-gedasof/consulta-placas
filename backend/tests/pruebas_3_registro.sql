-- Pruebas del registro permanente de consultas positivas.
-- Corre después de las pruebas 1 y 2 (usa sus datos).
\set ON_ERROR_STOP on

do $$
declare
  v_id bigint;
  n    integer;
begin
  -- Todas las coincidencias tienen radicado con el formato CP-AAAA-0000000.
  assert not exists (select 1 from coincidencias where radicado is null or radicado !~ '^CP-[0-9]{4}-[0-9]{7}$'),
    'Toda coincidencia debe tener radicado';
  raise notice 'OK radicado';

  -- Una coincidencia nueva genera su primera entrada en la bitácora.
  perform consultar_placa('EMB417', '00000000-0000-0000-0000-000000000001', 4.8, -75.7, current_date);
  select max(id) into v_id from coincidencias;
  assert exists (select 1 from bitacora_coincidencias where coincidencia_id = v_id and accion = 'detectada');
  raise notice 'OK bitácora al detectar';

  -- En operativo con agente: también queda el aviso al agente.
  perform consultar_placa('OPE123', null, null, null, current_date, '0a000000-0000-0000-0000-00000000000a');
  select max(id) into v_id from coincidencias;
  assert exists (select 1 from bitacora_coincidencias where coincidencia_id = v_id and accion = 'aviso_agente');
  raise notice 'OK bitácora aviso al agente';

  -- La actuación del agente queda en la bitácora.
  perform registrar_actuacion('a1000000-0000-0000-0000-000000000001', v_id, 'abordado', 'Conductor atendido');
  assert exists (select 1 from bitacora_coincidencias
                 where coincidencia_id = v_id and accion = 'actuacion' and actuacion = 'abordado');
  -- Una segunda actuación no borra la primera: ambas quedan.
  perform registrar_actuacion('a1000000-0000-0000-0000-000000000001', v_id, 'medida_ejecutada', 'Inmovilizado');
  select count(*) into n from bitacora_coincidencias where coincidencia_id = v_id and accion = 'actuacion';
  assert n = 2, 'Cada actuación queda registrada';
  raise notice 'OK historial de actuaciones';

  -- Seguimiento desde el panel de la entidad.
  select max(id) into v_id from coincidencias where placa = 'EMB417';
  perform registrar_seguimiento(v_id, 'Funcionaria de cobro (ficticia)', 'en_gestion', 'Se remite a cobro coactivo');
  perform registrar_seguimiento(v_id, 'Funcionaria de cobro (ficticia)', null, 'Se llamó al propietario');
  assert (select estado from coincidencias where id = v_id) = 'en_gestion';
  assert exists (select 1 from bitacora_coincidencias where coincidencia_id = v_id and accion = 'cambio_estado');
  assert exists (select 1 from bitacora_coincidencias where coincidencia_id = v_id and accion = 'nota');
  raise notice 'OK seguimiento de la entidad';
end $$;

-- Los datos de la detección no se pueden cambiar.
do $$
begin
  begin
    update coincidencias set placa = 'AAA111' where id = (select min(id) from coincidencias);
    assert false, 'Debió bloquear el cambio de placa';
  exception when insufficient_privilege then null;
  end;
  begin
    update coincidencias set latitud = 0 where id = (select min(id) from coincidencias);
    assert false, 'Debió bloquear el cambio de ubicación';
  exception when insufficient_privilege then null;
  end;
  begin
    update coincidencias set detectada_en = now() - interval '1 year' where id = (select min(id) from coincidencias);
    assert false, 'Debió bloquear el cambio de fecha';
  exception when insufficient_privilege then null;
  end;
  raise notice 'OK detección inalterable';
end $$;

-- Nada del registro se puede borrar ni editar.
do $$
begin
  begin
    delete from coincidencias where id = (select min(id) from coincidencias);
    assert false, 'No se pueden borrar coincidencias';
  exception when insufficient_privilege then null;
  end;
  begin
    delete from bitacora_coincidencias where id = (select min(id) from bitacora_coincidencias);
    assert false, 'No se puede borrar la bitácora';
  exception when insufficient_privilege then null;
  end;
  begin
    update bitacora_coincidencias set observacion = 'cambiada' where id = (select min(id) from bitacora_coincidencias);
    assert false, 'No se puede editar la bitácora';
  exception when insufficient_privilege then null;
  end;
  begin
    delete from auditoria where id = (select min(id) from auditoria);
    assert false, 'No se puede borrar la auditoría';
  exception when insufficient_privilege then null;
  end;
  begin
    update consultas set estado_soat = 'al_dia' where id = (select min(id) from consultas);
    assert false, 'No se pueden editar las consultas';
  exception when insufficient_privilege then null;
  end;
  raise notice 'OK registro solo de adición';
end $$;

-- Vistas de control.
do $$
begin
  assert (select count(*) from registro_positivos) = (select count(*) from coincidencias),
    'Cada coincidencia aparece en el registro';
  assert exists (select 1 from registro_positivos
                 where agente_identificacion = 'AG-001' and actuacion = 'medida_ejecutada'
                   and tiempo_hasta_actuacion is not null);
  assert exists (select 1 from consultas_positivas where estado_rtm = 'vence_pronto');
  assert not exists (select 1 from consultas_positivas
                     where not hubo_coincidencia and estado_soat = 'al_dia' and estado_rtm = 'al_dia');
  raise notice 'OK vistas de control';
end $$;

\echo 'Pruebas del registro de positivos pasaron.'

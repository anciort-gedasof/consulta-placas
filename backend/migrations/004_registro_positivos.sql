-- 004_registro_positivos.sql
-- Registro permanente de cada consulta positiva y de las acciones
-- realizadas sobre ella, para control (regla 12 de CLAUDE.md).
--
-- - Cada coincidencia recibe un radicado único (CP-AAAA-0000001).
-- - Los datos de la detección no se pueden modificar ni borrar.
-- - Cada acción queda en una bitácora a la que solo se le agregan filas.
-- - Consultas y auditoría tampoco se pueden modificar ni borrar.

-- ---------------------------------------------------------------------------
-- Utilidad: bloquear cambios en tablas de solo adición
-- ---------------------------------------------------------------------------

create or replace function bloquear_cambios()
returns trigger
language plpgsql
as $$
begin
  raise exception 'La tabla % es un registro permanente: no admite %', tg_table_name, lower(tg_op)
    using errcode = '42501';
end;
$$;

create trigger auditoria_solo_adicion
before update or delete on auditoria
for each row execute function bloquear_cambios();

create trigger consultas_solo_adicion
before update or delete on consultas
for each row execute function bloquear_cambios();

-- ---------------------------------------------------------------------------
-- Radicado de cada coincidencia
-- ---------------------------------------------------------------------------

alter table coincidencias add column radicado text unique;

create or replace function asignar_radicado()
returns trigger
language plpgsql
as $$
begin
  new.radicado := 'CP-' || to_char(new.detectada_en, 'YYYY') || '-' || lpad(new.id::text, 7, '0');
  return new;
end;
$$;

create trigger coincidencias_radicado
before insert on coincidencias
for each row execute function asignar_radicado();

-- ---------------------------------------------------------------------------
-- Coincidencias: lo detectado es inalterable; solo cambia el seguimiento
-- ---------------------------------------------------------------------------

create or replace function proteger_coincidencia()
returns trigger
language plpgsql
as $$
begin
  if tg_op = 'DELETE' then
    raise exception 'Las coincidencias son un registro permanente: no se pueden borrar'
      using errcode = '42501';
  end if;

  if (new.item_id, new.lista_id, new.entidad_id, new.placa, new.detectada_en,
      new.latitud, new.longitud, new.operador_id, new.operativo_id,
      new.notificada_a, new.radicado)
     is distinct from
     (old.item_id, old.lista_id, old.entidad_id, old.placa, old.detectada_en,
      old.latitud, old.longitud, old.operador_id, old.operativo_id,
      old.notificada_a, old.radicado)
  then
    raise exception 'Los datos de la detección (radicado %) no se pueden modificar', old.radicado
      using errcode = '42501';
  end if;

  return new;
end;
$$;

create trigger coincidencias_proteger
before update or delete on coincidencias
for each row execute function proteger_coincidencia();

-- ---------------------------------------------------------------------------
-- Bitácora de acciones sobre cada coincidencia (solo adición)
-- ---------------------------------------------------------------------------

create table bitacora_coincidencias (
  id              bigserial primary key,
  coincidencia_id bigint not null references coincidencias (id),
  radicado        text not null,
  ocurrido_en     timestamptz not null default now(),
  actor_id        uuid references operadores (id),
  actor           text not null,            -- nombre o usuario del panel
  accion          text not null,            -- detectada, aviso_agente, cambio_estado, actuacion, nota
  estado          estado_coincidencia,
  actuacion       resultado_actuacion,
  observacion     text
);
create index bitacora_coincidencia_idx on bitacora_coincidencias (coincidencia_id, ocurrido_en);

create trigger bitacora_solo_adicion
before update or delete on bitacora_coincidencias
for each row execute function bloquear_cambios();

-- Al detectarse: primera entrada de la bitácora.
create or replace function bitacora_al_detectar()
returns trigger
language plpgsql
as $$
begin
  insert into bitacora_coincidencias (coincidencia_id, radicado, actor_id, actor, accion, estado)
  values (new.id, new.radicado, new.operador_id,
          coalesce((select nombre from operadores where id = new.operador_id), 'sistema'),
          'detectada', new.estado);

  if new.notificada_a is not null then
    insert into bitacora_coincidencias (coincidencia_id, radicado, actor_id, actor, accion, estado)
    values (new.id, new.radicado, new.notificada_a,
            (select nombre from operadores where id = new.notificada_a),
            'aviso_agente', new.estado);
  end if;
  return new;
end;
$$;

create trigger coincidencias_bitacora_insert
after insert on coincidencias
for each row execute function bitacora_al_detectar();

-- ---------------------------------------------------------------------------
-- Acciones: agente (actuación) y entidad desde el panel (seguimiento)
-- ---------------------------------------------------------------------------

create or replace function registrar_actuacion(
  p_agente       uuid,
  p_coincidencia bigint,
  p_resultado    resultado_actuacion,
  p_observacion  text default null
)
returns void
language plpgsql
as $$
declare
  v_c       coincidencias%rowtype;
  v_estado  estado_coincidencia;
begin
  select * into v_c from coincidencias where id = p_coincidencia;
  if not found or v_c.notificada_a is distinct from p_agente then
    raise exception 'La coincidencia no está asignada a este agente' using errcode = '42501';
  end if;

  v_estado := case when p_resultado = 'medida_ejecutada' then 'cerrado'::estado_coincidencia
                   else 'en_gestion'::estado_coincidencia end;

  update coincidencias
     set actuacion = p_resultado,
         actuacion_obs = p_observacion,
         actuacion_en = now(),
         estado = v_estado
   where id = p_coincidencia;

  insert into bitacora_coincidencias (coincidencia_id, radicado, actor_id, actor, accion, estado, actuacion, observacion)
  values (p_coincidencia, v_c.radicado, p_agente,
          (select nombre from operadores where id = p_agente),
          'actuacion', v_estado, p_resultado, p_observacion);

  insert into auditoria (accion, entidad_id, detalle)
  values ('actuacion_registrada', v_c.entidad_id,
          jsonb_build_object('coincidencia_id', p_coincidencia, 'radicado', v_c.radicado,
                             'agente_id', p_agente, 'resultado', p_resultado));
end;
$$;

-- Seguimiento de la entidad desde el panel: cambio de estado y/o nota.
create or replace function registrar_seguimiento(
  p_coincidencia bigint,
  p_actor        text,
  p_estado       estado_coincidencia default null,
  p_observacion  text default null
)
returns void
language plpgsql
as $$
declare
  v_c coincidencias%rowtype;
begin
  if coalesce(trim(p_actor), '') = '' then
    raise exception 'Debe indicar quién registra el seguimiento' using errcode = '22023';
  end if;
  if p_estado is null and coalesce(trim(p_observacion), '') = '' then
    raise exception 'Debe indicar un estado o una observación' using errcode = '22023';
  end if;

  select * into v_c from coincidencias where id = p_coincidencia;
  if not found then
    raise exception 'Coincidencia inexistente' using errcode = '22023';
  end if;

  if p_estado is not null and p_estado is distinct from v_c.estado then
    update coincidencias set estado = p_estado where id = p_coincidencia;
  end if;

  insert into bitacora_coincidencias (coincidencia_id, radicado, actor, accion, estado, observacion)
  values (p_coincidencia, v_c.radicado, p_actor,
          case when p_estado is not null and p_estado is distinct from v_c.estado then 'cambio_estado' else 'nota' end,
          coalesce(p_estado, v_c.estado), p_observacion);
end;
$$;

-- ---------------------------------------------------------------------------
-- Vistas de control
-- ---------------------------------------------------------------------------

-- Una fila por consulta positiva con su último estado y tiempos.
create or replace view registro_positivos as
select
  c.radicado,
  c.placa,
  c.detectada_en,
  e.nombre                       as entidad,
  i.tipo_medida,
  i.referencia_proceso,
  o.lugar                        as operativo_lugar,
  op.nombre                      as operador,
  ag.nombre                      as agente,
  ag.identificacion_oficial      as agente_identificacion,
  c.latitud,
  c.longitud,
  c.estado,
  c.actuacion,
  c.actuacion_en,
  c.actuacion_en - c.detectada_en as tiempo_hasta_actuacion,
  (select count(*) from bitacora_coincidencias b where b.coincidencia_id = c.id) as acciones_registradas,
  c.entidad_id,
  c.id                           as coincidencia_id
from coincidencias c
join entidades e   on e.id = c.entidad_id
join items_lista i on i.id = c.item_id
left join operativos o  on o.id = c.operativo_id
left join operadores op on op.id = c.operador_id
left join operadores ag on ag.id = c.notificada_a;

-- Consultas comerciales positivas: documento vencido o por vencer, o aviso a entidad.
create or replace view consultas_positivas as
select *
from consultas
where hubo_coincidencia
   or estado_soat in ('posible_vencido', 'vence_pronto')
   or estado_rtm  in ('posible_vencido', 'vence_pronto');

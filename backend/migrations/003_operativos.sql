-- 003_operativos.sql
-- Operativos con autoridad (Policía o agentes de tránsito).
--
-- En un operativo, el operador lee placas en presencia de un uniformado.
-- Si hay coincidencia con una lista que la autoridad puede ver, el aviso
-- con el detalle (medida y proceso) llega SOLO al agente a cargo, en su
-- propia cuenta. El operador sigue sin ver el motivo (regla 2).
-- Quien aborda al conductor es siempre el uniformado (regla 9).

-- ---------------------------------------------------------------------------
-- Roles de las personas de campo
-- ---------------------------------------------------------------------------

create type rol_campo as enum ('operador_comercial', 'agente_autoridad');

alter table operadores
  add column rol rol_campo not null default 'operador_comercial',
  add column entidad_id uuid references entidades (id),
  add column identificacion_oficial text,   -- número de placa del agente
  add constraint agente_con_entidad
    check (rol <> 'agente_autoridad' or (entidad_id is not null and identificacion_oficial is not null));

-- ---------------------------------------------------------------------------
-- Qué autoridades pueden ver el detalle de cada lista.
-- La entidad dueña de la lista siempre puede; otras solo si se pacta.
-- ---------------------------------------------------------------------------

create table accesos_lista (
  lista_id   uuid not null references listas_interes (id),
  entidad_id uuid not null references entidades (id),
  soporte    text not null,      -- convenio o acto que autoriza el acceso
  otorgado_en timestamptz not null default now(),
  primary key (lista_id, entidad_id)
);

create or replace function autoridad_puede_ver_lista(p_entidad uuid, p_lista uuid)
returns boolean
language sql stable
as $$
  select exists (select 1 from listas_interes where id = p_lista and entidad_id = p_entidad)
      or exists (select 1 from accesos_lista where lista_id = p_lista and entidad_id = p_entidad)
$$;

-- ---------------------------------------------------------------------------
-- Operativos
-- ---------------------------------------------------------------------------

create table operativos (
  id                  uuid primary key default gen_random_uuid(),
  entidad_id          uuid not null references entidades (id),   -- autoridad responsable
  agente_responsable  uuid not null references operadores (id),
  lugar               text not null,
  latitud             numeric(9, 6),
  longitud            numeric(9, 6),
  soporte             text not null,      -- orden o acto que dispone el operativo
  inicio              timestamptz not null,
  fin                 timestamptz,
  creado_en           timestamptz not null default now(),
  check (fin is null or fin > inicio)
);

create or replace function validar_agente_operativo()
returns trigger
language plpgsql
as $$
declare
  v_agente operadores%rowtype;
begin
  select * into v_agente from operadores where id = new.agente_responsable;
  if v_agente.rol <> 'agente_autoridad' or not v_agente.activo then
    raise exception 'El responsable del operativo debe ser un agente de autoridad activo'
      using errcode = '23514';
  end if;
  if v_agente.entidad_id <> new.entidad_id then
    raise exception 'El agente debe pertenecer a la entidad del operativo'
      using errcode = '23514';
  end if;
  return new;
end;
$$;

create trigger operativos_validar_agente
before insert or update on operativos
for each row execute function validar_agente_operativo();

create or replace function operativo_en_curso(p_operativo uuid, p_momento timestamptz default now())
returns boolean
language sql stable
as $$
  select exists (
    select 1 from operativos
    where id = p_operativo
      and inicio <= p_momento
      and (fin is null or fin > p_momento)
  )
$$;

-- ---------------------------------------------------------------------------
-- Coincidencias: vínculo con el operativo y actuación del agente
-- ---------------------------------------------------------------------------

create type resultado_actuacion as enum ('abordado', 'medida_ejecutada', 'no_detenido', 'sin_actuacion');

alter table coincidencias
  add column operativo_id uuid references operativos (id),
  add column notificada_a uuid references operadores (id),  -- agente que recibió el detalle
  add column actuacion resultado_actuacion,
  add column actuacion_obs text,
  add column actuacion_en timestamptz;

-- ---------------------------------------------------------------------------
-- consultar_placa con operativo
--
-- Misma respuesta al operador que antes, más 'aviso_al_agente' cuando la
-- coincidencia quedó asignada al agente del operativo. Sin motivo.
-- ---------------------------------------------------------------------------

drop function consultar_placa(text, uuid, numeric, numeric, date);

create or replace function consultar_placa(
  p_placa     text,
  p_operador  uuid default null,
  p_latitud   numeric default null,
  p_longitud  numeric default null,
  p_hoy       date default current_date,
  p_operativo uuid default null
)
returns jsonb
language plpgsql
as $$
declare
  v_placa         text := normalizar_placa(p_placa);
  v_vehiculo      vehiculos%rowtype;
  v_venc_soat     date;
  v_venc_rtm      date;
  v_estado_soat   estado_documento;
  v_estado_rtm    estado_documento;
  v_coincidencias integer := 0;
  v_al_agente     integer := 0;
  v_operativo     operativos%rowtype;
  v_en_operativo  boolean := false;
  v_item          record;
  v_va_al_agente  boolean;
begin
  if not placa_valida(v_placa) then
    raise exception 'Placa con formato no válido: %', p_placa using errcode = '22023';
  end if;

  if p_operativo is not null then
    if not operativo_en_curso(p_operativo) then
      raise exception 'El operativo no está en curso' using errcode = '22023';
    end if;
    select * into v_operativo from operativos where id = p_operativo;
    v_en_operativo := true;
  end if;

  select * into v_vehiculo from vehiculos where placa = v_placa;
  v_venc_soat   := vencimiento_soat(v_placa);
  v_venc_rtm    := vencimiento_rtm(v_placa);
  v_estado_soat := estado_por_vencimiento(v_venc_soat, p_hoy);
  v_estado_rtm  := estado_por_vencimiento(v_venc_rtm, p_hoy);

  for v_item in
    select i.id as item_id, l.id as lista_id, l.entidad_id
    from items_lista i
    join listas_interes l on l.id = i.lista_id
    join entidades e on e.id = l.entidad_id
    where i.placa = v_placa
      and i.activo
      and l.activa
      and e.activa
      and (l.vigente_hasta is null or l.vigente_hasta >= p_hoy)
  loop
    v_va_al_agente := v_en_operativo
      and autoridad_puede_ver_lista(v_operativo.entidad_id, v_item.lista_id);

    insert into coincidencias (item_id, lista_id, entidad_id, placa, latitud, longitud,
                               operador_id, operativo_id, notificada_a)
    values (v_item.item_id, v_item.lista_id, v_item.entidad_id, v_placa, p_latitud, p_longitud,
            p_operador,
            case when v_en_operativo then p_operativo end,
            case when v_va_al_agente then v_operativo.agente_responsable end);

    insert into auditoria (accion, entidad_id, detalle)
    values ('coincidencia_detectada', v_item.entidad_id,
            jsonb_build_object('placa', v_placa, 'lista_id', v_item.lista_id,
                               'operador_id', p_operador, 'operativo_id', p_operativo,
                               'al_agente', v_va_al_agente));

    v_coincidencias := v_coincidencias + 1;
    if v_va_al_agente then
      v_al_agente := v_al_agente + 1;
    end if;
  end loop;

  insert into consultas (placa, operador_id, estado_soat, estado_rtm, hubo_coincidencia)
  values (v_placa, p_operador, v_estado_soat, v_estado_rtm, v_coincidencias > 0);

  return jsonb_build_object(
    'placa',        v_placa,
    'registrado',   v_vehiculo.placa is not null,
    'tipo',         v_vehiculo.tipo,
    'soat', jsonb_build_object('estado', v_estado_soat, 'vencimiento', v_venc_soat, 'dias', v_venc_soat - p_hoy),
    'rtm',  jsonb_build_object('estado', v_estado_rtm,  'vencimiento', v_venc_rtm,  'dias', v_venc_rtm - p_hoy),
    'aviso_enviado',   v_coincidencias > 0,
    'aviso_al_agente', v_al_agente > 0
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- Vista del agente: detalle de las coincidencias de SU operativo.
-- Solo el agente responsable, solo listas que su entidad puede ver.
-- Cada consulta del agente queda en auditoría.
-- ---------------------------------------------------------------------------

create or replace function coincidencias_para_agente(p_agente uuid, p_operativo uuid)
returns table (
  coincidencia_id    bigint,
  placa              text,
  detectada_en       timestamptz,
  entidad            text,
  tipo_medida        text,
  referencia_proceso text,
  actuacion          resultado_actuacion,
  advertencia        text
)
language plpgsql
as $$
declare
  v_operativo operativos%rowtype;
begin
  select * into v_operativo from operativos where id = p_operativo;
  if not found or v_operativo.agente_responsable <> p_agente then
    raise exception 'Solo el agente responsable puede ver las coincidencias del operativo'
      using errcode = '42501';
  end if;

  insert into auditoria (accion, entidad_id, detalle)
  values ('agente_consulta_detalle', v_operativo.entidad_id,
          jsonb_build_object('agente_id', p_agente, 'operativo_id', p_operativo));

  return query
  select c.id, c.placa::text, c.detectada_en, e.nombre, i.tipo_medida, i.referencia_proceso,
         c.actuacion,
         'Dato de la lista de la entidad. Antes de cualquier medida, verifique en los sistemas oficiales.'::text
  from coincidencias c
  join items_lista i on i.id = c.item_id
  join entidades e on e.id = c.entidad_id
  where c.operativo_id = p_operativo
    and c.notificada_a = p_agente
  order by c.detectada_en desc;
end;
$$;

-- El agente registra qué pasó con cada coincidencia.
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
  v_c coincidencias%rowtype;
begin
  select * into v_c from coincidencias where id = p_coincidencia;
  if not found or v_c.notificada_a is distinct from p_agente then
    raise exception 'La coincidencia no está asignada a este agente' using errcode = '42501';
  end if;

  update coincidencias
     set actuacion = p_resultado,
         actuacion_obs = p_observacion,
         actuacion_en = now(),
         estado = case when p_resultado = 'medida_ejecutada' then 'cerrado'::estado_coincidencia
                       else 'en_gestion'::estado_coincidencia end
   where id = p_coincidencia;

  insert into auditoria (accion, entidad_id, detalle)
  values ('actuacion_registrada', v_c.entidad_id,
          jsonb_build_object('coincidencia_id', p_coincidencia, 'agente_id', p_agente, 'resultado', p_resultado));
end;
$$;

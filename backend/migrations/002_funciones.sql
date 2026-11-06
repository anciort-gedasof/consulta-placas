-- 002_funciones.sql
-- Reglas de vencimiento, consulta por placa, registro del plan B,
-- programación de alertas y auditoría de listas.

-- ---------------------------------------------------------------------------
-- Utilidades
-- ---------------------------------------------------------------------------

create or replace function param_int(p_clave text)
returns integer
language sql stable
as $$
  select valor::integer from parametros where clave = p_clave
$$;

-- Normaliza una placa: mayúsculas, sin espacios ni guiones.
create or replace function normalizar_placa(p_placa text)
returns text
language sql immutable
as $$
  select upper(regexp_replace(coalesce(p_placa, ''), '[^A-Za-z0-9]', '', 'g'))
$$;

create or replace function placa_valida(p_placa text)
returns boolean
language sql immutable
as $$
  select p_placa ~ '^[A-Z]{3}[0-9]{3}$' or p_placa ~ '^[A-Z]{3}[0-9]{2}[A-Z]$'
$$;

-- ---------------------------------------------------------------------------
-- Vencimientos
-- ---------------------------------------------------------------------------

-- SOAT: el vencimiento más reciente registrado. Null si no hay.
create or replace function vencimiento_soat(p_placa text)
returns date
language sql stable
as $$
  select max(fecha_vencimiento) from soat where placa = p_placa
$$;

-- RTM: el vencimiento más reciente registrado; si no hay ninguna revisión,
-- la fecha de la primera revisión según matrícula, tipo y servicio.
create or replace function vencimiento_rtm(p_placa text)
returns date
language plpgsql stable
as $$
declare
  v_registrado date;
  v_vehiculo   vehiculos%rowtype;
  v_anios      integer;
begin
  select max(fecha_vencimiento) into v_registrado from rtm where placa = p_placa;
  if v_registrado is not null then
    return v_registrado;
  end if;

  select * into v_vehiculo from vehiculos where placa = p_placa;
  if not found or v_vehiculo.fecha_matricula is null then
    return null;
  end if;

  if v_vehiculo.servicio = 'publico' then
    v_anios := param_int('rtm_primera_publico_anios');
  elsif v_vehiculo.tipo = 'moto' then
    v_anios := param_int('rtm_primera_moto_anios');
  elsif v_vehiculo.tipo = 'carro' then
    v_anios := param_int('rtm_primera_particular_anios');
  else
    -- Tipo desconocido: no se adivina la regla.
    return null;
  end if;

  return (v_vehiculo.fecha_matricula + make_interval(years => v_anios))::date;
end;
$$;

-- Estado de un documento a partir de su vencimiento.
create or replace function estado_por_vencimiento(p_vencimiento date, p_hoy date default current_date)
returns estado_documento
language sql stable
as $$
  select case
    when p_vencimiento is null then 'sin_dato'::estado_documento
    when p_vencimiento < p_hoy then 'posible_vencido'::estado_documento
    when p_vencimiento - p_hoy <= param_int('dias_vence_pronto') then 'vence_pronto'::estado_documento
    else 'al_dia'::estado_documento
  end
$$;

-- ---------------------------------------------------------------------------
-- Consulta por placa (lo que llama la app)
--
-- Devuelve el estado de SOAT y RTM y si se envió un aviso a alguna entidad.
-- NUNCA devuelve el motivo, la entidad ni el proceso (regla 2).
-- La ubicación solo se guarda si hay coincidencia (regla 4).
-- ---------------------------------------------------------------------------

create or replace function consultar_placa(
  p_placa     text,
  p_operador  uuid default null,
  p_latitud   numeric default null,
  p_longitud  numeric default null,
  p_hoy       date default current_date
)
returns jsonb
language plpgsql
as $$
declare
  v_placa        text := normalizar_placa(p_placa);
  v_vehiculo     vehiculos%rowtype;
  v_venc_soat    date;
  v_venc_rtm     date;
  v_estado_soat  estado_documento;
  v_estado_rtm   estado_documento;
  v_coincidencias integer := 0;
  v_item         record;
begin
  if not placa_valida(v_placa) then
    raise exception 'Placa con formato no válido: %', p_placa
      using errcode = '22023';
  end if;

  select * into v_vehiculo from vehiculos where placa = v_placa;
  v_venc_soat   := vencimiento_soat(v_placa);
  v_venc_rtm    := vencimiento_rtm(v_placa);
  v_estado_soat := estado_por_vencimiento(v_venc_soat, p_hoy);
  v_estado_rtm  := estado_por_vencimiento(v_venc_rtm, p_hoy);

  -- Cruce con listas de interés activas y vigentes.
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
    insert into coincidencias (item_id, lista_id, entidad_id, placa, latitud, longitud, operador_id)
    values (v_item.item_id, v_item.lista_id, v_item.entidad_id, v_placa, p_latitud, p_longitud, p_operador);

    insert into auditoria (accion, entidad_id, detalle)
    values ('coincidencia_detectada', v_item.entidad_id,
            jsonb_build_object('placa', v_placa, 'lista_id', v_item.lista_id, 'operador_id', p_operador));

    v_coincidencias := v_coincidencias + 1;
  end loop;

  insert into consultas (placa, operador_id, estado_soat, estado_rtm, hubo_coincidencia)
  values (v_placa, p_operador, v_estado_soat, v_estado_rtm, v_coincidencias > 0);

  return jsonb_build_object(
    'placa',        v_placa,
    'registrado',   v_vehiculo.placa is not null,
    'tipo',         v_vehiculo.tipo,
    'soat', jsonb_build_object(
      'estado',      v_estado_soat,
      'vencimiento', v_venc_soat,
      'dias',        v_venc_soat - p_hoy),
    'rtm', jsonb_build_object(
      'estado',      v_estado_rtm,
      'vencimiento', v_venc_rtm,
      'dias',        v_venc_rtm - p_hoy),
    'aviso_enviado', v_coincidencias > 0
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- Plan B: el operador anota las fechas que vio en la consulta oficial.
-- ---------------------------------------------------------------------------

create or replace function registrar_consulta_oficial(
  p_placa            text,
  p_venc_soat        date,
  p_venc_rtm         date,
  p_operador         uuid default null,
  p_tipo             tipo_vehiculo default 'otro'
)
returns void
language plpgsql
as $$
declare
  v_placa text := normalizar_placa(p_placa);
begin
  if not placa_valida(v_placa) then
    raise exception 'Placa con formato no válido: %', p_placa using errcode = '22023';
  end if;
  if p_venc_soat is null and p_venc_rtm is null then
    raise exception 'Debe anotar al menos una fecha' using errcode = '22023';
  end if;

  insert into vehiculos (placa, tipo) values (v_placa, p_tipo)
  on conflict (placa) do nothing;

  if p_venc_soat is not null then
    insert into soat (placa, fecha_vencimiento, fuente, registrado_por)
    values (v_placa, p_venc_soat, 'consulta_oficial', p_operador);
  end if;

  if p_venc_rtm is not null then
    insert into rtm (placa, fecha_vencimiento, fuente, registrado_por)
    values (v_placa, p_venc_rtm, 'consulta_oficial', p_operador);
  end if;
end;
$$;

-- Venta propia de SOAT: el vencimiento se calcula desde el inicio de vigencia.
create or replace function registrar_venta_soat(
  p_placa       text,
  p_inicio      date,
  p_aseguradora text default null,
  p_operador    uuid default null
)
returns date
language plpgsql
as $$
declare
  v_placa text := normalizar_placa(p_placa);
  v_venc  date := (p_inicio + make_interval(years => param_int('soat_vigencia_anios')))::date;
begin
  insert into soat (placa, inicio_vigencia, fecha_vencimiento, aseguradora, fuente, registrado_por)
  values (v_placa, p_inicio, v_venc, p_aseguradora, 'venta_propia', p_operador);
  return v_venc;
end;
$$;

-- ---------------------------------------------------------------------------
-- Programación de alertas: solo propietarios con autorización (regla 6).
-- Idempotente: se puede correr cada día sin duplicar.
-- ---------------------------------------------------------------------------

create or replace function programar_alertas(p_hoy date default current_date)
returns integer
language plpgsql
as $$
declare
  v_dias   integer[] := string_to_array((select valor from parametros where clave = 'alertas_dias'), ',')::integer[];
  v_creadas integer;
begin
  with autorizados as (
    select distinct placa from propietarios where autoriza_datos
  ),
  documentos as (
    select a.placa, 'soat'::text as documento, vencimiento_soat(a.placa) as venc from autorizados a
    union all
    select a.placa, 'rtm'::text, vencimiento_rtm(a.placa) from autorizados a
  ),
  candidatas as (
    select d.placa, d.documento, d.venc, (d.venc - x.dias) as fecha_programada
    from documentos d
    cross join unnest(v_dias) as x(dias)
    where d.venc is not null
      and d.venc - x.dias >= p_hoy
  ),
  insertadas as (
    insert into alertas (placa, documento, fecha_vencimiento, fecha_programada)
    select placa, documento, venc, fecha_programada from candidatas
    on conflict do nothing
    returning 1
  )
  select count(*) into v_creadas from insertadas;

  return v_creadas;
end;
$$;

-- ---------------------------------------------------------------------------
-- Auditoría de cambios en listas de interés (regla 7)
-- ---------------------------------------------------------------------------

create or replace function auditar_item_lista()
returns trigger
language plpgsql
as $$
declare
  v_entidad uuid;
begin
  select entidad_id into v_entidad from listas_interes where id = new.lista_id;
  if tg_op = 'UPDATE' then
    new.actualizado_en := now();
  end if;
  insert into auditoria (accion, entidad_id, detalle)
  values (
    case tg_op when 'INSERT' then 'item_cargado' else 'item_actualizado' end,
    v_entidad,
    jsonb_build_object('lista_id', new.lista_id, 'placa', new.placa, 'activo', new.activo)
  );
  return new;
end;
$$;

create trigger items_lista_auditoria
before insert or update on items_lista
for each row execute function auditar_item_lista();

create or replace function auditar_coincidencia()
returns trigger
language plpgsql
as $$
begin
  if new.estado is distinct from old.estado then
    new.actualizado_en := now();
    insert into auditoria (accion, entidad_id, detalle)
    values ('coincidencia_estado', new.entidad_id,
            jsonb_build_object('coincidencia_id', new.id, 'de', old.estado, 'a', new.estado));
  end if;
  return new;
end;
$$;

create trigger coincidencias_auditoria
before update on coincidencias
for each row execute function auditar_coincidencia();

-- 001_esquema.sql
-- Tablas base: vehículos, documentos (SOAT y RTM), propietarios, consultas,
-- alertas y listas de interés de entidades.
-- Reglas de privacidad: ver CLAUDE.md.

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------------
-- Tipos
-- ---------------------------------------------------------------------------

create type tipo_vehiculo as enum ('carro', 'moto', 'otro');
create type tipo_servicio as enum ('particular', 'publico');
create type fuente_dato as enum ('venta_propia', 'consulta_oficial', 'carga_masiva');
create type estado_documento as enum ('al_dia', 'vence_pronto', 'posible_vencido', 'sin_dato');
create type estado_coincidencia as enum ('nuevo', 'en_gestion', 'cerrado');

-- Formato de placa colombiana: carro ABC123, moto ABC12D.
create domain placa_co as text
  check (value ~ '^[A-Z]{3}[0-9]{3}$' or value ~ '^[A-Z]{3}[0-9]{2}[A-Z]$');

-- ---------------------------------------------------------------------------
-- Parámetros editables (plazos de RTM, SOAT y alertas)
-- Nunca fijar estos valores en el código.
-- ---------------------------------------------------------------------------

create table parametros (
  clave       text primary key,
  valor       text not null,
  descripcion text not null
);

insert into parametros (clave, valor, descripcion) values
  ('rtm_primera_particular_anios', '5',      'Años desde la matrícula hasta la primera RTM, servicio particular (carros)'),
  ('rtm_primera_moto_anios',       '2',      'Años desde la matrícula hasta la primera RTM, motocicletas'),
  ('rtm_primera_publico_anios',    '2',      'Años desde la matrícula hasta la primera RTM, servicio público'),
  ('rtm_renovacion_anios',         '1',      'Años de vigencia de cada RTM después de la primera'),
  ('soat_vigencia_anios',          '1',      'Años de vigencia del SOAT'),
  ('dias_vence_pronto',            '30',     'Días antes del vencimiento en que el estado pasa a vence_pronto'),
  ('alertas_dias',                 '30,7,1', 'Días antes del vencimiento en que se envían recordatorios');

-- ---------------------------------------------------------------------------
-- Operadores de campo
-- ---------------------------------------------------------------------------

create table operadores (
  id        uuid primary key default gen_random_uuid(),
  nombre    text not null,
  activo    boolean not null default true,
  creado_en timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- Vehículos y documentos
-- ---------------------------------------------------------------------------

create table vehiculos (
  placa           placa_co primary key,
  tipo            tipo_vehiculo not null,
  servicio        tipo_servicio not null default 'particular',
  fecha_matricula date,
  marca           text,
  linea           text,
  modelo          integer,
  creado_en       timestamptz not null default now(),
  actualizado_en  timestamptz not null default now()
);

create table soat (
  id                uuid primary key default gen_random_uuid(),
  placa             placa_co not null references vehiculos (placa),
  inicio_vigencia   date,
  fecha_vencimiento date not null,
  aseguradora       text,
  fuente            fuente_dato not null,
  registrado_por    uuid references operadores (id),
  registrado_en     timestamptz not null default now()
);
create index soat_placa_idx on soat (placa, fecha_vencimiento desc);

create table rtm (
  id                uuid primary key default gen_random_uuid(),
  placa             placa_co not null references vehiculos (placa),
  fecha_revision    date,
  fecha_vencimiento date not null,
  cda               text,
  fuente            fuente_dato not null,
  registrado_por    uuid references operadores (id),
  registrado_en     timestamptz not null default now()
);
create index rtm_placa_idx on rtm (placa, fecha_vencimiento desc);

-- ---------------------------------------------------------------------------
-- Propietarios: contacto solo con autorización (Ley 1581 de 2012)
-- ---------------------------------------------------------------------------

create table propietarios (
  id                  uuid primary key default gen_random_uuid(),
  placa               placa_co not null references vehiculos (placa),
  nombre              text,
  celular             text,
  correo              text,
  autoriza_datos      boolean not null default false,
  autorizacion_fecha  timestamptz,
  autorizacion_canal  text,
  creado_en           timestamptz not null default now(),
  -- Sin autorización no se guarda contacto.
  constraint contacto_requiere_autorizacion
    check (autoriza_datos or (celular is null and correo is null)),
  -- Si hay autorización, debe quedar cuándo y por qué canal.
  constraint autorizacion_trazable
    check (not autoriza_datos or (autorizacion_fecha is not null and autorizacion_canal is not null))
);
create index propietarios_placa_idx on propietarios (placa);

-- ---------------------------------------------------------------------------
-- Registro de consultas: SIN ubicación (regla 4 de CLAUDE.md)
-- ---------------------------------------------------------------------------

create table consultas (
  id                bigserial primary key,
  placa             placa_co not null,
  operador_id       uuid references operadores (id),
  consultado_en     timestamptz not null default now(),
  estado_soat       estado_documento not null,
  estado_rtm        estado_documento not null,
  hubo_coincidencia boolean not null default false
);
create index consultas_fecha_idx on consultas (consultado_en);

-- ---------------------------------------------------------------------------
-- Alertas de vencimiento al propietario
-- ---------------------------------------------------------------------------

create table alertas (
  id               bigserial primary key,
  placa            placa_co not null references vehiculos (placa),
  documento        text not null check (documento in ('soat', 'rtm')),
  fecha_vencimiento date not null,
  fecha_programada date not null,
  canal            text not null default 'whatsapp' check (canal in ('whatsapp', 'sms', 'correo')),
  estado           text not null default 'programada'
                   check (estado in ('programada', 'enviada', 'entregada', 'fallida', 'cancelada')),
  venta_generada   boolean not null default false,
  creada_en        timestamptz not null default now(),
  unique (placa, documento, fecha_vencimiento, fecha_programada)
);
create index alertas_pendientes_idx on alertas (fecha_programada) where estado = 'programada';

-- ---------------------------------------------------------------------------
-- Listas de interés de entidades (fase 2)
-- Datos mínimos: placa, medida, referencia del proceso, fecha (regla 5).
-- ---------------------------------------------------------------------------

create table entidades (
  id        uuid primary key default gen_random_uuid(),
  nombre    text not null,
  nit       text,
  activa    boolean not null default true,
  creada_en timestamptz not null default now()
);

create table listas_interes (
  id            uuid primary key default gen_random_uuid(),
  entidad_id    uuid not null references entidades (id),
  nombre        text not null,
  finalidad     text not null,          -- finalidad pactada en el acuerdo de datos
  vigente_hasta date,                   -- fin del acuerdo o de la prueba
  activa        boolean not null default true,
  creada_en     timestamptz not null default now()
);

create table items_lista (
  id                 bigserial primary key,
  lista_id           uuid not null references listas_interes (id),
  placa              placa_co not null,
  tipo_medida        text not null,
  referencia_proceso text,
  fecha_medida       date,
  activo             boolean not null default true,
  cargado_en         timestamptz not null default now(),
  actualizado_en     timestamptz not null default now(),
  unique (lista_id, placa)
);
create index items_lista_placa_activos_idx on items_lista (placa) where activo;

-- Coincidencias: única tabla donde se guarda ubicación.
create table coincidencias (
  id             bigserial primary key,
  item_id        bigint not null references items_lista (id),
  lista_id       uuid not null references listas_interes (id),
  entidad_id     uuid not null references entidades (id),
  placa          placa_co not null,
  detectada_en   timestamptz not null default now(),
  latitud        numeric(9, 6),
  longitud       numeric(9, 6),
  operador_id    uuid references operadores (id),
  estado         estado_coincidencia not null default 'nuevo',
  actualizado_en timestamptz not null default now()
);
create index coincidencias_entidad_idx on coincidencias (entidad_id, detectada_en desc);

-- ---------------------------------------------------------------------------
-- Auditoría (regla 7)
-- ---------------------------------------------------------------------------

create table auditoria (
  id         bigserial primary key,
  ocurrido_en timestamptz not null default now(),
  actor      text not null default current_user,
  accion     text not null,
  entidad_id uuid,
  detalle    jsonb not null default '{}'::jsonb
);
create index auditoria_fecha_idx on auditoria (ocurrido_en);

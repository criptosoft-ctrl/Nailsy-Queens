-- =====================================================================
-- NAILSY — Esquema de base de datos · Fase 1 (App Pro, sin pagos)
-- Supabase / PostgreSQL. Ejecutar en: Supabase > SQL Editor.
-- Crear el proyecto de Supabase en una región UE (p. ej. Frankfurt o París).
-- =====================================================================

-- ---------- Tipos ----------
create type estado_cita as enum ('pendiente', 'confirmada', 'en_curso', 'completada', 'cancelada', 'no_show');
create type estado_pago as enum ('sin_pago', 'pagado', 'reembolsado', 'reembolso_parcial'); -- preparado para Fase 2
create type categoria_servicio as enum ('semipermanente', 'gel', 'acrilico', 'rusa', 'pedicura', 'retirada', 'otro');

-- ---------- Manicuristas (1:1 con auth.users) ----------
create table manicuristas (
  id              uuid primary key references auth.users(id) on delete cascade,
  nombre          text not null,
  nombre_negocio  text,
  telefono        text,
  ciudad          text,
  direccion       text,
  foto_url        text,
  bio             text,
  pais            char(2) not null default 'ES',     -- ES / CO … (para la capa de pagos por país)
  moneda          char(3) not null default 'EUR',
  fianza_importe  numeric(10,2) not null default 10, -- fianza anti no-show
  horas_cancelacion int not null default 24,
  stripe_account_id text,                            -- Fase 2
  creado_en       timestamptz not null default now()
);

-- ---------- Horario laboral y bloqueos ----------
create table horario_semanal (
  id             uuid primary key default gen_random_uuid(),
  manicurista_id uuid not null references manicuristas(id) on delete cascade,
  dia_semana     smallint not null check (dia_semana between 1 and 7), -- 1 = lunes
  hora_inicio    time not null,
  hora_fin       time not null check (hora_fin > hora_inicio)
);

create table bloqueos (            -- almuerzo, vacaciones, días libres
  id             uuid primary key default gen_random_uuid(),
  manicurista_id uuid not null references manicuristas(id) on delete cascade,
  inicio         timestamptz not null,
  fin            timestamptz not null check (fin > inicio),
  motivo         text
);

-- ---------- Tarifario: servicios base + añadidos de Nail Art ----------
create table servicios (
  id             uuid primary key default gen_random_uuid(),
  manicurista_id uuid not null references manicuristas(id) on delete cascade,
  nombre         text not null,                 -- "Manicura rusa + nivelación gel"
  categoria      categoria_servicio not null,
  duracion_min   int not null check (duracion_min > 0),
  precio         numeric(10,2) not null check (precio >= 0),
  activo         boolean not null default true,
  orden          int not null default 0
);

create table anadidos (            -- mano alzada, cristales, encapsulado…
  id             uuid primary key default gen_random_uuid(),
  manicurista_id uuid not null references manicuristas(id) on delete cascade,
  nombre         text not null,
  duracion_min   int not null default 0,
  precio         numeric(10,2) not null default 0,
  por_una        boolean not null default false, -- true = precio/tiempo por cada uña
  activo         boolean not null default true
);

-- ---------- Clientas (de la manicurista; en Fase 3 se enlazan a una cuenta) ----------
create table clientas (
  id             uuid primary key default gen_random_uuid(),
  manicurista_id uuid not null references manicuristas(id) on delete cascade,
  usuario_id     uuid references auth.users(id),  -- null si aún no tiene cuenta
  nombre         text not null,
  telefono       text,
  email          text,
  foto_url       text,
  notas          text,
  creado_en      timestamptz not null default now()
);

-- ---------- Consentimiento RGPD para datos de salud ----------
create table consentimientos (
  id             uuid primary key default gen_random_uuid(),
  clienta_id     uuid not null references clientas(id) on delete cascade,
  tipo           text not null default 'datos_salud',
  version_texto  text not null,                  -- versión del texto legal aceptado
  metodo         text not null,                  -- 'app', 'enlace_whatsapp', 'firma_tablet'
  aceptado_en    timestamptz not null default now(),
  revocado_en    timestamptz
);

-- ---------- Ficha técnica de la uña ----------
create table fichas_una (
  clienta_id     uuid primary key references clientas(id) on delete cascade,
  diagnosticos   text[] not null default '{}',   -- {'quebradiza','grasa','mordida','cuticula_seca'}
  alergias       text[] not null default '{}',   -- {'acrilatos'}  → se muestra en ROJO
  forma_deseada  text,                           -- 'almendrada', 'coffin', 'cuadrada'…
  largo_deseado  text,
  tonos_favoritos text[] not null default '{}',
  observaciones  text,
  actualizado_en timestamptz not null default now()
);

-- ---------- Citas ----------
create table citas (
  id             uuid primary key default gen_random_uuid(),
  manicurista_id uuid not null references manicuristas(id) on delete cascade,
  clienta_id     uuid not null references clientas(id) on delete restrict,
  servicio_id    uuid references servicios(id) on delete set null,
  inicio         timestamptz not null,
  fin            timestamptz not null check (fin > inicio),
  precio_total   numeric(10,2) not null,
  estado         estado_cita not null default 'confirmada',
  tono_usado     text,
  notas          text,
  -- Fase 2 (pagos)
  estado_pago    estado_pago not null default 'sin_pago',
  stripe_payment_intent_id text,
  importe_reembolsado numeric(10,2),
  creado_en      timestamptz not null default now(),
  cancelado_en   timestamptz
);

create table cita_anadidos (
  cita_id        uuid not null references citas(id) on delete cascade,
  anadido_id     uuid not null references anadidos(id) on delete restrict,
  cantidad       int not null default 1,
  primary key (cita_id, anadido_id)
);

-- Evita solapar dos citas activas de la misma manicurista
create extension if not exists btree_gist;
alter table citas add constraint citas_sin_solape
  exclude using gist (manicurista_id with =, tstzrange(inicio, fin) with &&)
  where (estado not in ('cancelada', 'no_show'));

-- ---------- Fotos (historial + portafolio público) ----------
create table fotos (
  id             uuid primary key default gen_random_uuid(),
  manicurista_id uuid not null references manicuristas(id) on delete cascade,
  cita_id        uuid references citas(id) on delete set null,
  clienta_id     uuid references clientas(id) on delete set null,
  storage_path   text not null,                  -- ruta en Supabase Storage
  tipo           text not null default 'despues' check (tipo in ('antes','despues')),
  categoria      categoria_servicio,
  publica        boolean not null default false, -- true = sale en el portafolio del marketplace
  creado_en      timestamptz not null default now()
);

-- ---------- Índices ----------
create index on citas (manicurista_id, inicio);
create index on clientas (manicurista_id, nombre);
create index on fotos (manicurista_id, publica);

-- ---------- Seguridad (RLS): cada manicurista solo ve lo suyo ----------
alter table manicuristas     enable row level security;
alter table horario_semanal  enable row level security;
alter table bloqueos         enable row level security;
alter table servicios        enable row level security;
alter table anadidos         enable row level security;
alter table clientas         enable row level security;
alter table consentimientos  enable row level security;
alter table fichas_una       enable row level security;
alter table citas            enable row level security;
alter table cita_anadidos    enable row level security;
alter table fotos            enable row level security;

create policy "propio perfil" on manicuristas
  for all using (id = auth.uid()) with check (id = auth.uid());

create policy "propio" on horario_semanal for all using (manicurista_id = auth.uid()) with check (manicurista_id = auth.uid());
create policy "propio" on bloqueos        for all using (manicurista_id = auth.uid()) with check (manicurista_id = auth.uid());
create policy "propio" on servicios       for all using (manicurista_id = auth.uid()) with check (manicurista_id = auth.uid());
create policy "propio" on anadidos        for all using (manicurista_id = auth.uid()) with check (manicurista_id = auth.uid());
create policy "propio" on clientas        for all using (manicurista_id = auth.uid()) with check (manicurista_id = auth.uid());
create policy "propio" on citas           for all using (manicurista_id = auth.uid()) with check (manicurista_id = auth.uid());
create policy "propio" on fotos           for all using (manicurista_id = auth.uid()) with check (manicurista_id = auth.uid());

create policy "via clienta" on fichas_una for all
  using (exists (select 1 from clientas c where c.id = clienta_id and c.manicurista_id = auth.uid()))
  with check (exists (select 1 from clientas c where c.id = clienta_id and c.manicurista_id = auth.uid()));

create policy "via clienta" on consentimientos for all
  using (exists (select 1 from clientas c where c.id = clienta_id and c.manicurista_id = auth.uid()))
  with check (exists (select 1 from clientas c where c.id = clienta_id and c.manicurista_id = auth.uid()));

create policy "via cita" on cita_anadidos for all
  using (exists (select 1 from citas ci where ci.id = cita_id and ci.manicurista_id = auth.uid()))
  with check (exists (select 1 from citas ci where ci.id = cita_id and ci.manicurista_id = auth.uid()));

-- La ficha de la uña solo se puede guardar si hay consentimiento vigente (RGPD)
create function exigir_consentimiento() returns trigger language plpgsql as $$
begin
  if not exists (select 1 from consentimientos
                 where clienta_id = new.clienta_id and tipo = 'datos_salud' and revocado_en is null) then
    raise exception 'La clienta no ha dado consentimiento para guardar datos de salud';
  end if;
  new.actualizado_en := now();
  return new;
end $$;

create trigger ficha_requiere_consentimiento
  before insert or update on fichas_una
  for each row execute function exigir_consentimiento();

-- ---------- Vista: resumen del día (cabecera "Ingresos de hoy / Citas") ----------
create view resumen_hoy with (security_invoker = true) as
select manicurista_id,
       count(*) filter (where estado <> 'cancelada')                    as citas_total,
       count(*) filter (where estado = 'completada')                    as citas_hechas,
       coalesce(sum(precio_total) filter (where estado = 'completada'),0) as ingresos
from citas
where inicio >= date_trunc('day', now() at time zone 'Atlantic/Canary') at time zone 'Atlantic/Canary'
  and inicio <  (date_trunc('day', now() at time zone 'Atlantic/Canary') + interval '1 day') at time zone 'Atlantic/Canary'
group by manicurista_id;

-- ---------- Alta automática: al registrarse, se crea su ficha de manicurista ----------
create function public.crear_manicurista() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.manicuristas (id, nombre)
  values (new.id, coalesce(new.raw_user_meta_data->>'nombre', split_part(new.email, '@', 1)));
  return new;
end $$;

create trigger al_registrarse
  after insert on auth.users
  for each row execute function public.crear_manicurista();

-- =====================================================================
-- NAILSY — Migración 0002 · Buscador de manicuristas y reservas de clientas
-- Ejecutar en: Supabase > SQL Editor (después de 0001_fase1.sql).
--
-- Las clientas NUNCA leen las tablas directamente: solo usan estas funciones,
-- que devuelven lo justo (perfil público, huecos libres) sin exponer agendas
-- ni datos de otras clientas.
-- =====================================================================

-- ---------- Perfil público de la manicurista ----------
alter table manicuristas
  add column if not exists publico        boolean not null default false,
  add column if not exists especialidades text[]  not null default '{}',
  add column if not exists instagram      text,
  add column if not exists lat            double precision,
  add column if not exists lng            double precision,
  add column if not exists zona_horaria   text not null default 'Atlantic/Canary';

-- ---------- Cuentas de clienta ----------
create table if not exists perfiles_clienta (
  id         uuid primary key references auth.users(id) on delete cascade,
  nombre     text not null,
  telefono   text,
  creado_en  timestamptz not null default now()
);
alter table perfiles_clienta enable row level security;
drop policy if exists "propio" on perfiles_clienta;
create policy "propio" on perfiles_clienta for all using (id = auth.uid()) with check (id = auth.uid());

-- Al registrarse: si viene de la app de clientas (rol = 'clienta') se crea su perfil de clienta;
-- si no, el de manicurista (como hasta ahora).
create or replace function public.crear_manicurista() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  v_nombre text := coalesce(nullif(new.raw_user_meta_data->>'nombre', ''), split_part(new.email, '@', 1));
begin
  if new.raw_user_meta_data->>'rol' = 'clienta' then
    insert into public.perfiles_clienta (id, nombre, telefono)
    values (new.id, v_nombre, nullif(new.raw_user_meta_data->>'telefono', ''));
  else
    insert into public.manicuristas (id, nombre) values (new.id, v_nombre);
  end if;
  return new;
end $$;

-- ---------- Portafolio: fotos en Supabase Storage ----------
insert into storage.buckets (id, name, public)
values ('portafolio', 'portafolio', true)
on conflict (id) do nothing;

drop policy if exists "portafolio subir propio" on storage.objects;
create policy "portafolio subir propio" on storage.objects for insert to authenticated
  with check (bucket_id = 'portafolio' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists "portafolio actualizar propio" on storage.objects;
create policy "portafolio actualizar propio" on storage.objects for update to authenticated
  using (bucket_id = 'portafolio' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists "portafolio borrar propio" on storage.objects;
create policy "portafolio borrar propio" on storage.objects for delete to authenticated
  using (bucket_id = 'portafolio' and (storage.foldername(name))[1] = auth.uid()::text);

-- =====================================================================
-- Funciones públicas (las llama la app de clientas)
-- =====================================================================

-- Buscar manicuristas por texto (ciudad, zona, nombre), estilo y cercanía.
create or replace function public.buscar_manicuristas(
  p_texto text default null,
  p_estilo text default null,
  p_lat double precision default null,
  p_lng double precision default null
) returns table (
  id uuid, nombre text, ciudad text, foto text, bio text, especialidades text[],
  distancia_km double precision, precio_desde numeric, fotos text[]
)
language sql stable security definer set search_path = public as $$
  select m.id,
         coalesce(nullif(m.nombre_negocio, ''), m.nombre),
         m.ciudad,
         m.foto_url,
         m.bio,
         m.especialidades,
         case when p_lat is null or p_lng is null or m.lat is null or m.lng is null then null
              else 6371 * 2 * asin(sqrt(
                     power(sin(radians(m.lat - p_lat) / 2), 2) +
                     cos(radians(p_lat)) * cos(radians(m.lat)) * power(sin(radians(m.lng - p_lng) / 2), 2)))
         end,
         (select min(s.precio) from servicios s where s.manicurista_id = m.id and s.activo),
         array(select f.storage_path from fotos f
               where f.manicurista_id = m.id and f.publica
               order by f.creado_en desc limit 6)
  from manicuristas m
  where m.publico
    and (coalesce(p_texto, '') = ''
         or m.ciudad ilike '%' || p_texto || '%'
         or m.direccion ilike '%' || p_texto || '%'
         or m.nombre_negocio ilike '%' || p_texto || '%'
         or m.nombre ilike '%' || p_texto || '%')
    and (coalesce(p_estilo, '') = ''
         or p_estilo = any (m.especialidades)
         or exists (select 1 from servicios s
                    where s.manicurista_id = m.id and s.activo and s.categoria::text = p_estilo))
  order by 7 nulls last, 2
  limit 50;
$$;

-- Perfil público completo: datos, servicios, añadidos, fotos y días que trabaja.
create or replace function public.perfil_publico(p_id uuid) returns json
language sql stable security definer set search_path = public as $$
  select json_build_object(
    'id', m.id,
    'nombre', coalesce(nullif(m.nombre_negocio, ''), m.nombre),
    'ciudad', m.ciudad,
    'direccion', m.direccion,
    'bio', m.bio,
    'foto', m.foto_url,
    'instagram', m.instagram,
    'especialidades', m.especialidades,
    'horas_cancelacion', m.horas_cancelacion,
    'servicios', (select coalesce(json_agg(json_build_object(
                    'id', s.id, 'nombre', s.nombre, 'categoria', s.categoria,
                    'duracion_min', s.duracion_min, 'precio', s.precio) order by s.orden, s.nombre), '[]'::json)
                  from servicios s where s.manicurista_id = m.id and s.activo),
    'anadidos', (select coalesce(json_agg(json_build_object(
                    'id', a.id, 'nombre', a.nombre, 'duracion_min', a.duracion_min,
                    'precio', a.precio, 'por_una', a.por_una) order by a.nombre), '[]'::json)
                 from anadidos a where a.manicurista_id = m.id and a.activo),
    'fotos', (select coalesce(json_agg(f.storage_path order by f.creado_en desc), '[]'::json)
              from fotos f where f.manicurista_id = m.id and f.publica),
    'dias_laborables', (select coalesce(json_agg(distinct h.dia_semana), '[]'::json)
                        from horario_semanal h where h.manicurista_id = m.id)
  )
  from manicuristas m
  where m.id = p_id and m.publico;
$$;

-- Huecos libres de un día para una duración dada (cada 30 min, dentro del horario,
-- sin pisar citas ni bloqueos, y con al menos 1 h de antelación).
create or replace function public.huecos_libres(p_manicurista uuid, p_dia date, p_duracion int)
returns setof timestamptz
language sql stable security definer set search_path = public as $$
  with m as (
    select zona_horaria as tz from manicuristas where id = p_manicurista and publico
  ),
  franjas as (
    select (p_dia + h.hora_inicio) at time zone m.tz as ini,
           (p_dia + h.hora_fin)    at time zone m.tz as fin
    from horario_semanal h, m
    where h.manicurista_id = p_manicurista
      and h.dia_semana = extract(isodow from p_dia)
  ),
  candidatos as (
    select generate_series(f.ini, f.fin - make_interval(mins => p_duracion), interval '30 minutes') as t
    from franjas f
    where p_duracion > 0
  )
  select c.t
  from candidatos c
  where c.t >= now() + interval '1 hour'
    and not exists (
      select 1 from citas ci
      where ci.manicurista_id = p_manicurista
        and ci.estado not in ('cancelada', 'no_show')
        and tstzrange(ci.inicio, ci.fin) && tstzrange(c.t, c.t + make_interval(mins => p_duracion)))
    and not exists (
      select 1 from bloqueos b
      where b.manicurista_id = p_manicurista
        and tstzrange(b.inicio, b.fin) && tstzrange(c.t, c.t + make_interval(mins => p_duracion)))
  order by 1;
$$;

-- Reservar (requiere sesión de clienta). Precio y duración se calculan aquí,
-- nunca se aceptan del móvil. p_anadidos: [{"id": "...", "cantidad": 3}, ...]
create or replace function public.reservar(
  p_manicurista uuid,
  p_servicio uuid,
  p_inicio timestamptz,
  p_anadidos jsonb default '[]'::jsonb,
  p_notas text default null
) returns uuid
language plpgsql security definer set search_path = public as $$
declare
  v_uid     uuid := auth.uid();
  v_tz      text;
  v_serv    servicios%rowtype;
  v_dur     int;
  v_precio  numeric(10,2);
  v_cant    int;
  v_nombre  text;
  v_tel     text;
  v_email   text;
  v_clienta uuid;
  v_cita    uuid;
  r         record;
begin
  if v_uid is null then
    raise exception 'Inicia sesión para reservar';
  end if;

  select zona_horaria into v_tz from manicuristas where id = p_manicurista and publico;
  if v_tz is null then
    raise exception 'Esta manicurista no acepta reservas ahora mismo';
  end if;

  select * into v_serv from servicios
  where id = p_servicio and manicurista_id = p_manicurista and activo;
  if not found then
    raise exception 'Ese servicio ya no está disponible';
  end if;

  v_dur := v_serv.duracion_min;
  v_precio := v_serv.precio;
  for r in
    select a.duracion_min, a.precio, a.por_una, coalesce((e->>'cantidad')::int, 1) as cantidad
    from jsonb_array_elements(coalesce(p_anadidos, '[]'::jsonb)) e
    join anadidos a on a.id = (e->>'id')::uuid and a.manicurista_id = p_manicurista and a.activo
  loop
    v_cant := greatest(0, least(r.cantidad, case when r.por_una then 20 else 1 end));
    v_dur := v_dur + r.duracion_min * v_cant;
    v_precio := v_precio + r.precio * v_cant;
  end loop;

  if not exists (
    select 1 from huecos_libres(p_manicurista, (p_inicio at time zone v_tz)::date, v_dur) h where h = p_inicio
  ) then
    raise exception 'Ese horario ya no está disponible';
  end if;

  select pc.nombre, pc.telefono into v_nombre, v_tel from perfiles_clienta pc where pc.id = v_uid;
  select u.email, coalesce(v_nombre, nullif(u.raw_user_meta_data->>'nombre', ''), split_part(u.email, '@', 1))
    into v_email, v_nombre
  from auth.users u where u.id = v_uid;

  -- La clienta aparece en la lista de clientas de esa manicurista (una sola vez).
  select c.id into v_clienta from clientas c where c.manicurista_id = p_manicurista and c.usuario_id = v_uid;
  if v_clienta is null then
    insert into clientas (manicurista_id, usuario_id, nombre, telefono, email)
    values (p_manicurista, v_uid, v_nombre, v_tel, v_email)
    returning id into v_clienta;
  end if;

  insert into citas (manicurista_id, clienta_id, servicio_id, inicio, fin, precio_total, estado, notas)
  values (p_manicurista, v_clienta, p_servicio, p_inicio, p_inicio + make_interval(mins => v_dur),
          v_precio, 'confirmada', nullif(trim(p_notas), ''))
  returning id into v_cita;

  insert into cita_anadidos (cita_id, anadido_id, cantidad)
  select v_cita, a.id, least((e->>'cantidad')::int, case when a.por_una then 20 else 1 end)
  from jsonb_array_elements(coalesce(p_anadidos, '[]'::jsonb)) e
  join anadidos a on a.id = (e->>'id')::uuid and a.manicurista_id = p_manicurista and a.activo
  where coalesce((e->>'cantidad')::int, 0) > 0;

  return v_cita;
end $$;

-- Citas de la clienta que ha iniciado sesión (en todas sus manicuristas).
create or replace function public.mis_citas() returns table (
  id uuid, inicio timestamptz, fin timestamptz, precio_total numeric, estado text,
  servicio text, manicurista_id uuid, manicurista text, direccion text, ciudad text, horas_cancelacion int
)
language sql stable security definer set search_path = public as $$
  select ci.id, ci.inicio, ci.fin, ci.precio_total, ci.estado::text,
         s.nombre, m.id, coalesce(nullif(m.nombre_negocio, ''), m.nombre), m.direccion, m.ciudad, m.horas_cancelacion
  from citas ci
  join clientas c on c.id = ci.clienta_id
  join manicuristas m on m.id = ci.manicurista_id
  left join servicios s on s.id = ci.servicio_id
  where c.usuario_id = auth.uid()
  order by ci.inicio desc
  limit 100;
$$;

-- La clienta cancela una cita suya futura.
create or replace function public.cancelar_mi_cita(p_cita uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  update citas ci set estado = 'cancelada', cancelado_en = now()
  where ci.id = p_cita
    and ci.inicio > now()
    and ci.estado in ('pendiente', 'confirmada')
    and ci.clienta_id in (select c.id from clientas c where c.usuario_id = auth.uid());
  if not found then
    raise exception 'No se puede cancelar esta cita';
  end if;
end $$;

grant execute on function public.buscar_manicuristas(text, text, double precision, double precision) to anon, authenticated;
grant execute on function public.perfil_publico(uuid) to anon, authenticated;
grant execute on function public.huecos_libres(uuid, date, int) to anon, authenticated;
grant execute on function public.reservar(uuid, uuid, timestamptz, jsonb, text) to authenticated;
grant execute on function public.mis_citas() to authenticated;
grant execute on function public.cancelar_mi_cita(uuid) to authenticated;

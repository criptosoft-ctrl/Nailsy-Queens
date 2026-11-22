-- 0008 Atención a domicilio.
-- La profesional elige si atiende en su local, a domicilio o ambas; hasta cuántos km va,
-- el suplemento (fijo o por km, lo pone ella) y el tiempo de viaje que se reserva antes y después.

alter table public.manicuristas
  add column if not exists atiende_local boolean not null default true,
  add column if not exists atiende_domicilio boolean not null default false,
  add column if not exists radio_km int not null default 10 check (radio_km between 1 and 100),
  add column if not exists suplemento_tipo text not null default 'fijo' check (suplemento_tipo in ('fijo', 'km')),
  add column if not exists suplemento_importe numeric(6,2) not null default 0 check (suplemento_importe >= 0),
  add column if not exists viaje_min int not null default 30 check (viaje_min between 0 and 120);

alter table public.citas
  add column if not exists a_domicilio boolean not null default false,
  add column if not exists direccion_cita text,
  add column if not exists lat_cita double precision,
  add column if not exists lng_cita double precision,
  add column if not exists distancia_km numeric(6,2),
  add column if not exists suplemento numeric(8,2) not null default 0,
  add column if not exists viaje_min int not null default 0 check (viaje_min between 0 and 120),
  -- Tiempo realmente ocupado: la cita más el viaje de ida y vuelta (lo rellena un trigger).
  add column if not exists ocupado_inicio timestamptz,
  add column if not exists ocupado_fin timestamptz;

create or replace function public.calcular_ocupado() returns trigger
language plpgsql set search_path = public as $$
begin
  new.ocupado_inicio := new.inicio - make_interval(mins => coalesce(new.viaje_min, 0));
  new.ocupado_fin := new.fin + make_interval(mins => coalesce(new.viaje_min, 0));
  return new;
end $$;
revoke execute on function public.calcular_ocupado() from public, anon, authenticated;

drop trigger if exists citas_ocupado on public.citas;
create trigger citas_ocupado before insert or update of inicio, fin, viaje_min on public.citas
  for each row execute function public.calcular_ocupado();

update public.citas set ocupado_inicio = inicio - make_interval(mins => viaje_min),
                        ocupado_fin = fin + make_interval(mins => viaje_min);
alter table public.citas alter column ocupado_inicio set not null, alter column ocupado_fin set not null;

-- Sin solapes contando el viaje.
alter table public.citas drop constraint if exists citas_sin_solape;
alter table public.citas add constraint citas_sin_solape
  exclude using gist (manicurista_id with =, tstzrange(ocupado_inicio, ocupado_fin) with &&)
  where (estado not in ('cancelada', 'no_show'));

-- Distancia en km entre dos puntos (haversine).
create or replace function public.distancia_km(lat1 double precision, lng1 double precision,
                                               lat2 double precision, lng2 double precision)
returns double precision language sql immutable set search_path = public as $$
  select 6371 * 2 * asin(sqrt(
    power(sin(radians(lat2 - lat1) / 2), 2) +
    cos(radians(lat1)) * cos(radians(lat2)) * power(sin(radians(lng2 - lng1) / 2), 2)));
$$;

-- Huecos libres. p_viaje: minutos de viaje que tienen que quedar libres antes y después (a domicilio).
drop function if exists public.huecos_libres(uuid, date, int);
create or replace function public.huecos_libres(p_manicurista uuid, p_dia date, p_duracion int, p_viaje int default 0)
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
        and tstzrange(ci.ocupado_inicio, ci.ocupado_fin) &&
            tstzrange(c.t - make_interval(mins => coalesce(p_viaje, 0)),
                      c.t + make_interval(mins => p_duracion + coalesce(p_viaje, 0))))
    and not exists (
      select 1 from bloqueos b
      where b.manicurista_id = p_manicurista
        and tstzrange(b.inicio, b.fin) && tstzrange(c.t, c.t + make_interval(mins => p_duracion)))
  order by 1;
$$;
grant execute on function public.huecos_libres(uuid, date, int, int) to anon, authenticated;

-- Perfil público: añade cómo atiende. Si solo va a domicilio, no se muestra su dirección.
create or replace function public.perfil_publico(p_id uuid) returns json
language sql stable security definer set search_path = public as $$
  select json_build_object(
    'id', m.id,
    'nombre', coalesce(nullif(m.nombre_negocio, ''), m.nombre),
    'ciudad', m.ciudad,
    'direccion', case when m.atiende_local then m.direccion end,
    'bio', m.bio,
    'foto', m.foto_url,
    'instagram', m.instagram,
    'especialidades', m.especialidades,
    'horas_cancelacion', m.horas_cancelacion,
    'atiende_local', m.atiende_local,
    'atiende_domicilio', m.atiende_domicilio,
    'radio_km', m.radio_km,
    'suplemento_tipo', m.suplemento_tipo,
    'suplemento_importe', m.suplemento_importe,
    'viaje_min', m.viaje_min,
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

-- Reservar: ahora también a domicilio. La distancia y el suplemento se calculan aquí,
-- nunca se aceptan del móvil.
drop function if exists public.reservar(uuid, uuid, timestamptz, jsonb, text);
create or replace function public.reservar(
  p_manicurista uuid,
  p_servicio uuid,
  p_inicio timestamptz,
  p_anadidos jsonb default '[]'::jsonb,
  p_notas text default null,
  p_domicilio boolean default false,
  p_direccion text default null,
  p_lat double precision default null,
  p_lng double precision default null
) returns uuid
language plpgsql security definer set search_path = public as $$
declare
  v_uid     uuid := auth.uid();
  v_m       manicuristas%rowtype;
  v_serv    servicios%rowtype;
  v_dur     int;
  v_precio  numeric(10,2);
  v_cant    int;
  v_nombre  text;
  v_tel     text;
  v_email   text;
  v_clienta uuid;
  v_cita    uuid;
  v_dom     boolean := coalesce(p_domicilio, false);
  v_dist    double precision;
  v_supl    numeric(8,2) := 0;
  v_viaje   int := 0;
  r         record;
begin
  if v_uid is null then
    raise exception 'Inicia sesión para reservar';
  end if;

  select * into v_m from manicuristas where id = p_manicurista and publico;
  if not found then
    raise exception 'Este perfil no acepta reservas ahora mismo';
  end if;

  if v_dom then
    if not v_m.atiende_domicilio then
      raise exception 'Este perfil no atiende a domicilio';
    end if;
    if nullif(trim(p_direccion), '') is null then
      raise exception 'Escribe tu dirección';
    end if;
    if p_lat is null or p_lng is null or v_m.lat is null or v_m.lng is null then
      raise exception 'No se pudo comprobar la distancia. Usa tu ubicación';
    end if;
    v_dist := distancia_km(v_m.lat, v_m.lng, p_lat, p_lng);
    if v_dist > v_m.radio_km then
      raise exception 'Tu dirección está fuera de su zona';
    end if;
    v_supl := case when v_m.suplemento_tipo = 'km' then round((v_m.suplemento_importe * v_dist)::numeric, 2)
                   else v_m.suplemento_importe end;
    v_viaje := v_m.viaje_min;
  elsif not v_m.atiende_local then
    raise exception 'Este perfil solo atiende a domicilio';
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
  v_precio := v_precio + v_supl;

  if not exists (
    select 1 from huecos_libres(p_manicurista, (p_inicio at time zone v_m.zona_horaria)::date, v_dur, v_viaje) h
    where h = p_inicio
  ) then
    raise exception 'Ese horario ya no está disponible';
  end if;

  select pc.nombre, pc.telefono into v_nombre, v_tel from perfiles_clienta pc where pc.id = v_uid;
  select u.email, coalesce(v_nombre, nullif(u.raw_user_meta_data->>'nombre', ''), split_part(u.email, '@', 1))
    into v_email, v_nombre
  from auth.users u where u.id = v_uid;

  select c.id into v_clienta from clientas c where c.manicurista_id = p_manicurista and c.usuario_id = v_uid;
  if v_clienta is null then
    insert into clientas (manicurista_id, usuario_id, nombre, telefono, email)
    values (p_manicurista, v_uid, v_nombre, v_tel, v_email)
    returning id into v_clienta;
  end if;

  insert into citas (manicurista_id, clienta_id, servicio_id, inicio, fin, precio_total, estado, notas,
                     a_domicilio, direccion_cita, lat_cita, lng_cita, distancia_km, suplemento, viaje_min)
  values (p_manicurista, v_clienta, p_servicio, p_inicio, p_inicio + make_interval(mins => v_dur),
          v_precio, 'confirmada', nullif(trim(p_notas), ''),
          v_dom,
          case when v_dom then trim(p_direccion) end,
          case when v_dom then p_lat end,
          case when v_dom then p_lng end,
          round(v_dist::numeric, 2), v_supl, v_viaje)
  returning id into v_cita;

  insert into cita_anadidos (cita_id, anadido_id, cantidad)
  select v_cita, a.id, least((e->>'cantidad')::int, case when a.por_una then 20 else 1 end)
  from jsonb_array_elements(coalesce(p_anadidos, '[]'::jsonb)) e
  join anadidos a on a.id = (e->>'id')::uuid and a.manicurista_id = p_manicurista and a.activo
  where coalesce((e->>'cantidad')::int, 0) > 0;

  return v_cita;
end $$;
revoke execute on function public.reservar(uuid, uuid, timestamptz, jsonb, text, boolean, text, double precision, double precision) from public, anon;
grant execute on function public.reservar(uuid, uuid, timestamptz, jsonb, text, boolean, text, double precision, double precision) to authenticated;

-- Mis citas: con la dirección de casa cuando es a domicilio.
drop function if exists public.mis_citas();
create or replace function public.mis_citas() returns table (
  id uuid, inicio timestamptz, fin timestamptz, precio_total numeric, estado text,
  servicio text, manicurista_id uuid, manicurista text, direccion text, ciudad text, horas_cancelacion int,
  a_domicilio boolean, suplemento numeric
)
language sql stable security definer set search_path = public as $$
  select ci.id, ci.inicio, ci.fin, ci.precio_total, ci.estado::text,
         s.nombre, m.id, coalesce(nullif(m.nombre_negocio, ''), m.nombre),
         case when ci.a_domicilio then ci.direccion_cita else m.direccion end,
         case when ci.a_domicilio then null else m.ciudad end,
         m.horas_cancelacion, ci.a_domicilio, ci.suplemento
  from citas ci
  join clientas c on c.id = ci.clienta_id
  join manicuristas m on m.id = ci.manicurista_id
  left join servicios s on s.id = ci.servicio_id
  where c.usuario_id = auth.uid()
  order by ci.inicio desc
  limit 100;
$$;
revoke execute on function public.mis_citas() from public, anon;
grant execute on function public.mis_citas() to authenticated;

-- Buscador: filtro "A domicilio" y datos para la etiqueta de la tarjeta.
drop function if exists public.buscar_manicuristas(text, text, double precision, double precision, boolean, text);
create or replace function public.buscar_manicuristas(
  p_texto text default null,
  p_estilo text default null,
  p_lat double precision default null,
  p_lng double precision default null,
  p_solo_hoy boolean default false,
  p_sector text default 'nails',
  p_domicilio boolean default false
) returns table (
  id uuid, nombre text, ciudad text, foto text, bio text, especialidades text[],
  distancia_km double precision, precio_desde numeric, fotos text[], proximo_hueco timestamptz,
  duracion_desde int,
  a_domicilio boolean, radio_km int, suplemento_tipo text, suplemento_importe numeric
)
language sql stable security definer set search_path = public as $$
  with base as (
    select m.*,
           (select min(s.duracion_min) from servicios s where s.manicurista_id = m.id and s.activo) as dur_min,
           (now() at time zone m.zona_horaria)::date as hoy_local
    from manicuristas m
    where m.publico
      and m.sector = coalesce(nullif(p_sector, ''), 'nails')
      and (not coalesce(p_domicilio, false) or m.atiende_domicilio)
      and (coalesce(p_texto, '') = ''
           or m.ciudad ilike '%' || p_texto || '%'
           or m.direccion ilike '%' || p_texto || '%'
           or m.nombre_negocio ilike '%' || p_texto || '%'
           or m.nombre ilike '%' || p_texto || '%')
      and (coalesce(p_estilo, '') = ''
           or p_estilo = any (m.especialidades)
           or exists (select 1 from servicios s
                      where s.manicurista_id = m.id and s.activo and s.categoria::text = p_estilo))
  ),
  con_hueco as (
    select b.*,
           (select h.t
            from generate_series(0, 13) as dd
            cross join lateral huecos_libres(b.id, b.hoy_local + dd, b.dur_min) as h(t)
            order by dd, h.t
            limit 1) as hueco
    from base b
  )
  select c.id,
         coalesce(nullif(c.nombre_negocio, ''), c.nombre),
         c.ciudad,
         c.foto_url,
         c.bio,
         c.especialidades,
         case when p_lat is null or p_lng is null or c.lat is null or c.lng is null then null
              else public.distancia_km(p_lat, p_lng, c.lat, c.lng)
         end as distancia_km,
         (select min(s.precio) from servicios s where s.manicurista_id = c.id and s.activo),
         array(select f.storage_path from fotos f
               where f.manicurista_id = c.id and f.publica
               order by f.creado_en desc limit 6),
         c.hueco,
         (select s.duracion_min::int from servicios s where s.manicurista_id = c.id and s.activo
          order by s.precio, s.duracion_min limit 1),
         c.atiende_domicilio, c.radio_km, c.suplemento_tipo, c.suplemento_importe
  from con_hueco c
  where not coalesce(p_solo_hoy, false)
     or (c.hueco is not null and (c.hueco at time zone c.zona_horaria)::date = c.hoy_local)
  order by 7 nulls last, (c.hueco is null), c.hueco, 2
  limit 50;
$$;
grant execute on function public.buscar_manicuristas(text, text, double precision, double precision, boolean, text, boolean) to anon, authenticated;

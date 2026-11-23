-- 0012 Reseñas: solo clientas con una cita finalizada pueden valorar (1 reseña por cita).
-- La profesional puede responder una vez. Nadie puede borrarlas desde la app.

create table if not exists public.resenas (
  id             uuid primary key default gen_random_uuid(),
  cita_id        uuid not null unique references public.citas(id) on delete cascade,
  manicurista_id uuid not null references public.manicuristas(id) on delete cascade,
  usuario_id     uuid not null references auth.users(id) on delete cascade,
  autor          text not null,
  estrellas      int  not null check (estrellas between 1 and 5),
  comentario     text check (char_length(comentario) <= 500),
  respuesta      text check (char_length(respuesta) <= 500),
  respondida_en  timestamptz,
  creado_en      timestamptz not null default now()
);
create index if not exists resenas_manicurista on public.resenas (manicurista_id, creado_en desc);

alter table public.resenas enable row level security;
-- La profesional ve las suyas; el resto se lee por las funciones de abajo.
drop policy if exists "propias" on public.resenas;
create policy "propias" on public.resenas for select using (manicurista_id = auth.uid());

-- "Laura Martín" -> "Laura M."
create or replace function public.nombre_corto(p text) returns text
language sql immutable set search_path = public as $$
  select case
    when coalesce(trim(p), '') = '' then 'Cliente'
    when position(' ' in trim(p)) = 0 then initcap(trim(p))
    else initcap(split_part(trim(p), ' ', 1)) || ' ' || upper(left(split_part(trim(p), ' ', 2), 1)) || '.'
  end;
$$;

-- La clienta valora una cita suya ya finalizada.
create or replace function public.valorar_cita(p_cita uuid, p_estrellas int, p_comentario text default null)
returns uuid
language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
  v_ci  citas%rowtype;
  v_nombre text;
  v_id uuid;
begin
  if v_uid is null then raise exception 'Inicia sesión para valorar'; end if;
  if p_estrellas is null or p_estrellas < 1 or p_estrellas > 5 then
    raise exception 'Elige de 1 a 5 estrellas';
  end if;
  select ci.* into v_ci from citas ci join clientas c on c.id = ci.clienta_id
  where ci.id = p_cita and c.usuario_id = v_uid;
  if not found then raise exception 'No encontramos esa cita'; end if;
  if v_ci.estado <> 'completada' then
    raise exception 'Podrás valorar cuando la cita esté finalizada';
  end if;
  if exists (select 1 from resenas where cita_id = p_cita) then
    raise exception 'Ya valoraste esta cita';
  end if;
  select coalesce(pc.nombre, nullif(u.raw_user_meta_data->>'nombre', ''), split_part(u.email, '@', 1))
    into v_nombre
  from auth.users u left join perfiles_clienta pc on pc.id = u.id where u.id = v_uid;
  insert into resenas (cita_id, manicurista_id, usuario_id, autor, estrellas, comentario)
  values (p_cita, v_ci.manicurista_id, v_uid, nombre_corto(v_nombre), p_estrellas,
          nullif(left(trim(p_comentario), 500), ''))
  returning id into v_id;
  return v_id;
end $$;
revoke execute on function public.valorar_cita(uuid, int, text) from public, anon;
grant execute on function public.valorar_cita(uuid, int, text) to authenticated;

-- Reseñas públicas de una profesional (sin datos personales).
create or replace function public.resenas_publicas(p_id uuid, p_limite int default 20)
returns table (id uuid, autor text, estrellas int, comentario text, respuesta text, creado_en timestamptz)
language sql stable security definer set search_path = public as $$
  select r.id, r.autor, r.estrellas, r.comentario, r.respuesta, r.creado_en
  from resenas r join manicuristas m on m.id = r.manicurista_id and m.publico
  where r.manicurista_id = p_id
  order by r.creado_en desc
  limit least(greatest(coalesce(p_limite, 20), 1), 100);
$$;
grant execute on function public.resenas_publicas(uuid, int) to anon, authenticated;

-- La profesional responde una vez.
create or replace function public.responder_resena(p_id uuid, p_texto text)
returns void
language plpgsql security definer set search_path = public as $$
begin
  if nullif(trim(p_texto), '') is null then raise exception 'Escribe tu respuesta'; end if;
  update resenas set respuesta = left(trim(p_texto), 500), respondida_en = now()
  where id = p_id and manicurista_id = auth.uid() and respuesta is null;
  if not found then raise exception 'Esta reseña ya tiene respuesta'; end if;
end $$;
revoke execute on function public.responder_resena(uuid, text) from public, anon;
grant execute on function public.responder_resena(uuid, text) to authenticated;

-- Mis citas: con las estrellas que puse (null si aún no la valoré).
drop function if exists public.mis_citas();
create or replace function public.mis_citas() returns table (
  id uuid, inicio timestamptz, fin timestamptz, precio_total numeric, estado text,
  servicio text, manicurista_id uuid, manicurista text, direccion text, ciudad text, horas_cancelacion int,
  a_domicilio boolean, suplemento numeric, mis_estrellas int
)
language sql stable security definer set search_path = public as $$
  select ci.id, ci.inicio, ci.fin, ci.precio_total, ci.estado::text,
         s.nombre, m.id, coalesce(nullif(m.nombre_negocio, ''), m.nombre),
         case when ci.a_domicilio then ci.direccion_cita else m.direccion end,
         case when ci.a_domicilio then null else m.ciudad end,
         m.horas_cancelacion, ci.a_domicilio, ci.suplemento,
         (select r.estrellas from resenas r where r.cita_id = ci.id)
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

-- Perfil público: nota media, número de reseñas y reparto por estrellas.
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
    'whatsapp', case when m.whatsapp_visible then nullif(trim(m.telefono), '') end,
    'nota', (select round(avg(r.estrellas)::numeric, 1) from resenas r where r.manicurista_id = m.id),
    'num_resenas', (select count(*) from resenas r where r.manicurista_id = m.id),
    'reparto', (select coalesce(json_object_agg(e, n), '{}'::json) from
                 (select r.estrellas as e, count(*) as n from resenas r where r.manicurista_id = m.id group by 1) x),
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


-- Buscador: nota y número de reseñas; orden "Mejor valoradas".
drop function if exists public.buscar_manicuristas(text, text, double precision, double precision, boolean, text, boolean, double precision);
create or replace function public.buscar_manicuristas(
  p_texto text default null,
  p_estilo text default null,
  p_lat double precision default null,
  p_lng double precision default null,
  p_solo_hoy boolean default false,
  p_sector text default 'nails',
  p_domicilio boolean default false,
  p_zona_km double precision default null,
  p_mejor_valoradas boolean default false
) returns table (
  id uuid, nombre text, ciudad text, foto text, bio text, especialidades text[],
  distancia_km double precision, precio_desde numeric, fotos text[], proximo_hueco timestamptz,
  duracion_desde int,
  a_domicilio boolean, radio_km int, suplemento_tipo text, suplemento_importe numeric,
  nota numeric, num_resenas int
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
           or m.nombre ilike '%' || p_texto || '%'
           or exists (select 1 from unnest(m.especialidades) e where e ilike '%' || p_texto || '%')
           -- Zona escrita y situada en el mapa (p_lat/p_lng): quien está cerca de ese punto
           -- o quien va a domicilio hasta allí.
           or (p_zona_km is not null and p_lat is not null and p_lng is not null
               and m.lat is not null and m.lng is not null
               and (public.distancia_km(p_lat, p_lng, m.lat, m.lng) <= p_zona_km
                    or (m.atiende_domicilio and public.distancia_km(p_lat, p_lng, m.lat, m.lng) <= m.radio_km))))
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
            limit 1) as hueco,
           (select round(avg(r.estrellas)::numeric, 1) from resenas r where r.manicurista_id = b.id) as nota,
           (select count(*)::int from resenas r where r.manicurista_id = b.id) as num_resenas
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
         c.atiende_domicilio, c.radio_km, c.suplemento_tipo, c.suplemento_importe,
         c.nota, c.num_resenas
  from con_hueco c
  where not coalesce(p_solo_hoy, false)
     or (c.hueco is not null and (c.hueco at time zone c.zona_horaria)::date = c.hoy_local)
  order by case when coalesce(p_mejor_valoradas, false) then coalesce(c.nota, 0) end desc nulls last,
           case when coalesce(p_mejor_valoradas, false) then c.num_resenas end desc nulls last,
           7 nulls last, (c.hueco is null), c.hueco, 2
  limit 50;
$$;
grant execute on function public.buscar_manicuristas(text, text, double precision, double precision, boolean, text, boolean, double precision, boolean) to anon, authenticated;

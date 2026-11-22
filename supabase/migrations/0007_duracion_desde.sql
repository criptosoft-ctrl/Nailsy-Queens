-- 0007 Tarjeta premium del buscador: añade la duración del servicio más barato ("Desde 35 € · 1 h").
drop function if exists public.buscar_manicuristas(text, text, double precision, double precision, boolean, text);

create or replace function public.buscar_manicuristas(
  p_texto text default null,
  p_estilo text default null,
  p_lat double precision default null,
  p_lng double precision default null,
  p_solo_hoy boolean default false,
  p_sector text default 'nails'
) returns table (
  id uuid, nombre text, ciudad text, foto text, bio text, especialidades text[],
  distancia_km double precision, precio_desde numeric, fotos text[], proximo_hueco timestamptz,
  duracion_desde int
)
language sql stable security definer set search_path = public as $$
  with base as (
    select m.*,
           (select min(s.duracion_min) from servicios s where s.manicurista_id = m.id and s.activo) as dur_min,
           (now() at time zone m.zona_horaria)::date as hoy_local
    from manicuristas m
    where m.publico
      and m.sector = coalesce(nullif(p_sector, ''), 'nails')
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
              else 6371 * 2 * asin(sqrt(
                     power(sin(radians(c.lat - p_lat) / 2), 2) +
                     cos(radians(p_lat)) * cos(radians(c.lat)) * power(sin(radians(c.lng - p_lng) / 2), 2)))
         end as distancia_km,
         (select min(s.precio) from servicios s where s.manicurista_id = c.id and s.activo),
         array(select f.storage_path from fotos f
               where f.manicurista_id = c.id and f.publica
               order by f.creado_en desc limit 6),
         c.hueco,
         (select s.duracion_min::int from servicios s where s.manicurista_id = c.id and s.activo
          order by s.precio, s.duracion_min limit 1)
  from con_hueco c
  where not coalesce(p_solo_hoy, false)
     or (c.hueco is not null and (c.hueco at time zone c.zona_horaria)::date = c.hoy_local)
  order by distancia_km nulls last, (c.hueco is null), c.hueco, 2
  limit 50;
$$;


grant execute on function public.buscar_manicuristas(text, text, double precision, double precision, boolean, text) to anon, authenticated;

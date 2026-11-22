-- 0010 Buscar por zona: si la clienta escribe una zona, la app la sitúa en el mapa y aquí
-- salen también las profesionales cercanas a ese punto y las que van a domicilio hasta allí.
-- El texto también busca en las especialidades que escribe cada profesional.
drop function if exists public.buscar_manicuristas(text, text, double precision, double precision, boolean, text, boolean);
create or replace function public.buscar_manicuristas(
  p_texto text default null,
  p_estilo text default null,
  p_lat double precision default null,
  p_lng double precision default null,
  p_solo_hoy boolean default false,
  p_sector text default 'nails',
  p_domicilio boolean default false,
  p_zona_km double precision default null
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
grant execute on function public.buscar_manicuristas(text, text, double precision, double precision, boolean, text, boolean, double precision) to anon, authenticated;

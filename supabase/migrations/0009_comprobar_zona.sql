-- 0009 Comprobar si una dirección está dentro de la zona a domicilio de una profesional,
-- sin enseñar a la clienta las coordenadas de la profesional.
create or replace function public.comprobar_zona(p_id uuid, p_lat double precision, p_lng double precision)
returns json
language sql stable security definer set search_path = public as $$
  select case
    when m.lat is null or m.lng is null or p_lat is null or p_lng is null then
      json_build_object('dentro', false, 'distancia_km', null, 'suplemento', null, 'radio_km', m.radio_km)
    else (
      select json_build_object(
        'dentro', d.km <= m.radio_km,
        'distancia_km', round(d.km::numeric, 1),
        'suplemento', case when m.suplemento_tipo = 'km' then round((m.suplemento_importe * d.km)::numeric, 2)
                           else m.suplemento_importe end,
        'radio_km', m.radio_km)
      from (select distancia_km(m.lat, m.lng, p_lat, p_lng) as km) d)
  end
  from manicuristas m
  where m.id = p_id and m.publico and m.atiende_domicilio;
$$;
grant execute on function public.comprobar_zona(uuid, double precision, double precision) to anon, authenticated;

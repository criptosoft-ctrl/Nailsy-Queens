-- 0011 Botón de WhatsApp: cada profesional decide si su teléfono se muestra para que le escriban.
alter table public.manicuristas
  add column if not exists whatsapp_visible boolean not null default false;

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

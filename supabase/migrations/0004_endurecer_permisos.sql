-- NAILSY — Migración 0004 · Permisos más estrictos (recomendación del asesor de seguridad de Supabase)
-- Funciones internas: nadie debe llamarlas desde la API (los triggers siguen funcionando)
revoke execute on function public.crear_manicurista() from public, anon, authenticated;
revoke execute on function public.exigir_consentimiento() from public, anon, authenticated;
alter function public.exigir_consentimiento() set search_path = public;

-- Funciones que requieren sesión: fuera del rol anónimo
revoke execute on function public.reservar(uuid, uuid, timestamptz, jsonb, text) from public, anon;
revoke execute on function public.mis_citas() from public, anon;
revoke execute on function public.cancelar_mi_cita(uuid) from public, anon;
grant execute on function public.reservar(uuid, uuid, timestamptz, jsonb, text) to authenticated;
grant execute on function public.mis_citas() to authenticated;
grant execute on function public.cancelar_mi_cita(uuid) to authenticated;

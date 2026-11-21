-- 0006 Barbershop: categorías de servicio de barbería.
-- La ficha del cliente de barbería se guarda en fichas_una con otros significados:
--   diagnosticos = pelo y piel · forma_deseada = corte habitual · largo_deseado = barba ·
--   tonos_favoritos = números de máquina. Así reutiliza la seguridad (RLS) y el consentimiento.
alter type categoria_servicio add value if not exists 'degradado';
alter type categoria_servicio add value if not exists 'clasico';
alter type categoria_servicio add value if not exists 'barba';
alter type categoria_servicio add value if not exists 'afeitado';
alter type categoria_servicio add value if not exists 'disenos';
alter type categoria_servicio add value if not exists 'ninos';

comment on table public.fichas_una is
  'Ficha técnica del cliente. Uñas: diagnósticos, forma, largo, tonos. Barbería: pelo y piel, corte habitual, barba, números de máquina.';

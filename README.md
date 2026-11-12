# Nailsy Queens

Plataforma 100% especializada en manicura: **App Pro** para la manicurista (agenda, fichas de la uña, portafolio, cobros) y, más adelante, **App Clienta** (descubrimiento y reservas).

## Estructura

| Carpeta | Qué hay |
|---|---|
| `app_pro/` | App Flutter de la manicurista (iOS + Android) |
| `supabase/migrations/` | Base de datos (PostgreSQL en Supabase) |
| `.github/workflows/` | Compilación automática: análisis, tests y APK de Android |

## Estado — Fase 1 (uso propio)

- [x] Modelo de datos: manicuristas, horario, tarifario (servicios + añadidos de Nail Art), clientas, ficha de la uña con consentimiento RGPD, citas sin solapes, fotos
- [x] Inicio de sesión / registro
- [x] Agenda diaria con resumen de ingresos, bloqueos (almuerzo) y cambio de estado de citas
- [ ] Crear y editar citas
- [ ] Clientas y ficha de la uña
- [ ] Tarifario y calculador de tiempos
- [ ] Portafolio con cámara

## Puesta en marcha

### 1. Base de datos
1. Crea un proyecto en [supabase.com](https://supabase.com) en una **región de la UE**.
2. *SQL Editor* → pega `supabase/migrations/0001_fase1.sql` → **Run**.
3. *Project Settings → API*: copia la **URL** y la **anon key**.

### 2. Conectar la app con Supabase
En GitHub: *Settings → Secrets and variables → Actions → New repository secret*:
- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`

Sin estos secretos la app se compila en **modo demo** (datos de ejemplo, sin login).

### 3. Probar en Android
Cada push compila la app. En la pestaña **Actions** → última ejecución → *Artifacts* → `nailsy-pro-apk`. Descarga el `.apk` en el móvil Android e instálalo.

### Desarrollo local (opcional)
```bash
cd app_pro
flutter pub get
flutter run --dart-define=SUPABASE_URL=https://xxxx.supabase.co --dart-define=SUPABASE_ANON_KEY=eyJ...
```

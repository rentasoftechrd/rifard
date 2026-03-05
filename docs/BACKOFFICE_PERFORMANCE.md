# Carga rápida del Backoffice (Flutter Web)

Resumen de lo que se hizo para que la app cargue más rápido y cómo sacarle partido al construir para producción.

## Optimizaciones aplicadas

### 1. Carga diferida de pantallas (deferred loading)

Solo se carga al inicio el código necesario para la **pantalla de login**. El resto de pantallas (Dashboard, Usuarios, Personas, Loterías, etc.) se descargan cuando el usuario navega a esa ruta.

- **En desarrollo** (`flutter run -d chrome`): no hay splitting; todo va en un solo bundle. La diferencia se nota sobre todo en **producción**.
- **En producción** (`flutter build web`): se generan chunks separados (`main.dart.js`, `dashboard_screen.dart.js`, etc.). La primera carga descarga menos JavaScript.

### 2. Cache del token de auth

El token se lee una vez del almacenamiento seguro y se guarda en memoria. Así las comprobaciones de “¿está logueado?” no vuelven a leer disco/storage en cada rebuild del router.

## Cómo construir para producción (carga más rápida)

Desde la raíz del monorepo:

```bash
cd apps/backoffice
flutter build web --release --dart-define=API_URL=https://tu-api.com
```

- `--release` (por defecto en `flutter build web`): minimiza y tree-shake; los imports diferidos se dividen en archivos aparte.
- Sustituye `https://tu-api.com` por la URL real de tu API.

Para probar en local un build similar a producción:

```bash
flutter run -d chrome --release
```

## Otras recomendaciones

- **Servir con compresión (gzip/brotli)** en el servidor para los `.js` y `.wasm`; reduce mucho el tiempo de descarga.
- **Cache de assets**: que el servidor envíe cabeceras de cache largas para los chunks (p. ej. `main.dart.js`, `*_part.js`) y versionado en la URL si usas despliegues frecuentes.
- **Backend**: si el arranque sigue siendo lento, revisar que el primer request (p. ej. `/auth/me` o `/health`) sea ligero y que la API esté cerca (misma región) del usuario.

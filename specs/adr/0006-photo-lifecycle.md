# ADR-0006: Limpieza de fotos y caras huérfanas

## Estado
Aceptado

## Contexto
Las fotos de cámara quedaban en el directorio temporal y `face_verification` podía conservar IDs sin persona (legacy o por fallos entre el registro facial y la escritura en SQLite).

## Decisión
- Borrar toda foto capturada tras su uso:
  - escaneo: tras verificar o al terminar el freeze;
  - registro: al guardar, repetir fotos o salir.
- Al iniciar, `CleanupService`:
  - compara IDs de `face_verification` con `persons` y borra caras sin persona;
  - borra imágenes (`jpg`, `jpeg`, `png`) del directorio temporal.
- El arranque ejecuta `FaceService.init()` → apertura de DB → `CleanupService.run()`.

## Consecuencias
- En el primer arranque tras migrar a v2 se borran todas las caras legacy; hay que re-registrar.
- No quedan IDs ni fotos huérfanas tras reiniciar.
- La limpieza es idempotente y se reintenta en cada arranque si falla.

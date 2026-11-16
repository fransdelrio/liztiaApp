# Feature: Registration

## Objetivo
Registrar nueva persona con 3 fotos.

## Flujo
1. Desde "No match" → botón "Registrar" → register_screen
2. Capturar foto 1/3, 2/3, 3/3; validar que haya exactamente un rostro
3. Solicitar nombre y apellido
4. Guardar → `registerFromImagePath()` ×3
5. Guardar `persons` + `history` en una transacción
6. Borrar las 3 fotos y volver
7. Al volver, pantalla blanca con `"Registro Exitoso!"` + nombre/apellido + ✅ durante 3 s
8. Después de los 3 s, restaurar la cámara con `"Escanear"` y `"Volver"`

## Reglas
- Exactamente 3 fotos obligatorias
- Mostrar contador (1/3, 2/3, 3/3)
- Repetir una foto rechazada sin avanzar el contador
- Si falla el registro facial o la DB, borrar las caras registradas del intento
- Insertar en historial con nombre/apellido snapshot
- Borrar fotos al guardar, repetir o salir
- El éxito se muestra en `scan_screen`, no con SnackBar ni en `register_screen`
- La pantalla de éxito no se puede interrumpir con botones (solo el Atrás del sistema)

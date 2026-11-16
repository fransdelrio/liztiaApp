# Feature: Face Scan

## Objetivo
Identificar persona mediante cámara.

## Flujo
1. Home → botón "Iniciar" → scan_screen
2. Cámara activa + botón "Escanear" + botón "Volver" abajo
3. Llamar `verifyFromImagePath()`
4. Si devuelve ID → resolver en `persons`
5. Si existe persona → insertar historial (snapshot) y mostrar nombre + apellido + ✅ durante 3 s, ocultando los botones `"Escanear"` y `"Volver"` para evitar solapes con nombres largos
6. Si no hay match o el ID no existe en `persons` → mostrar "No ha sido posible identificar" + "Escanear" (reintentar) + "Registrar"

## Reglas
- El botón "Escanear" rehabilita el escaneo tras un no-match.
- Botón "Volver" siempre visible.
- En match exitoso SOLO mostrar nombre + apellido + ícono.
- Sin persona asociada: no insertar historial.
- Insertar historial SIEMPRE en match exitoso.
- Borrar la foto del escaneo tras verificar o al terminar el freeze.

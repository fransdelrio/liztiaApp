# Feature: History

## Objetivo
Guardar y consultar el historial de escaneos y registros.

## UI
- Pantalla `history_screen.dart` con filtro por fecha.
- Navegación día anterior/siguiente y selector de fecha.

## Esquema
Ver `data-model.md`.

## Reglas
- Insertar SIEMPRE en match exitoso
- Insertar SIEMPRE en registro nuevo
- No insertar si no hay persona asociada
- `nombre`/`apellido` son snapshot del momento
- Formato `timestamp` `YYYYMMDDhhmmss`
- Formato `fecha` `YYYY-MM-DD`

# Data Model

## Person (SQLite)
Tabla `persons`
- `id`: INTEGER PRIMARY KEY (mismo ID que `face_verification`, epoch ms)
- `nombre`: TEXT NOT NULL
- `apellido`: TEXT NOT NULL

## History (SQLite)
Tabla `history`
- `id`: INTEGER PRIMARY KEY AUTOINCREMENT
- `fecha`: TEXT NOT NULL (YYYY-MM-DD)
- `persona_id`: INTEGER NOT NULL
- `apellido`: TEXT NOT NULL
- `nombre`: TEXT NOT NULL
- `timestamp`: TEXT NOT NULL (YYYYMMDDhhmmss)

`nombre` y `apellido` son un snapshot del momento del escaneo/registro.

## Relación
`history.persona_id` referencia lógicamente a `persons.id`. Sin FK.

## Reglas
- DB versión 1 (`_dbVersion = 1`).
- Sin migraciones: esquema inicial = `persons` + `history` + `idx_history_fecha`. Un cambio de esquema se aplica reinstalando (desarrollo).
- Registro: insertar `persons` + `history` en una transacción.
- Match: resolver `persona_id` en `persons`; si no existe, no hay match ni historial.
- Al iniciar: borrar caras cuyo ID no exista en `persons`.
- Las fotos capturadas se borran tras su uso y al iniciar.
- `timestamp` y `fecha` deben generarse con formato exacto.

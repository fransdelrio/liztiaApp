# ADR-0005: Tabla `persons` como fuente de identidad

## Estado
Aceptado

## Contexto
`face_verification` devuelve solo el ID en la verificación. El nombre/apellido se resolvía consultando el historial, lo que dejaba casos con datos vacíos y no había una entidad de persona.

## Decisión
- Crear la tabla `persons (id INTEGER PRIMARY KEY, nombre, apellido)` en SQLite v2.
- Usar el mismo ID de `face_verification` (epoch ms) como clave.
- Guardar `persons` + `history` en una transacción al registrar.
- En escaneo, resolver el ID con `getPersonById`; sin persona no hay match.
- Mantener `history.nombre/apellido` como snapshot.

## Consecuencias
- El nombre/apellido ya no se infiere del historial.
- La migración v1→v2 elimina el historial legacy y no hace backfill.
- Se habilita un futuro CRUD de personas.
- La consistencia depende del código, no de FK.

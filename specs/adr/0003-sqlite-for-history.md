# ADR-0003: SQLite para historial

## Estado
Aceptado

## Contexto
Necesitamos persistir historial localmente.

## Decisión
Usar `sqflite` + `path`.

## Consecuencias
- Datos persisten entre sesiones
- Consultas locales rápidas
- Sin servidor necesario

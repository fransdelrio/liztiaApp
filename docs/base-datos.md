# Base de datos (SQLite)

## 1. Objetivo y alcance

Este documento describe la capa de persistencia local de la app **liztia**: esquema SQL exacto, ciclo de vida del esquema, API pública de `DatabaseService`, formatos de fecha e invariantes de negocio.

**Qué NO cubre este documento:**

- El modelo de datos conceptual (entidades, relaciones y decisiones de alto nivel) ya está definido en [`specs/data-model.md`](../specs/data-model.md). Este doc lo enlaza y añade el detalle de implementación, sin duplicarlo.
- La justificación de usar SQLite está en [ADR-0003: SQLite para historial](../specs/adr/0003-sqlite-for-history.md).
- La decisión de crear la tabla `persons` como fuente de identidad está en [ADR-0005: Tabla persons](../specs/adr/0005-persons-table.md).
- La limpieza de caras y fotos temporales es responsabilidad de `CleanupService` (`lib/services/cleanup_service.dart`), no de la base de datos.

Fuente única de código: [`lib/services/database_service.dart`](../lib/services/database_service.dart), [`lib/models/person.dart`](../lib/models/person.dart), [`lib/models/history_record.dart`](../lib/models/history_record.dart), [`lib/utils/date_formats.dart`](../lib/utils/date_formats.dart).

## 2. Esquema de tablas

### 2.1 Tabla `persons`

Definida en `_createPersons` de `lib/services/database_service.dart`:

```sql
CREATE TABLE IF NOT EXISTS persons (
  id INTEGER PRIMARY KEY,
  nombre TEXT NOT NULL,
  apellido TEXT NOT NULL
)
```

| Columna | Tipo | Nulabilidad | Descripción |
| :-- | :-- | :-- | :-- |
| `id` | INTEGER | NOT NULL | PK. Mismo ID que `face_verification` (epoch ms), según `specs/data-model.md`. |
| `nombre` | TEXT | NOT NULL | Nombre de la persona. |
| `apellido` | TEXT | NOT NULL | Apellido de la persona. |

### 2.2 Tabla `history`

Definida en `_createHistory` de `lib/services/database_service.dart`:

```sql
CREATE TABLE IF NOT EXISTS history (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  fecha TEXT NOT NULL,
  persona_id INTEGER NOT NULL,
  apellido TEXT NOT NULL,
  nombre TEXT NOT NULL,
  timestamp TEXT NOT NULL
)
```

| Columna | Tipo | Nulabilidad | Descripción |
| :-- | :-- | :-- | :-- |
| `id` | INTEGER | NOT NULL | PK autoincremental. En `HistoryRecord` (`lib/models/history_record.dart`) el campo es `int?` porque lo genera SQLite. |
| `fecha` | TEXT | NOT NULL | Día del escaneo/registro, formato `YYYY-MM-DD`. |
| `persona_id` | INTEGER | NOT NULL | ID de la persona identificada/registrada. Referencia lógica a `persons.id`, sin FK. |
| `apellido` | TEXT | NOT NULL | Snapshot del apellido en el momento del escaneo/registro. |
| `nombre` | TEXT | NOT NULL | Snapshot del nombre en el momento del escaneo/registro. |
| `timestamp` | TEXT | NOT NULL | Momento exacto, formato `YYYYMMDDhhmmss`. |

### 2.3 Índice

```sql
CREATE INDEX IF NOT EXISTS idx_history_fecha ON history(fecha)
```

Se crea junto a la tabla `history` en `_createHistory` y acelera el filtro por fecha que usa `getHistoryByDate` (y la pantalla `lib/screens/history_screen.dart`).

## 3. Ciclo de vida del esquema

Constantes en `lib/services/database_service.dart`:

| Constante | Valor | Uso |
| :-- | :-- | :-- |
| `_dbName` | `'liztia.db'` | Fichero en el directorio de bases de datos estándar (`getDatabasesPath()` + `join`). |
| `_dbVersion` | `1` | Versión actual del esquema (única, sin migraciones). |

Apertura: el getter `database` abre la BD solo la primera vez (`openDatabase` con `version: _dbVersion`, `onCreate: _createDB`). El método `open()` (`DatabaseService.open()`) fuerza la apertura de forma temprana para que el esquema se cree al arrancar; lo invoca `SplashScreen` en `lib/screens/splash_screen.dart:47`, justo después de `FaceService.init()` y antes de `CleanupService.run()`.

### 3.1 Esquema inicial (`onCreate`)

En una instalación nueva (sin BD previa), `_createDB` ejecuta `_createPersons` y luego `_createHistory`, que crean la tabla `persons`, la tabla `history` y el índice `idx_history_fecha`, todos con `IF NOT EXISTS`.

### 3.2 Sin migraciones

No hay versiones en producción, por lo que el esquema no migra: no existe `onUpgrade` en `lib/services/database_service.dart`. Un cambio de esquema se aplica reinstalando la app o borrando sus datos en desarrollo. Añadir `onUpgrade` o incrementar `_dbVersion` requiere autorización explícita del responsable.

**Nota de desarrollo:** si un dispositivo conservara una BD con `user_version = 2` (de una instalación anterior), la apertura con versión 1 falla porque sqflite rechaza el downgrade; se resuelve desinstalando la app o borrando sus datos. No es una migración, es limpieza de entorno de desarrollo.

## 4. API pública de `DatabaseService`

Clase singleton (`DatabaseService.instance`, constructor privado `_init()`). Todas las resoluciones de BD pasan por el getter `database`, que reutiliza una única conexión (`_database`).

| Método | Firma resumida | Qué hace | Notas |
| :-- | :-- | :-- | :-- |
| `open` | `Future<Database> open()` | Fuerza la apertura de la BD (dispara `onCreate` si procede). | Llamado al inicio de la app desde el splash. |
| `getPersonById` | `Future<Person?> getPersonById(int id)` | Busca la persona por `id` (`limit: 1`). | Devuelve `null` si no existe: base de la regla "sin persona no hay match". |
| `getAllPersonIds` | `Future<Set<int>> getAllPersonIds()` | Devuelve el conjunto de todos los `id` de `persons`. | Usado por `CleanupService` para detectar caras huérfanas. |
| `saveRegistration` | `Future<void> saveRegistration({required Person person, required HistoryRecord history})` | Inserta persona + historial de forma **atómica** dentro de `db.transaction`. | Garantiza que no quede historial sin persona (ni viceversa) en un registro nuevo. |
| `insertHistory` | `Future<int> insertHistory(HistoryRecord record)` | Inserta una fila en `history` con `record.toMap()`. | Se usa tras un match exitoso con persona resuelta. |
| `getHistoryByDate` | `Future<List<HistoryRecord>> getHistoryByDate(String fecha)` | Filtra por `fecha = ?` (parámetro de la vista previa), ordenado por `timestamp DESC`. | Se apoya en el índice `idx_history_fecha`. `fecha` debe venir en `YYYY-MM-DD`. |

Métodos privados (no forman parte de la API pública, se listan por trazabilidad): `_initDB`, `_createDB`, `_createPersons`, `_createHistory`.

## 5. Formatos y ordenación

Los formatos se generan en `lib/utils/date_formats.dart` (clase `DateFormats`, constructor privado, todos métodos estáticos):

| Método | Formato | Entrada → salida | Consumidores |
| :-- | :-- | :-- | :-- |
| `DateFormats.fecha` | `YYYY-MM-DD` | `DateTime` → `String` | Columna `history.fecha`; filtro de historial. |
| `DateFormats.timestamp` | `YYYYMMDDhhmmss` | `DateTime` → `String` | Columna `history.timestamp`; base del orden. |
| `DateFormats.displayDate` | `dd/MM/yyyy` | `DateTime` → `String` | Presentación en UI (historial). |
| `DateFormats.displayTimestamp` | `dd/MM/yyyy - HH:mm:ss` | `String` de 14 chars → `String` | Presentación en UI; si la longitud no es 14, devuelve la cadena original tal cual. |

Rellenado con ceros a la izquierda (`padLeft`) para todos los componentes; `timestamp` de 14 dígitos ordena lexicográficamente de forma equivalente al orden cronológico, por lo que `ORDER BY timestamp DESC` devuelve primero lo más reciente. `getHistoryByDate` usa `orderBy: 'timestamp DESC'`.

## 6. Invariantes y reglas de negocio

Estas reglas viven en el código y la UI (NO hay claves foráneas ni triggers en SQLite):

1. **Referencia lógica sin FK:** `history.persona_id` apunta a `persons.id` por convención; la integridad la garantiza el código, no el motor (`specs/adr/0005-persons-table.md`, "Consecuencias").
2. **Snapshot de nombre/apellido:** `history.nombre` y `history.apellido` se congelan en el momento del escaneo/registro; cambiar el nombre de una persona en el futuro no alteraría el historial ya guardado.
3. **Sin historial si no hay persona:** el flujo de escaneo (`lib/screens/scan_screen.dart`) solo inserta historial cuando `getPersonById` resuelve la persona. Identificación fallida o ID sin persona ⇒ no hay inserción en `history`.
4. **Registro atómico:** un registro nuevo siempre escribe `persons` + `history` en la misma transacción (`saveRegistration`), evitando huérfanos de cualquier tipo.
5. **Columnas NOT NULL:** en el esquema real, `persona_id`, `nombre`, `apellido`, `fecha` y `timestamp` son `NOT NULL`; una fila de historial sin snapshot de identidad no es representable.
6. **Consistencia personas ↔ caras:** la limpieza de caras sin persona correspondiente la hace `CleanupService` al arrancar, fuera de este documento (ver `lib/services/cleanup_service.dart`).

## 7. Pendiente

Sin discrepancias abiertas entre `AGENTS.md`, `specs/data-model.md` y el código real.

- Histórico: este documento describió una migración v1 → v2 (`_onUpgrade`) que ya no existe en el código; fue eliminada al fijar `_dbVersion = 1` sin migraciones.
- Histórico: `specs/data-model.md` no marcaba `NOT NULL` en las columnas de `history`; ya coincide con el esquema real.

---
name: Analizar logs de Flutter
description: Estructura y clasifica logs de error de Flutter, salidas de `flutter analyze` y stack traces de Dart para aislar la causa raíz antes de proponer un fix. Úsalo cuando el reporte de error sea largo, mezcle varios fallos o venga como stack trace crudo.
---

# Analizar logs de Flutter

## Cuándo usar
- Hay un log de `flutter analyze`, un error de compilación o una excepción en runtime.
- El log es largo o mezcla varios errores y hace falta priorizar.
- El stack trace es difícil de leer y hay que ubicar el origen real.

## Procedimiento
1. Clasificar el problema: compilación, linter o excepción runtime.
2. Ordenar por severidad y agrupar por `archivo:línea`.
3. Si falta el log, ejecutar `flutter analyze` en la raíz del proyecto (pedir permiso antes).
4. Distinguir causa raíz de síntomas secundarios: los errores en cascada del linter suelen
   depender de uno o dos fallos reales.
5. Proponer el parche mínimo por síntoma, indicando `archivo:línea` y el diff exacto.
6. No modificar archivos sin confirmación del humano.

## Helper opcional
`scripts/analyze.py` normaliza un log pegado por stdin y devuelve JSON con
`exit_code`, `stdout`, `stderr` y `summary` (errores y warnings agrupados).
Si no recibe entrada, ejecuta `flutter analyze` en el directorio actual.

```sh
# log pegado
python scripts/analyze.py < log.txt

# ejecutar el linter del proyecto
python scripts/analyze.py
```

Para analizar otro directorio, pasalo como primer argumento:

```sh
python scripts/analyze.py ../otra-app
```

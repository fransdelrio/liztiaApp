# Acceptance Criteria - Face Scan

- [ ] Home muestra título + botones "Iniciar" e "Historial"
- [ ] Scan muestra cámara, botón "Escanear", botón "Volver" abajo
- [ ] Al escanear con match y persona existente: muestra nombre + apellido + ✅ durante 3 s sin botones `"Escanear"`/`"Volver"`
- [ ] Al escanear sin match: muestra mensaje + botones "Escanear" y "Registrar"
- [ ] Si `verify()` devuelve un ID sin fila en `persons`: no-match, sin historial
- [ ] "Registrar" navega a registro
- [ ] Match exitoso inserta historial con nombre/apellido snapshot
- [ ] La foto del escaneo se borra tras el resultado

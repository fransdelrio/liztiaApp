# Acceptance Criteria - Registration

- [ ] Muestra contador de fotos 1/3, 2/3, 3/3
- [ ] Requiere 3 fotos y un solo rostro por foto
- [ ] Solicita nombre y apellido
- [ ] Guarda usando `registerFromImagePath()` 3 veces
- [ ] Guarda `persons` + `history` de forma atómica
- [ ] Si falla el registro, borra las caras del intento
- [ ] Borra las fotos temporales al guardar, repetir o salir
- [ ] Al volver, muestra pantalla blanca `"Registro Exitoso!"` + nombre/apellido + ✅
- [ ] La pantalla de éxito dura 3 s y luego restaura cámara con `"Escanear"` y `"Volver"`
- [ ] No se muestra ningún SnackBar de registro

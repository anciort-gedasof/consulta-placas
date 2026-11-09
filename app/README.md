# App del operador (Flutter)

Estado: esqueleto. Tiene validación de placa, lectura de texto OCR,
modelo de la respuesta del backend, servicio de datos de prueba y las
pantallas de captura y resultado.

## Primer arranque

Este repositorio trae solo `lib/` y `test/`. Para generar las carpetas
de plataforma (Android) una sola vez:

```bash
cd app
flutter create --platforms=android --org co.gedasof .
flutter pub get
flutter test
flutter run
```

## Módulos pendientes (en orden)

1. Cámara + ML Kit: lectura de placa con `extraerPlacaDeTexto`.
2. Cliente Supabase: implementación real de `ServicioConsulta`.
3. Plan B: abrir consulta oficial y registrar fechas.
4. Registro de cliente con autorización de datos y envío por WhatsApp.
5. Inicio de sesión con rol (operador comercial o agente de autoridad).
6. Modo operativo: el operador elige el operativo activo; las consultas
   envían `p_operativo`.
7. Vista del agente: coincidencias de su operativo
   (`coincidencias_para_agente`) con la advertencia de verificar en
   sistemas oficiales, y registro de actuación (`registrar_actuacion`).

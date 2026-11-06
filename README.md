# Consulta de placas

App para consultar por placa el estado del SOAT y de la revisión
técnico-mecánica, con alertas de vencimiento y cruce con listas de
interés de entidades.

- `backend/` — base de datos PostgreSQL, reglas de vencimiento y consulta.
- `app/` — app Flutter del operador.
- `panel/` — panel web (próxima fase).
- `docs/` — especificación.

Instrucciones de desarrollo: ver `CLAUDE.md`.

## Probar el backend

Requiere PostgreSQL 16 instalado.

```bash
cd backend
./tests/run_tests.sh
```

## Probar la app

Requiere Flutter.

```bash
cd app
flutter pub get
flutter test
flutter run
```

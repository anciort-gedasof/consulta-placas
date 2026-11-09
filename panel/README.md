# Panel web

Next.js 15 + PostgreSQL. Dos perfiles:

- **Entidad:** registro de consultas positivas por radicado (filtros,
  indicadores, tiempo hasta la actuación), detalle con bitácora y registro
  de seguimiento, carga de su lista por CSV (solo datos mínimos), retiro
  de placas y exportación del registro en CSV.
- **Agente de autoridad:** avisos de su operativo en curso con el detalle
  de la medida, advertencia de verificar en sistemas oficiales, registro
  de actuación. Se actualiza solo cada 15 segundos.

Cada entidad ve solo lo suyo (regla 3): todas las consultas se filtran
por la entidad de la sesión y las funciones de la base validan al agente.

## Correr en local

```bash
# 1. Base de datos de demostración (puerto 54330)
../backend/dev_db.sh start

# 2. Panel
npm install
npm run dev        # http://localhost:3000
```

Variables (opcionales en local):

- `DATABASE_URL` (por defecto `postgresql://postgres@localhost:54330/postgres`)
- `SESSION_SECRET` (obligatoria en producción)

## Pendiente antes de datos reales

- **Inicio de sesión real** (usuario y clave por persona). Hoy el acceso
  es un selector de perfiles de demostración.
- Usuario de base de datos con permisos mínimos para el panel (sin
  `delete` ni `truncate`).
- Despliegue con HTTPS.

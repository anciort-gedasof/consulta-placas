import { Pool, type QueryResultRow } from "pg";

// Una sola conexión compartida por el servidor.
const globalParaPool = globalThis as unknown as { pool?: Pool };

export const pool =
  globalParaPool.pool ??
  new Pool({
    connectionString:
      process.env.DATABASE_URL ?? "postgresql://postgres@localhost:54330/postgres",
    max: 5,
  });

if (process.env.NODE_ENV !== "production") globalParaPool.pool = pool;

export async function consulta<T extends QueryResultRow>(sql: string, params: unknown[] = []) {
  const r = await pool.query<T>(sql, params);
  return r.rows;
}

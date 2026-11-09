import { consulta } from "@/lib/db";
import { leerSesion } from "@/lib/sesion";

export const dynamic = "force-dynamic";

// Exporta el registro de consultas positivas de la entidad, con su bitácora.
// Regla 3: solo lo de la entidad de la sesión.
export async function GET() {
  const sesion = await leerSesion();
  if (!sesion || sesion.tipo !== "entidad") return new Response("No autorizado", { status: 401 });

  const filas = await consulta<Record<string, unknown>>(
    `select r.radicado, r.placa,
            to_char(r.detectada_en at time zone 'America/Bogota', 'YYYY-MM-DD HH24:MI') as detectada,
            r.tipo_medida, r.referencia_proceso, r.operativo_lugar, r.operador, r.agente,
            r.agente_identificacion, r.latitud, r.longitud, r.estado, r.actuacion,
            to_char(r.actuacion_en at time zone 'America/Bogota', 'YYYY-MM-DD HH24:MI') as actuacion_en,
            round(extract(epoch from r.tiempo_hasta_actuacion) / 60) as minutos_hasta_actuacion,
            (select string_agg(
                to_char(b.ocurrido_en at time zone 'America/Bogota', 'YYYY-MM-DD HH24:MI') || ' ' ||
                b.accion || ' (' || b.actor || ')' || coalesce(': ' || b.observacion, ''),
                ' | ' order by b.ocurrido_en, b.id)
               from bitacora_coincidencias b where b.coincidencia_id = r.coincidencia_id) as bitacora
       from registro_positivos r
      where r.entidad_id = $1
      order by r.detectada_en`,
    [sesion.id]);

  const columnas = [
    "radicado", "placa", "detectada", "tipo_medida", "referencia_proceso", "operativo_lugar",
    "operador", "agente", "agente_identificacion", "latitud", "longitud", "estado", "actuacion",
    "actuacion_en", "minutos_hasta_actuacion", "bitacora",
  ];
  const celda = (v: unknown) => {
    const s = v == null ? "" : String(v);
    // Evita fórmulas al abrir en Excel y escapa comillas.
    const seguro = /^[=+\-@]/.test(s) ? `'${s}` : s;
    return `"${seguro.replace(/"/g, '""')}"`;
  };
  const csv = [columnas.join(","), ...filas.map((f) => columnas.map((c) => celda(f[c])).join(","))].join("\r\n");
  const hoy = new Date().toISOString().slice(0, 10);

  return new Response("﻿" + csv, {
    headers: {
      "Content-Type": "text/csv; charset=utf-8",
      "Content-Disposition": `attachment; filename="registro-positivos-${hoy}.csv"`,
      "Cache-Control": "no-store",
    },
  });
}

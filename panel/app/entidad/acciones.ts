"use server";

import { redirect } from "next/navigation";
import { revalidatePath } from "next/cache";
import { consulta, pool } from "@/lib/db";
import { exigirEntidad } from "@/lib/sesion";

const ESTADOS = ["nuevo", "en_gestion", "cerrado"];

export async function registrarSeguimiento(formData: FormData) {
  const sesion = await exigirEntidad();
  const radicado = String(formData.get("radicado") ?? "");
  const actor = String(formData.get("actor") ?? "").trim();
  const estadoCrudo = String(formData.get("estado") ?? "");
  const estado = ESTADOS.includes(estadoCrudo) ? estadoCrudo : null;
  const observacion = String(formData.get("observacion") ?? "").trim() || null;
  const volver = `/entidad/${encodeURIComponent(radicado)}`;

  // Regla 3: la coincidencia debe ser de esta entidad.
  const [c] = await consulta<{ id: string }>(
    "select id from coincidencias where radicado = $1 and entidad_id = $2", [radicado, sesion.id]);
  if (!c) redirect("/entidad");

  if (!actor) redirect(`${volver}?error=${encodeURIComponent("Indique quién registra.")}`);
  if (!estado && !observacion) {
    redirect(`${volver}?error=${encodeURIComponent("Indique un nuevo estado o una observación.")}`);
  }

  await consulta("select registrar_seguimiento($1, $2, $3::estado_coincidencia, $4)",
    [c.id, `${actor} · ${sesion.nombre}`, estado, observacion]);

  revalidatePath("/entidad");
  redirect(`${volver}?ok=1`);
}

// ---------------------------------------------------------------------------
// Carga de la lista por CSV: placa,tipo_medida,referencia_proceso,fecha_medida
// Solo datos mínimos (regla 5). Columnas adicionales se rechazan.
// ---------------------------------------------------------------------------

const PLACA = /^([A-Z]{3}[0-9]{3}|[A-Z]{3}[0-9]{2}[A-Z])$/;
const FECHA = /^\d{4}-\d{2}-\d{2}$/;
const COLUMNAS = ["placa", "tipo_medida", "referencia_proceso", "fecha_medida"];

export type ResultadoCarga = { cargadas: number; rechazadas: { linea: number; motivo: string }[] } | { error: string };

export async function cargarLista(_previo: ResultadoCarga | null, formData: FormData): Promise<ResultadoCarga> {
  const sesion = await exigirEntidad();
  const listaId = String(formData.get("lista") ?? "");
  const archivo = formData.get("archivo");

  const [lista] = await consulta<{ id: string }>(
    "select id from listas_interes where id = $1 and entidad_id = $2 and activa", [listaId, sesion.id]);
  if (!lista) return { error: "Lista no válida." };
  if (!(archivo instanceof File) || archivo.size === 0) return { error: "Adjunte un archivo CSV." };
  if (archivo.size > 5_000_000) return { error: "El archivo supera 5 MB." };

  const lineas = (await archivo.text()).replace(/^﻿/, "").split(/\r?\n/).filter((l) => l.trim());
  if (lineas.length < 2) return { error: "El archivo no tiene filas." };

  const sep = lineas[0].includes(";") ? ";" : ",";
  const encabezado = lineas[0].split(sep).map((c) => c.trim().toLowerCase());
  const extras = encabezado.filter((c) => !COLUMNAS.includes(c));
  if (extras.length) {
    return { error: `Columnas no permitidas: ${extras.join(", ")}. Solo se aceptan datos mínimos: ${COLUMNAS.join(", ")}.` };
  }
  if (!encabezado.includes("placa") || !encabezado.includes("tipo_medida")) {
    return { error: "El encabezado debe incluir al menos placa y tipo_medida." };
  }
  const col = (fila: string[], nombre: string) => {
    const i = encabezado.indexOf(nombre);
    return i >= 0 ? (fila[i] ?? "").trim() : "";
  };

  const rechazadas: { linea: number; motivo: string }[] = [];
  const validas: [string, string, string | null, string | null][] = [];
  lineas.slice(1).forEach((l, i) => {
    const f = l.split(sep);
    const placa = col(f, "placa").toUpperCase().replace(/[^A-Z0-9]/g, "");
    const medida = col(f, "tipo_medida");
    const ref = col(f, "referencia_proceso") || null;
    const fecha = col(f, "fecha_medida") || null;
    if (!PLACA.test(placa)) return void rechazadas.push({ linea: i + 2, motivo: `Placa no válida: ${placa || "(vacía)"}` });
    if (!medida) return void rechazadas.push({ linea: i + 2, motivo: "Falta tipo_medida" });
    if (fecha && !FECHA.test(fecha)) return void rechazadas.push({ linea: i + 2, motivo: "fecha_medida debe ser AAAA-MM-DD" });
    validas.push([placa, medida, ref, fecha]);
  });

  const cliente = await pool.connect();
  try {
    await cliente.query("begin");
    for (const [placa, medida, ref, fecha] of validas) {
      await cliente.query(
        `insert into items_lista (lista_id, placa, tipo_medida, referencia_proceso, fecha_medida)
         values ($1, $2, $3, $4, $5)
         on conflict (lista_id, placa) do update
           set tipo_medida = excluded.tipo_medida,
               referencia_proceso = excluded.referencia_proceso,
               fecha_medida = excluded.fecha_medida,
               activo = true`,
        [lista.id, placa, medida, ref, fecha]);
    }
    await cliente.query("commit");
  } catch {
    await cliente.query("rollback");
    return { error: "No se pudo cargar el archivo. No se guardó ninguna fila." };
  } finally {
    cliente.release();
  }

  revalidatePath("/entidad/lista");
  return { cargadas: validas.length, rechazadas };
}

// Retirar una placa: deja de generar avisos de inmediato. Queda en auditoría.
export async function retirarPlaca(formData: FormData) {
  const sesion = await exigirEntidad();
  const itemId = String(formData.get("item") ?? "");
  await consulta(
    `update items_lista i set activo = false
       from listas_interes l
      where i.id = $1 and l.id = i.lista_id and l.entidad_id = $2`,
    [itemId, sesion.id]);
  revalidatePath("/entidad/lista");
}

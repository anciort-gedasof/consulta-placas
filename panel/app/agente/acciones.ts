"use server";

import { redirect } from "next/navigation";
import { consulta } from "@/lib/db";
import { exigirAgente } from "@/lib/sesion";

const RESULTADOS = ["abordado", "medida_ejecutada", "no_detenido", "sin_actuacion"];

export async function registrarActuacion(formData: FormData) {
  const sesion = await exigirAgente();
  const coincidencia = String(formData.get("coincidencia") ?? "");
  const operativo = String(formData.get("operativo") ?? "");
  const resultado = String(formData.get("resultado") ?? "");
  const observacion = String(formData.get("observacion") ?? "").trim() || null;
  const volver = `/agente?operativo=${encodeURIComponent(operativo)}`;

  if (!RESULTADOS.includes(resultado)) redirect(`${volver}&error=${encodeURIComponent("Seleccione un resultado.")}`);

  try {
    // La función verifica que la coincidencia esté asignada a este agente.
    await consulta("select registrar_actuacion($1, $2, $3::resultado_actuacion, $4)",
      [sesion.id, coincidencia, resultado, observacion]);
  } catch {
    redirect(`${volver}&error=${encodeURIComponent("No se pudo registrar la actuación.")}`);
  }
  redirect(`${volver}&ok=1`);
}

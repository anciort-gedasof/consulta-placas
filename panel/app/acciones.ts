"use server";

import { redirect } from "next/navigation";
import { consulta } from "@/lib/db";
import { cerrarSesion, guardarSesion } from "@/lib/sesion";

// Entrar como entidad o agente (solo demostración). Se verifica contra la
// base que la entidad o el agente existan y estén activos.
export async function entrar(formData: FormData) {
  const valor = String(formData.get("perfil") ?? "");
  const [tipo, id] = valor.split(":");

  if (tipo === "entidad") {
    const [e] = await consulta<{ nombre: string }>(
      "select nombre from entidades where id = $1 and activa", [id]);
    if (!e) redirect("/?error=1");
    await guardarSesion({ tipo: "entidad", id, nombre: e.nombre });
    redirect("/entidad");
  }

  if (tipo === "agente") {
    const [a] = await consulta<{ nombre: string }>(
      "select nombre from operadores where id = $1 and activo and rol = 'agente_autoridad'", [id]);
    if (!a) redirect("/?error=1");
    await guardarSesion({ tipo: "agente", id, nombre: a.nombre });
    redirect("/agente");
  }

  redirect("/?error=1");
}

export async function salir() {
  await cerrarSesion();
  redirect("/");
}

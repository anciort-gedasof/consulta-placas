import "server-only";
import { createHmac, timingSafeEqual } from "node:crypto";
import { cookies } from "next/headers";
import { redirect } from "next/navigation";

// SESIÓN DE DEMOSTRACIÓN.
// Permite entrar como una entidad o como un agente para mostrar el panel.
// Antes de usar datos reales debe reemplazarse por inicio de sesión con
// usuario y clave (Supabase Auth u otro). La cookie va firmada para que
// nadie la cambie a mano y entre como otra entidad (regla 3).

export type Sesion =
  | { tipo: "entidad"; id: string; nombre: string }
  | { tipo: "agente"; id: string; nombre: string };

const NOMBRE = "sesion_panel";
const SECRETO = process.env.SESSION_SECRET ?? "solo-para-desarrollo-cambiar-en-produccion";

function firmar(valor: string) {
  return createHmac("sha256", SECRETO).update(valor).digest("base64url");
}

export async function guardarSesion(s: Sesion) {
  const valor = Buffer.from(JSON.stringify(s)).toString("base64url");
  (await cookies()).set(NOMBRE, `${valor}.${firmar(valor)}`, {
    httpOnly: true,
    sameSite: "lax",
    secure: process.env.NODE_ENV === "production",
    path: "/",
    maxAge: 60 * 60 * 8,
  });
}

export async function cerrarSesion() {
  (await cookies()).delete(NOMBRE);
}

export async function leerSesion(): Promise<Sesion | null> {
  const crudo = (await cookies()).get(NOMBRE)?.value;
  if (!crudo) return null;
  const [valor, firma] = crudo.split(".");
  if (!valor || !firma) return null;
  const esperada = Buffer.from(firmar(valor));
  const recibida = Buffer.from(firma);
  if (esperada.length !== recibida.length || !timingSafeEqual(esperada, recibida)) return null;
  try {
    return JSON.parse(Buffer.from(valor, "base64url").toString()) as Sesion;
  } catch {
    return null;
  }
}

export async function exigirEntidad() {
  const s = await leerSesion();
  if (!s || s.tipo !== "entidad") redirect("/");
  return s;
}

export async function exigirAgente() {
  const s = await leerSesion();
  if (!s || s.tipo !== "agente") redirect("/");
  return s;
}

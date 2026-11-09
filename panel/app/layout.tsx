import type { Metadata } from "next";
import Link from "next/link";
import "./globals.css";
import { leerSesion } from "@/lib/sesion";
import { salir } from "./acciones";

export const metadata: Metadata = {
  title: "Panel de consulta de placas",
  description: "Panel de entidades y agentes: coincidencias, seguimiento y registro de control.",
};

export default async function Layout({ children }: { children: React.ReactNode }) {
  const sesion = await leerSesion();
  return (
    <html lang="es">
      <body>
        <header className="barra">
          <div className="contenido">
            <div className="marca">
              <Link href="/" style={{ textDecoration: "none" }}>Panel de consulta de placas</Link>
              <span className="etiqueta-demo">Demostración · datos ficticios</span>
            </div>
            {sesion && (
              <form action={salir} className="fila">
                <span>{sesion.tipo === "entidad" ? "Entidad" : "Agente"}: {sesion.nombre}</span>
                <button type="submit" className="secundario-btn" style={{ color: "var(--marino-texto)", borderColor: "var(--marino-texto)" }}>
                  Salir
                </button>
              </form>
            )}
          </div>
        </header>
        <main className="contenido">{children}</main>
      </body>
    </html>
  );
}

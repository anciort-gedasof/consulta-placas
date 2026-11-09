import Link from "next/link";
import { consulta } from "@/lib/db";
import { exigirEntidad } from "@/lib/sesion";
import { retirarPlaca } from "../acciones";
import CargaLista from "./CargaLista";

export const dynamic = "force-dynamic";

export default async function MiLista() {
  const sesion = await exigirEntidad();
  const listas = await consulta<{ id: string; nombre: string; finalidad: string; vigente_hasta: string | null }>(
    `select id, nombre, finalidad, vigente_hasta from listas_interes
      where entidad_id = $1 and activa order by nombre`, [sesion.id]);
  const items = await consulta<{
    id: string; lista: string; placa: string; tipo_medida: string;
    referencia_proceso: string | null; fecha_medida: string | null;
  }>(
    `select i.id, l.nombre as lista, i.placa, i.tipo_medida, i.referencia_proceso,
            to_char(i.fecha_medida, 'YYYY-MM-DD') as fecha_medida
       from items_lista i join listas_interes l on l.id = i.lista_id
      where l.entidad_id = $1 and i.activo
      order by i.cargado_en desc limit 500`, [sesion.id]);

  return (
    <div className="pila">
      <Link href="/entidad">← Volver al registro</Link>
      <h1>Mi lista de vehículos</h1>

      <div className="dos-columnas">
        <section className="tarjeta pila" style={{ gap: 12 }}>
          <h2>Cargar o actualizar desde CSV</h2>
          <p className="secundario">
            Solo datos mínimos. Columnas permitidas: <code>placa, tipo_medida, referencia_proceso, fecha_medida</code>.
            No incluya nombres, cédulas, direcciones ni teléfonos.
          </p>
          <CargaLista listas={listas.map((l) => ({ id: l.id, nombre: l.nombre }))} />
        </section>
        <section className="tarjeta pila" style={{ gap: 8 }}>
          <h2>Listas activas</h2>
          {listas.map((l) => (
            <div key={l.id}>
              <strong>{l.nombre}</strong>
              <div className="secundario">{l.finalidad}</div>
              <div className="secundario">Vigente hasta: {l.vigente_hasta ? new Date(l.vigente_hasta).toLocaleDateString("es-CO") : "sin fecha"}</div>
            </div>
          ))}
        </section>
      </div>

      <section className="tarjeta pila" style={{ gap: 12 }}>
        <h2>Placas activas ({items.length})</h2>
        <p className="secundario">Al retirar una placa deja de generar avisos de inmediato. El retiro queda en la auditoría.</p>
        <div className="tabla-caja">
          <table>
            <thead><tr><th>Placa</th><th>Medida</th><th>Proceso</th><th>Fecha de la medida</th><th>Lista</th><th></th></tr></thead>
            <tbody>
              {items.map((i) => (
                <tr key={i.id}>
                  <td><span className="placa">{i.placa}</span></td>
                  <td>{i.tipo_medida}</td>
                  <td>{i.referencia_proceso ?? "—"}</td>
                  <td>{i.fecha_medida ?? "—"}</td>
                  <td className="secundario">{i.lista}</td>
                  <td>
                    <form action={retirarPlaca}>
                      <input type="hidden" name="item" value={i.id} />
                      <button type="submit" className="secundario-btn">Retirar</button>
                    </form>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>
    </div>
  );
}

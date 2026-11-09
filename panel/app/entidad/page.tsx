import Link from "next/link";
import { consulta } from "@/lib/db";
import { exigirEntidad } from "@/lib/sesion";
import { ETIQUETA_ACTUACION, ETIQUETA_ESTADO, fechaHora } from "@/lib/formato";

export const dynamic = "force-dynamic";

type Fila = {
  radicado: string; placa: string; detectada_en: string; tipo_medida: string;
  referencia_proceso: string | null; operativo_lugar: string | null; agente: string | null;
  estado: string; actuacion: string | null; acciones_registradas: string;
};

const FILTROS = [
  { valor: "", texto: "Todas" },
  { valor: "nuevo", texto: "Nuevas" },
  { valor: "en_gestion", texto: "En gestión" },
  { valor: "cerrado", texto: "Cerradas" },
];

export default async function PanelEntidad({ searchParams }: { searchParams: Promise<{ estado?: string }> }) {
  const sesion = await exigirEntidad();
  const { estado = "" } = await searchParams;
  const filtro = FILTROS.some((f) => f.valor === estado) ? estado : "";

  // Regla 3: todo filtrado por la entidad de la sesión.
  const [k] = await consulta<{
    placas: string; nuevas: string; gestion: string; cerradas: string; promedio_min: string | null;
  }>(
    `select
       (select count(*) from items_lista i join listas_interes l on l.id = i.lista_id
         where l.entidad_id = $1 and i.activo and l.activa) as placas,
       count(*) filter (where estado = 'nuevo')      as nuevas,
       count(*) filter (where estado = 'en_gestion') as gestion,
       count(*) filter (where estado = 'cerrado')    as cerradas,
       round(avg(extract(epoch from tiempo_hasta_actuacion) / 60)) as promedio_min
     from registro_positivos where entidad_id = $1`,
    [sesion.id]);

  const filas = await consulta<Fila>(
    `select radicado, placa, detectada_en, tipo_medida, referencia_proceso, operativo_lugar,
            agente, estado, actuacion, acciones_registradas
       from registro_positivos
      where entidad_id = $1 and ($2 = '' or estado::text = $2)
      order by detectada_en desc
      limit 200`,
    [sesion.id, filtro]);

  return (
    <div className="pila">
      <div className="fila" style={{ justifyContent: "space-between" }}>
        <h1>{sesion.nombre}</h1>
        <div className="fila">
          <Link className="boton secundario-btn" href="/entidad/lista">Mi lista de vehículos</Link>
          <a className="boton" href="/entidad/exportar">Exportar registro (CSV)</a>
        </div>
      </div>

      <section className="kpis">
        <div className="tarjeta kpi"><div className="titulo">Placas activas en la lista</div><div className="valor">{k.placas}</div></div>
        <div className="tarjeta kpi"><div className="titulo">Coincidencias nuevas</div><div className="valor">{k.nuevas}</div></div>
        <div className="tarjeta kpi"><div className="titulo">En gestión</div><div className="valor">{k.gestion}</div></div>
        <div className="tarjeta kpi"><div className="titulo">Cerradas</div><div className="valor">{k.cerradas}</div></div>
        <div className="tarjeta kpi">
          <div className="titulo">Tiempo promedio hasta la actuación</div>
          <div className="valor">{k.promedio_min ? `${k.promedio_min} min` : "—"}</div>
        </div>
      </section>

      <section className="tarjeta pila" style={{ gap: 12 }}>
        <div className="fila" style={{ justifyContent: "space-between" }}>
          <h2>Registro de consultas positivas</h2>
          <nav className="fila filtros" aria-label="Filtrar por estado">
            {FILTROS.map((f) => (
              <Link key={f.valor} href={f.valor ? `/entidad?estado=${f.valor}` : "/entidad"}
                    className={filtro === f.valor ? "activo" : ""}>{f.texto}</Link>
            ))}
          </nav>
        </div>
        <p className="secundario">
          Registro permanente: cada detección tiene radicado y no se puede modificar ni borrar.
          Las acciones posteriores se agregan a su bitácora.
        </p>
        <div className="tabla-caja">
          <table>
            <thead>
              <tr>
                <th>Radicado</th><th>Placa</th><th>Detectada</th><th>Medida / proceso</th>
                <th>Operativo</th><th>Estado</th><th>Actuación</th><th>Acciones</th>
              </tr>
            </thead>
            <tbody>
              {filas.length === 0 && (
                <tr><td colSpan={8} className="secundario">No hay coincidencias con este filtro.</td></tr>
              )}
              {filas.map((f) => (
                <tr key={f.radicado}>
                  <td><Link href={`/entidad/${f.radicado}`}>{f.radicado}</Link></td>
                  <td><span className="placa">{f.placa}</span></td>
                  <td>{fechaHora(f.detectada_en)}</td>
                  <td>{f.tipo_medida}<div className="secundario">{f.referencia_proceso ?? "—"}</div></td>
                  <td>{f.operativo_lugar ?? <span className="secundario">Lectura comercial</span>}
                    {f.agente && <div className="secundario">Agente: {f.agente}</div>}</td>
                  <td><span className={`estado estado-${f.estado}`}>{ETIQUETA_ESTADO[f.estado]}</span></td>
                  <td>{f.actuacion ? ETIQUETA_ACTUACION[f.actuacion] : <span className="secundario">—</span>}</td>
                  <td>{f.acciones_registradas}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>
    </div>
  );
}

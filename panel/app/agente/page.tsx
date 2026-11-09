import { consulta } from "@/lib/db";
import { exigirAgente } from "@/lib/sesion";
import { ETIQUETA_ACTUACION, fechaHora } from "@/lib/formato";
import { registrarActuacion } from "./acciones";
import Refrescar from "./Refrescar";

export const dynamic = "force-dynamic";

type Coincidencia = {
  coincidencia_id: string; placa: string; detectada_en: string; entidad: string;
  tipo_medida: string; referencia_proceso: string | null; actuacion: string | null; advertencia: string;
};

export default async function PanelAgente({
  searchParams,
}: { searchParams: Promise<{ operativo?: string; error?: string; ok?: string }> }) {
  const sesion = await exigirAgente();
  const { operativo: pedido, error, ok } = await searchParams;

  const operativos = await consulta<{ id: string; lugar: string; soporte: string; inicio: string; fin: string | null }>(
    `select id, lugar, soporte, inicio, fin from operativos
      where agente_responsable = $1 and inicio <= now() and (fin is null or fin > now())
      order by inicio desc`, [sesion.id]);

  const operativo = operativos.find((o) => o.id === pedido) ?? operativos[0];

  if (!operativo) {
    return (
      <div className="pila">
        <h1>Operativo</h1>
        <p className="tarjeta">No tiene operativos en curso a su cargo.</p>
      </div>
    );
  }

  // La función de la base verifica que sea el agente responsable y deja auditoría.
  const coincidencias = await consulta<Coincidencia>(
    "select * from coincidencias_para_agente($1, $2)", [sesion.id, operativo.id]);
  const pendientes = coincidencias.filter((c) => !c.actuacion);

  return (
    <div className="pila">
      <Refrescar segundos={15} />
      <div className="fila" style={{ justifyContent: "space-between" }}>
        <div>
          <h1>Operativo en curso</h1>
          <div className="secundario">{operativo.lugar} · {operativo.soporte} · desde {fechaHora(operativo.inicio)}</div>
        </div>
        <div className="tarjeta kpi">
          <div className="titulo">Pendientes de actuación</div>
          <div className="valor">{pendientes.length}</div>
        </div>
      </div>

      <p className="advertencia">
        <strong>Antes de cualquier medida verifique en los sistemas oficiales</strong> (RUNT, SIMIT, expediente).
        Estos avisos son un indicio a partir de la lista de la entidad.
      </p>
      {error && <p className="error">{error}</p>}
      {ok && <p className="ok">Actuación registrada.</p>}

      {coincidencias.length === 0 && <p className="tarjeta">Aún no hay avisos en este operativo. La página se actualiza sola.</p>}

      {coincidencias.map((c) => (
        <section key={c.coincidencia_id} className="tarjeta pila" style={{ gap: 12 }}>
          <div className="fila" style={{ justifyContent: "space-between" }}>
            <div className="fila">
              <span className="placa" style={{ fontSize: 20 }}>{c.placa}</span>
              <span className="secundario">{fechaHora(c.detectada_en)}</span>
            </div>
            {c.actuacion && <span className="estado estado-cerrado">{ETIQUETA_ACTUACION[c.actuacion]}</span>}
          </div>
          <dl className="datos">
            <dt>Entidad</dt><dd>{c.entidad}</dd>
            <dt>Medida</dt><dd>{c.tipo_medida}</dd>
            <dt>Proceso</dt><dd>{c.referencia_proceso ?? "—"}</dd>
          </dl>
          <form action={registrarActuacion} className="formulario">
            <input type="hidden" name="coincidencia" value={c.coincidencia_id} />
            <input type="hidden" name="operativo" value={operativo.id} />
            <div className="dos-columnas" style={{ gap: 12 }}>
              <label>
                Resultado
                <select name="resultado" required defaultValue="">
                  <option value="" disabled>Seleccione…</option>
                  <option value="abordado">Abordado</option>
                  <option value="medida_ejecutada">Medida ejecutada</option>
                  <option value="no_detenido">No detenido</option>
                  <option value="sin_actuacion">Sin actuación</option>
                </select>
              </label>
              <label>
                Observación
                <input name="observacion" maxLength={500} placeholder="Opcional" />
              </label>
            </div>
            <button type="submit">{c.actuacion ? "Registrar nueva actuación" : "Registrar actuación"}</button>
          </form>
        </section>
      ))}
    </div>
  );
}

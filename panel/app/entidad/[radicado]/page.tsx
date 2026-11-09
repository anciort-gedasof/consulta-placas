import Link from "next/link";
import { notFound } from "next/navigation";
import { consulta } from "@/lib/db";
import { exigirEntidad } from "@/lib/sesion";
import { ETIQUETA_ACCION, ETIQUETA_ACTUACION, ETIQUETA_ESTADO, duracion, fechaHora } from "@/lib/formato";
import { registrarSeguimiento } from "../acciones";

export const dynamic = "force-dynamic";

type Detalle = {
  coincidencia_id: string; radicado: string; placa: string; detectada_en: string;
  tipo_medida: string; referencia_proceso: string | null; operativo_lugar: string | null;
  operador: string | null; agente: string | null; agente_identificacion: string | null;
  latitud: string | null; longitud: string | null; estado: string; actuacion: string | null;
  tiempo_hasta_actuacion: unknown;
};

type Entrada = {
  id: string; ocurrido_en: string; actor: string; accion: string;
  estado: string | null; actuacion: string | null; observacion: string | null;
};

export default async function DetalleCoincidencia({
  params, searchParams,
}: { params: Promise<{ radicado: string }>; searchParams: Promise<{ error?: string; ok?: string }> }) {
  const sesion = await exigirEntidad();
  const { radicado } = await params;
  const { error, ok } = await searchParams;

  // Regla 3: solo si la coincidencia es de la entidad de la sesión.
  const [d] = await consulta<Detalle>(
    "select * from registro_positivos where radicado = $1 and entidad_id = $2",
    [radicado, sesion.id]);
  if (!d) notFound();

  const bitacora = await consulta<Entrada>(
    `select id, ocurrido_en, actor, accion, estado, actuacion, observacion
       from bitacora_coincidencias where coincidencia_id = $1 order by ocurrido_en, id`,
    [d.coincidencia_id]);

  const mapa = d.latitud && d.longitud
    ? `https://www.openstreetmap.org/?mlat=${d.latitud}&mlon=${d.longitud}#map=17/${d.latitud}/${d.longitud}`
    : null;

  return (
    <div className="pila">
      <Link href="/entidad">← Volver al registro</Link>
      <div className="fila">
        <h1>{d.radicado}</h1>
        <span className="placa">{d.placa}</span>
        <span className={`estado estado-${d.estado}`}>{ETIQUETA_ESTADO[d.estado]}</span>
      </div>

      <div className="dos-columnas">
        <section className="tarjeta pila" style={{ gap: 12 }}>
          <h2>Detección</h2>
          <p className="secundario">Datos inalterables.</p>
          <dl className="datos">
            <dt>Fecha y hora</dt><dd>{fechaHora(d.detectada_en)}</dd>
            <dt>Medida</dt><dd>{d.tipo_medida}</dd>
            <dt>Proceso</dt><dd>{d.referencia_proceso ?? "—"}</dd>
            <dt>Origen</dt><dd>{d.operativo_lugar ? `Operativo: ${d.operativo_lugar}` : "Lectura comercial"}</dd>
            <dt>Operador</dt><dd>{d.operador ?? "—"}</dd>
            <dt>Agente</dt><dd>{d.agente ? `${d.agente} (${d.agente_identificacion})` : "—"}</dd>
            <dt>Ubicación</dt>
            <dd>{mapa ? <a href={mapa} target="_blank" rel="noreferrer">{d.latitud}, {d.longitud} (ver mapa)</a> : "—"}</dd>
            <dt>Actuación</dt><dd>{d.actuacion ? ETIQUETA_ACTUACION[d.actuacion] : "—"}</dd>
            <dt>Tiempo hasta actuar</dt><dd>{duracion(d.tiempo_hasta_actuacion)}</dd>
          </dl>
        </section>

        <section className="tarjeta pila" style={{ gap: 12 }}>
          <h2>Registrar seguimiento</h2>
          {error && <p className="error">{error}</p>}
          {ok && <p className="ok">Seguimiento registrado en la bitácora.</p>}
          <form action={registrarSeguimiento} className="formulario">
            <input type="hidden" name="radicado" value={d.radicado} />
            <label>
              Funcionario que registra
              <input name="actor" required maxLength={120} placeholder="Nombre y cargo" />
            </label>
            <label>
              Nuevo estado (opcional)
              <select name="estado" defaultValue="">
                <option value="">Sin cambio</option>
                <option value="nuevo">Nuevo</option>
                <option value="en_gestion">En gestión</option>
                <option value="cerrado">Cerrado</option>
              </select>
            </label>
            <label>
              Observación
              <textarea name="observacion" maxLength={1000} placeholder="Qué se hizo o se decidió" />
            </label>
            <button type="submit">Agregar a la bitácora</button>
          </form>
        </section>
      </div>

      <section className="tarjeta pila" style={{ gap: 12 }}>
        <h2>Bitácora</h2>
        <p className="secundario">Cada acción se agrega; ninguna se borra ni se reescribe.</p>
        <ol className="bitacora">
          {bitacora.map((b) => (
            <li key={b.id}>
              <strong>{ETIQUETA_ACCION[b.accion] ?? b.accion}</strong>
              {b.actuacion && <> · {ETIQUETA_ACTUACION[b.actuacion]}</>}
              {b.accion === "cambio_estado" && b.estado && <> · {ETIQUETA_ESTADO[b.estado]}</>}
              <div className="secundario">{fechaHora(b.ocurrido_en)} · {b.actor}</div>
              {b.observacion && <div>{b.observacion}</div>}
            </li>
          ))}
        </ol>
      </section>
    </div>
  );
}

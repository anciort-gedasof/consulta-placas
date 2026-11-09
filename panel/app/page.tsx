import { consulta } from "@/lib/db";
import { entrar } from "./acciones";

export const dynamic = "force-dynamic";

export default async function Inicio({ searchParams }: { searchParams: Promise<{ error?: string }> }) {
  const { error } = await searchParams;
  const entidades = await consulta<{ id: string; nombre: string }>(
    "select id, nombre from entidades where activa order by nombre");
  const agentes = await consulta<{ id: string; nombre: string; entidad: string; identificacion_oficial: string }>(
    `select o.id, o.nombre, e.nombre as entidad, o.identificacion_oficial
       from operadores o join entidades e on e.id = o.entidad_id
      where o.activo and o.rol = 'agente_autoridad' order by o.nombre`);

  return (
    <div className="pila" style={{ maxWidth: 560, margin: "0 auto" }}>
      <h1>Entrar</h1>
      <p className="advertencia">
        Acceso de demostración: elija un perfil para ver el panel. Antes de usar datos reales se
        reemplaza por inicio de sesión con usuario y clave.
      </p>
      {error && <p className="error">No se pudo entrar con ese perfil.</p>}
      <form action={entrar} className="tarjeta formulario">
        <label>
          Perfil
          <select name="perfil" required defaultValue="">
            <option value="" disabled>Seleccione…</option>
            <optgroup label="Entidades">
              {entidades.map((e) => (
                <option key={e.id} value={`entidad:${e.id}`}>{e.nombre}</option>
              ))}
            </optgroup>
            <optgroup label="Agentes de autoridad">
              {agentes.map((a) => (
                <option key={a.id} value={`agente:${a.id}`}>
                  {a.nombre} · {a.identificacion_oficial} · {a.entidad}
                </option>
              ))}
            </optgroup>
          </select>
        </label>
        <button type="submit">Entrar</button>
      </form>
    </div>
  );
}

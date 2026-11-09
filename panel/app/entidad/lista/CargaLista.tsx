"use client";

import { useActionState } from "react";
import { cargarLista, type ResultadoCarga } from "../acciones";

export default function CargaLista({ listas }: { listas: { id: string; nombre: string }[] }) {
  const [resultado, accion, enviando] = useActionState<ResultadoCarga | null, FormData>(cargarLista, null);

  return (
    <form action={accion} className="formulario">
      <label>
        Lista
        <select name="lista" required>
          {listas.map((l) => <option key={l.id} value={l.id}>{l.nombre}</option>)}
        </select>
      </label>
      <label>
        Archivo CSV
        <input type="file" name="archivo" accept=".csv,text/csv" required />
      </label>
      <button type="submit" disabled={enviando}>{enviando ? "Cargando…" : "Cargar"}</button>

      {resultado && "error" in resultado && <p className="error">{resultado.error}</p>}
      {resultado && "cargadas" in resultado && (
        <div className={resultado.rechazadas.length ? "advertencia" : "ok"}>
          <strong>{resultado.cargadas} placas cargadas o actualizadas.</strong>
          {resultado.rechazadas.length > 0 && (
            <>
              <div>{resultado.rechazadas.length} filas rechazadas:</div>
              <ul>
                {resultado.rechazadas.slice(0, 20).map((r) => (
                  <li key={r.linea}>Línea {r.linea}: {r.motivo}</li>
                ))}
              </ul>
            </>
          )}
        </div>
      )}
    </form>
  );
}

const zona = "America/Bogota";

export function fechaHora(d: Date | string | null | undefined) {
  if (!d) return "—";
  return new Intl.DateTimeFormat("es-CO", {
    dateStyle: "medium",
    timeStyle: "short",
    timeZone: zona,
  }).format(new Date(d));
}

export const ETIQUETA_ESTADO: Record<string, string> = {
  nuevo: "Nuevo",
  en_gestion: "En gestión",
  cerrado: "Cerrado",
};

export const ETIQUETA_ACTUACION: Record<string, string> = {
  abordado: "Abordado",
  medida_ejecutada: "Medida ejecutada",
  no_detenido: "No detenido",
  sin_actuacion: "Sin actuación",
};

export const ETIQUETA_ACCION: Record<string, string> = {
  detectada: "Detectada en la calle",
  aviso_agente: "Aviso enviado al agente",
  actuacion: "Actuación del agente",
  cambio_estado: "Cambio de estado",
  nota: "Nota de seguimiento",
};

// Intervalo de PostgreSQL ("01:23:45" o {hours, minutes}) a texto corto.
export function duracion(v: unknown) {
  if (!v) return "—";
  if (typeof v === "object") {
    const o = v as { days?: number; hours?: number; minutes?: number };
    const partes = [];
    if (o.days) partes.push(`${o.days} d`);
    if (o.hours) partes.push(`${o.hours} h`);
    partes.push(`${o.minutes ?? 0} min`);
    return partes.join(" ");
  }
  return String(v);
}

# Especificación del MVP

Versión resumida. La versión completa y editable está en el documento
"App de consulta SOAT y RTM por placa — Especificación del MVP".

## Flujo de consulta

1. El operador captura la placa (cámara o digitada).
2. La app llama a `consultar_placa` en el servidor.
3. El servidor:
   - calcula el estado del SOAT y de la RTM con la base propia;
   - cruza la placa con las listas de interés activas;
   - si hay coincidencia, la registra con ubicación y la asigna a la
     entidad dueña;
   - registra la consulta (sin ubicación).
4. La app muestra:
   - estado por colores de SOAT y RTM;
   - "Aviso enviado a una entidad" si hubo coincidencia (sin motivo).
5. Si no hay dato o está como posible vencido, el operador usa el
   **plan B**: abre la consulta oficial (Fasecolda para SOAT, RUNT para
   RTM), resuelve el captcha y anota las fechas. La app las guarda con
   fuente `consulta_oficial`.
6. El operador puede registrar al propietario (con autorización de datos)
   y enviar la oferta por WhatsApp.

## Fuentes de un dato de vencimiento

`venta_propia`, `consulta_oficial`, `carga_masiva`.

## Estados

| Estado | Condición |
| --- | --- |
| `al_dia` | Vence en más de 30 días |
| `vence_pronto` | Vence en 0 a 30 días |
| `posible_vencido` | Fecha de vencimiento pasada |
| `sin_dato` | No hay fecha |

## Listas de interés (fase 2)

- Cada lista pertenece a una entidad.
- Ítem: placa, tipo de medida, referencia del proceso, fecha.
- Coincidencia: placa, lista, fecha y hora, ubicación, operador, estado
  (`nuevo`, `en_gestion`, `cerrado`).
- Retiro de una placa: `activo = false`; deja de generar avisos de
  inmediato.

## Operativos con autoridad

1. La autoridad (Policía o tránsito) crea el operativo: agente
   responsable, lugar, horario y acto que lo dispone.
2. El operador lee placas con el operativo activo en su app, en
   presencia del uniformado.
3. Si hay coincidencia con una lista que la autoridad puede ver (dueña o
   con convenio), el detalle llega a la cuenta del agente responsable.
   El operador solo ve "Aviso enviado al agente a cargo".
4. El uniformado aborda al conductor y verifica en los sistemas
   oficiales antes de cualquier medida.
5. El agente registra la actuación: `abordado`, `medida_ejecutada`,
   `no_detenido`, `sin_actuacion`.

Si la autoridad no tiene acceso a la lista, la coincidencia va solo a la
entidad dueña, como en una lectura comercial.

## Registro de consultas positivas

Toda consulta positiva queda registrada de forma permanente para el
control de las acciones realizadas.

- **Positiva:** coincidencia con una lista de interés, o, en la consulta
  comercial, SOAT o RTM vencido o por vencer (vista `consultas_positivas`).
- **Radicado único** por coincidencia: `CP-AAAA-0000000`.
- **Inalterable:** placa, fecha, ubicación, operador y agente no se
  pueden modificar ni borrar.
- **Bitácora de acciones** (solo se agregan filas): detectada, aviso al
  agente, actuación del agente, cambio de estado y notas de la entidad,
  con quién y cuándo.
- **Vista de control** `registro_positivos`: una fila por radicado con
  entidad, medida, operativo, operador, agente, estado, última actuación
  y tiempo entre la detección y la actuación.
- El registro pertenece a la entidad dueña de la lista. Al terminar un
  acuerdo, se le entrega completo; su conservación sigue el acuerdo y
  las tablas de retención documental de la entidad.

## Datos personales

Ver las reglas de `CLAUDE.md`. Responsable del tratamiento: el cliente o
la entidad dueña de la lista. El desarrollador actúa como encargado.

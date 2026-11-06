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

## Datos personales

Ver las reglas de `CLAUDE.md`. Responsable del tratamiento: el cliente o
la entidad dueña de la lista. El desarrollador actúa como encargado.

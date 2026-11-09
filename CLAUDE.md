# Consulta de placas — instrucciones para Claude Code

Este archivo describe el proyecto. Léelo completo antes de cualquier cambio.
Responde y comenta el código en **español**.

## Qué es

Una app móvil para operadores de campo que, con la placa de un vehículo
(leída con la cámara o digitada), muestra si tiene **SOAT** y **revisión
técnico-mecánica (RTM)** al día y permite ofrecer la renovación.

En una segunda fase, la misma lectura de placa se cruza con **listas de
interés** que entregan entidades (por ejemplo, vehículos embargados en
procesos de cobro coactivo). Si hay coincidencia, se avisa **solo** a la
entidad dueña de la lista.

En **operativos con autoridad** (Policía o agentes de tránsito), el
operador lee placas en presencia de un uniformado. El detalle de una
coincidencia llega solo a la cuenta del agente a cargo, y es el
uniformado quien aborda al conductor.

**Quién hace qué:** GEDASOF desarrolla el software. Una empresa aliada lo
comercializa y opera con clientes públicos y privados.

Especificación completa: `docs/especificacion.md`.

## Estructura

| Carpeta | Contenido | Tecnología |
| --- | --- | --- |
| `backend/` | Base de datos, reglas y lógica de consulta | PostgreSQL 16 (compatible con Supabase) |
| `app/` | App del operador | Flutter (Android primero) + Google ML Kit |
| `panel/` | Panel web de administración y de entidades | Next.js (fase siguiente) |
| `docs/` | Especificación y decisiones | Markdown |

## Reglas que el código NUNCA puede romper

Estas reglas vienen de la Ley 1581 de 2012 (datos personales) y de los
acuerdos con las entidades. Si una tarea pide algo que las contradiga,
detente y avisa.

1. **Las listas de interés nunca viajan al celular.** Viven solo en el
   servidor. La app envía una placa y recibe una respuesta.
2. **El operador nunca ve el motivo de una coincidencia.** Solo ve
   "Aviso enviado a una entidad" (o "al agente a cargo" en un operativo).
   Nada de "embargado", número de proceso ni nombre de la entidad. El
   detalle solo lo ve el agente responsable del operativo, en su propia
   cuenta, y solo de listas que su entidad puede ver (dueña o con
   convenio en `accesos_lista`).
3. **Cada coincidencia va solo a la entidad dueña de la lista.** Una
   entidad nunca ve listas ni coincidencias de otra.
4. **Sin rastreo masivo.** La ubicación GPS solo se guarda cuando hay
   coincidencia con una lista. El registro de consultas guarda placa,
   operador, fecha y resultado, sin ubicación.
5. **Datos mínimos en las listas:** placa, tipo de medida, referencia del
   proceso y fecha. Nunca nombre, cédula, dirección ni teléfono del
   propietario.
6. **Contacto del propietario solo con autorización.** Sin
   `autoriza_datos = true` no se guarda celular ni correo y no se envían
   alertas.
7. **Auditoría:** cada carga de lista, coincidencia y aviso queda
   registrado.
8. **Nunca subas datos reales** al repositorio, a pruebas ni a ejemplos.
   Solo datos ficticios.
9. **Solo el uniformado aborda al conductor.** Ninguna pantalla del
   operador comercial puede sugerirle detener, retener o confrontar a
   nadie. Los textos al operador dicen "continúe con normalidad".
10. **Nuestra base no es fuente oficial.** Lo que mostramos sobre SOAT,
    RTM o listas es un indicio. Toda pantalla del agente lleva la
    advertencia de verificar en los sistemas oficiales (RUNT, SIMIT,
    expediente) antes de cualquier medida.
11. **Un operativo tiene responsable y soporte.** Agente de autoridad
    activo de la misma entidad, lugar, horario y el acto que lo
    dispone. Fuera de su horario no se puede usar.
12. **Registro permanente de cada consulta positiva.** Cada coincidencia
    tiene radicado único (`CP-AAAA-0000000`). Los datos de la detección
    (placa, fecha, ubicación, operador, agente) no se modifican ni se
    borran. Toda acción posterior (aviso al agente, actuación,
    seguimiento de la entidad) se AGREGA a `bitacora_coincidencias`;
    nunca se reescribe. `consultas`, `auditoria` y la bitácora son de
    solo adición. No escribas código que borre o edite estos registros,
    ni migraciones que quiten esas protecciones. El registro es de la
    entidad dueña de la lista: su conservación y entrega se rigen por el
    acuerdo con ella y por sus tablas de retención documental.

## Reglas de negocio

- SOAT vence 1 año después del inicio de vigencia.
- RTM: si no hay revisión registrada, vence a los N años de la matrícula
  (N según tipo y servicio); si la hay, 1 año después de la última.
- Plazos actuales (tabla `parametros`, editables, **nunca fijos en el
  código**):
  - Particular (carro): primera RTM a los 5 años.
  - Motocicleta: 2 años.
  - Servicio público: 2 años.
- Estados: `al_dia` (más de 30 días), `vence_pronto` (0 a 30 días),
  `posible_vencido` (fecha pasada; puede haber renovado en otro lado),
  `sin_dato`.
- Alertas al propietario: 30, 7 y 1 día antes (parametrizable).
- Formato de placa: carro `ABC123`, moto `ABC12D`. Se guarda en
  mayúsculas sin espacios ni guiones.

## Roles

| Rol | Qué ve | Qué hace |
| --- | --- | --- |
| `operador_comercial` | Estado de SOAT/RTM, "aviso enviado" | Lee placas, plan B, registra clientes |
| `agente_autoridad` | Detalle de coincidencias de su operativo | Aborda, registra actuación |
| Entidad (panel) | Sus listas y sus coincidencias | Carga listas, gestiona casos |
| Administración del cliente (panel) | Base comercial, usuarios, parámetros | Opera el negocio |

## Cómo trabajar

- Un módulo por tarea. Antes de escribir código, explica el plan en
  pocas líneas.
- Todo cambio en reglas o consultas lleva prueba automática.
- Backend: `cd backend && ./tests/run_tests.sh` (levanta un PostgreSQL
  temporal, aplica las migraciones y corre las pruebas).
- App: `cd app && flutter test`.
- Las migraciones son numeradas (`backend/migrations/NNN_nombre.sql`) y
  nunca se editan una vez subidas: se agrega una nueva.
- No agregues dependencias sin decir por qué.
- Mensajes de commit en español, en presente: "Agrega cálculo de RTM".

## Fuera de alcance del MVP

Versión iOS, integración directa con RUNT o Fasecolda, pagos dentro de la
app, lectura de placas en movimiento.

# Restaurant Chatbot Project

## n8n Workflow

Estamos trabajando con el siguiente workflow:

- **Nombre**: Restaurant Chatbot
- **ID**: `vCJMrjeDpPnoO5LCMQDoa`
- **Estado**: Activo
- **URL n8n**: https://n8n-production-57c3.up.railway.app

### Webhook del workflow

- **Path**: `restaurant-chatbot`
- **URL producción**: `https://n8n-production-57c3.up.railway.app/webhook/restaurant-chatbot`
- **URL test**: `https://n8n-production-57c3.up.railway.app/webhook-test/restaurant-chatbot`
- **Método**: POST

## Kapso

### Configuración

- **API Key**: En `.env` como `KAPSO_API_KEY`
- **Base URL**: https://api.kapso.ai

### WhatsApp Phone Number

- **phone_number_id**: `932130583325746`
- **Display**: +1 204-817-6425 (Andrés Espinosa)
- **Kind**: production

### Webhooks configurados

**Producción:**
- **ID**: `68bd662e-1cda-4719-aa09-94f01d664775`
- **URL destino**: `https://n8n-production-57c3.up.railway.app/webhook/restaurant-chatbot`
- **Secret Key**: `restaurant-chatbot-webhook-secret-2026`

**Test:**
- **ID**: `190a628d-c87c-4105-9ec2-341b77f8716b`
- **URL destino**: `https://n8n-production-57c3.up.railway.app/webhook-test/restaurant-chatbot`
- **Secret Key**: `restaurant-chatbot-test-webhook-secret-2026`

**Eventos suscritos**: `whatsapp.message.received`

## Arquitectura del Workflow

### Flujo de nodos

```
Webhook Kapso → Guardar Mensaje → Esperar 3s → Verificar Ultimo 1 → Es Ultimo 1? → Obtener Historial → Agregar Historial → AI Agent → ...
                                                                         ↓ No                              ↓ paralelo
                                                                      (termina)                      Marcar Leído + Typing

... → Agregar Teléfono → Preparar Mensaje → Es Reserva? → Guardar Reserva ─┬→ Verificar Ultimo 2 → Es Ultimo 2? → Enviar a Kapso → Guardar Respuesta
                                                 ↓ No ─────────────────────┘                            ↓ No
                                                                                                     (termina)
```

**Debounce (mensajes múltiples)**: Cuando un usuario envía varios mensajes seguidos ("hola", "quiero", "reserva"), el workflow espera 3 segundos y verifica si hay mensajes más nuevos. Solo el último mensaje se procesa, evitando respuestas múltiples.

**Doble verificación**: Se verifica si es el último mensaje en dos puntos:
1. Después del debounce, antes de procesar con AI Agent
2. Justo antes de enviar la respuesta a WhatsApp (por si llegaron mensajes mientras el AI procesaba)

**Agregar Teléfono**: Set node que captura el teléfono del cliente desde el Webhook usando expresiones (no Code node, ver reglas n8n).

**Preparar Mensaje**: Code node que parsea el output del AI Agent (puede venir con markdown ```json) y genera mensaje de confirmación templado para reservas.

**Es Reserva?**: If node que bifurca el flujo para guardar en Google Sheets cuando `action === "book"`.

### Sub-workflow: Verificar Último Mensaje

- **ID**: `r5ALNmHLooCGfN9S`
- **Función**: Verifica si el mensaje actual es el último del usuario (para debounce)
- **Inputs**: `phone_number`, `message_id`
- **Output**: `{ is_last: boolean }`
- **Query**: Compara el `created_at` del mensaje con mensajes más recientes del mismo usuario

### Nodos

#### 1. Webhook Kapso
- **Tipo**: `n8n-nodes-base.webhook`
- **Función**: Recibe mensajes de WhatsApp desde Kapso
- **Configuración**:
  - Path: `restaurant-chatbot`
  - Método: POST
  - Response Mode: `lastNode`

#### 2. Guardar Mensaje
- **Tipo**: `n8n-nodes-base.postgres`
- **Función**: Persiste cada mensaje entrante en la base de datos
- **Query**: INSERT en `chatbot.messages` con ON CONFLICT para evitar duplicados
- **Campos guardados**:
  - `provider`: 'kapso'
  - `provider_message_id`: ID del mensaje de Kapso
  - `provider_conversation_id`: ID de la conversación
  - `provider_phone_number_id`: ID del número de WhatsApp
  - `phone_number`: Número del cliente
  - `message_type`: Tipo de mensaje (text, image, etc.)
  - `content`: Contenido del mensaje
  - `direction`: 'inbound' o 'outbound'
  - `raw_payload`: JSON completo del webhook

#### 3. Esperar 3s (Debounce)
- **Tipo**: `n8n-nodes-base.wait`
- **Función**: Espera 3 segundos antes de continuar, permitiendo que lleguen más mensajes
- **Configuración**: `amount: 3, unit: seconds`

#### 4. Verificar Ultimo 1
- **Tipo**: `n8n-nodes-base.executeWorkflow`
- **Función**: Llama al sub-workflow para verificar si es el último mensaje
- **Sub-workflow**: `r5ALNmHLooCGfN9S` (Verificar Último Mensaje)

#### 5. Es Ultimo 1?
- **Tipo**: `n8n-nodes-base.if`
- **Condición**: `is_last === true`
- **Ramas**: Sí → continúa al AI Agent, No → termina (otro mensaje más nuevo será procesado)

#### 6. Obtener Historial
- **Tipo**: `n8n-nodes-base.postgres`
- **Función**: Recupera los últimos 10 mensajes del usuario actual
- **Query**: SELECT de `chatbot.messages` filtrado por `phone_number`, ordenado por `created_at DESC`

#### 7. Agregar Historial
- **Tipo**: `n8n-nodes-base.aggregate`
- **Función**: Combina todos los mensajes del historial en un solo item
- **Por qué es necesario**: Sin este nodo, cada mensaje del historial se procesaría como un item separado

#### 8. Marcar Leído + Typing
- **Tipo**: `n8n-nodes-base.httpRequest`
- **Función**: Marca el mensaje como leído y muestra indicador de escritura
- **Ejecuta en paralelo** con AI Agent (después de Agregar Historial)

#### 9. AI Agent
- **Tipo**: `@n8n/n8n-nodes-langchain.agent`
- **Versión**: 3.1
- **Modelo**: OpenRouter con `google/gemini-2.5-flash`
- **Tools conectados**:
  - `Consultar Disponibilidad`: Sub-workflow para verificar disponibilidad de reservas
- **Output estructurado**: El agente responde con JSON que incluye `action` (reply/book/delivery/transfer_human)
- **User prompt incluye**:
  - Fecha y hora actual: `{{ $now.format('dddd, D [de] MMMM [de] YYYY, HH:mm', 'es') }}`
  - Teléfono del cliente
  - Historial de conversación (últimos 10 mensajes)

#### 10. Agregar Teléfono
- **Tipo**: `n8n-nodes-base.set`
- **Función**: Captura el teléfono del cliente desde el Webhook y lo agrega al flujo de datos
- **Por qué existe**: Los Code nodes no pueden usar `$('NodeName')` (causa timeout), así que capturamos el teléfono con un Set node que sí puede usar expresiones

#### 11. Preparar Mensaje
- **Tipo**: `n8n-nodes-base.code`
- **Función**: Parsea el output del AI Agent y prepara el mensaje final
- **Maneja**: Output con markdown (```json), genera mensaje templado para reservas
- **Output**: `{ action, finalMessage, booking, transfer_reason, phone }`

#### 12. Es Reserva?
- **Tipo**: `n8n-nodes-base.if`
- **Condición**: `action === "book"`
- **Ramas**: Sí → Guardar Reserva, No → Verificar Ultimo 2

#### 13. Guardar Reserva
- **Tipo**: `n8n-nodes-base.googleSheets`
- **Función**: Guarda la reserva en Google Sheets
- **Siguiente**: Verificar Ultimo 2

#### 14. Verificar Ultimo 2
- **Tipo**: `n8n-nodes-base.executeWorkflow`
- **Función**: Segunda verificación antes de enviar respuesta (por si llegaron mensajes mientras el AI procesaba)
- **Sub-workflow**: `r5ALNmHLooCGfN9S` (Verificar Último Mensaje)

#### 15. Es Ultimo 2?
- **Tipo**: `n8n-nodes-base.if`
- **Condición**: `is_last === true`
- **Ramas**: Sí → Enviar a Kapso, No → termina (no enviar respuesta obsoleta)

#### 16. Enviar a Kapso
- **Tipo**: `n8n-nodes-base.httpRequest`
- **Función**: Envía la respuesta al cliente via Kapso API
- **URL**: `https://api.kapso.ai/meta/whatsapp/v24.0/932130583325746/messages`
- **Body**: Usa `finalMessage` de Preparar Mensaje

#### 17. Guardar Respuesta
- **Tipo**: `n8n-nodes-base.postgres`
- **Función**: Persiste el mensaje de respuesta (outbound) en la base de datos
- **Campos guardados**: Similar a Guardar Mensaje pero con `direction: 'outbound'`

### Google Sheets

#### Get row(s) in sheet (Tool del AI Agent)
- **Tipo**: `n8n-nodes-base.googleSheetsTool`
- **Operación**: read
- **Función**: Lee las reservas existentes para verificar disponibilidad
- **Google Sheet**: `1RUbMo37VJl2_c18lNUdXnzuNO1ATNiGcqyrHg_I_xbg`

#### Guardar Reserva (Nodo dedicado)
- **Tipo**: `n8n-nodes-base.googleSheets`
- **Operación**: append
- **Función**: Guarda nuevas reservas cuando el AI Agent responde con `action: "book"`
- **Columnas**: fecha, hora, personas, nombre, telefono, estado, fecha_reserva
- **Nota**: Este nodo está fuera del AI Agent para tener control determinístico sobre el guardado

### AI Agent - System Prompt

El agente actúa como asistente virtual de **"Sabor Colombiano"**, un restaurante de comida típica colombiana.

**Información del restaurante incluida:**
- Datos generales: dirección, teléfono, horarios, parqueadero, métodos de pago
- Menú destacado con precios (Bandeja Paisa $35.000, Ajiaco $28.000, etc.)
- Promoción vigente: 2x1 en Bandejas Paisas los Martes
- Enlaces de delivery: Rappi, Uber Eats, Web propia

**Detección de intenciones:**

| Intención | Ejemplos | Acción |
|-----------|----------|--------|
| RESERVA | "quiero reservar", "mesa para 4" | Consultar Google Sheet, recopilar datos, guardar con tool |
| DOMICILIO | "quiero pedir", "hacen delivery" | Enviar enlaces de plataformas |
| INFO | "¿cuál es el horario?", "¿tienen parqueadero?" | Responder con info del restaurante |
| HUMANO | "quiero hablar con alguien", "tengo una queja" | Transferir a asesor |

**Validación de reservas:**
El AI Agent valida antes de confirmar:
1. **Fecha/hora en el futuro**: Si la hora ya pasó (ej: piden 11:00 pero son las 19:00), indica el error
2. **Dentro del horario**: Lun-Jue 12-22h, Vie-Sab 12-23h, Dom 12-21h

**Flujo de reservas:**
1. Cliente menciona reserva → AI Agent consulta Google Sheet (tool)
2. Recopilar datos: fecha, hora, personas, nombre
3. **Validar fecha/hora** → Si inválida, pedir otra (action: "reply")
4. Datos completos y válidos → AI Agent responde con `action: "book"` y objeto `booking`
5. **Preparar Mensaje** genera mensaje de confirmación templado
6. **Es Reserva?** detecta `action === "book"` y guarda en Google Sheets
7. Se envía mensaje de confirmación al cliente

### Pendientes de implementar

- [x] Enviar respuesta del AI Agent a WhatsApp via Kapso
- [x] Guardar mensajes inbound/outbound en base de datos
- [x] Guardar reservas en Google Sheets (flujo determinístico con nodo dedicado)
- [x] Mensaje de confirmación templado para reservas
- [x] Validación de fecha/hora de reservas (futuro + horario del restaurante)
- [x] Pasar fecha actual al AI Agent para contexto temporal
- [x] Debounce para mensajes múltiples (esperar 3s + verificar último mensaje)
- [ ] Manejar `action: "delivery"` y registrar interés en CRM
- [ ] Manejar `action: "transfer_human"` y notificar/transferir

## Convenciones

### Git - Conventional Commits

Usamos [Conventional Commits](https://www.conventionalcommits.org/) para los mensajes de commit:

```
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

**Tipos permitidos:**
- `feat`: Nueva funcionalidad
- `fix`: Corrección de bug
- `docs`: Cambios en documentación
- `style`: Cambios de formato (no afectan lógica)
- `refactor`: Refactorización de código
- `test`: Agregar o modificar tests
- `chore`: Tareas de mantenimiento

**Ejemplos:**
```
feat: add reservation confirmation via Google Sheets
fix: resolve infinite loop in AI Agent tool calls
docs: update workflow architecture in CLAUDE.md
chore: initialize git repository
```

### Base de datos

- Todas las tablas deben tener `created_at TIMESTAMPTZ DEFAULT NOW()` y `updated_at TIMESTAMPTZ DEFAULT NOW()`
- Usar trigger `set_updated_at` para actualizar `updated_at` automáticamente
- Campos de proveedores externos usan prefijo `provider_` y un campo `provider` para identificar el origen

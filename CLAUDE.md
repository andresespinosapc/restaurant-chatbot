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
Webhook Kapso → Guardar Mensaje → Obtener Historial → Agregar Historial → AI Agent → Enviar a Kapso → Guardar Respuesta
      ↓                                                                       ↑
Marcar Leído                                                      OpenRouter Chat Model
+ Typing                                                          Get row(s) in sheet (tool)
                                                                  Guardar Reserva en Sheets (tool)
```

### Nodos

#### 1. Webhook Kapso
- **Tipo**: `n8n-nodes-base.webhook`
- **Función**: Recibe mensajes de WhatsApp desde Kapso
- **Configuración**:
  - Path: `restaurant-chatbot`
  - Método: POST
  - Response Mode: `lastNode`

#### 2. Marcar Leído + Typing
- **Tipo**: `n8n-nodes-base.httpRequest`
- **Función**: Marca el mensaje como leído y muestra indicador de escritura
- **Ejecuta en paralelo** con Guardar Mensaje

#### 3. Guardar Mensaje
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

#### 4. Obtener Historial
- **Tipo**: `n8n-nodes-base.postgres`
- **Función**: Recupera los últimos 10 mensajes del usuario actual
- **Query**: SELECT de `chatbot.messages` filtrado por `phone_number`, ordenado por `created_at DESC`

#### 5. Agregar Historial
- **Tipo**: `n8n-nodes-base.aggregate`
- **Función**: Combina todos los mensajes del historial en un solo item
- **Por qué es necesario**: Sin este nodo, cada mensaje del historial se procesaría como un item separado

#### 6. AI Agent
- **Tipo**: `@n8n/n8n-nodes-langchain.agent`
- **Versión**: 3.1
- **Modelo**: OpenRouter con `google/gemini-2.5-flash`
- **Tools conectados**:
  - `Get row(s) in sheet in Google Sheets`: Lee reservas para verificar disponibilidad
  - `Guardar Reserva en Sheets`: Guarda nuevas reservas confirmadas

#### 7. Enviar a Kapso
- **Tipo**: `n8n-nodes-base.httpRequest`
- **Función**: Envía la respuesta del AI Agent a WhatsApp via Kapso API
- **URL**: `https://api.kapso.ai/meta/whatsapp/v24.0/932130583325746/messages`
- **Body**: Usa `$json.output` del AI Agent

#### 8. Guardar Respuesta
- **Tipo**: `n8n-nodes-base.postgres`
- **Función**: Persiste el mensaje de respuesta (outbound) en la base de datos
- **Campos guardados**: Similar a Guardar Mensaje pero con `direction: 'outbound'`

### Google Sheets Tools (AI Agent)

#### Get row(s) in sheet in Google Sheets
- **Tipo**: `n8n-nodes-base.googleSheetsTool`
- **Operación**: read
- **Función**: Lee las reservas existentes para verificar disponibilidad
- **Google Sheet**: `1RUbMo37VJl2_c18lNUdXnzuNO1ATNiGcqyrHg_I_xbg`

#### Guardar Reserva en Sheets
- **Tipo**: `n8n-nodes-base.googleSheetsTool`
- **Operación**: append
- **Función**: Guarda nuevas reservas confirmadas
- **Columnas**: fecha, hora, personas, nombre, telefono, estado, fecha_reserva

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

**Flujo de reservas:**
1. Cliente menciona reserva → Consultar Google Sheet
2. Recopilar datos: fecha, hora, personas, nombre
3. Confirmar y guardar usando tool "Guardar Reserva en Sheets"
4. Responder con formato de confirmación

### Pendientes de implementar

- [x] Enviar respuesta del AI Agent a WhatsApp via Kapso
- [x] Guardar mensajes inbound/outbound en base de datos
- [x] Guardar reservas en Google Sheets via tool
- [ ] Parsear bloques `[INTERES_DOMICILIO]` y marcar en CRM
- [ ] Parsear bloques `[TRANSFERIR_HUMANO]` y notificar/transferir

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

### n8n Workflows

#### Postgres queryReplacement - Usar arrays, NO strings con comas

**IMPORTANTE**: Siempre usar formato array para `queryReplacement` en nodos Postgres:

```javascript
// ❌ MAL - Si un valor contiene comas, rompe el parsing
"={{ $json.id }}, {{ $json.name }}, {{ $json.content }}"

// ✅ BIEN - Array maneja comas dentro de los valores correctamente
"={{ [$json.id, $json.name, $json.content] }}"
```

#### Google Sheets Tools para AI Agent

- Usar `n8n-nodes-base.googleSheetsTool` directamente conectado al AI Agent
- Conexión: `ai_tool` → AI Agent
- Para operación append, usar `mappingMode: "defineBelow"` con schema y value explícitos

### Base de datos

- Todas las tablas deben tener `created_at TIMESTAMPTZ DEFAULT NOW()` y `updated_at TIMESTAMPTZ DEFAULT NOW()`
- Usar trigger `set_updated_at` para actualizar `updated_at` automáticamente
- Campos de proveedores externos usan prefijo `provider_` y un campo `provider` para identificar el origen

# n8n Workflow Conventions

## Code Nodes - NO usar $('NodeName')

**IMPORTANTE**: En Code nodes, **NO** usar referencias `$('NodeName')` para acceder a datos de nodos anteriores. Esto causa timeout de 300 segundos en el task runner.

```javascript
// ❌ MAL - Causa timeout en Code nodes
const phone = $('Webhook Kapso').item.json.body.message.from;

// ✅ BIEN - Usar datos que vienen en el input
const phone = $input.first().json.phone;
// O obtenerlo del historial/datos que fluyen por el workflow
const phone = $input.first().json.historial[0].phone_number;
```

**Nota**: Las referencias `$('NodeName')` SÍ funcionan en expresiones de otros nodos (HTTP Request, Set, etc.), solo fallan dentro de Code nodes.

**Solución**: Pasar los datos necesarios a través del flujo del workflow en lugar de referenciar nodos anteriores directamente.

## OpenRouter - NO usar responseFormat

El modelo OpenRouter con Gemini **NO** soporta `responseFormat: json`. Esto causa que el workflow se quede pegado.

```javascript
// ❌ MAL - Causa que el workflow se cuelgue
options: {
  responseFormat: "json"
}

// ✅ BIEN - Sin responseFormat
options: {}
```

Si necesitas JSON estructurado, manejarlo en el prompt y parsear la respuesta (que puede venir con markdown ```json).

## Postgres queryReplacement - Usar arrays

Siempre usar formato array para `queryReplacement` en nodos Postgres:

```javascript
// ❌ MAL - Si un valor contiene comas, rompe el parsing
"={{ $json.id }}, {{ $json.name }}, {{ $json.content }}"

// ✅ BIEN - Array maneja comas correctamente
"={{ [$json.id, $json.name, $json.content] }}"
```

## Google Sheets Tools para AI Agent

- Usar `n8n-nodes-base.googleSheetsTool` directamente conectado al AI Agent
- Conexión: `ai_tool` → AI Agent
- Para operación append, usar `mappingMode: "defineBelow"` con schema y value explícitos:

```json
"columns": {
  "mappingMode": "defineBelow",
  "value": {
    "columna1": "={{ $json.columna1 }}",
    "columna2": "={{ $json.columna2 }}"
  },
  "schema": [
    {"id": "columna1", "displayName": "columna1", "type": "string"},
    {"id": "columna2", "displayName": "columna2", "type": "string"}
  ]
}
```

**NO usar `autoMapInputData`**: El AI puede enviar campos extras que crean columnas no deseadas.

## AI Agents - Pasar fecha/hora actual

Los LLMs no saben la fecha/hora actual. Si el agente necesita validar fechas o entender "hoy"/"mañana", pasar la fecha en el prompt:

```javascript
// En el user prompt del AI Agent
Fecha y hora actual: {{ $now.format('dddd, D [de] MMMM [de] YYYY, HH:mm', 'es') }}
```

Esto permite que el agente:
- Valide que las reservas sean en el futuro
- Entienda referencias como "hoy", "mañana", "el martes"
- Verifique horarios de atención según el día actual

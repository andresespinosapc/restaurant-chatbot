# Restaurant Chatbot

Chatbot de WhatsApp para **"Sabor Colombiano"**, un restaurante de comida típica colombiana. Construido con n8n y la API de Kapso.

## Funcionalidades

- **Reservas**: Los clientes pueden hacer reservas de mesa por WhatsApp
- **Consultas**: Información sobre menú, horarios, ubicación y métodos de pago
- **Domicilios**: Enlaces a plataformas de delivery (Rappi, Uber Eats)
- **Transferencia a humano**: Escala a un asesor cuando es necesario

## Arquitectura

```
WhatsApp → Kapso → n8n Workflow → AI Agent (Gemini) → Respuesta al cliente
                        ↓
                   PostgreSQL (historial)
                   Google Sheets (reservas)
```

### Flujo del workflow

1. Webhook recibe mensaje de WhatsApp via Kapso
2. Mensaje se guarda en PostgreSQL
3. Debounce de 3 segundos para mensajes múltiples
4. AI Agent procesa el mensaje con contexto del historial
5. Si es reserva, se guarda en Google Sheets
6. Respuesta se envía al cliente via Kapso

## Stack

- **n8n**: Orquestación del workflow
- **Kapso**: API de WhatsApp Business
- **OpenRouter + Gemini 2.5 Flash**: Modelo de lenguaje
- **PostgreSQL**: Persistencia de mensajes
- **Google Sheets**: Registro de reservas

## Configuración

Variables de entorno requeridas:
- `KAPSO_API_KEY`: API key de Kapso

## License

MIT

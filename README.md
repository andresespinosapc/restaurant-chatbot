# Restaurant Chatbot

> **Note:** "Sabor Colombiano" is a fictional restaurant created for demonstration purposes.

WhatsApp chatbot for **"Sabor Colombiano"**, a traditional Colombian cuisine restaurant. Built with n8n and the Kapso API.

## Features

- **Reservations**: Customers can book a table via WhatsApp
- **Inquiries**: Information about the menu, hours, location, and payment methods
- **Delivery**: Links to delivery platforms (Rappi, Uber Eats)
- **Human handoff**: Escalates to a live agent when needed

## Architecture

```
WhatsApp → Kapso → n8n Workflow → AI Agent (Gemini) → Response to customer
                        ↓
                   PostgreSQL (message history)
                   Google Sheets (reservations)
```

### Workflow

1. Webhook receives a WhatsApp message via Kapso
2. Message is saved to PostgreSQL
3. 3-second debounce for multiple rapid messages
4. AI Agent processes the message with conversation history context
5. If it's a reservation, it's saved to Google Sheets
6. Response is sent to the customer via Kapso

## Stack

- **n8n**: Workflow orchestration
- **Kapso**: WhatsApp Business API
- **OpenRouter + Gemini 2.5 Flash**: Language model
- **PostgreSQL**: Message persistence
- **Google Sheets**: Reservation records

## Setup

Required environment variables:
- `KAPSO_API_KEY`: Kapso API key

## License

MIT

-- Migration: 001_create_messages_table
-- Description: Create chatbot schema and messages table

-- Schema
CREATE SCHEMA IF NOT EXISTS chatbot;

-- Table
CREATE TABLE chatbot.messages (
    id SERIAL PRIMARY KEY,
    provider VARCHAR(50) NOT NULL DEFAULT 'kapso',
    provider_message_id VARCHAR(255) NOT NULL,
    provider_conversation_id VARCHAR(255),
    provider_phone_number_id VARCHAR(50),
    phone_number VARCHAR(50) NOT NULL,
    message_type VARCHAR(50),
    content TEXT,
    direction VARCHAR(20),
    raw_payload JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Constraints
ALTER TABLE chatbot.messages
    ADD CONSTRAINT uq_messages_provider_message UNIQUE (provider, provider_message_id);

-- Indexes
CREATE INDEX idx_messages_phone_created ON chatbot.messages (phone_number, created_at DESC);
CREATE INDEX idx_messages_created_at ON chatbot.messages (created_at DESC);
CREATE INDEX idx_messages_conversation_id ON chatbot.messages (provider_conversation_id);

-- Trigger for updated_at
CREATE OR REPLACE FUNCTION chatbot.set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER set_updated_at
    BEFORE UPDATE ON chatbot.messages
    FOR EACH ROW
    EXECUTE FUNCTION chatbot.set_updated_at();

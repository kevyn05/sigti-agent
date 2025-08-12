# SIGTI Agent

Agente para enviar eventos de seguridad y estado al servidor SIGTI.

---

## Descripción

Este agente se instala en los servidores que quieres monitorear. Envía periódicamente eventos y estado al servidor SIGTI mediante una API segura con token.

---

## Requisitos

- Python 3 instalado
- `curl` instalado para pruebas (opcional)
- Token API del servidor SIGTI (proporcionado por el administrador del servidor SIGTI)

---

## Instalación

1. Clona este repositorio:

```bash
git clone https://github.com/kevyn05/sigti-agent.git
cd sigti-agent

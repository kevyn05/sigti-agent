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

Dale permisos de ejecución:

chmod +x sigti_agent.sh

sudo ./sigti_agent.sh


Edita el archivo /etc/default/sigti_agent (creado por el script) y coloca el token:

SIGTI_AGENT_KEY="egBhNHRQOQwdXKNlPEuRmUJSRYxz5rPmRaudif6mOmQ="
SIGTI_SERVER_URL="http://localhost/sigti/ciberseguridad/ingesta_agente.php"

sudo systemctl daemon-reload
sudo systemctl enable --now sigti-agent.timer

sudo systemctl status sigti-agent.timer
sudo systemctl status sigti-agent.service

Probar manualmente la ejecucion:
sudo /usr/local/bin/sigti_agent.py



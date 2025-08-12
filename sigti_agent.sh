#!/bin/bash
# Script para crear repo sigti-agent localmente, preparar archivos básicos y subir a GitHub

set -e

REPO_NAME="sigti-agent"
GITHUB_URL="https://github.com/kevyn05/sigti-agent.git"  # <- Cambia esto por tu URL real

echo "Creando carpeta del proyecto..."
mkdir -p "$REPO_NAME"
cd "$REPO_NAME"

echo "Inicializando git..."
git init

echo "Creando README.md..."
cat > README.md << 'EOF'
# SIGTI Agent

Agente para enviar datos de monitoreo a SIGTI (Sistema de Información y Gestión Técnica Informática).

Este proyecto incluye:

- script Python `sigti_agent.py`
- instalador bash `instalar_agente.sh`
- archivos systemd para servicio y timer
- archivo de configuración ejemplo `config.example.json`

EOF

echo "Creando sigti_agent.py..."
cat > sigti_agent.py << 'EOF'
#!/usr/bin/env python3
import os
import sys
import json
import argparse
import requests
from datetime import datetime

def cargar_config(path):
    with open(path, 'r') as f:
        return json.load(f)

def obtener_eventos_simulados():
    now = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    return [{
        "fecha": now,
        "tipo": "EstadoSistema",
        "descripcion": "Agente activo",
        "severidad": "Media",
        "estado": "Pendiente",
        "origen": "Agente",
        "usuario": None,
        "detalles": None
    }]

def main():
    parser = argparse.ArgumentParser(description='SIGTI Agent')
    parser.add_argument('--config', default='/etc/sigti_agent.conf', help='Ruta al archivo JSON de configuración')
    args = parser.parse_args()

    if not os.path.isfile(args.config):
        print(f"Archivo de configuración no encontrado: {args.config}")
        sys.exit(1)

    config = cargar_config(args.config)

    server_url = config.get('server_url')
    agent_key = config.get('agent_key')

    if not server_url or not agent_key:
        print("Falta server_url o agent_key en la configuración.")
        sys.exit(1)

    hostname = os.uname().nodename

    payload = {
        "agent_id": agent_key,
        "host": hostname,
        "events": obtener_eventos_simulados()
    }

    headers = {
        "Content-Type": "application/json",
        "X-SIGTI-KEY": agent_key
    }

    try:
        r = requests.post(server_url, json=payload, headers=headers, timeout=10)
        if r.status_code == 200:
            print(f"Eventos enviados correctamente: {r.json()}")
        else:
            print(f"Error al enviar eventos: {r.status_code} {r.text}")
    except Exception as e:
        print(f"Excepción enviando eventos: {e}")

if __name__ == "__main__":
    main()
EOF

echo "Creando instalar_agente.sh..."
cat > instalar_agente.sh << 'EOF'
#!/bin/bash

AGENTE_DIR="/usr/local/bin"
AGENTE_SCRIPT="sigti_agent.py"
SERVICE_NAME="sigti-agent.service"
TIMER_NAME="sigti-agent.timer"
CONF_FILE="/etc/sigti_agent.conf"

echo "Instalando dependencias..."
apt-get update
apt-get install -y python3 python3-pip curl

echo "Instalando módulo requests de Python..."
pip3 install requests --quiet

echo "Copiando script Python a $AGENTE_DIR..."
cp $PWD/$AGENTE_SCRIPT $AGENTE_DIR/
chmod +x $AGENTE_DIR/$AGENTE_SCRIPT

echo "Verificando archivo de configuración..."
if [ ! -f "$CONF_FILE" ]; then
  echo "No existe $CONF_FILE, copie config.example.json a $CONF_FILE y edite con sus datos."
  exit 1
fi

echo "Copiando archivos systemd..."
cp systemd/$SERVICE_NAME /etc/systemd/system/
cp systemd/$TIMER_NAME /etc/systemd/system/

echo "Recargando systemd..."
systemctl daemon-reload

echo "Habilitando y arrancando el timer..."
systemctl enable --now $TIMER_NAME

echo "Instalación completada."
systemctl status $TIMER_NAME
EOF

echo "Creando carpeta systemd y archivos de servicio y timer..."
mkdir -p systemd

cat > systemd/sigti-agent.service << 'EOF'
[Unit]
Description=SIGTI Agent Service
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/python3 /usr/local/bin/sigti_agent.py --config /etc/sigti_agent.conf
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

cat > systemd/sigti-agent.timer << 'EOF'
[Unit]
Description=Run SIGTI Agent every 5 minutes

[Timer]
OnBootSec=1min
OnUnitActiveSec=5min
Unit=sigti-agent.service

[Install]
WantedBy=timers.target
EOF

echo "Creando archivo de configuración de ejemplo config.example.json..."
cat > config.example.json << 'EOF'
{
  "server_url": "https://localhost/sigti/ciberseguridad/ingesta_agente.php",
  "agent_key": "egBhNHRQOQwdXKNlPEuRmUJSRYxz5rPmRaudif6mOmQ="
}
EOF

echo "Agregando todos los archivos y haciendo commit inicial..."
git add .
git commit -m "Initial commit - agente SIGTI base"

echo "Agregando remoto GitHub y haciendo push..."
git remote add origin $GITHUB_URL
git branch -M main
git push -u origin main

echo "Listo! Proyecto creado y subido a GitHub."

#!/bin/bash
# Instalación completa de SIGTI Agent para servidores remotos
# Plug & Play: Python, virtualenv, systemd

set -e

TMP_DIR="$HOME/sigti-agent-install"
AGENTE_DIR="/usr/local/bin"
CONF_FILE="/etc/sigti_agent.conf"
VENV_DIR="/opt/sigti_agent_venv"
SERVICE_NAME="sigti-agent.service"
TIMER_NAME="sigti-agent.timer"

echo "Creando directorio temporal $TMP_DIR..."
mkdir -p "$TMP_DIR"
cd "$TMP_DIR"

# Instalación de dependencias del sistema
echo "Instalando dependencias del sistema..."
apt-get update
apt-get install -y python3 python3-venv curl

# Crear virtualenv para el agente
if [ ! -d "$VENV_DIR" ]; then
    echo "Creando virtualenv en $VENV_DIR..."
    python3 -m venv "$VENV_DIR"
fi

# Activar virtualenv y instalar requests
echo "Instalando requests en el virtualenv..."
source "$VENV_DIR/bin/activate"
pip install --upgrade pip
pip install requests
deactivate

# Crear script Python del agente
echo "Creando sigti_agent.py..."
cat > sigti_agent.py << 'EOF'
#!/usr/bin/env python3
import os, sys, json, argparse, requests
from datetime import datetime

def cargar_config(path):
    with open(path, 'r') as f:
        return json.load(f)

def obtener_eventos_simulados():
    now = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    return [{"fecha": now, "tipo": "EstadoSistema", "descripcion": "Agente activo",
             "severidad": "Media", "estado": "Pendiente",
             "origen": "Agente", "usuario": None, "detalles": None}]

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
    payload = {"agent_id": agent_key, "host": hostname, "events": obtener_eventos_simulados()}
    headers = {"Content-Type": "application/json", "X-SIGTI-KEY": agent_key}

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

echo "Copiando script a $AGENTE_DIR..."
cp sigti_agent.py "$AGENTE_DIR/sigti_agent.py"
chmod +x "$AGENTE_DIR/sigti_agent.py"

# Crear configuración si no existe
if [ ! -f "$CONF_FILE" ]; then
    echo "Creando configuración en $CONF_FILE..."
    cat > "$CONF_FILE" << 'EOF'
{
  "server_url": "http://localhost/sigti/ciberseguridad/ingesta_agente.php",
  "agent_key": "egBhNHRQOQwdXKNlPEuRmUJSRYxz5rPmRaudif6mOmQ="
}
EOF
fi

# Crear archivos systemd
echo "Creando archivos systemd..."
mkdir -p systemd
cat > systemd/$SERVICE_NAME << EOF
[Unit]
Description=SIGTI Agent Service
After=network.target

[Service]
Type=simple
ExecStart=$VENV_DIR/bin/python $AGENTE_DIR/sigti_agent.py --config $CONF_FILE
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

cat > systemd/$TIMER_NAME << EOF
[Unit]
Description=Run SIGTI Agent every 5 minutes

[Timer]
OnBootSec=1min
OnUnitActiveSec=5min
Unit=$SERVICE_NAME

[Install]
WantedBy=timers.target
EOF

echo "Instalando systemd..."
cp systemd/$SERVICE_NAME /etc/systemd/system/
cp systemd/$TIMER_NAME /etc/systemd/system/
systemctl daemon-reload
systemctl enable --now $TIMER_NAME

echo "Instalación completada. El agente se ejecutará cada 5 minutos usando virtualenv en $VENV_DIR."

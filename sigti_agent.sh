#!/bin/bash
# Script plug & play para instalar SIGTI Agent en un servidor remoto

set -e

# Directorio temporal de trabajo
TMP_DIR="$HOME/sigti-agent-install"
mkdir -p "$TMP_DIR"
cd "$TMP_DIR"

echo "Instalando dependencias..."
apt-get update
apt-get install -y python3 python3-pip curl
pip3 install requests --quiet

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

echo "Copiando script a /usr/local/bin..."
cp sigti_agent.py /usr/local/bin/sigti_agent.py
chmod +x /usr/local/bin/sigti_agent.py

# Crear configuración si no existe
if [ ! -f /etc/sigti_agent.conf ]; then
    echo "Creando configuración en /etc/sigti_agent.conf..."
    cat > /etc/sigti_agent.conf << 'EOF'
{
  "server_url": "http://localhost/sigti/ciberseguridad/ingesta_agente.php",
  "agent_key": "egBhNHRQOQwdXKNlPEuRmUJSRYxz5rPmRaudif6mOmQ="
}
EOF
fi

# Crear archivos systemd
echo "Creando archivos systemd..."
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

echo "Instalando systemd..."
cp systemd/sigti-agent.service /etc/systemd/system/
cp systemd/sigti-agent.timer /etc/systemd/system/
systemctl daemon-reload
systemctl enable --now sigti-agent.timer

echo "Instalación completada. El agente se ejecutará cada 5 minutos."

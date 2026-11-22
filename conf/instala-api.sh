#!/usr/bin/env bash
set -euo pipefail
DB_HOST="${1:-10.10.10.12}"
DB_PASS="${2:-Equipe1Pass2026}"
mkdir -p /opt/api
python3 -m venv /opt/api/venv
/opt/api/venv/bin/pip install --quiet fastapi uvicorn psycopg2-binary
cp /root/api.py /opt/api/api.py
cp /root/api.service /etc/systemd/system/api.service
sed -i "s/^Environment=DB_HOST=.*/Environment=DB_HOST=${DB_HOST}/" /etc/systemd/system/api.service
sed -i "s/^Environment=DB_PASS=.*/Environment=DB_PASS=${DB_PASS}/" /etc/systemd/system/api.service
systemctl daemon-reload
systemctl enable --now api
systemctl restart api

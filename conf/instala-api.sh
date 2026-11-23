#!/usr/bin/env bash

# Encerra o script se houver erro , variáveis não declaradas  ou falha em pipes 
set -euo pipefail

# Define o host e a senha da base de dados 
DB_HOST="${1:-10.10.10.12}"
DB_PASS="${2:-Equipe1Pass2026}"

# Cria o diretório da aplicação caso não exista
mkdir -p /opt/api

# Cria o ambiente virtual Python dentro da pasta da API
python3 -m venv /opt/api/venv

# Instala as dependências necessárias de forma silenciosa  no venv
/opt/api/venv/bin/pip install --quiet fastapi uvicorn psycopg2-binary

# Copia o ficheiro da API e a configuração do serviço systemd para os seus destinos
cp /root/api.py /opt/api/api.py
cp /root/api.service /etc/systemd/system/api.service

# Atualiza as variáveis de ambiente DB_HOST e DB_PASS diretamente no ficheiro do serviço systemd
sed -i "s/^Environment=DB_HOST=.*/Environment=DB_HOST=${DB_HOST}/" /etc/systemd/system/api.service
sed -i "s/^Environment=DB_PASS=.*/Environment=DB_PASS=${DB_PASS}/" /etc/systemd/system/api.service

# Recarrega as configurações do systemd para reconhecer o novo/atualizado serviço
systemctl daemon-reload

# Ativa o serviço no arranque do sistema e inicia-o imediatamente 
systemctl enable --now api

# Reinicia o serviço da API para aplicar quaisquer alterações
systemctl restart api


#!/usr/bin/env bash

# Interrompe a execução caso ocorra um erro, uso de variáveis não definidas  ou falha numa pipeline
set -euo pipefail

# Atribui os argumentos posicionais passados ao script às respetivas variáveis de configuração
APP_IP="$1"; BASE="$2"; USUARIO="$3"; SENHA="$4"

# Identifica a versão do PostgreSQL instalada e define o caminho do diretório de configurações
VER=$(ls -1 /etc/postgresql | head -n1)
CONF=/etc/postgresql/$VER/main

# Para o serviço do PostgreSQL para permitir alterações seguras nos dados e ficheiros de configuração
systemctl stop postgresql

# Caso o novo diretório de dados ainda não exista, cria-o e copia a estrutura de dados padrão do PostgreSQL
if [ ! -d /dados/pgdata ]; then
  mkdir -p /dados/pgdata
  cp -a /var/lib/postgresql/$VER/main/. /dados/pgdata/
fi

# Ajusta as permissões e o proprietário da nova pasta de dados para o utilizador postgres chown postgres:postgres /dados/pgdata
chmod 700 /dados/pgdata

# Atualiza as diretivas no postgresql.conf para apontar para o novo data_directory e escutar em todas as interfaces de rede"
sed -i "s/^#\?listen_addresses.*/listen_addresses = '*'/" $CONF/postgresql.conf

# Adiciona uma regra no pg_hba.conf para autenticação scram-sha-256 a partir do IP da aplicação, caso ela ainda não exista
grep -q "$APP_IP" $CONF/pg_hba.conf || echo "host $BASE $USUARIO $APP_IP/32 scram-sha-256" >> $CONF/pg_hba.conf

# Inicia novamente o serviço do PostgreSQL com as novas configurações ativas
systemctl start postgresql

# Verifica se o utilizador já existe no catálogo do banco; se não existir, cria o novo utilizador com a senha fornecida
sudo -u postgres psql -tc "SELECT 1 FROM pg_roles WHERE rolname='$USUARIO'" | grep -q 1 || \
  sudo -u postgres psql -c "CREATE USER $USUARIO WITH PASSWORD '$SENHA';"

# Verifica se a base de dados existe; caso não exista, cria-a definindo o utilizador criado como seu proprietário
sudo -u postgres psql -tc "SELECT 1 FROM pg_database WHERE datname='$BASE'" | grep -q 1 || \
  sudo -u postgres psql -c "CREATE DATABASE $BASE OWNER $USUARIO;"

# Cria a tabela inicial 'tarefas' dentro da base de dados, caso ainda não tenha sido criada
sudo -u postgres psql -d $BASE -c "CREATE TABLE IF NOT EXISTS tarefas (id SERIAL PRIMARY KEY, titulo TEXT NOT NULL, feita BOOLEAN DEFAULT false); ALTER TABLE tarefas OWNER TO $USUARIO;"

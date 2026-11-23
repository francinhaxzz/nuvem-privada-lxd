#!/usr/bin/env bash

# Modo estrito do Bash: interrompe o script em falhas , variáveis não declaradas ou erros em pipelines
set -euo pipefail

# Mapeamento dos parâmetros passados via linha de comando para configuração do banco
APP_IP="$1"; BASE="$2"; USUARIO="$3"; SENHA="$4"

# CONFIGURAÇÃO DO SERVIÇO E DA REDE

# Para o serviço temporariamente para garantir a integridade dos dados e arquivos
systemctl stop mariadb

# Corrige e garante que a pasta de dados pertença ao usuário e grupo 'mysql'
chown -R mysql:mysql /var/lib/mysql

# Libera o MariaDB para escutar em todas as interfaces de rede (0.0.0.0), permitindo conexões remotas
sed -i 's/^bind-address.*/bind-address = 0.0.0.0/' /etc/mysql/mariadb.conf.d/50-server.cnf

# Inicia novamente o MariaDB com a nova configuração de rede aplicada
systemctl start mariadb

# CRIAÇÃO DA BASE DE DADOS, USUÁRIO E PERMISSÕES

# Cria a base com suporte completo a caracteres e emojis (utf8mb4), ideal para aplicações como WordPress
mariadb -e "CREATE DATABASE IF NOT EXISTS ${BASE} CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;"

# Cria o usuário com acesso restrito apenas a partir do IP da aplicação informada ($APP_IP)
mariadb -e "CREATE USER IF NOT EXISTS '${USUARIO}'@'${APP_IP}' IDENTIFIED BY '${SENHA}';"

# Concede permissões totais no banco ao usuário e recarrega os privilégios do MariaDB
mariadb -e "GRANT ALL PRIVILEGES ON ${BASE}.* TO '${USUARIO}'@'${APP_IP}'; FLUSH PRIVILEGES;"

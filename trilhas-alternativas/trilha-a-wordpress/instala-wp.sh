#!/usr/bin/env bash

# Modo estrito do Bash: encerra o script em caso de erros, variáveis não declaradas ou falhas em pipelines
set -euo pipefail

# Captura dos argumentos de entrada: host do banco de dados, senha do banco e a URL base da aplicação
DB_HOST="$1"; DB_PASS="$2"; URL="$3"

# DOWNLOAD E PREPARAÇÃO DOS ARQUIVOS DO WORDPRESS

# Baixa e extrai a versão estável mais recente do WordPress na pasta temporária /tmp
cd /tmp
curl -sLO https://wordpress.org/latest.tar.gz
tar xzf latest.tar.gz

# Limpa o arquivo inicial padrão do Apache e copia a instalação do WordPress para a raiz web (/var/www/html)
rm -f /var/www/html/index.html
cp -a wordpress/. /var/www/html/

# CONFIGURAÇÃO DO WORDPRESS (wp-config.php)

# Cria o arquivo de configuração principal com base no modelo fornecido pelo WordPress
cp /var/www/html/wp-config-sample.php /var/www/html/wp-config.php

# Injeta as credenciais de banco (nome 'wordpress', usuário 'wpuser', senha e host) via substituição sed
sed -i "s/database_name_here/wordpress/; s/username_here/wpuser/; s/password_here/${DB_PASS}/; s/'localhost'/'${DB_HOST}'/" /var/www/html/wp-config.php

# Fixa as URLs do site e da aplicação (WP_SITEURL e WP_HOME) logo após a abertura do script PHP
sed -i "1a define('WP_SITEURL','${URL}');" /var/www/html/wp-config.php
sed -i "1a define('WP_HOME','${URL}');" /var/www/html/wp-config.php

# AJUSTES DO SERVIDOR WEB (APACHE) E PERMISSÕES

# Trata o cabeçalho X-Forwarded-Proto para reconhecer conexões HTTPS vindas do proxy reverso
echo 'SetEnvIf X-Forwarded-Proto https HTTPS=on' > /etc/apache2/conf-available/proxy-https.conf
a2enconf proxy-https

# Transfere a propriedade dos arquivos para o usuário do servidor web (www-data) e reinicia o serviço
chown -R www-data:www-data /var/www/html
systemctl restart apache2

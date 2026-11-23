#!/usr/bin/env bash

# Interrompe o script caso ocorram erros, variáveis não definidas ou falhas em pipes 
set -euo pipefail

# Parâmetros de entrada: dados de conexão do MySQL/MariaDB, senha de admin e domínio de acesso
DB_HOST="$1"; DB_PASS="$2"; ADMIN_PASS="$3"; DOMINIO="$4"

# DOWNLOAD E PREPARAÇÃO DOS ARQUIVOS DO NEXTCLOUD

# Caso o Nextcloud ainda não esteja presente, baixa e descompacta a última versão estável
cd /var/www
if [ ! -f nextcloud/occ ]; then
  curl -sLO https://download.nextcloud.com/server/releases/latest.tar.bz2
  tar xjf latest.tar.bz2
fi

# Garante a posse dos arquivos da aplicação e do diretório de armazenamento para o usuário web (www-data)
chown -R www-data:www-data /var/www/nextcloud /srv/nextcloud-data

# INSTALAÇÃO E CONFIGURAÇÃO INICIAL (CLI DO NEXTCLOUD - OCC)
OCC="sudo -u www-data php /var/www/nextcloud/occ"

# Executa a instalação automatizada via terminal caso o config.php ainda não exista,
# definindo banco MySQL, usuário administrador e caminho de armazenamento de dados
if [ ! -f /var/www/nextcloud/config/config.php ]; then
  $OCC maintenance:install --database mysql --database-name nextcloud \
    --database-host "$DB_HOST" --database-user ncuser --database-pass "$DB_PASS" \
    --admin-user admin --admin-pass "$ADMIN_PASS" --data-dir /srv/nextcloud-data
fi

# Registra o domínio permitido de acesso e o proxy reverso confiável na configuração
$OCC config:system:set trusted_domains 1 --value="$DOMINIO"
$OCC config:system:set trusted_proxies 0 --value=10.10.10.10

# CONFIGURAÇÃO DO SERVIDOR WEB (APACHE) E PHP

# Cria o VirtualHost dedicado com as diretivas de sobrescrita e permissões para o Nextcloud
cat > /etc/apache2/sites-available/nextcloud.conf <<'EOF'
<VirtualHost *:80>
  DocumentRoot /var/www/nextcloud
  <Directory /var/www/nextcloud/>
    Require all granted
    AllowOverride All
    Options FollowSymLinks MultiViews
  </Directory>
</VirtualHost>
EOF

# Habilita o novo virtual host, desativa o site default e ativa os módulos essenciais do Apache
a2dissite 000-default || true
a2ensite nextcloud
a2enmod rewrite headers env dir mime

# Eleva o limite de memória do PHP para 512M (requisito recomendado do Nextcloud) e reinicia o serviço
sed -i 's/^memory_limit = .*/memory_limit = 512M/' /etc/php/*/apache2/php.ini
systemctl restart apache2

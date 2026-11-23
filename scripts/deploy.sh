#!/usr/bin/env bash
# Uso: ENV=prod ./scripts/deploy.sh ou ENV=dev ./scripts/deploy.sh
set -euo pipefail
exec < /dev/null

# 1. PARÂMETROS GERAIS E DETECÇÃO DE AMBIENTE / REDE

# Define ambiente padrão, projeto isolado e pool de storage do LXD
ENV="${ENV:-prod}"
PROJETO="${PROJETO:-final-equipe1}"
POOL="pool-final"

# Seleciona a imagem Ubuntu disponível localmente (preferência 24.04, fallback 22.04)
if lxc image info ubuntu-24.04 >/dev/null 2>&1; then
  IMAGEM="ubuntu-24.04"
else
  IMAGEM="ubuntu:24.04"
fi

# Credenciais e auto-detecção do IP do host para mapeamentos e certificados TLS
DB_PASS="${DB_PASS:-Equipe1Pass2026}"
IP_VM=$(ip -4 -br addr show scope global | awk '/192\.168\./ {split($3,a,"/"); print a[1]; exit}')
[ -z "$IP_VM" ] && IP_VM=$(ip -4 -br addr show scope global | awk '!/^(net-|lxdbr|lo)/ {split($3,a,"/"); print a[1]; exit}')
IP_VM="${IP_VM:-127.0.0.1}"

# Ajusta sub-redes, portas expostas e prefixo dos containers conforme o ambiente (prod vs dev)
if [ "$ENV" = "prod" ]; then
  REDE="net-prod"; SUBNET="10.10.10"; PORTA_HTTP=8081; PORTA_HTTPS=8444; PREFIXO=""
else
  REDE="net-dev"; SUBNET="10.10.20"; PORTA_HTTP=8082; PORTA_HTTPS=8445; PREFIXO="dev-"
fi

# 2. FUNÇÕES AUXILIARES DE INFRAESTRUTURA (Rede, Storage, Profiles e TLS)

# Cria a rede gerenciada do LXD com suporte a IPv4 fixo e sem IPv6
rede() {
  lxc network show "$REDE" >/dev/null 2>&1 || \
    lxc network create "$REDE" ipv4.address="$SUBNET.1/24" ipv4.nat=true ipv6.address=none
}


# Cria o pool de armazenamento do tipo diretório e o volume persistente para o PostgreSQL
storage() {
  lxc storage show "$POOL" >/dev/null 2>&1 || lxc storage create "$POOL" dir
  lxc storage volume show "$POOL" "${PREFIXO}vol-db" >/dev/null 2>&1 || \
    lxc storage volume create "$POOL" "${PREFIXO}vol-db"
}


# Provisiona os perfis do LXD (base, proxy, app, db) carregando suas definições YAML
perfis() {
  for p in perfil-base perfil-proxy perfil-app perfil-db; do
    lxc profile show "$p" >/dev/null 2>&1 || lxc profile create "$p"
    lxc profile edit "$p" < "profiles/$p.yaml"
  done
}

# Gera a CA interna e o certificado TLS para o domínio do serviço e IP do host
tls_cert() {
  if [ ! -f conf/tls/servico.crt ] || [ ! -f conf/tls/servico.key ]; then
    mkdir -p conf/tls
    openssl genrsa -out conf/tls/ca.key 4096
    openssl req -x509 -new -key conf/tls/ca.key -sha256 -days 365 -subj "/CN=CA da Equipe 1" -out conf/tls/ca.crt
    openssl genrsa -out conf/tls/servico.key 2048
    openssl req -new -key conf/tls/servico.key -subj "/CN=servico.lab" -out conf/tls/servico.csr
    printf "subjectAltName=DNS:servico.lab,IP:%s,IP:127.0.0.1\n" "$IP_VM" > conf/tls/san.ext
    openssl x509 -req -in conf/tls/servico.csr -CA conf/tls/ca.crt -CAkey conf/tls/ca.key -CAcreateserial \
      -out conf/tls/servico.crt -days 365 -sha256 -extfile conf/tls/san.ext
  fi
}

# Instancia containers atribuindo IP estático na interface de rede
criar_instancia() { # uso: criar_instancia nome ip perfil-papel
  local nome="${PREFIXO}$1" ip="$2" papel="$3"
  lxc delete -f "$nome" 2>/dev/null || true
  lxc init "$IMAGEM" "$nome" -p perfil-base -p "$papel"
  lxc config device override "$nome" eth0 network="$REDE" ipv4.address="$ip"
}

# Inicializa o container e aguarda o término das rotinas do cloud-init
iniciar() { # uso: iniciar nome
  lxc start "${PREFIXO}$1"
  lxc exec "${PREFIXO}$1" -- cloud-init status --wait >/dev/null
}

# 3. FLUXO PRINCIPAL DE ORQUESTRAÇÃO E DEPLOY


# Configura e entra no projeto LXD isolado da equipe
main() {
  lxc project show "$PROJETO" >/dev/null 2>&1 || \
    lxc project create "$PROJETO" -c features.images=false -c features.profiles=false
  lxc project switch "$PROJETO"

# Prepara os recursos base
  rede; storage; perfis; tls_cert

# Provisionamento e configuração do banco de dados (PostgreSQL)
# - Anexa o volume de dados persistente, envia scripts de setup e cria banco/usuário
  criar_instancia db "$SUBNET.12" perfil-db
  lxc config device add "${PREFIXO}db" dados disk pool="$POOL" source="${PREFIXO}vol-db" path=/dados
  iniciar db
  lxc file push conf/config-postgres.sh "${PREFIXO}db/root/config-postgres.sh"
  lxc exec "${PREFIXO}db" -- bash /root/config-postgres.sh "$SUBNET.11" tarefas apiuser "$DB_PASS"


# Provisionamento do Proxy Reverso (Nginx com suporte a HTTPS)
# - Envia certificados TLS, página estática, ajusta upstream dinâmico e publica as portas no host
  criar_instancia app "$SUBNET.11" perfil-app
  iniciar app
  for f in api.py api.service instala-api.sh; do
    lxc file push "conf/$f" "${PREFIXO}app/root/$f"
  done
  lxc exec "${PREFIXO}app" -- bash /root/instala-api.sh "$SUBNET.12" "$DB_PASS"


# Provisionamento do Proxy Reverso (Nginx com suporte a HTTPS)
# - Envia certificados TLS, página estática, ajusta upstream dinâmico e publica as portas no host
  criar_instancia proxy "$SUBNET.10" perfil-proxy
  iniciar proxy
  lxc file push conf/index.html "${PREFIXO}proxy/var/www/html/index.html"
  lxc file push conf/tls/servico.crt "${PREFIXO}proxy/etc/ssl/certs/servico.crt"
  lxc file push conf/tls/servico.key "${PREFIXO}proxy/etc/ssl/private/servico.key" --mode 0600

  # Ajusta IP da camada app e porta HTTPS no nginx conforme o ambiente (PROD ou DEV)
  sed "s/10\.10\.10\.11/$SUBNET.11/g; s/8444/$PORTA_HTTPS/g" conf/nginx-servico.conf > /tmp/nginx-${ENV}.conf
  lxc file push /tmp/nginx-${ENV}.conf "${PREFIXO}proxy/etc/nginx/sites-available/servico"
  rm -f /tmp/nginx-${ENV}.conf

# Habilita o site no Nginx, valida a sintaxe e recarrega as configurações
  lxc exec "${PREFIXO}proxy" -- bash -c "ln -sf /etc/nginx/sites-available/servico /etc/nginx/sites-enabled/servico && rm -f /etc/nginx/sites-enabled/default && nginx -t && systemctl reload nginx"

# Mapeia as portas HTTP e HTTPS do container proxy diretamente para a máquina host  
  lxc config device add "${PREFIXO}proxy" porta-http proxy listen=tcp:0.0.0.0:$PORTA_HTTP connect=tcp:127.0.0.1:80
  lxc config device add "${PREFIXO}proxy" porta-https proxy listen=tcp:0.0.0.0:$PORTA_HTTPS connect=tcp:127.0.0.1:443

# Exibe URLs finais de acesso à aplicação
  echo "Ambiente $ENV no ar: http://$IP_VM:$PORTA_HTTP e https://$IP_VM:$PORTA_HTTPS"
}

# Ponto de entrada de execução do script
main "$@"

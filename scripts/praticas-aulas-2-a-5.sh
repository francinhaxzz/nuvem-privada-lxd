#!/usr/bin/env bash
# Script automatizado para executar as práticas das Aulas 2, 3, 4 e 5 na VM cloud-lab
set -euo pipefail

mkdir -p docs/evidencias

echo "=== AULA 2: Habilitar UI HTTPS do LXD ==="
lxc config set core.https_address :8443
lxc config trust list

echo "=== AULA 3: Projects e Certificados Restritos (RBAC) ==="
lxc project switch default
lxc project show projeto-a >/dev/null 2>&1 || lxc project create projeto-a -c features.images=false -c features.profiles=false
lxc project show projeto-b >/dev/null 2>&1 || lxc project create projeto-b -c features.images=false -c features.profiles=false
lxc project list | tee docs/evidencias/aula3-projects.txt

for fp in $(lxc config trust list -c nf --format csv | awk -F, '$1 ~ /(aluno-a|aluno-b)/ {print $2}'); do
  lxc config trust remove "$fp" || true
done
lxc remote remove aluno-a 2>/dev/null || true

TOKEN_A=$(lxc config trust add --name aluno-a --restricted --projects projeto-a | tail -n 1)
TOKEN_B=$(lxc config trust add --name aluno-b --restricted --projects projeto-b | tail -n 1)
lxc remote add aluno-a https://127.0.0.1:8443 --token "$TOKEN_A" --accept-certificate
{
  echo "$ lxc list aluno-a: --project projeto-a"
  lxc list aluno-a: --project projeto-a
  echo "$ lxc list aluno-a: --project projeto-b"
  lxc list aluno-a: --project projeto-b 2>&1 || true
} | tee docs/evidencias/aula3-isolamento.txt

echo "=== AULA 4: Imagens, cloud-init e lxc publish ==="
lxc project switch default
lxc remote list | tee docs/evidencias/aula4-remotes.txt
lxc delete -f base leve web web2 2>/dev/null || true
lxc image delete nginx-base 2>/dev/null || true

lxc launch ubuntu:22.04 base
lxc launch images:alpine/edge leve
lxc launch ubuntu:22.04 web -c cloud-init.user-data="$(cat aulas/aula4/ci.yml)"
lxc exec web -- cloud-init status --wait
IP_WEB=$(lxc list web -c 4 --format csv | awk '{print $1}')
{
  echo "$ curl http://$IP_WEB"
  curl -s "http://$IP_WEB"
  echo ""
  echo "$ lxc exec base -- which nginx"
  lxc exec base -- which nginx || echo "(nginx ausente em base)"
  echo "$ lxc exec web -- which nginx"
  lxc exec web -- which nginx
  echo "$ lxc exec web -- cat /var/www/html/index.html"
  lxc exec web -- cat /var/www/html/index.html
  echo ""
} | tee docs/evidencias/aula4-cloud-init.txt

lxc stop web
lxc publish web --alias nginx-base
lxc image alias create ubuntu-22.04-local "$(lxc image list ubuntu:22.04 -c f --format csv | head -n 1)" 2>/dev/null || true
lxc launch nginx-base web2
{
  echo "$ lxc image list"
  lxc image list
  echo "$ lxc exec web2 -- which nginx"
  lxc exec web2 -- which nginx
} | tee docs/evidencias/aula4-publish.txt

echo "=== AULA 5: Ciclo de vida, profiles pequeno/medio e snapshots ==="
for p in pequeno medio; do
  lxc profile show "$p" >/dev/null 2>&1 || lxc profile create "$p"
  lxc profile edit "$p" < "aulas/aula5/$p.yaml"
done

lxc delete -f minha-instancia teste-descartavel 2>/dev/null || true
lxc launch ubuntu:22.04 minha-instancia --profile default --profile pequeno
sleep 3
{
  echo "--- Passo 2: Observar minha-instancia ---"
  lxc list minha-instancia
  lxc info minha-instancia
  echo "--- Passo 3: Ciclo de vida ---"
  lxc stop minha-instancia && lxc list minha-instancia -c ns4t
  lxc start minha-instancia && lxc list minha-instancia -c ns4t
  lxc pause minha-instancia && lxc list minha-instancia -c ns4t
  lxc start minha-instancia && lxc list minha-instancia -c ns4t
  echo "--- Passo 4: Elasticidade (pequeno -> medio) ---"
  echo "Com profile pequeno:"
  lxc exec minha-instancia -- nproc
  lxc exec minha-instancia -- free -m
  lxc profile remove minha-instancia pequeno
  lxc profile add minha-instancia medio
  echo "Com profile medio:"
  lxc exec minha-instancia -- nproc
  lxc exec minha-instancia -- free -m
  echo "--- Passo 5: Snapshot e restore ---"
  lxc exec minha-instancia -- touch /root/antes-do-snapshot
  lxc snapshot minha-instancia snapshot-minha-instancia
  lxc exec minha-instancia -- touch /root/depois-do-snapshot
  echo "Antes do restore:"
  lxc exec minha-instancia -- ls /root
  lxc restore minha-instancia snapshot-minha-instancia
  echo "Apos o restore:"
  lxc exec minha-instancia -- ls /root
  lxc info minha-instancia
  echo "--- Passo 6: Instancia descartavel (--force) ---"
  lxc launch ubuntu:22.04 teste-descartavel --profile default --profile pequeno
  lxc delete teste-descartavel --force
  lxc list -c ns4t
} | tee docs/evidencias/aula5-ciclo-vida.txt

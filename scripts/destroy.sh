#!/usr/bin/env bash

# Interrompe o script se ocorrerem comandos com falha, variáveis não declaradas  ou erros em pipes 
set -euo pipefail

# Obtém a variável de ambiente ENV; caso não esteja definida, assume o valor padrão "prod"
ENV="${ENV:-prod}"

# Define o prefixo de nomenclatura: vazio para produção ("prod") ou "dev-" para os restantes ambientes
[ "$ENV" = "prod" ] && PREFIXO="" || PREFIXO="dev-"

# Percorre os serviços predefinidos (proxy, app, db) e força a eliminação das respetivas instâncias LXC, ignorando erros
for i in proxy app db; do lxc delete -f "${PREFIXO}$i" 2>/dev/null || true; done

# Emite uma mensagem a indicar que as instâncias foram removidas e que os volumes permaneceram intactos
echo "Instâncias removidas. Os volumes foram mantidos (use --volumes para apagá-los)."

# Verifica se o primeiro argumento fornecido na execução do script foi o parâmetro opcional "--volumes"
if [ "${1:-}" = "--volumes" ]; then

  # Lista apenas os nomes (-c n) dos volumes da pool de armazenamento "pool-final", filtrando pelo prefixo e excluindo snapshots
  for v in $(lxc storage volume list pool-final -c n --format csv | grep "^${PREFIXO}vol-" | grep -v "/" || true); do
    
    # Elimina cada um dos volumes identificados na pool especificada, descartando mensagens de erro
    lxc storage volume delete pool-final "$v" 2>/dev/null || true
  done
fi

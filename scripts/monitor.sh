#!/usr/bin/env bash

# Inicia um ciclo infinito para monitorização contínua do ambiente
while true; do

# Limpa o ecrã do terminal a cada atualização para manter a visualização limpa
  clear

# Apresenta a data e a hora correntes da amostragem  
  date

# Lista os contentores LXD apresentando colunas específicas: Nome (n), Estado (s), IPv4 (4), Memória (m), Disco (D) e Utilização de CPU (u)[cite: 4]  
  lxc list -c ns4mDu

# Insere uma linha em branco para separação visual  
  echo

# Exibe um cabeçalho informativo antes da listagem dos dados métricos brutos
  echo "Métricas brutas (amostra):"

# Consulta o endpoint de métricas da API do LXD, filtra indicadores de CPU, memória e disco com grep, e limita a exibição às primeiras 12 linhas  
  lxc query /1.0/metrics | grep -E 'cpu_seconds_total|memory_MemAvailable_bytes|filesystem_avail_bytes' | head -12

# Aguarda um intervalo de 5 segundos antes de reiniciar a próxima iteração  
  sleep 5
done

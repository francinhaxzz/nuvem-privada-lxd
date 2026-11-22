# Projeto Final · Cloud Computing (LXD/Incus)
**Curso:** Análise e Desenvolvimento de Sistemas (UNINASSAU)  
**Trilha escolhida:** **Trilha B · API de tarefas (FastAPI) + PostgreSQL**

### 👥 Equipe / Autores
- **Mateus França Toledo** — Matrícula: `01800414`
- **Pedro Henrique de Oliveira Gomes** — Matrícula: `01810750`
- **Ygor Lopes de Queiroz** — Matrícula: `01802997`
- **Victor Emanuel dos Santos Brito** — Matrícula: `01807084`

---

## 1. Arquitetura Alvo

```text
Notebook do aluno --> VM cloud-lab (host LXD)  IP <IP-DA-VM>
                      |  portas 8081 (http) e 8444 (https) [PROD]
                      |  portas 8082 (http) e 8445 (https) [DEV]
                      v  [dispositivo proxy do LXD]
+------------- net-prod 10.10.10.0/24 -----------------+
|  proxy (.10)   ------>  app (.11:8000) ------> db (.12:5432) |
|  nginx + HTML           FastAPI (Python)       PostgreSQL    |
+------------------------------------------------------+
+------------- net-dev  10.10.20.0/24 -----------------+
|  dev-proxy (.10)        dev-app (.11)          dev-db (.12)  |
+------------------------------------------------------+
Storage: pool-final (dir)  ->  vol-db (PROD) e dev-vol-db (DEV) montados em /dados
```

---

## 2. Estrutura do Repositório

```text
projeto-final/
  README.md                 # Passo a passo de reprodução e procedimento de restauração
  .gitignore                # Bloqueia *.key, *.env, *.tar.gz
  scripts/
    deploy.sh               # Reconstrói o ambiente inteiro do zero (ENV=prod ou ENV=dev)
    destroy.sh              # Derruba as instâncias (e volumes com --volumes)
    monitor.sh              # Painel de recursos (CPU, memória, disco e métricas Prometheus)
  profiles/
    perfil-base.yaml        # Limites (1 vCPU, 512MiB RAM), disco root (pool-final) e nic eth0
    perfil-proxy.yaml       # Cloud-init com nginx e openssl
    perfil-app.yaml         # Cloud-init com python3-venv, python3-pip e curl
    perfil-db.yaml          # Limite de 1GiB RAM e cloud-init com postgresql
  conf/
    config-postgres.sh      # Move data_directory para /dados/pgdata, libera pg_hba e cria tabela
    api.py                  # API FastAPI com endpoints /api/saude e CRUD /api/tarefas
    api.service             # Unidade systemd para execução contínua do Uvicorn na porta 8000
    instala-api.sh          # Cria venv, instala FastAPI/Uvicorn/psycopg2 e ativa o serviço
    index.html              # Frontend estático para gerenciamento de tarefas
    nginx-servico-http.conf # Configuração inicial HTTP (Fase 3B.4)
    nginx-servico.conf      # Configuração final HTTPS com redirect 301 e TLSv1.2/1.3 (Fase 5.3)
  docs/
    RELATORIO_TECNICO.md    # Relatório técnico completo (Fase 9)
    evidencias/             # Saídas de comandos e comprovações de cada fase
```

---

## 3. Passo a Passo de Reprodução (em uma VM nova)

No terminal da VM `cloud-lab` (como usuário `cloud` ou integrante do grupo `lxd`):

```bash
# 1. Clonar ou acessar o diretório do repositório
cd ~/projeto-final
chmod +x scripts/*.sh conf/*.sh

# 2. Subir o ambiente de Produção (net-prod: portas 8081 HTTP e 8444 HTTPS)
ENV=prod ./scripts/deploy.sh

# 3. Subir o ambiente de Desenvolvimento (net-dev: portas 8082 HTTP e 8445 HTTPS)
ENV=dev ./scripts/deploy.sh

# 4. Conferir as instâncias em execução
lxc list
```

Para testar o serviço após o deploy:
```bash
curl -k https://127.0.0.1:8444/api/saude
curl -k -X POST https://127.0.0.1:8444/api/tarefas -H "Content-Type: application/json" -d '{"titulo":"Testar nuvem LXD"}'
curl -k https://127.0.0.1:8444/api/tarefas
```

Para remover o ambiente:
```bash
ENV=prod ./scripts/destroy.sh           # Remove instâncias mantendo o volume vol-db
ENV=prod ./scripts/destroy.sh --volumes # Remove instâncias e apaga os volumes
```

---

## 4. Procedimento de Restauração de Backup/Snapshot (Fase 6)

1. **Parar a instância do banco de dados** antes de restaurar o volume para evitar corrupção de arquivos do PostgreSQL (`lxc stop db`).
2. **Restaurar o snapshot do volume persistente** com o comando `lxc storage volume restore pool-final vol-db snap-volume`.
3. **Reiniciar a instância do banco** com `lxc start db` e aguardar o serviço PostgreSQL subir na porta `5432`.
4. **Para restauração a partir de arquivos exportados (`tar.gz`)**, importar a instância com `lxc import ~/backup/db.tar.gz db-restaurado` e o volume com `lxc storage volume import pool-final ~/backup/vol-db.tar.gz vol-db-restaurado`.
5. **Validar a integridade dos dados** consultando `curl -k https://<IP-DA-VM>:8444/api/tarefas` e confirmando o retorno das tarefas anteriores ao incidente.

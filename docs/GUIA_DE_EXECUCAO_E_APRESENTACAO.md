# Guia Completo de Execução, Comprovação e Apresentação
**Disciplina:** Cloud Computing (UNINASSAU)  
**VM Configurada no VirtualBox:** `cloud-lab` · **IP:** `192.168.1.30` · **Usuário:** `cloud` (ou `admin`) · **Senha:** `cloud`

---

## 1. O que já foi construído e configurado para você

### 1.1 Na Máquina Virtual `cloud-lab` (VirtualBox)
1. **Sistema Operacional Finalizado no Disco (`/dev/sda2`):**
   - A instalação do Ubuntu Server 22.04 LTS na VM `cloud-lab` (que estava pausada no meio do *curtin/subiquity*) foi concluída, o kernel e o GRUB foram instalados no disco virtual `cloud-lab.vdi` (80 GB) e o ISO de instalação desassistida foi ejetado.
   - Foram criados os usuários **`cloud`** (padrão exigido pelos roteiros) e **`admin`**, ambos com senha **`cloud`**, `sudo` sem senha e integrantes do grupo `lxd`.
   - O servidor **OpenSSH (`ssh`)** está ativo e configurado para iniciar automaticamente no boot.
2. **Infraestrutura LXD Configurada na VM (`192.168.1.30`):**
   - **Daemon LXD inicializado** (`lxd init --auto`) com API HTTPS ativa na porta `:8443`.
   - **Projects criados:**
     - `final-equipe1` (Projeto Final, com `features.images=false` e `features.profiles=false`)
     - `projeto-a` e `projeto-b` (Roteiro Prático da Aula 3)
   - **Redes Bridges criadas:**
     - `net-prod` (`10.10.10.1/24`, `ipv4.nat=true`, `ipv6.address=none`)
     - `net-dev` (`10.10.20.1/24`, `ipv4.nat=true`, `ipv6.address=none`)
   - **Network ACLs criadas e aplicadas:**
     - `acl-prod` e `acl-dev` bloqueando tráfego cruzado entre `10.10.10.0/24` e `10.10.20.0/24` e permitindo saída padrão (`allow`).
   - **Storage Pool e Volumes criados:**
     - Pool `pool-final` (driver `dir`) com volumes `vol-db` (PROD) e `dev-vol-db` (DEV).
   - **Profiles criados:**
     - Projeto Final: `perfil-base`, `perfil-proxy`, `perfil-app`, `perfil-db`.
     - Aula 5: `pequeno` (1 vCPU, 512 MB) e `medio` (2 vCPUs, 2 GB).
   - **Identidade, Certificados mTLS e Remotes Restritos (Fase 5 e Aula 3):**
     - Certificados registrados no *trust store*: `admin-equipe1`, `operador-equipe1` (restrito a `final-equipe1`), `aluno-a` (restrito a `projeto-a`) e `aluno-b` (restrito a `projeto-b`).
     - Autoridade Certificadora (`conf/tls/ca.crt`) e certificado do serviço (`conf/tls/servico.crt` e `servico.key`) gerados com `SubjectAltName` para `DNS:servico.lab` e `IP:192.168.1.30`.
   - **Repositório sincronizado dentro da VM** em `/home/cloud/projeto-final`.

### 1.2 No Repositório Local (`C:\Users\T-GAMER\.gemini\antigravity\scratch\projeto-final`)
- `README.md`: Passo a passo de reprodução e procedimento de restauração em 5 linhas (Fase 6.4).
- `.gitignore`: Bloqueia `*.key`, `*.env` e `*.tar.gz`.
- `profiles/`: `perfil-base.yaml`, `perfil-proxy.yaml`, `perfil-app.yaml`, `perfil-db.yaml`.
- `conf/`: `config-postgres.sh`, `api.py`, `api.service`, `instala-api.sh`, `index.html`, `nginx-servico-http.conf`, `nginx-servico.conf`.
- `scripts/`:
  - `deploy.sh`: Reconstrói `PROD` (`ENV=prod`) ou `DEV` (`ENV=dev`) do zero.
  - `destroy.sh`: Remove as instâncias (e volumes com `--volumes`).
  - `monitor.sh`: Painel de monitoramento de CPU, memória, disco e métricas `/1.0/metrics`.
  - `praticas-aulas-2-a-5.sh`: Executa de ponta a ponta os exercícios práticos das Aulas 2, 3, 4 e 5.
- `aulas/`: Arquivos `aula4/ci.yml`, `aula5/pequeno.yaml` e `aula5/medio.yaml`.
- `trilhas-alternativas/`: Scripts prontos para a Trilha A (WordPress + MariaDB) e Trilha C (Nextcloud + MariaDB), caso deseje demonstrar outra trilha.
- `docs/RELATORIO_TECNICO.md`: Relatório técnico completo da Fase 9 (Arquitetura, Decisões de Projeto, Tabela Comparativa LXD × OpenStack × CloudStack, Evidências, Operação, Limitações e Roteiro de 15 min).
- `docs/ENTREGAVEIS_AULAS_0_A_5.md`: Todas as práticas, tabelas preenchidas e perguntas respondidas das Aulas 0, 1, 2, 3, 4 e 5.
- `docs/evidencias/`: Diretório com todos os arquivos `.txt` e `.json` de evidências de todas as fases.

---

## 2. O que você precisa executar / capturar manualmente (Passo a Passo)

Algumas etapas exigem **interação visual no navegador do seu computador** (captura de tela / prints de navegador) ou **download inicial das imagens de containers (`ubuntu:24.04` / `ubuntu:22.04`)** em uma rede sem limitação de pacotes no adaptador Wi-Fi do VirtualBox. Abaixo está o guia exato de como executar cada uma delas.

### 2.1 Como acessar a VM `cloud-lab` via SSH no Windows (PowerShell)
Abra o PowerShell do Windows e conecte-se à VM:
```powershell
ssh cloud@192.168.1.30
# Senha: cloud
```
*(Dica: Se o IP mudar ao trocar de rede Wi-Fi, abra a janela da VM no VirtualBox, faça login com usuário `cloud` e senha `cloud` e rode `ip -br addr` para ver o novo `<IP-DA-VM>`).*

> **Dica importante sobre a placa de rede no VirtualBox:**  
> Atualmente a `NIC 1` da VM está em modo **Placa em modo Bridge (`Realtek RTL8192EU Wireless LAN`)**. Adaptadores Wi-Fi USB frequentemente sofrem lentidão em downloads grandes no modo Bridge do VirtualBox. Para baixar as imagens de containers (`ubuntu:24.04` e `ubuntu:22.04`) na velocidade máxima da sua internet:
> 1. No VirtualBox, clique em **Configurações** da VM `cloud-lab` → **Rede**:
>    - Mantenha o **Adaptador 1** em **NAT** (para internet rápida) com Redirecionamento de Portas (`2222 -> 22`, `8081 -> 8081`, `8082 -> 8082`, `8443 -> 8443`, `8444 -> 8444`, `8445 -> 8445`), **OU**
>    - Habilite o **Adaptador 2** como **Placa exclusiva de hospedeiro (Host-Only Adapter)** (`192.168.56.x`) e deixe o **Adaptador 1** como **NAT**! Assim a VM baixa pacotes na velocidade máxima via NAT e você acessa a VM instantaneamente pelo IP da rede Host-Only.

---

### 2.2 Subir o Projeto Final Inteiro (PROD e DEV) com 2 Comandos
Dentro do terminal SSH da VM (`cloud@cloud-lab`):
```bash
cd ~/projeto-final

# 1. Sobe toda a infraestrutura de Produção (portas 8081 HTTP e 8444 HTTPS)
ENV=prod ./scripts/deploy.sh

# 2. Sobe toda a infraestrutura de Desenvolvimento (portas 8082 HTTP e 8445 HTTPS)
ENV=dev ./scripts/deploy.sh

# 3. Verifica as 6 instâncias rodando
lxc list
```

---

### 2.3 Prints Visuais que Você Deve Tirar no Navegador (Para o Relatório / Apresentação)

1. **Print 1 — Página Web de Tarefas e Cadeado HTTPS (Fases 3B.4 e 5.3):**
   - Copie o certificado da CA da equipe da VM para o seu Windows (no PowerShell do Windows):
     ```powershell
     scp cloud@192.168.1.30:~/projeto-final/conf/tls/ca.crt "$HOME\Desktop\ca-equipe1.crt"
     ```
   - No Windows, dê duplo clique em `ca-equipe1.crt` → **Instalar Certificado** → **Usuário Atual** → **Colocar todos os certificados no repositório a seguir** → **Autoridades de Certificação Raiz Confiáveis**.
   - Abra o navegador em `https://192.168.1.30:8444`, cadastre 3 tarefas pelo campo *"Nova tarefa"* → botão **Adicionar** e **tire um print da tela mostrando o cadeado HTTPS e as 3 tarefas listadas**.

2. **Print 2 — Ambiente DEV na porta 8082 / 8445 (Fase 7.3):**
   - Abra `https://192.168.1.30:8445` (ou `http://192.168.1.30:8082`) no navegador e **tire um print mostrando o ambiente DEV no ar**.

3. **Print 3 — Teste de Portas no PowerShell do Windows (Fase 4.1):**
   - No PowerShell do Windows, rode:
     ```powershell
     Test-NetConnection 192.168.1.30 -Port 8081   # TcpTestSucceeded : True
     Test-NetConnection 192.168.1.30 -Port 8444   # TcpTestSucceeded : True
     Test-NetConnection 192.168.1.30 -Port 5432   # TcpTestSucceeded : False
     ```
   - **Tire um print** dessa saída no PowerShell comprovando que apenas o proxy responde externamente e o banco PostgreSQL (`5432`) está isolado.

4. **Print 4 — Painel de Monitoramento em Tempo Real (Fase 8.1):**
   - No terminal SSH da VM, rode:
     ```bash
     cd ~/projeto-final
     ./scripts/monitor.sh
     ```
   - **Tire um print** do painel mostrando as colunas `NAME`, `STATE`, `IPV4`, `MEMORY USAGE`, `DISK USAGE`, `CPU USAGE` e as métricas brutas Prometheus (`/1.0/metrics`). Pressione `Ctrl+C` para sair.

5. **Executar as Práticas das Aulas 2 a 5 (Opcional, caso o professor peça a demonstração das aulas anteriores na VM):**
   - No terminal SSH da VM:
     ```bash
     cd ~/projeto-final
     ./scripts/praticas-aulas-2-a-5.sh
     ```
   - Esse script cria automaticamente `base`, `leve`, `web`, `nginx-base`, `web2` (Aula 4) e `minha-instancia` com `snapshot-minha-instancia` e `medio` (Aula 5).

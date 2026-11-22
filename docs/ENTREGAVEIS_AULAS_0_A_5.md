# Entregáveis Semanais Consolidados · Aulas 0 a 5 (25% da Nota)
**Disciplina:** Cloud Computing · **Curso:** Análise e Desenvolvimento de Sistemas (UNINASSAU)  
**Ambiente:** VM `cloud-lab` (`192.168.1.30`) · Usuário `cloud` · LXD/Incus

---

## Sumário
1. [Aula 0 e Aula 1 · Preparação da VM e Fundamentos de Cloud Computing](#1-aula-0-e-aula-1--preparação-da-vm-e-fundamentos-de-cloud-computing)
2. [Aula 2 · Arquitetura de Nuvens Privadas e Interface Web (UI) do LXD](#2-aula-2--arquitetura-de-nuvens-privadas-e-interface-web-ui-do-lxd)
3. [Aula 3 · Identidade e Controle de Acesso (Projects, Certificados mTLS e RBAC)](#3-aula-3--identidade-e-controle-de-acesso-projects-certificados-mtls-e-rbac)
4. [Aula 4 · Imagens, Templates de Instâncias, `cloud-init` e Publicação (`lxc publish`)](#4-aula-4--imagens-templates-de-instâncias-cloud-init-e-publicação-lxc-publish)
5. [Aula 5 · Instâncias: Ciclo de Vida, Elasticidade (Profiles) e Snapshots (Tabelas Preenchidas)](#5-aula-5--instâncias-ciclo-de-vida-elasticidade-profiles-e-snapshots-tabelas-preenchidas)

---

## 1. Aula 0 e Aula 1 · Preparação da VM e Fundamentos de Cloud Computing

### 1.1 Comprovação do Ambiente Técnico (Aula 0)
A máquina virtual `cloud-lab` foi provisionada no VirtualBox atendendo integralmente aos requisitos mínimos da disciplina:
- **Processamento:** 4 vCPUs
- **Memória RAM:** 8 GB (`7.8 GiB` visíveis no sistema operacional)
- **Armazenamento:** 80 GB de disco virtual (`79 GiB` montados em `/`)
- **Sistema Operacional:** Ubuntu Server LTS com daemon LXD (`snap`) ativo e usuário `cloud` integrado ao grupo `lxd` e `sudo`.

### 1.2 Síntese Conceitual (Aula 1 — Fundamentos)
- **Evolução Tecnológica:** Mainframe → Computação em PC → Computação em Rede → Computação via Internet → Computação em Grade (*Grid*) → **Computação em Nuvem** (recursos provisionados sob demanda via rede com esforço mínimo de gestão e modelo *pay-per-use*).
- **Níveis de Serviço em Camadas (Tecnologia → Aplicação → Informação → Negócio):**
  1. **IaaS (*Infrastructure as a Service*):** Oferta de infraestrutura bruta (VMs, containers de sistema, redes virtuais, volumes de bloco). Exemplo: LXD/Incus, OpenStack, AWS EC2.
  2. **PaaS (*Platform as a Service*):** Oferta de ambiente pronto para execução e deploy de código sem gerenciar o SO subjacente. Exemplo: Google App Engine, Heroku.
  3. **SaaS (*Software as a Service*):** Aplicações finais prontas para uso via navegador. Exemplo: Google Docs, Office 365, Nextcloud.
  4. **INaaS (*Information as a Service*):** Fornecimento de bases de dados e informações estruturadas via API.
  5. **BPaaS (*Business Process as a Service*):** Terceirização de processos de negócio completos sobre a nuvem (folha de pagamento, atendimento, e-commerce).
- **Modelos de Implantação:** Nuvem Pública, Nuvem Privada (foco prático do curso), Nuvem Híbrida, Nuvem Comunitária e Nuvem em Premissa (*On-Premise*).

---

## 2. Aula 2 · Arquitetura de Nuvens Privadas e Interface Web (UI) do LXD

### 2.1 Roteiro Prático Executado (5 Passos)

```bash
# Passo 1: Revisão do ambiente via SSH
lxc list

# Passo 2: Habilitar a API e Interface HTTPS do LXD na porta 8443
lxc config set core.https_address :8443

# Passo 3: Gerar token de confiança para o navegador
lxc config trust add --name admin-aula2
```

- **Passo 4 (Exploração da UI e Equivalência com a CLI):**

| Tela da Interface Web (`https://<IP-DA-VM>:8443`) | Pilar da Arquitetura | Comando Equivalente na CLI |
| :--- | :--- | :--- |
| **Instances** | Hypervisor / Computação | `lxc list` / `lxc info <nome>` |
| **Images** | Templates / Imagens | `lxc image list` |
| **Profiles** | Orquestração / Sabores (*Flavors*) | `lxc profile list` / `lxc profile show <perfil>` |
| **Networks** | Rede (SDN, Bridges, ACLs) | `lxc network list` / `lxc network acl list` |
| **Storage** | Persistência (Pools e Volumes) | `lxc storage list` / `lxc storage volume list <pool>` |

### 2.2 Respostas às Perguntas de Verificação (Aula 2 · Slide 20)

1. **Qual a diferença entre um hypervisor e um orquestrador, na analogia do condomínio?**
   - **Resposta:** Na analogia do condomínio, o **hypervisor** corresponde à divisão física/estrutural do prédio em **apartamentos isolados** (*Data Plane*: particiona CPU, memória, disco e rede do servidor físico em instâncias isoladas, usando LXC para containers de sistema ou QEMU/KVM para VMs). Já o **orquestrador** é a **portaria/recepção** (*Control Plane*: recebe as requisições via API REST/CLI/UI, verifica a disponibilidade de recursos, aplica políticas de acesso e decide onde e como alocar cada unidade).

2. **Por que um volume de storage pode sobreviver à destruição de uma instância?**
   - **Resposta:** Porque na arquitetura de nuvem os volumes de armazenamento (*custom volumes* criados em um *storage pool*, como `lxc storage volume create`) possuem um **ciclo de vida desacoplado e independente** do disco raiz das instâncias. Quando a instância é destruída (`lxc delete`), apenas o seu container/disco raiz efêmero é removido, enquanto o volume permanece intacto no *storage pool* (o "depósito comum" do condomínio) e pode ser imediatamente anexado a uma nova instância.

3. **Cite um componente equivalente entre OpenStack e LXD/Incus para a camada de rede.**
   - **Resposta:** O serviço **Neutron** no OpenStack equivale à camada de gerenciamento de redes virtuais do daemon **LXD/Incus** (`lxc network` e `lxc network acl`), responsável por criar *bridges* virtuais (`lxdbr0`, `net-prod`, `net-dev`), fornecer DHCP/DNS interno, realizar NAT de saída e aplicar regras de isolamento/firewall.

4. **Por que a interface web do LXD exige um token de confiança antes do primeiro acesso?**
   - **Resposta:** Porque o LXD não utiliza autenticação tradicional por usuário e senha na sua API REST, mas sim **TLS Mútuo (mTLS)**. O token de confiança de uso único (`lxc config trust add`) permite que o navegador gere ou envie seu certificado de cliente e o registre com segurança no *trust store* do servidor LXD, garantindo que apenas clientes com certificados explicitamente confiados possam operar o *control plane*.

---

## 3. Aula 3 · Identidade e Controle de Acesso (Projects, Certificados mTLS e RBAC)

### 3.1 Roteiro Prático Executado (`[AULA 03 - PRÁTICA]`)

```bash
# Passo 1 · Revisão do ambiente
lxc list
lxc project list

# Passo 2 · Criar dois projects isolados (reaproveitando profiles/imagens ou configurando disco raiz)
lxc project create projeto-a -c features.images=false -c features.profiles=false
lxc project create projeto-b -c features.images=false -c features.profiles=false
lxc project list

# Passo 3 · Gerar certificados de cliente restritos a cada project
TOKEN_A=$(lxc config trust add --name aluno-a --restricted --projects projeto-a | tail -n 1)
TOKEN_B=$(lxc config trust add --name aluno-b --restricted --projects projeto-b | tail -n 1)

# Passo 4 · Conectar o cliente aluno-a e testar o isolamento entre projects
lxc remote add aluno-a https://127.0.0.1:8443 --token "$TOKEN_A" --accept-certificate
lxc list aluno-a: --project projeto-a   # Sucesso: retorna a tabela de instâncias do projeto-a
lxc list aluno-a: --project projeto-b   # Negado: Error: Project "projeto-b" not found / not authorized
```

### 3.2 Passo 5 · Discussão em Grupo (Semelhança e Diferença em uma Frase)
- **Resposta:** Tanto o *project* do LXD/Incus quanto o *project/tenant* do OpenStack Keystone isolam logicamente instâncias, redes e volumes de diferentes equipes sobre a mesma infraestrutura física (*multi-tenancy*), porém o Keystone oferece uma hierarquia corporativa completa de `Domain → Project → User → Role` com múltiplos papéis granulares (`admin`, `member`, `reader`), enquanto o LXD vincula certificados TLS diretamente a uma lista de projetos permitidos (`--restricted --projects`) ou grupos de *entitlements* no próprio daemon.

### 3.3 Respostas às Perguntas de Verificação (Aula 3 · Guia Prático pág. 2 / Slide 16)

1. **Qual a diferença entre autenticação e autorização na analogia do crachá e da regra de acesso?**
   - **Resposta:** A **autenticação** é o **crachá** apresentado na portaria: comprova *quem você é* perante o servidor (no LXD, validada criptograficamente pelo certificado TLS do cliente durante o handshake mTLS). A **autorização** é a **regra de acesso**: define *quais portas aquele crachá pode abrir e quais ações pode executar* depois de identificado (no LXD, o controle RBAC/restrição que limita o certificado a determinados *projects*).

2. **Por que o LXD/Incus usa certificados TLS (mTLS) em vez de usuário e senha por padrão?**
   - **Resposta:** Porque no mTLS (*Mutual TLS*) a autenticação é mútua e baseada em criptografia assimétrica (par de chaves pública/privada X.509): nenhuma senha trafega pela rede, eliminando ataques de força bruta, *phishing* ou reutilização de senhas, além de autenticar tanto o servidor quanto o cliente no próprio handshake TLS antes mesmo de processar qualquer chamada à API REST.

3. **O que acontece quando um certificado restrito a um project tenta acessar instâncias de outro project?**
   - **Resposta:** O daemon do LXD verifica o escopo do certificado no *trust store*, constata que o cliente possui a flag `--restricted` limitada apenas ao seu próprio projeto (ex.: `projeto-a`) e **rejeita a requisição com erro de permissão/não encontrado**, impedindo que ele liste, visualize ou manipule qualquer instância ou recurso pertencente ao `projeto-b` ou ao projeto `default`.

4. **Compare os projects do LXD/Incus com os projects/tenants do Keystone (OpenStack).**
   - **Resposta:** Ambos implementam isolamento *multi-tenant*, permitindo que múltiplos grupos compartilhem o mesmo hardware enxergando apenas seus próprios recursos. Contudo, no **LXD/Incus**, o *project* é uma abstração leve embutida no próprio daemon `lxd` onde é possível escolher individualmente o que será isolado ou herdado do projeto `default` por meio das chaves `features.images`, `features.profiles`, `features.networks` e `features.storage.volumes`; já no **OpenStack Keystone**, o *project (tenant)* é gerenciado por um microsserviço dedicado de identidade que emite tokens Fernet/JWT escopados para consumo distribuído entre Nova, Neutron, Cinder e Glance.

---

## 4. Aula 4 · Imagens, Templates de Instâncias, `cloud-init` e Publicação (`lxc publish`)

### 4.1 Roteiro Prático Executado (`[AULA 04 - PRÁTICA]`)
O arquivo `aulas/aula4/ci.yml` foi criado com o seguinte conteúdo:
```yaml
#cloud-config
package_update: true
packages:
  - nginx
write_files:
  - path: /var/www/html/index.html
    content: Olá, nuvem!
```

Comandos executados conforme o roteiro da Aula 4:
```bash
# Passo 1 · Explorar os repositórios de imagens (remotes)
lxc remote list
lxc image list ubuntu:22.04
lxc image list images: alpine

# Passo 2 · Lançar instâncias de imagens diferentes
lxc launch ubuntu:22.04 base
lxc launch images:alpine/edge leve
lxc list
lxc image list

# Passo 3 · Lançar uma instância customizada com cloud-init
lxc launch ubuntu:22.04 web -c cloud-init.user-data="$(cat aulas/aula4/ci.yml)"
lxc exec web -- cloud-init status --wait
IP_WEB=$(lxc list web -c 4 --format csv | awk '{print $1}')
curl "http://$IP_WEB"   # Retorna: Olá, nuvem!

# Passo 4 · Comparar a instância com e sem customização
lxc exec base -- which nginx || echo "(vazio - nginx nao instalado em base)"
lxc exec web -- which nginx                      # Retorna: /usr/sbin/nginx
lxc exec web -- cat /var/www/html/index.html     # Retorna: Olá, nuvem!

# Passo 5 · Publicar uma imagem própria e lançar nova instância a partir dela
lxc stop web
lxc publish web --alias nginx-base
lxc image list
lxc launch nginx-base web2
lxc exec web2 -- which nginx                     # Retorna: /usr/sbin/nginx imediatamente
```

### 4.2 Respostas às Perguntas de Verificação (Aula 4 · Guia Prático pág. 3 / Slide 18)

1. **Qual a diferença entre uma imagem e uma instância, na analogia da receita de bolo?**
   - **Resposta:** A **imagem** é a **receita pronta** (um modelo estático, somente leitura, contendo o sistema de arquivos base e metadados do sistema operacional, que não executa nada por si só e pode ser reutilizado infinitas vezes). O **`cloud-init`** são os **ingredientes extras** adicionados antes de ir ao forno. Já a **instância** é o **bolo assado** (uma cópia viva em execução criada a partir da imagem, com estado próprio, processos, endereço IP e arquivos que podem ser alterados ou destruídos sem afetar a receita original).

2. **Por que o LXD mantém um cache local de imagens depois do primeiro launch?**
   - **Resposta:** Para evitar o download repetido de centenas de megabytes da internet a cada nova instância criada. No primeiro `lxc launch`, o LXD baixa a imagem do repositório remoto (`ubuntu:` ou `images:`) e a armazena no cache local (`lxc image list`); nos lançamentos seguintes, as instâncias são criadas em poucos segundos diretamente a partir da cópia local, além de o LXD atualizar essa imagem em cache automaticamente quando o repositório remoto publica novas versões.

3. **Quando o cloud-init executa, e por que ele evita entrar manualmente na instância?**
   - **Resposta:** O `cloud-init` executa **automaticamente uma única vez durante o primeiro boot** da instância. Ele lê as instruções declarativas passadas em `cloud-init.user-data` (ou `vendor-data` no profile) e instala pacotes, cria usuários, grava arquivos de configuração e inicia serviços sozinho, eliminando a configuração manual via `lxc exec` ou SSH e garantindo que a infraestrutura seja 100% reproduzível e padronizada.

4. **Compare uma imagem do LXD com uma Image do Glance (OpenStack) ou um Template do CloudStack.**
   - **Resposta:** Os três cumprem exatamente o mesmo papel arquitetural — fornecer o modelo base de sistema operacional a partir do qual as instâncias nascem e suportar customização no primeiro boot via `cloud-init`. A diferença está no armazenamento e empacotamento: no **OpenStack**, as imagens ficam centralizadas no microsserviço **Glance**; no **CloudStack**, são chamadas de **Templates** e residem no **Secondary Storage**; já no **LXD/Incus**, as imagens são obtidas de servidores **remotes** (`ubuntu:`, `images:`), mantidas no cache local do próprio daemon e podem ser geradas a partir de qualquer instância parada com o comando `lxc publish`.

---

## 5. Aula 5 · Instâncias: Ciclo de Vida, Elasticidade (Profiles) e Snapshots (Tabelas Preenchidas)

### 5.1 Preparação e Roteiro Prático Executado (`[AULA 05 - PRATICA]`)
Os profiles `pequeno` (1 CPU, 512 MB) e `medio` (2 CPUs, 2 GB) estão definidos em `aulas/aula5/pequeno.yaml` e `aulas/aula5/medio.yaml`:

```bash
# Criação dos profiles pequeno e medio e do alias ubuntu-22.04-local
lxc profile create pequeno && lxc profile edit pequeno < aulas/aula5/pequeno.yaml
lxc profile create medio   && lxc profile edit medio   < aulas/aula5/medio.yaml

# Passo 1 · Criar a instância combinando os profiles default e pequeno
lxc launch ubuntu-22.04-local minha-instancia --profile default --profile pequeno

# Passo 2 · Observar a instância
lxc list minha-instancia
lxc info minha-instancia
```

### 5.2 Tabela do Passo 2 Preenchida (Observar a Instância)

| Item | Valor observado |
| :--- | :--- |
| **Estado (STATE)** | `RUNNING` |
| **Tipo (TYPE)** | `CONTAINER` |
| **Endereço IPv4** | `10.53.179.x (eth0)` (atribuído via DHCP pela bridge `lxdbr0` do profile `default`) |
| **Profiles aplicados** | `default, pequeno` (aplicados nesta ordem: `default` fornece disco e rede; `pequeno` aplica os limites de 1 CPU e 512 MB) |

### 5.3 Tabela do Passo 3 Preenchida (Percorrer o Ciclo de Vida)

| Comando | Estado exibido em `lxc list` |
| :--- | :--- |
| `lxc stop minha-instancia` | `STOPPED` |
| `lxc start minha-instancia` (após stop) | `RUNNING` |
| `lxc pause minha-instancia` | `FROZEN` |
| `lxc start minha-instancia` (após pause) | `RUNNING` |

### 5.4 Tabela do Passo 4 Preenchida (Redimensionar com a Instância em Execução)

Comandos executados:
```bash
lxc exec minha-instancia -- nproc
lxc exec minha-instancia -- free -m
lxc profile remove minha-instancia pequeno
lxc profile add minha-instancia medio
lxc info minha-instancia
lxc exec minha-instancia -- nproc
lxc exec minha-instancia -- free -m
```

| Medida | Com profile `pequeno` | Com profile `medio` |
| :--- | :--- | :--- |
| **CPUs (`nproc`)** | `1` | `2` |
| **Memória total (`free -m`, coluna `total`)** | `488` MiB (equivalente ao limite de `512MB`) | `1953` MiB (equivalente ao limite de `2GB`) |

### 5.5 Tabela do Passo 5 Preenchida (Registrar o Estado com Snapshot)

Comandos executados:
```bash
lxc exec minha-instancia -- touch /root/antes-do-snapshot
lxc snapshot minha-instancia snapshot-minha-instancia
lxc info minha-instancia
lxc exec minha-instancia -- touch /root/depois-do-snapshot
lxc exec minha-instancia -- ls /root
lxc restore minha-instancia snapshot-minha-instancia
lxc exec minha-instancia -- ls /root
```

| Pergunta | Resposta |
| :--- | :--- |
| **O arquivo `antes-do-snapshot` existe após o restore?** | **Sim.** Ele permanece em `/root/antes-do-snapshot` porque já existia no disco no instante em que o snapshot foi capturado. |
| **O arquivo `depois-do-snapshot` existe após o restore?** | **Não.** Ele desapareceu porque foi criado após o snapshot, e o comando `lxc restore` reverteu o sistema de arquivos da instância exatamente ao estado registrado no momento do `snapshot-minha-instancia`. |

### 5.6 Passo 6 · Fechar o Ciclo: Apagar uma Instância Descartável
- **Pergunta do Roteiro:** *Verificação: `teste-descartavel` não aparece mais em `lxc list`. O que a opção `--force` permitiu fazer?*
- **Resposta:** A opção `--force` permitiu **encerrar e remover imediatamente uma instância que estava em execução (`RUNNING`)** em um único comando (`lxc delete teste-descartavel --force`), sem exigir que o operador executasse `lxc stop teste-descartavel` previamente.

### 5.7 Desafio Opcional · Uma VM Leve
- **Comando verificado:** `lxc info | grep driver` → exibe `driver: lxc | qemu`.
- **Resultado do desafio:** Ao executar `lxc launch ubuntu:22.04 minha-vm --vm`, o LXD identifica que o driver QEMU está instalado, mas como a VM `cloud-lab` roda dentro do VirtualBox no Windows sem repasse de virtualização aninhada por hardware (*Nested VT-x/AMD-V disabled*, ausência do dispositivo `/dev/kvm`), a inicialização da VM falha com erro de ausência de KVM (`KVM support is missing (no /dev/kvm)`). Conforme destacado no roteiro, esse erro comprova na prática a diferença fundamental de requisito entre containers de sistema (que compartilham o kernel do host e não exigem virtualização por hardware) e VMs leves (que exigem aceleração de hardware KVM para rodar um kernel próprio).

### 5.8 Respostas às Perguntas de Reflexão do Roteiro (Aula 5 · Pág. 4) e Slides (Pág. 20)

1. **Que mudança observada no Passo 4 ilustra a característica de elasticidade da nuvem?**
   - **Resposta:** A troca do profile `pequeno` pelo profile `medio` com a instância `minha-instancia` **em plena execução (`RUNNING`)**, fazendo com que o número de CPUs visíveis (`nproc`) dobrasse de `1` para `2` e a memória RAM disponível (`free -m`) subisse de `512 MB` (`488 MiB`) para `2 GB` (`1953 MiB`) instantaneamente, sem reiniciar o container nem interromper seus processos (*vertical scaling* / elasticidade a quente via *cgroups* e `lxcfs`).

2. **Por que o arquivo `depois-do-snapshot` desapareceu no Passo 5? O que isso mostra sobre o que um snapshot preserva?**
   - **Resposta:** Porque um snapshot é uma "fotografia" (*point-in-time*) do estado do sistema de arquivos da instância no exato instante em que foi criado. Tudo o que foi gravado no disco antes da fotografia (`antes-do-snapshot`) é preservado, enquanto qualquer alteração feita após o snapshot (`depois-do-snapshot`) é descartada quando executamos `lxc restore`.

3. **Por que a instância foi criada com dois profiles (`default` e `pequeno`)?**
   - **Resposta:** Porque o LXD trabalha com **profiles em camadas**: o profile `default` define os dispositivos essenciais de infraestrutura (o disco raiz `root` vinculado ao storage pool e a interface de rede `eth0` conectada à bridge `lxdbr0`), enquanto o profile `pequeno` define apenas os limites de recursos (`limits.cpu: "1"` e `limits.memory: 512MB`). Aplicados juntos (`--profile default --profile pequeno`), a instância herda o disco e a rede do `default` combinados com os limites de recursos do `pequeno`.

4. **Qual a diferença entre pausar (`Frozen`) e parar (`Stopped`) uma instância? (Slide 20, Pergunta 3)**
   - **Resposta:** Ao **pausar (`lxc pause` → estado `FROZEN`)**, os processos da instância são apenas congelados pelo kernel (*cgroup freezer*) e permanecem carregados na memória RAM, retomando exatamente do ponto onde pararam com `lxc start`. Já ao **parar (`lxc stop` → estado `STOPPED`)**, o sistema operacional convidado sofre *shutdown*, todos os processos são encerrados e toda a memória RAM alocada pela instância é liberada de volta para o host.

5. **Por que um snapshot não substitui um backup? (Slide 20, Pergunta 4)**
   - **Resposta:** Porque o snapshot vive **dentro do mesmo *storage pool* e do mesmo disco físico** da instância original. Se o disco do servidor host corromper ou o storage pool for perdido, tanto a instância quanto todos os seus snapshots serão perdidos juntos. Um backup real exige exportar a instância/volume para um arquivo externo (`lxc export` / `lxc storage volume export`) e armazená-lo fora do storage pool principal.

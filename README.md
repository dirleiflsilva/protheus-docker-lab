# Protheus Docker Lab

Laboratório pessoal para estudo de Protheus em Docker, com foco em organização de ambiente, documentação como código e práticas DevOps.

> Este laboratório é baseado na documentação pública **Protheus Docker**, mantida pela TOTVS Engineering Pro. As imagens são indicadas para uso de desenvolvimento e não são homologadas para produção.

## Objetivo

Montar um ambiente Protheus reproduzível usando Docker Compose, permitindo estudar:

- padronização de ambiente de desenvolvimento;
- configuração versionada;
- isolamento de serviços;
- documentação operacional;
- práticas iniciais de DevOps aplicadas ao ecossistema Protheus.

## Arquitetura do laboratório

```text
host Linux
│
├── Docker Compose
│   ├── license
│   ├── postgres-iniciado
│   ├── dbaccess-postgres
│   └── appserver
│
├── config/
│   ├── appserver.ini
│   ├── dbaccess.ini
│   ├── odbc.ini
│   └── odbcinst.ini
│
└── volumes/
    ├── apo/
    ├── systemload/
    └── logs/
```

## Serviços

| Serviço | Função |
|---|---|
| `license` | Servidor de licença para o ambiente de desenvolvimento |
| `postgres-iniciado` | Banco PostgreSQL com base Protheus de laboratório |
| `dbaccess-postgres` | Camada DBAccess para comunicação entre AppServer e PostgreSQL |
| `appserver` | AppServer Protheus |

## Organização com Docker Compose

O Compose agrupa os recursos pelo valor de `COMPOSE_PROJECT_NAME`, definido no arquivo `.env`.
Os nomes dos containers são gerados automaticamente a partir do projeto e do serviço, evitando colisões com outros ambientes e mantendo o arquivo compatível com os recursos nativos do Compose.

Para comandos operacionais e comunicação entre containers, utilize os nomes dos serviços, não nomes de containers ou endereços IP:

```bash
docker compose logs -f appserver
docker compose exec dbaccess-postgres sh
```

O laboratório utiliza a rede padrão criada pelo Compose. Nessa rede, cada serviço pode localizar os demais pelo DNS interno:

| Origem | Destino interno | Porta |
|---|---|---|
| `appserver` | `license` | `5555` |
| `appserver` | `dbaccess-postgres` | `7890` |
| `dbaccess-postgres` | `postgres-iniciado` | `5432` |

Somente as portas do AppServer e do WebApp são publicadas no host. As portas do PostgreSQL, DBAccess e License Server não são publicadas e são destinadas à comunicação interna do projeto.

### Ordem de inicialização

O PostgreSQL possui um `healthcheck` com `pg_isready`. O DBAccess usa `condition: service_healthy` e só é iniciado depois que o banco aceita conexões.

Para License Server e DBAccess, `condition: service_started` garante apenas a ordem de criação dos containers. Não significa que esses serviços estejam funcionalmente prontos. Healthchecks adicionais só devem ser incluídos depois de validar comandos ou endpoints compatíveis com as imagens TOTVS utilizadas pelo laboratório.

### Montagens locais

As configurações são montadas como somente leitura. Os diretórios que precisam receber dados do ambiente permanecem graváveis:

| Conteúdo | Modo | Motivo |
|---|---|---|
| `config/appserver.ini` | somente leitura | Configuração do AppServer |
| `config/dbaccess.ini` e arquivos ODBC | somente leitura | Configuração gerada localmente |
| `volumes/apo/tttm120.rpo` | leitura e escrita | RPO de trabalho do laboratório |
| `volumes/systemload/` | leitura e escrita | O AppServer exige escrita ou lock neste ambiente |
| `volumes/logs/` | leitura e escrita | Persistência dos logs do AppServer |

## Pré-requisitos

- Linux Mint, Ubuntu ou distribuição compatível;
- Docker instalado;
- Docker Compose instalado;
- acesso aos artefatos necessários do Protheus, quando aplicável:
  - `tttm120.rpo`;
  - `sxsbra.txt`;
  - `sx2.unq`.

## Preparação

Coloque os artefatos obtidos para o laboratório em `files/`:

```bash
files/tttm120.rpo
files/sxsbra.txt
files/sx2.unq
```

Execute a preparação automática:

```bash
./scripts/setup.sh
```

O script:

- verifica a disponibilidade do Docker e do Docker Compose;
- cria `.env` e `config/appserver.ini` somente quando estão ausentes;
- cria os diretórios de volumes;
- copia os artefatos de `files/` sem sobrescrever cópias de trabalho existentes;
- informa quais artefatos obrigatórios estão ausentes ou vazios;
- gera as configurações do DBAccess na primeira preparação ou com `--force`;
- executa a validação final sem iniciar os containers.

Os arquivos editáveis e as cópias de trabalho existentes são preservados. As três configurações derivadas do DBAccess são tratadas como um conjunto: se todas existirem, são reutilizadas; se apenas parte delas existir, a preparação solicita regeneração explícita.

Para atualizar as cópias de trabalho com os artefatos disponíveis em `files/` e regenerar o conjunto do DBAccess, use:

```bash
./scripts/setup.sh --force
```

Essa opção pode substituir o RPO e os arquivos de `systemload` dos volumes de trabalho. Ela não altera `.env`, `config/appserver.ini`, o banco PostgreSQL nem os volumes de dados do banco.

Para recriar essa configuração depois de alterar `.env`, execute diretamente:

```bash
./scripts/generate-dbaccess.sh
```

O gerador executa o `dbaccesscfg` da própria imagem definida em `.env` e cria:

- `config/dbaccess.ini`, com a senha codificada no formato esperado pelo DBAccess;
- `config/odbc.ini`, com o DSN `protheus`;
- `config/odbcinst.ini`, registrando o driver ANSI `psqlodbca.so`.

> O arquivo `config/dbaccess.ini` efetivo deve ser gerado pelo script para evitar corrupção da senha codificada.
> Os arquivos `config/odbc.ini` e `config/odbcinst.ini` também são locais e são montados diretamente no container do DBAccess.

A estrutura esperada do `config/dbaccess.ini` gerado é:

```ini
[General]
MAXSTRINGSIZE=100
LicenseServer=license
LicensePort=5555
AdjustColName=1
ConsoleLog=1
ConsoleMaxSize=20971520
CountAllConnections=1
ODBC30=1
ODBCConnectionPool=1
Port=7890
ReleaseInactiveConn=30
ShowAllErrors=0
UseLargeRecno=1
AuditLog=0

[POSTGRES/protheus]
user=postgres
password=<senha codificada pelo dbaccesscfg>
TableSpace=
IndexSpace=
ConnectionMode=2
ConnectionString=DRIVER={PostgreSQL};SERVERNAME=postgres-iniciado;PORT=5432;DATABASE=protheus;USERNAME=postgres;PASSWORD=postgres

[POSTGRES]
environments=protheus
ClientLibrary=/usr/lib64/libodbc.so
```

### Preparação manual

Se quiser executar cada etapa separadamente:

```bash
cp .env.example .env
chmod 600 .env
cp config/appserver.ini.example config/appserver.ini
mkdir -p volumes/apo volumes/systemload volumes/logs
cp files/tttm120.rpo volumes/apo/tttm120.rpo
cp files/sxsbra.txt volumes/systemload/sxsbra.txt
cp files/sx2.unq volumes/systemload/sx2.unq
./scripts/generate-dbaccess.sh
./scripts/check.sh
```

> Os arquivos em `files/` e `volumes/` são locais do laboratório e não devem ser publicados no repositório.
> O RPO em `volumes/apo/` é uma cópia de trabalho do laboratório; mantenha uma origem limpa fora de `volumes/` caso precise restaurar o ambiente.
> No container AppServer, a pasta `volumes/systemload` é montada inteira e com permissão de escrita. Neste lab, o AppServer reportou `SXSBRA.TXT not found` quando a pasta foi montada como somente leitura.
> Os arquivos de `systemload` permanecem em minúsculas no host para seguir o padrão esperado em instalações Linux.

Antes de subir o ambiente, valide os arquivos obrigatórios:

```bash
./scripts/check.sh
```

Os scripts `setup.sh`, `check.sh` e `generate-dbaccess.sh` podem ser chamados de qualquer diretório. O arquivo `.env` é interpretado pelo próprio Docker Compose e não é executado como código Shell.

Além dos arquivos obrigatórios, `check.sh` valida:

- Docker e Docker Compose;
- variáveis obrigatórias e portas configuradas;
- configuração efetiva do Compose;
- arquivos ausentes, vazios, ilegíveis ou que não sejam regulares;
- correspondência básica entre `.env`, `appserver.ini`, `dbaccess.ini` e `odbc.ini`.

## Subindo o laboratório

```bash
./scripts/up.sh
```

Ou diretamente:

```bash
./scripts/check.sh
docker compose up -d
```

## Verificando logs

```bash
./scripts/logs.sh
```

Ou:

```bash
docker compose logs -f appserver
```

## Pausando e retomando o ambiente

Para interromper o uso e continuar com os mesmos containers e dados:

```bash
./scripts/stop.sh
./scripts/start.sh
```

`start.sh` inicia apenas containers já criados. Na primeira inicialização, use `up.sh`.

## Removendo os containers

O comando abaixo remove os containers. Faça backup antes: o PostgreSQL desta imagem usa um volume anônimo, que não é reutilizado automaticamente após `down` seguido de `up`.

```bash
./scripts/down.sh
```

Para o uso diário, prefira `stop.sh` e `start.sh`. Consulte os procedimentos de [dados e manutenção](docs/parte-4/README.md) antes de recriar containers.

## Parte 4 — Dados e manutenção

Os procedimentos de persistência, backup do PostgreSQL, restauração em banco separado e manutenção estão no [README da parte 4](docs/parte-4/README.md), junto das evidências de validação e dos limites dessa etapa.

## Parte 5 — Validação DevOps e limites do laboratório

O [workflow de validação](.github/workflows/validacao.yml) verifica a configuração do Compose com `.env.example`, a sintaxe Bash e os testes com Docker simulado em pushes e pull requests. Os comandos para reproduzir as verificações, a validação funcional complementar e os limites da série estão no [README da parte 5](docs/parte-5/README.md).

A [execução do GitHub Actions referente ao commit `a4cd7ee`](https://github.com/dirleiflsilva/protheus-docker-lab/actions/runs/35935070926) foi concluída com sucesso em 23/09/2026, com aprovação da configuração do Compose, da sintaxe Bash e dos testes com Docker simulado. Essa evidência valida a CI da parte 5; a validação funcional do ERP permanece separada.

## Portas expostas

| Porta | Uso |
|---|---|
| `1234` | conexão TCP AppServer |
| `8080` | WebApp |

## Ambiente Protheus

O AppServer usa o ambiente `PROTHEUS_DOCKER`, definido em `config/appserver.ini`.
Os caminhos do exemplo oficial em Windows foram adaptados para os diretórios Linux usados dentro do container:

| Configuração | Caminho no container |
|---|---|
| `SourcePath` | `/opt/totvs/protheus/apo` |
| `RootPath` | `/opt/totvs/protheus/protheus_data` |
| `DBAccess Server` | `dbaccess-postgres` |
| `License Server` | `license` |

O RPO base do laboratório fica no diretório indicado por `SourcePath`.
`RpoCustom` aponta para um RPO de customizações, como `custom.rpo`, e fica documentado no `appserver.ini.example` por se tratar de um laboratório de desenvolvimento.

## Serviços futuros

Este laboratório mantém apenas os serviços necessários para validar o AppServer, WebApp, DBAccess, PostgreSQL e License Server.
REST e outros serviços do ecossistema Protheus serão tratados em laboratórios futuros para manter este primeiro ambiente simples e estável.

## Conexão com DevOps

Este laboratório pode ser usado como base para demonstrar conceitos de DevOps em ambientes Protheus:

### 1. Ambiente reproduzível

O `docker-compose.yml` descreve os serviços necessários para subir o ambiente de forma padronizada.

### 2. Configuração como código

Arquivos de exemplo como `.env.example` e `appserver.ini.example` ficam organizados e versionáveis.
O `dbaccess.ini` efetivo é gerado pelo `scripts/generate-dbaccess.sh`, pois contém senha codificada pelo `dbaccesscfg`.
Os arquivos reais de ambiente permanecem locais e fora do Git.

### 3. Isolamento

Cada componente do ambiente roda em seu próprio container, reduzindo conflitos com a máquina local.

### 4. Automação operacional

Scripts simples em `scripts/` reduzem comandos repetitivos e ajudam a documentar o fluxo de operação.
O `scripts/check.sh` valida a preparação mínima antes do `docker compose up`.

### 5. Base para evolução

A estrutura inclui automação local, backup/restore do PostgreSQL e validações básicas no GitHub Actions. Atualizações de imagens continuam exigindo validação de compatibilidade e plano de retorno.

## O que não é objetivo deste laboratório

- Produção;
- homologação oficial de ambiente Protheus;
- substituição de instalação tradicional em cliente;
- criação de imagem Docker própria do Protheus neste primeiro momento.

## Limitações conhecidas

- O PostgreSQL usa `healthcheck` com `pg_isready`, e o DBAccess só inicia depois que o banco fica `healthy`.
- O `depends_on` do Docker Compose controla a ordem de inicialização dos demais serviços, mas não substitui validações funcionais completas.
- As variáveis em `.env` parametrizam o Compose, mas os arquivos `.ini` de exemplo ainda usam valores explícitos para facilitar a leitura inicial.
- O RPO base deve ser carregado pelo `SourcePath`; `RpoCustom` fica reservado para customizações e não deve apontar para o RPO base.
- Os artefatos Protheus, como RPO e arquivos de systemload, precisam ser obtidos separadamente e mantidos fora do Git.
- Este laboratório usa imagens de desenvolvimento da TOTVS Engineering Pro e não representa uma topologia de produção.

## Roadmap da série

Este repositório organiza uma série enxuta de cinco partes sobre Protheus, Docker e práticas iniciais de DevOps.
O objetivo é validar conceitos essenciais em um ambiente de desenvolvimento. REST, observabilidade centralizada e cenários corporativos ficam para outros laboratórios.

| Parte | Tema | Status |
|---|---|---|
| 1 | Criando um laboratório Protheus com Docker | Validado |
| 2 | Organização do projeto e boas práticas com Docker Compose | Validado |
| 3 | Automação e configuração local | Validado |
| 4 | [Dados e manutenção do ambiente](docs/parte-4/README.md) | Validado: backup e restauração em banco separado |
| 5 | [Validação DevOps e limites do laboratório](docs/parte-5/README.md) | Validado: Compose, sintaxe Bash e testes aprovados no GitHub Actions |

## Testes dos scripts

Os testes usam um Docker simulado e não iniciam containers nem baixam imagens:

```bash
./tests/test-scripts.sh
```

## Referências

- [Protheus Docker - TOTVS Engineering Pro](https://docker-protheus.engpro.totvs.com.br/)

## Próximas evoluções possíveis

Após concluir as cinco partes, novos repositórios ou laboratórios podem explorar:

- serviços REST e componentes adicionais do ecossistema Protheus;
- observabilidade e centralização de logs;
- pipelines corporativos de entrega;
- uso com fontes AdvPL/TL++ versionados;
- requisitos de segurança, disponibilidade e operação que não se aplicam a estas imagens de desenvolvimento.

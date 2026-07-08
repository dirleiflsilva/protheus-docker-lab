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

## Pré-requisitos

- Linux Mint, Ubuntu ou distribuição compatível;
- Docker instalado;
- Docker Compose instalado;
- acesso aos artefatos necessários do Protheus, quando aplicável:
  - `tttm120.rpo`;
  - `sxsbra.txt`;
  - `sx2.unq`.

## Preparação

Copie o arquivo de variáveis:

```bash
cp .env.example .env
```

Copie a configuração do AppServer:

```bash
cp config/appserver.ini.example config/appserver.ini
```

Gere a configuração efetiva do DBAccess:

```bash
./scripts/generate-dbaccess.sh
```

Esse script executa o `dbaccesscfg` da própria imagem definida em `.env` e gera:

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

Crie os diretórios de volumes locais, caso ainda não existam:

```bash
mkdir -p volumes/apo volumes/systemload volumes/logs
```

Copie os arquivos do Protheus para os diretórios esperados pelo `docker-compose.yml`.
Se você mantiver os artefatos temporariamente em `files/`, use:

```bash
cp files/tttm120.rpo volumes/apo/tttm120.rpo
cp files/sxsbra.txt volumes/systemload/sxsbra.txt
cp files/sx2.unq volumes/systemload/sx2.unq
```

> Os arquivos em `files/` e `volumes/` são locais do laboratório e não devem ser publicados no repositório.
> O RPO em `volumes/apo/` é uma cópia de trabalho do laboratório; mantenha uma origem limpa fora de `volumes/` caso precise restaurar o ambiente.
> No container AppServer, a pasta `volumes/systemload` é montada inteira e com permissão de escrita. Neste lab, o AppServer reportou `SXSBRA.TXT not found` quando a pasta foi montada como somente leitura.
> Os arquivos de `systemload` permanecem em minúsculas no host para seguir o padrão esperado em instalações Linux.

Antes de subir o ambiente, valide os arquivos obrigatórios:

```bash
./scripts/check.sh
```

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

## Derrubando o ambiente

```bash
./scripts/down.sh
```

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

A estrutura pode evoluir para incluir healthchecks, backup/restore do PostgreSQL, pipeline CI/CD, validações automáticas e observabilidade.

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

Este repositório é o primeiro passo de uma série de laboratórios sobre Protheus, Docker e práticas DevOps.
REST, serviços adicionais e cenários corporativos ficam para etapas futuras, mantendo este primeiro ambiente simples, reproduzível e estável.

| Parte | Tema | Status |
|---|---|---|
| 1 | **Criando um laboratório Protheus com Docker** | Validado |
| 2 | Organização do projeto e boas práticas com Docker Compose | Planejado |
| 3 | Automatizando o ambiente com scripts e Makefile | Planejado |
| 4 | Gerenciamento de configurações com `.env` | Planejado |
| 5 | Persistência de dados e volumes Docker | Planejado |
| 6 | Atualizando imagens do Protheus com segurança | Planejado |
| 7 | Integrando o laboratório com GitHub Actions | Planejado |
| 8 | Observabilidade: logs do AppServer e DBAccess | Planejado |
| 9 | Backup e restauração do PostgreSQL no laboratório | Planejado |
| 10 | Do laboratório ao DevOps: o que muda em um ambiente corporativo? | Planejado |

## Referências

- [Protheus Docker - TOTVS Engineering Pro](https://docker-protheus.engpro.totvs.com.br/)

## Próximas evoluções possíveis

- criar script de backup do PostgreSQL;
- incluir Makefile;
- adicionar GitHub Actions apenas para validação dos arquivos;
- evoluir a documentação de troubleshooting conforme novos cenários aparecerem;
- incluir logs centralizados;
- estudar uso com fontes AdvPL/TL++ versionados.

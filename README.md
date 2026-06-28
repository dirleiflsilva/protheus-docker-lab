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
│   └── dbaccess.ini
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

Copie os arquivos de configuração de exemplo:

```bash
cp config/appserver.ini.example config/appserver.ini
cp config/dbaccess.ini.example config/dbaccess.ini
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

O AppServer usa o ambiente `PROTHEUS-DOCKER`, definido em `config/appserver.ini`.
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

Arquivos de exemplo como `.env.example`, `appserver.ini.example` e `dbaccess.ini.example` ficam organizados e versionáveis.
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

- O `depends_on` do Docker Compose controla ordem de inicialização, mas não garante que PostgreSQL, DBAccess ou License Server estejam prontos para uso.
- As variáveis em `.env` parametrizam o Compose, mas os arquivos `.ini` de exemplo ainda usam valores explícitos para facilitar a leitura inicial.
- O RPO base deve ser carregado pelo `SourcePath`; `RpoCustom` fica reservado para customizações e não deve apontar para o RPO base.
- Os artefatos Protheus, como RPO e arquivos de systemload, precisam ser obtidos separadamente e mantidos fora do Git.
- Este laboratório usa imagens de desenvolvimento da TOTVS Engineering Pro e não representa uma topologia de produção.

## Roadmap da série

Este repositório é o primeiro passo de uma série de laboratórios sobre Protheus, Docker e práticas DevOps.
REST, serviços adicionais e cenários corporativos ficam para etapas futuras, mantendo este primeiro ambiente simples, reproduzível e estável.

| Parte | Tema | Status |
|---|---|---|
| 1 | **Criando um laboratório Protheus com Docker** | Em andamento |
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

- adicionar healthchecks no Docker Compose;
- criar script de backup do PostgreSQL;
- incluir Makefile;
- adicionar GitHub Actions apenas para validação dos arquivos;
- documentar troubleshooting;
- incluir logs centralizados;
- estudar uso com fontes AdvPL/TL++ versionados.

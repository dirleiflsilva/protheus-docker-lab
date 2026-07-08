# Anotações do Laboratório

## Objetivo do experimento

Registrar a montagem de um ambiente Protheus com Docker, usando os componentes oficiais de desenvolvimento disponibilizados pela TOTVS Engineering Pro.

## Hipótese

Um ambiente Protheus em Docker pode reduzir o tempo de preparação de laboratório, facilitar testes locais e servir como base para práticas DevOps.

## Evidências a coletar

- tempo para subir o ambiente;
- containers ativos;
- logs do AppServer;
- acesso ao WebApp;
- conexão com DBAccess;
- conexão com PostgreSQL;
- problemas encontrados e correções aplicadas.

## Comandos úteis

```bash
docker compose ps
docker compose logs -f appserver
docker compose logs -f dbaccess-postgres
docker compose down
docker compose up -d
```

## Troubleshooting

### AppServer não sobe

Verificar:

- arquivo `appserver.ini`;
- existência do `tttm120.rpo`;
- montagem dos volumes;
- logs do container.

#### Erro `Cant connect on Lock Server`

Se o log apresentar mensagens como:

```text
Cant connect on Lock Server: appserver:1234
Fail to Start WebMonitor
```

Verificar se existe uma seção `[lockserver]` apontando para o próprio `appserver` na mesma porta TCP do serviço.
Para este laboratório inicial, o AppServer deve subir sem essa seção explícita.

### DBAccess não conecta

Verificar:

- `dbaccess.ini`;
- nome do serviço PostgreSQL;
- usuário e senha;
- seção `[POSTGRES/protheus]` com o alias usado pelo AppServer;
- `ClientLibrary=/usr/lib64/libodbc.so` na seção `[POSTGRES]`;
- logs do DBAccess.

#### Erro `NO_DB_CONNECTION`

Se o AppServer apresentar:

```text
Error - TOPCONN - No connection: -35 - NO_DB_CONNECTION
```

Verificar o log interno do DBAccess:

```bash
docker compose exec -T dbaccess-postgres tail -n 120 /opt/totvs/dbaccess/multi/dbconsole.log
docker compose exec -T dbaccess-postgres tail -n 120 /opt/totvs/dbaccess/multi/dbaccess.log
```

Se o DBAccess registrar a mensagem abaixo logo após o `docker compose up`, o problema é uma corrida de inicialização: o AppServer tentou abrir conexão antes de o PostgreSQL aceitar conexões.

```text
FATAL:  the database system is not yet accepting connections
```

Neste caso, o Compose deve manter um `healthcheck` no serviço `postgres-iniciado` usando `pg_isready`, e o serviço `dbaccess-postgres` deve depender de `postgres-iniciado` com `condition: service_healthy`.

Neste laboratório, a conexão com PostgreSQL passou a funcionar quando:

- o `dbaccess.ini` foi mantido com a senha codificada original gerada pelo `dbaccesscfg`;
- a seção `[General]` do DBAccess recebeu `ODBC30=1`, `ODBCConnectionPool=1` e `Port=7890`;
- o arquivo local `config/odbc.ini` passou a ser montado como `/etc/odbc.ini`, criando o DSN ODBC `protheus`;
- o driver PostgreSQL do unixODBC passou a usar o driver ANSI `psqlodbca.so`;
- o nome esperado `libpsqlodbc.so` passou a apontar para o gerenciador ODBC `/usr/lib64/libodbc.so`;
- o AppServer passou a usar a seção `[DBAccess]` em vez de `DBDataBase`, `DBAlias`, `DBServer` e `DBPort` dentro do ambiente;
- o nome do ambiente foi alterado de `PROTHEUS-DOCKER` para `PROTHEUS_DOCKER`, pois a release 12.1.2510 não aceita hífen em nome de ambiente.

O arquivo `dbaccess.ini` não deve ser editado por ferramentas que convertam os bytes da senha para UTF-8 com caracteres de substituição (`�`). Se isso acontecer, regenere o arquivo com `dbaccesscfg`.

No rebuild limpo de 2026-07-07, a senha corrigida sozinha não foi suficiente. Sem os ajustes ODBC, o DBAccess falhou antes de autenticar no banco:

```text
Invalid client library [libpsqlodbc.so] (ODBC)
Connection [POSTGRES/PROTHEUS] could not load config client library [libpsqlodbc.so]
```

Após mapear `libpsqlodbc.so` para `libodbc.so` e criar o DSN `protheus`, o log passou a mostrar conexão em modo DSN:

```text
Connection [POSTGRES/PROTHEUS] using client library [libpsqlodbc.so] (ODBC10)
ODBC DBMS Name.............: PostgreSQL
ODBC Data Source Name......: PROTHEUS
ODBC Driver Name...........: psqlodbca.so
ODBC Connection Mode ......: DSN
```

#### Login inicial

Na base PostgreSQL usada neste laboratório, o usuário encontrado em `sys_usr` foi:

```text
usr_codigo=Administrador
usr_nome=Administrador
```

Não foi encontrado usuário `Admin` ou `admin`.

### SIGAADV falha com `Failed to load APPMAP`

Se o WebApp abrir, mas o acesso ao `SIGAADV` retornar:

```text
Failed to load APPMAP
The configuration registry key cannot be written
```

Verificar se `RpoCustom` não está apontando para o RPO base do laboratório.
Neste lab, o RPO base deve ficar apenas no diretório configurado em `SourcePath`; `RpoCustom` deve ser reservado para um RPO de customizações.

### Arquivos do systemload ausentes

Verificar se os arquivos abaixo existem:

```bash
ls -lh volumes/systemload/
```

Arquivos esperados:

- `sx2.unq`;
- `sxsbra.txt`.

O `docker-compose.yml` monta a pasta `volumes/systemload` inteira no container AppServer e sem `:ro`.

No teste de 2026-07-08, a pasta com `:ro` fez o Protheus voltar a apresentar:

```text
File \systemload\SXSBRA.TXT not found.
```

Como os arquivos existiam e eram legíveis dentro do container, a hipótese validada para este lab é que o AppServer abre os arquivos de `systemload` com algum modo que exige escrita ou lock. Por isso, `systemload` permanece gravável.

O teste definitivo de 2026-07-08 funcionou sem links em maiúsculas. O comportamento validado para este lab é manter apenas os arquivos em minúsculas no host:

- `sx2.unq`;
- `sxsbra.txt`.

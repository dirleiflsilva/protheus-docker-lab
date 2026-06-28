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

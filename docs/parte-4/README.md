# Parte 4 — Dados e manutenção do ambiente

[Voltar ao README principal](../../README.md)

Esta etapa reúne os procedimentos de persistência, backup, restauração e manutenção do laboratório. Execute os comandos abaixo a partir da raiz do repositório.

## Onde os dados ficam

| Conteúdo | Armazenamento atual | Cuidado operacional |
|---|---|---|
| PostgreSQL | Volume anônimo em `/var/lib/postgresql/data`, declarado pela imagem | Usar `stop`/`start` para conservar o container e sua montagem |
| RPO de trabalho | `volumes/apo/tttm120.rpo` | Preservar a origem em `files/` e copiar a versão de trabalho antes de substituir |
| Systemload | `volumes/systemload/` | Pode receber escrita; copiar com AppServer parado |
| Logs montados | `volumes/logs/` | Inspecionar espaço; não apagar automaticamente |
| Configuração local | `.env` e `config/*.ini` | Contém credenciais; guardar cópia privada |

O Compose não declara um volume nomeado para PostgreSQL. A imagem local `totvsengpro/postgres-dev:12.1.2510_bra` declara o volume anônimo e o servidor confirmou o mesmo diretório com `SHOW data_directory`.
`docker compose down` preserva esse volume por padrão, mas um `up` posterior não o remonta automaticamente. Essa distinção está descrita na [documentação do Docker](https://docs.docker.com/reference/cli/docker/compose/down/).

Não foi feita migração de volumes nesta etapa. Antes de adotar um volume nomeado, identifique o volume atual, faça backup e planeje a migração; uma montagem nova não transfere os dados existentes.
Outros arquivos gravados apenas na camada do container, inclusive fora dos bind mounts do AppServer, também exigem inventário antes da recriação. O backup abaixo não é uma cópia completa do ambiente Protheus.

## Backup do PostgreSQL

```bash
docker compose up -d postgres-iniciado
docker compose ps
./scripts/backup.sh
```

Espere o banco ficar `healthy`. O script utiliza `pg_dump --format=custom` dentro do serviço, com usuário, banco e porta obtidos de `docker compose config --environment`. Não executa `.env` como Shell e usa autenticação por socket local da imagem; se ela exigir autenticação adicional, o comando falha sem solicitar senha interativamente.

Cada execução cria um diretório exclusivo em `backups/`, com permissões restritas. O arquivo só recebe o nome `database.dump` depois que o dump e a leitura do catálogo com `pg_restore --list` terminam com sucesso. Em falha, o `.partial` é preservado para diagnóstico e não deve ser usado como backup concluído.

O dump cobre um banco, não os papéis globais, tablespaces, RPO, arquivos locais nem configurações. Copie os backups concluídos para outro local privado; uma cópia no mesmo disco não protege contra falha desse disco. Não há retenção ou exclusão automática.

## Ensaio de recuperação

Use somente backups de origem confiável. Substitua o caminho pelo resultado do backup:

```bash
./scripts/restore.sh backups/postgres-<data>-<identificador>/database.dump protheus_validacao
```

O script verifica o catálogo, cria um banco com `template0` e restaura em uma transação. Se o destino existir, `createdb` falha antes da importação. Uma falha de importação mantém o banco criado para diagnóstico, sem remover dados automaticamente.

A restauração usa `--no-owner --no-acl`: os objetos ficam com o usuário da restauração, sem reproduzir os privilégios originais. Trata-se de um ensaio dos dados e objetos no laboratório, não de uma recuperação completa de usuários e permissões. O comportamento das opções está na [documentação do PostgreSQL 15](https://www.postgresql.org/docs/15/app-pgrestore.html).

Compare tabelas e registros relevantes entre origem e destino, por exemplo, com o usuário padrão deste lab:

```bash
docker compose exec -T postgres-iniciado psql -U postgres -d protheus -c 'SELECT count(*) FROM public.sys_usr;'
docker compose exec -T postgres-iniciado psql -U postgres -d protheus_validacao -c 'SELECT count(*) FROM public.sys_usr;'
```

Adapte usuário e nomes à configuração local. Uma contagem igual é uma evidência parcial; o teste funcional do ERP continua necessário para uma recuperação operacional. O AppServer permanece conectado à origem. A troca do banco usado pelo ERP e a remoção de bancos de teste são operações posteriores, deliberadas.

## Rotina de manutenção

1. Consulte `docker compose ps` e `docker compose logs --tail=100`.
2. Confira espaço com `df -h .`, `du -sh backups volumes` e `docker system df`.
3. Antes de alterar artefatos, pare o AppServer e o DBAccess com `docker compose stop appserver dbaccess-postgres`.
4. Faça o backup do banco e copie os arquivos locais necessários para um diretório privado. Com esses serviços parados, banco e arquivos não recebem alterações deles durante a cópia.
5. Após a manutenção, execute `./scripts/check.sh` e retome os containers existentes com `./scripts/start.sh`; confira logs e acesso ao ERP.

Não copie o diretório físico de um PostgreSQL em execução como substituto do dump. Não use `down -v`, `prune` ou exclusão de volumes como rotina de manutenção. Atualizações de imagens e mudanças de versão do PostgreSQL exigem validação de compatibilidade e plano de retorno próprios.

## Evidências da execução em 12/09/2026

- Imagem local: `totvsengpro/postgres-dev:12.1.2510_bra`; servidor PostgreSQL 15.2.
- Backup real gerado em formato custom, aproximadamente 32 MiB, com catálogo legível.
- Restauração concluída em `protheus_validacao_20260912`, sem substituir a origem.
- Origem e destino: 126 tabelas em `pg_stat_user_tables` e 1 registro em `public.sys_usr`.
- Tentativas de restauração sobre `protheus` e sobre o destino já existente recusadas.
- Pausa e retomada executadas com `stop.sh` e `start.sh`; banco restaurado consultado após a retomada, com o registro preservado.
- Sintaxe dos scripts verificada com `bash -n`; suíte existente `tests/test-scripts.sh` aprovada. `shellcheck` indisponível no host.

O backup e o banco de validação foram preservados. Essas evidências validam o fluxo de backup e restauração no PostgreSQL; não representam homologação funcional do ERP nem migração para volume nomeado.

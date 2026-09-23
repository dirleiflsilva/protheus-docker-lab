# Parte 5 — Validação DevOps e limites do laboratório

[Voltar ao README principal](../../README.md)

Esta etapa encerra a série com integração contínua (CI) para a configuração versionada e os scripts. O workflow [Validação do laboratório](../../.github/workflows/validacao.yml) executa em pushes, pull requests e por acionamento manual na aba Actions do GitHub.

## O que a automação valida

| Verificação | Evidência produzida | Limite |
|---|---|---|
| Compose com `.env.example` | Configuração aceita pelo Docker Compose | Não verifica existência das imagens, arquivos montados ou disponibilidade dos serviços |
| `bash -n` em `scripts/` e `tests/` | Sintaxe Bash válida, incluindo a biblioteca de PostgreSQL | Não executa nem comprova o comportamento dos comandos |
| `tests/test-scripts.sh` | Cenários de preparação, preservação de arquivos, configuração inválida e falha do gerador | Usa Docker simulado; não testa o ERP nem executa backup e restauração reais |

A suíte também verifica que o conteúdo de `.env` não é executado como Shell e que a senha de teste não aparece na saída de uma falha simulada do gerador. Isso cobre esses cenários específicos, sem substituir uma revisão de segurança.

O runner utiliza Ubuntu 24.04 e permissão de leitura do repositório. Não precisa de secrets, RPO, systemload ou configurações locais. Nenhuma etapa inicia containers, baixa imagens TOTVS, publica artefatos ou faz deploy. Os arquivos fictícios usados nos testes ficam em diretórios temporários próprios, removidos ao final da suíte.

## Reproduzir as verificações localmente

Na raiz do repositório, com Bash, Docker CLI e Docker Compose disponíveis:

```bash
docker compose --env-file .env.example -f docker-compose.yml config --quiet

while IFS= read -r -d '' script; do
  bash -n "$script" || exit 1
done < <(find scripts tests -type f -name '*.sh' -print0)

./tests/test-scripts.sh
```

Esses comandos não exigem a preparação do ambiente nem o daemon Docker em execução. O Compose usa explicitamente `.env.example`; variáveis exportadas no Shell ainda podem sobrescrever valores de interpolação. Para reproduzir os valores da CI, execute em um terminal sem sobrescritas das variáveis do projeto.

O modo `config --quiet` valida sem imprimir a configuração resolvida, conforme a [referência oficial do Docker Compose](https://docs.docker.com/reference/cli/docker/compose/config/). Se disponível, ShellCheck pode complementar a análise local dos scripts; não é requisito deste workflow.

## Validação do ambiente real

A aprovação da CI permite revisar a configuração e os cenários simulados. Para validar o laboratório preparado, execute:

```bash
./scripts/check.sh
docker compose ps
docker compose logs --tail=100 appserver dbaccess-postgres license postgres-iniciado
```

Depois de iniciar o ambiente conforme o README principal, confira o acesso ao WebApp na porta configurada e a abertura do ambiente `PROTHEUS_DOCKER`. Verifique a comunicação AppServer → DBAccess → PostgreSQL e AppServer → License Server pelos logs e pelo uso do ERP. Container iniciado e porta acessível não comprovam readiness funcional.

Para validar recuperação de dados, siga o [ensaio da parte 4](../parte-4/README.md). Ele restaura em banco separado e não comprova, sozinho, a recuperação completa do ERP. Não execute operações de restauração sobre a origem como parte da CI.

## Encerramento e limites

As cinco partes cobrem configuração em Compose, organização, automação local, manutenção dos dados e validações contínuas. Permanecem os seguintes limites:

- As imagens TOTVS são destinadas a desenvolvimento; este projeto não é uma arquitetura homologada para produção.
- Algumas imagens usam tags implícitas e podem mudar. A CI não garante reprodutibilidade binária nem compatibilidade entre novas versões; atualizações exigem ensaio e plano de retorno.
- O banco usa volume anônimo. `down` seguido de `up` não reutiliza esse volume automaticamente; prefira `stop`/`start` e siga os cuidados da parte 4.
- O dump do PostgreSQL não inclui RPO, systemload, configurações locais nem todos os arquivos gravados na camada dos containers.
- Licenciamento, disponibilidade funcional, desempenho e recuperação completa dependem de verificações no ambiente real.
- Não há deploy automático, alta disponibilidade, gestão corporativa de secrets ou observabilidade centralizada nesta série.

Após publicar o workflow, consulte a execução na aba Actions. Uma execução remota só deve ser registrada como aprovada depois de efetivamente terminar com sucesso.

## Evidências da validação local em 23/09/2026

- Docker Compose v5.5.1: configuração aceita com `.env.example` e `config --quiet`.
- Sintaxe de todos os arquivos `.sh` em `scripts/` e `tests/` aprovada com `bash -n`.
- Os 12 cenários de `tests/test-scripts.sh` passaram com Docker simulado.
- `git diff --check` sem erros de whitespace nos arquivos rastreados alterados.
- ShellCheck indisponível no host; análise adicional não executada.
- Nenhum container foi iniciado ou alterado nesta validação. Teste funcional do ERP e execução remota do workflow não foram realizados nesta etapa.

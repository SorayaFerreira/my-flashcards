# Planos de implementação

Cada etapa do [design](../design.md) tem um plano próprio, com tarefas pequenas, código completo, testes e commits. As etapas são feitas **em ordem**: cada plano parte do código que o anterior deixou.

| # | Plano | Entrega |
|---|---|---|
| 0 | [00-ambiente-e-projeto.md](00-ambiente-e-projeto.md) | Flutter instalado, projeto criado e um app vazio rodando no celular |
| 1 | [01-dados-e-decks.md](01-dados-e-decks.md) | Banco de dados e tela de decks (criar, renomear, excluir) |
| 2 | [02-cards-de-texto.md](02-cards-de-texto.md) | Tela do deck e editor de cards só com texto |
| 3 | [03-revisao.md](03-revisao.md) | Revisão com o card que vira ao arrastar e o contador. **O app já fica usável** |
| 4 | [04-imagens.md](04-imagens.md) | Imagens pela câmera e pela galeria |
| 5 | [05-audio.md](05-audio.md) | Gravar e tocar áudio |
| 6 | [06-lembrete.md](06-lembrete.md) | Lembrete diário em horário aleatório e tela de configurações |
| 7 | [07-backup.md](07-backup.md) | Exportar e importar backup |
| 8 | [08-acabamento-e-release.md](08-acabamento-e-release.md) | Splash, assinatura, APK de release e checklist final |

## Ambiente

O Flutter deste projeto vem do **FVM**, na versão 3.47.5, fixada pelo `.fvmrc` na etapa 0. Os planos escrevem os comandos como `flutter ...`, mas o jeito de rodar depende de onde:

- **No terminal da Soraya:** `flutter` é um alias de `fvm flutter`, então os comandos funcionam como estão escritos.
- **Em scripts e agentes** (shell não interativo, sem o alias): troque `flutter` por `fvm flutter`.
- **`dart run`:** use sempre `fvm dart run`. O `dart` do terminal é o `/usr/bin/dart` do sistema, e não o do Flutter.

O Gradle usa o JDK 17 configurado no Flutter (`/usr/lib/jvm/java-17-openjdk`).

## Como executar um plano

1. Antes da etapa 0, o branch `planejamento` (que tem esta pasta `docs/`) precisa estar no `main`:
   ```bash
   git switch main && git merge --ff-only planejamento
   ```
2. Cada etapa começa com um branch próprio, criado a partir do `main` atualizado. O nome de cada branch aparece no início do plano.
3. As tarefas são feitas na ordem em que aparecem. Cada passo tem uma caixa (`- [ ]`) para marcar.
4. Toda tarefa de código segue o TDD:
   1. escrever o teste;
   2. rodar e ver o teste falhar;
   3. implementar;
   4. rodar e ver o teste passar;
   5. fazer o commit.
5. Ao fim da etapa, `flutter analyze` não pode mostrar nenhum problema e `flutter test` precisa passar inteiro.
6. **Os testes no celular são feitos pela Soraya.** Quem executa o plano para nesse ponto e entrega a ela o checklist manual da etapa. Os itens do checklist só são marcados com o retorno dela, nunca por suposição. O mesmo vale para os passos que precisam do aparelho, como autorizar a depuração USB, aceitar permissões ou mexer no relógio.
7. Com o checklist confirmado por ela, o branch entra no `main`:
   ```bash
   git switch main && git merge --no-ff etapa-N-nome && git branch -d etapa-N-nome
   ```

## Convenções de código

- **Os identificadores no código ficam em inglês** (classes, métodos, variáveis e arquivos). **Os textos que aparecem na tela ficam em português**, exatamente como no design.
- As ações descritas em português nas tabelas do design correspondem a estes nomes no código:

  | Design | Código |
  |---|---|
  | carregar | `load()` |
  | criar, renomear, excluir (deck) | `createDeck()`, `renameDeck()`, `deleteDeck()` |
  | salvar, descartar, excluir card | `save()`, `discard()`, `deleteCard()` |
  | iniciar, próximo, anterior, recomeçar | `start()`, `next()`, `previous()`, `restart()` |
  | versoVisto | `markBackSeen()` |
  | tirar foto / escolher da galeria | `pickImage(side, ImageOrigin.camera / ImageOrigin.gallery)` |
  | iniciar / parar gravação | `startRecording(side)` / `stopRecording()` |
  | ligar e desligar o lembrete | `setReminderEnabled(bool)` |
  | exportar / importar | `exportBackup()` / `pickAndPrepareImport()` + `confirmImport()` |

- **Navegação:**
  - Cada tela recebe o seu ViewModel pronto e callbacks para navegar (por exemplo, `onOpenDeck`).
  - Quem cria os ViewModels e as rotas é `lib/routes.dart`, que cria cada ViewModel **uma única vez por rota**.
  - A tela é **dona** do ViewModel que recebe e chama `dispose()` nele.
- **Testes:**
  - Repositórios são testados com SQLite em memória (`sqflite_common_ffi`).
  - ViewModels e telas são testados com repositórios falsos, que ficam em `test/fakes/`.
  - Os testes ficam em `test/`, espelhando a estrutura de `lib/`.

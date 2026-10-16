# Design do My Flashcards

Este documento descreve **como** o app será construído. O **quê** e o **porquê** estão em [requisitos.md](requisitos.md).

## Status das partes

| Parte | Conteúdo | Status |
|---|---|---|
| 1 | Arquitetura MVVM e dados | Aprovada em 2026-10-11. Ajustada na revisão final de 2026-10-12: entrou o `MediaRepository` e saiu o `SettingsRepository` |
| 2 | Telas e fluxos | Aprovada em 2026-10-11 |
| 3 | Mídia, permissões, lembrete e backup | Aprovada em 2026-10-12, com o lembrete em horário aleatório entre 9h e 20h |
| 4 | Erros, testes e etapas de implementação | Aprovada em 2026-10-12 |

## Decisões técnicas

| Assunto | Decisão | Motivo |
|---|---|---|
| Framework | Flutter 3.47.5 estável, com Dart 3.13.4, gerenciado pelo FVM e fixado no projeto com `.fvmrc` | Já instalado na máquina pelo FVM, e atende ao mínimo de todos os pacotes (Flutter 3.44) |
| Identificador do app | `applicationId` = `com.sorayaferreira.myflashcards`, `--org com.sorayaferreira` e nome do projeto Dart `my_flashcards` | Escolhido pela usuária. É permanente: se mudar, o Android trata como outro app |
| Banco de dados | `sqflite` | Usa o SQLite que já vem no Android, sem embutir uma cópia, o que deixa o APK menor. São só três tabelas, então escrever o SQL à mão custa pouco |
| Arquitetura | MVVM, seguindo o [guia oficial de arquitetura do Flutter](https://docs.flutter.dev/app-architecture) | Pedido da usuária. O guia oficial já é MVVM, e segui-lo deixa o projeto parecido com a documentação do Flutter |
| Estado | `ChangeNotifier` com `ListenableBuilder`, sem pacote de estado | Já vem no Flutter e basta para um app deste tamanho |
| Injeção de dependências | Por construtor, montada em `main.dart`, sem `provider` nem `get_it` | É um pacote a menos, e cada dependência fica explícita no construtor |
| Geração de código | Nenhuma | Sem `build_runner`, o build fica mais simples e rápido |

### Pacotes previstos

As versões foram conferidas no pub.dev em 2026-10-11. O plano de cada etapa adiciona os pacotes com `flutter pub add`, que pega a versão mais nova.

| Pacote | Versão | Para quê |
|---|---|---|
| `sqflite` | 2.4.4 | Banco de dados |
| `path_provider` | 2.1.6 | Pastas de documentos e temporária do app |
| `path` | 1.9.1 | Montar caminhos de arquivo |
| `image_picker` | 1.2.4 | Câmera e galeria, com redimensionamento e compressão embutidos |
| `record` | 7.1.2 | Gravar áudio em AAC |
| `audioplayers` | 6.8.1 | Tocar áudio, usando o MediaPlayer do Android, que é leve |
| `flutter_local_notifications` | 22.3.1 | Lembrete diário |
| `timezone` | 0.11.1 | Agendar a notificação no fuso local |
| `flutter_timezone` | 5.1.1 | Descobrir o fuso do aparelho |
| `share_plus` | 13.3.1 | Enviar o backup pelo menu de compartilhar |
| `file_picker` | 13.1.0 | Escolher o `.zip` na hora de importar |
| `archive` | 4.5.1 | Criar e extrair o `.zip` |
| `flutter_launcher_icons` (dev) | 0.14.4 | Gerar o ícone adaptativo a partir de `logo-f/` |
| `sqflite_common_ffi` (dev) | 2.4.3 | Rodar o banco nos testes, no computador |

O `flutter create` também adiciona o `cupertino_icons`, que é removido na etapa 0 porque o app só usa ícones do Material. O `flutter_lints` (dev) continua, porque o `analysis_options.yaml` depende dele.

### Ambiente de desenvolvimento (conferido em 2026-10-12)

- **Flutter:** 3.47.5 estável (Dart 3.13.4), instalado pelo **FVM** 4.1.2 como versão global. O projeto fixa essa versão com `.fvmrc`. No terminal da usuária, `flutter` é um alias de `fvm flutter`; em shells não interativos, o comando é `fvm flutter`. O `/usr/bin/dart` (3.13.5) do sistema **não** é o Dart do Flutter: use `fvm dart`.
- **`flutter doctor`:** ✓ Flutter e ✓ Android toolchain, com as licenças aceitas. Os ✗ de Chrome e Linux desktop não importam.
- **Java:** o Flutter usa o JDK 17 (`/usr/lib/jvm/java-17-openjdk`). O OpenJDK 25 do sistema não é usado no build.
- **Android SDK:** instalado em `~/Android/Sdk`, com as plataformas 31 a 37 e os build-tools 35 e 36.
- **Ícone:** `logo-f/` já tem as camadas do ícone adaptativo em 1024×1024 (fundo, frente, monocromático e legado).

---

## Parte 1: arquitetura MVVM e dados

### Camadas

```
View (widgets)        desenha o estado e repassa os toques da usuária
   │
   ▼
ViewModel             guarda o estado da tela e expõe as ações (ChangeNotifier)
   │
   ▼
Repository            fonte da verdade de cada tipo de dado e regras de persistência
   │
   ▼
Service               embrulha uma API externa: sqflite, arquivos, gravador,
                      player, câmera/galeria, notificações, zip
```

Regras:

- As dependências **só descem**. Uma View nunca chama um Repository nem um Service diretamente. Um ViewModel nunca chama um Service: sempre passa por um Repository.
- **Repositórios não dependem uns dos outros.** Quando dois precisam do mesmo recurso, compartilham o Service. Por exemplo, `CardRepository` e `MediaRepository` usam o mesmo `MediaFileService`. Quando uma ação envolve dois repositórios, quem coordena é o ViewModel. Por exemplo, depois de importar um backup, o `SettingsViewModel` chama o `BackupRepository` e depois o `ReminderRepository`.
- **View:** não tem regra de negócio. Estado puramente visual pode ficar nela, como o ângulo da animação de virar, os controladores de texto e o foco.
- **ViewModel:** não importa widgets e não recebe `BuildContext`. Também não navega: devolve o resultado da ação, e a View decide para onde ir. Isso permite testá-lo sem montar telas.
- **Repository:** converte as linhas do banco em modelos e as operações de arquivo em resultados. Os métodos que podem falhar devolvem `Result<T>`.
- **Service:** não guarda estado do app. Cada um só traduz uma API externa.
- **Model:** são classes imutáveis, como `Deck`, `Flashcard` e `CardSide`.

### Estrutura de pastas

A estrutura segue a convenção do guia do Flutter: na UI, as pastas são organizadas por funcionalidade; nos dados, por tipo.

```
lib/
  main.dart                          cria services e repositórios, abre o app
  app.dart                           MaterialApp, temas e rotas (cria os ViewModels)
  domain/
    models/
      deck.dart
      flashcard.dart
      card_side.dart                 texto?, imagem?, áudio? de um lado
  data/
    services/
      database_service.dart          abre o SQLite, schema e migrações
      media_file_service.dart        pastas media/ e temporária; mover e apagar
      image_picker_service.dart      câmera e galeria, com compressão
      audio_recorder_service.dart
      audio_player_service.dart
      notification_service.dart
      zip_service.dart               compactar e extrair o backup
    repositories/
      deck_repository.dart           decks (e apagar a mídia dos cards de um deck)
      card_repository.dart           cards, contador, ordem de revisão
      media_repository.dart          rascunhos de mídia: foto, galeria, gravar,
                                     tocar, resolver nome → caminho, confirmar/descartar
      reminder_repository.dart       chaves reminder_* em settings; sorteia e agenda
      backup_repository.dart         exportar, importar, rollback
  ui/
    core/
      theme.dart                     cores do logo, temas claro e escuro
      widgets/
        card_side_view.dart          desenha um lado (texto, imagem, botão ▶)
        audio_play_button.dart
    deck_list/
      view_models/deck_list_view_model.dart
      widgets/deck_list_screen.dart
    deck_detail/
      view_models/deck_detail_view_model.dart
      widgets/deck_detail_screen.dart
    card_editor/
      view_models/card_editor_view_model.dart
      widgets/card_editor_screen.dart
      widgets/side_editor.dart
      widgets/audio_recorder_field.dart
    review/
      view_models/review_view_model.dart
      widgets/review_screen.dart
      widgets/flip_card.dart
    settings/
      view_models/settings_view_model.dart
      widgets/settings_screen.dart
  utils/
    result.dart                      Result<T>: Ok(valor) ou Error(exceção)
test/                                espelha a estrutura de lib/
```

### ViewModels

| ViewModel | Depende de | Estado | Ações |
|---|---|---|---|
| `DeckListViewModel` | `DeckRepository` | lista de decks com a contagem de cards, carregando, erro | carregar, criar(nome), renomear(id, nome), excluir(id) |
| `DeckDetailViewModel` | `DeckRepository`, `CardRepository` | deck, lista de cards | carregar |
| `CardEditorViewModel` | `CardRepository`, `MediaRepository` | rascunho da frente e do verso, gravando ou não, tocando ou não, se há alterações, se pode salvar | definir texto, tirar foto, escolher da galeria, remover imagem, iniciar e parar gravação, tocar áudio, remover áudio (todas por lado), salvar, descartar, excluir card |
| `ReviewViewModel` | `CardRepository`, `MediaRepository` | fila de cards da sessão, posição atual, contagem de cada card, se terminou | iniciar, próximo, anterior, versoVisto, tocar áudio, parar áudio, recomeçar |
| `SettingsViewModel` | `ReminderRepository`, `BackupRepository` | lembrete ligado ou não, operação de backup em andamento | ligar e desligar o lembrete, exportar, importar |

**Como a View recebe a mídia:** o ViewModel entrega à View o **caminho completo** de cada imagem, já resolvido pelo `MediaRepository` a partir do nome guardado no banco. Os widgets de `ui/core/widgets/` só desenham:
- `CardSideView` recebe texto, caminho da imagem e se há áudio;
- `AudioPlayButton` recebe "está tocando?" e um callback `onPressed`.

O áudio é tocado pelo ViewModel, e não pelo widget.

A regra do contador (RF-16) mora no `ReviewViewModel`. A View avisa `markBackSeen()` quando a animação mostra o verso. O ViewModel decide se conta: só conta se for a primeira vez daquele card na sessão. Nesse caso, ele pede ao `CardRepository` para somar 1.

### Injeção de dependências

1. `main.dart` cria os services e os repositórios uma única vez.
2. Esses objetos são agrupados num objeto `AppDependencies`, que é passado para `App`.
3. Cada rota, definida em `lib/routes.dart`, cria o seu ViewModel uma única vez e passa os repositórios pelo construtor. A tela recebe esse ViewModel pronto e é dona dele, chamando `dispose()` quando sai.

Nos testes, os repositórios são trocados por versões falsas (fakes) que implementam a mesma classe.

### Inicialização do app

Antes de `runApp`, o `main.dart` faz estas tarefas, nesta ordem:

1. abre o banco;
2. esvazia `editor_tmp/` (`MediaRepository`);
3. apaga os `.zip` de exportações anteriores (`BackupRepository`);
4. se o lembrete estiver ligado, completa a agenda de lembretes (`ReminderRepository`).

Cada tarefa entra no app na etapa em que a sua funcionalidade nasce. Uma falha nos passos 2 a 4 só é registrada no console e não impede o app de abrir.

### Banco de dados

Um único arquivo, `flashcards.db`, na pasta de banco de dados do app.

```sql
CREATE TABLE decks (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  name        TEXT    NOT NULL,
  created_at  INTEGER NOT NULL                 -- epoch em milissegundos
);

CREATE TABLE cards (
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  deck_id       INTEGER NOT NULL REFERENCES decks(id) ON DELETE CASCADE,
  front_text    TEXT,
  front_image   TEXT,                          -- só o nome do arquivo
  front_audio   TEXT,
  back_text     TEXT,
  back_image    TEXT,
  back_audio    TEXT,
  review_count  INTEGER NOT NULL DEFAULT 0,
  created_at    INTEGER NOT NULL
);

CREATE INDEX idx_cards_deck ON cards(deck_id);

CREATE TABLE settings (
  key    TEXT PRIMARY KEY,
  value  TEXT NOT NULL
);
```

As chaves usadas em `settings` estão na parte 3, em "Lembrete diário".

- O banco roda `PRAGMA foreign_keys = ON` toda vez que é aberto. Sem isso, o SQLite ignora o `ON DELETE CASCADE`.
- A versão do schema fica em `PRAGMA user_version`, que o `sqflite` controla pelo parâmetro `version`. A versão 1 é a inicial. Cada mudança futura ganha uma migração em `onUpgrade`.
- As colunas de imagem e áudio guardam **só o nome do arquivo** (por exemplo, `img_1728690000000_a3f9.jpg`), nunca o caminho completo. Assim, um backup restaurado em outro aparelho continua funcionando.
- A cascata apaga as linhas do banco, mas não os arquivos. Por isso, ao excluir um deck, o `DeckRepository` segue esta ordem:
  1. lê os nomes dos arquivos de todos os cards do deck;
  2. apaga o deck numa transação;
  3. só depois apaga os arquivos.

### Ciclo de vida dos arquivos de mídia

- **Pasta definitiva:** `media/`, dentro da pasta de documentos do app. Ela é privada, e nenhum outro app a vê.
- **Pasta temporária:** `editor_tmp/`, dentro da pasta temporária do app.
- **No editor:**
  1. Fotos e gravações novas vão para `editor_tmp/`.
  2. **Ao salvar:** os arquivos novos vão para `media/`, o banco é gravado e só então os arquivos substituídos ou removidos são apagados.
  3. **Ao descartar:** os arquivos do rascunho em `editor_tmp/` são apagados.
- **Ao abrir o app:** `editor_tmp/` é esvaziada, para limpar sobras de um fechamento inesperado.

---

## Parte 2: telas e fluxos

### Navegação

O app usa o `Navigator` padrão do Flutter, com `MaterialPageRoute`, sem pacote de rotas. São cinco telas:

```
Lista de decks (início)
 ├── Deck
 │    ├── Editor de card   (novo ou edição)
 │    └── Revisão
 └── Configurações
```

Tocar na notificação do lembrete abre o app na lista de decks.

### 1. Lista de decks (tela inicial)

```
┌───────────────────────────────┐
│ My Flashcards              ⚙  │
├───────────────────────────────┤
│ Inglês – verbos            ⋮  │
│ 42 cards                      │
├───────────────────────────────┤
│ Inglês – phrasal verbs     ⋮  │
│ 17 cards                      │
├───────────────────────────────┤
│                               │
│                          (+)  │
└───────────────────────────────┘
```

- Os decks aparecem em **ordem alfabética**, sem diferenciar maiúsculas de minúsculas nem letras com e sem acento: "Água" fica entre "abacate" e "banana". A ordenação é feita no Dart (`Deck.compareByName`), porque o `COLLATE NOCASE` do SQLite só ignora maiúsculas nas letras sem acento. Cada deck mostra o nome e a quantidade de cards.
- **Tocar num deck** abre a tela do deck.
- **⋮** abre o menu com **Renomear** e **Excluir**.
- **(+)** abre o diálogo "Novo deck", com um campo de nome e os botões Cancelar e Criar.
- O nome passa por `trim`, não pode ficar vazio e tem no máximo 50 caracteres. Nomes repetidos são permitidos.
- Excluir pede confirmação: *"Excluir “Inglês – verbos”? Os 42 cards serão apagados. Isso não pode ser desfeito."* Os botões são Cancelar e Excluir.
- **Lista vazia:** *"Nenhum deck ainda. Toque em + para criar o primeiro."*
- **⚙** abre as Configurações.

### 2. Deck

```
┌───────────────────────────────┐
│ ←  Inglês – verbos            │
├───────────────────────────────┤
│ [      Revisar (42)        ]  │
├───────────────────────────────┤
│ to give up              🖼 7  │
│ to look forward to     🔊 12  │
│ 🖼 (só imagem)             0  │
│ ...                           │
│                          (+)  │
└───────────────────────────────┘
```

- O botão **Revisar (N)** fica no topo e é desativado quando o deck não tem cards.
- A lista mostra os **mais recentes primeiro**. Cada linha mostra:
  - a primeira linha do texto da frente, ou "(só imagem)" e "(só áudio)" quando a frente não tem texto;
  - ícones pequenos indicando imagem e áudio na frente;
  - o contador de revisões, alinhado à direita.
- **Tocar num card** abre o editor. A **exclusão do card fica dentro do editor**, para deixar a lista mais limpa.
- **(+)** abre o editor para um card novo.
- **Lista vazia:** *"Nenhum card ainda. Toque em + para criar."*
- Ao voltar do editor ou da revisão, a lista recarrega para mostrar os novos cards e contadores.

### 3. Editor de card

```
┌───────────────────────────────┐
│ ←  Novo card       🗑  SALVAR │
├───────────────────────────────┤
│ FRENTE                        │
│ ┌───────────────────────────┐ │
│ │ Texto                     │ │
│ └───────────────────────────┘ │
│ [📷 Câmera]  [🖼 Galeria]     │
│ [🎙 Gravar]                   │
├───────────────────────────────┤
│ VERSO                         │
│ ┌───────────────────────────┐ │
│ │ desistir                  │ │
│ └───────────────────────────┘ │
│ ┌──────┐                      │
│ │ img  │ ✕                    │
│ └──────┘                      │
│ ▶ 0:04   ↻ Regravar   ✕       │
└───────────────────────────────┘
```

- A frente e o verso ficam **um embaixo do outro**, na mesma tela com rolagem. Não há abas, então você vê o card inteiro de uma vez.
- Cada lado tem três partes:
  - **Texto:** um campo de várias linhas.
  - **Imagem:**
    - sem imagem, aparecem os botões **Câmera** e **Galeria**;
    - com imagem, aparecem uma miniatura e um **✕** para remover. Para trocar, remova e escolha outra.
  - **Áudio:**
    - sem áudio, aparece o botão **🎙 Gravar**;
    - durante a gravação, aparecem um ponto vermelho, o tempo correndo (por exemplo, `0:07`) e o botão **■ Parar**;
    - depois de gravado, aparecem **▶ Ouvir** com a duração, **↻ Regravar** e **✕** para remover.
- Só um lado grava por vez. Enquanto um lado grava, o botão Gravar do outro fica desativado.
- **Salvar** só fica ativo quando os dois lados têm conteúdo (texto que não seja só espaços, imagem ou áudio). Um lado vazio mostra a dica *"Adicione texto, imagem ou áudio"*.
- **Salvar** grava o card e volta para a tela do deck.
- **🗑** só aparece ao editar um card existente. Ele pede confirmação (*"Excluir este card?"*), apaga e volta.
- **Voltar com alterações não salvas** pergunta *"Descartar alterações?"*, com as opções Continuar editando e Descartar.
- O título é "Novo card" ou "Editar card".
- Num card novo, o cursor já começa no texto da **frente**, com o teclado aberto.
- **Enquanto salva**, a 🗑 fica desativada e o voltar não faz nada. Sem isso, o fim do salvamento podia fechar o diálogo de exclusão como se fosse uma confirmação (decisão de 2026-10-15).

### 4. Revisão

```
┌───────────────────────────────┐
│ ✕  Inglês – verbos     3 / 42 │
├───────────────────────────────┤
│ ┌───────────────────────────┐ │
│ │ Frente                    │ │
│ │                           │ │
│ │        to give up         │ │
│ │                           │ │
│ │       ┌─────────┐         │ │
│ │       │ imagem  │         │ │
│ │       └─────────┘         │ │
│ │           ( ▶ )           │ │
│ │                           │ │
│ │                        7  │ │
│ └───────────────────────────┘ │
│     ⟵ arraste para virar ⟶    │
│                               │
│  ‹ Anterior        Próximo ›  │
└───────────────────────────────┘
```

**O card:**
- Ocupa a maior parte da tela, com cantos arredondados e uma sombra leve.
- Mostra na ordem o texto (grande e centralizado), a imagem (inteira, sem cortes, com altura limitada) e o botão ▶, só com as partes que o lado tiver.
- Se o texto for longo, ele rola dentro do card.
- Uma etiqueta pequena, **"Frente"** ou **"Verso"**, fica no canto superior esquerdo.
- O **contador** fica pequeno e cinza no **canto inferior direito**, nos dois lados.

**Virar:**
- Arrastar na horizontal, para qualquer lado, gira o card no eixo vertical, acompanhando o dedo. Arrastar a largura inteira do card equivale a meia volta.
- Ao soltar:
  - se o giro passou da metade, ou o arrasto foi rápido, a animação completa a virada;
  - senão, o card volta ao lado em que estava.
- A animação dura cerca de 250 ms. No meio do giro, o conteúdo troca para o outro lado, já desespelhado.
- Um arrasto **interrompido pelo sistema** (por exemplo, quando o gesto de voltar na borda da tela ou a cortina de notificações toma o toque) não completa a virada: o card volta ao lado em que estava (decisão de 2026-10-16).
- Um peteleco rápido só vira o card se for no mesmo sentido do giro.

**O contador:**
- Na primeira vez que o verso aparece, a View chama `markBackSeen()`. "Aparecer" quer dizer **completar a virada** para o verso: espiar o verso no meio de um arrasto e soltar sem virar não conta (decisão de 2026-10-16).
- O número sobe na hora, se for a primeira vez daquele card na sessão (RF-16).

**Dica de gesto:**
- *"⟵ arraste para virar ⟶"* aparece embaixo do card só no primeiro card da sessão e some depois da primeira virada.

**Botões:**
- **‹ Anterior** fica desativado no primeiro card.
- No último card, **Próximo ›** vira **Concluir**.
- Trocar de card mostra o próximo pela frente, sem animação de deslizar.
- Qualquer áudio que esteja tocando para ao virar ou trocar de card.

**Fim da sessão:**
- Aparece a mensagem *"Revisão concluída! Você revisou X de Y cards."*, em que X é a quantidade de cards cujo verso foi visto.
- Os botões são **Revisar de novo**, que recalcula a ordem com os contadores atualizados, e **Voltar ao deck**.

**Sair no meio:**
- O ✕ ou o voltar do Android saem direto, sem confirmação.
- Nada se perde, porque cada contagem é salva no banco na hora.

### 5. Configurações

```
┌───────────────────────────────┐
│ ←  Configurações              │
├───────────────────────────────┤
│ LEMBRETE                      │
│ Lembrete diário        [ ◯ ]  │
│ Um por dia, em horário        │
│ aleatório entre 9h e 20h      │
├───────────────────────────────┤
│ BACKUP                        │
│ Exportar backup               │
│ Gera um .zip com tudo         │
│ Importar backup               │
│ Substitui todos os dados      │
├───────────────────────────────┤
│ Versão 1.0.0                  │
└───────────────────────────────┘
```

- O lembrete começa **desligado**. Não há seletor de horário: o horário é sorteado todo dia (veja a parte 3).
- Os detalhes de exportar e importar estão na parte 3.

### Visual

- **Material 3.** O esquema de cores é gerado a partir do magenta do logo (`#C52DC3`) e ajustado assim:
  - **Tema claro:** a cor principal é `#C52DC3`. O contraste com branco é de 4,6:1, acima do mínimo AA de 4,5:1.
  - **Tema escuro:** a cor principal é `#F05BD3`, com texto preto sobre ela.
  - As superfícies são quase neutras.
- O tema claro ou escuro segue o sistema (`ThemeMode.system`).
- A fonte é a padrão do sistema (Roboto). Nenhuma fonte é embutida.
- **Abertura (splash):** usa a tela de abertura nativa do Android 12+, sem pacote. Ela mostra só o "F" do logo (`drawable/splash_logo.xml`, um vetor feito a partir de `logo-f/logo_symbol.svg`) sobre a cor de fundo (`surface`) do tema do app: `#FFF7F9` no claro e `#171216` no escuro. Assim, a passagem da abertura para o app acontece sem salto de cor. A abertura fica na tela só enquanto o app carrega, sem tempo mínimo. Foi antecipada da etapa 8 para a etapa 1, a pedido da Soraya (2026-10-15).
- O ícone é adaptativo e vem de `logo-f/`, incluindo a camada monocromática para os ícones temáticos do Android 13.

---

## Parte 3: mídia, permissões, lembrete e backup

### Imagens

- **Origem:** `image_picker`, com `ImageSource.camera` ou `ImageSource.gallery`.
  - **Câmera:** abre o app de câmera do sistema. Como o app **não declara** a permissão `CAMERA` no manifesto, o Android não pede essa permissão.
  - **Galeria:** usa o seletor de fotos do Android 13, sem pedir acesso às suas fotos.
- **Compressão na captura:** `maxWidth: 1280`, `maxHeight: 1280` e `imageQuality: 80`. Cada imagem fica em torno de **100 a 300 KB**.
- **Nome do arquivo:** `img_<epoch-ms>_<4 caracteres aleatórios>.<extensão original>`. O arquivo vai para `editor_tmp/` e, ao salvar o card, para `media/`, como descrito na parte 1.
- **Exibição leve:** `Image.file` recebe `cacheWidth` igual à largura em que a imagem aparece na tela (miniatura de cerca de 300 px no editor; largura do card na revisão). Assim, o Flutter decodifica a imagem já pequena e gasta menos memória.
- **Arquivo sumido:** se o arquivo de uma imagem não for encontrado, aparece um quadro cinza escrito *"Imagem não encontrada"*. O app não trava.

### Áudio

- **Gravação:** `record`, com `AudioEncoder.aacLc`, 32 kbps, mono, 22.050 Hz e saída `.m4a`. São cerca de **40 KB a cada 10 segundos**, qualidade suficiente para voz.
- **Limite:** **60 segundos** por gravação. Ao chegar no limite, a gravação para sozinha e mantém o que foi gravado.
- **App em segundo plano:** se o app sair da tela durante a gravação, ela para e mantém o que já foi gravado.
- **Nome do arquivo:** `aud_<epoch-ms>_<4 caracteres>.m4a`. O ciclo de vida é o mesmo das imagens.
- **Reprodução:** `audioplayers`, com **um único player para o app inteiro** (`AudioPlayerService`). Por isso, nunca tocam dois áudios ao mesmo tempo. O áudio para ao virar o card, ao trocar de card e ao sair da tela.
- **Duração:** durante a gravação, o tempo vem de um cronômetro do próprio editor. Para áudios já salvos, vem do player. A duração não é guardada no banco.

### Permissões

| Permissão | Quando é pedida | Se for negada |
|---|---|---|
| `RECORD_AUDIO` (microfone) | No primeiro toque em **Gravar** | Aparece a mensagem *"Sem acesso ao microfone. Ative em Configurações › Apps › My Flashcards › Permissões."* O resto do app funciona normalmente |
| `POST_NOTIFICATIONS` | Ao **ligar** o lembrete | O interruptor volta para desligado, com uma mensagem parecida |
| `RECEIVE_BOOT_COMPLETED` | Nunca. É concedida na instalação | — |

- Câmera e galeria não pedem permissão, como explicado em "Imagens".
- O app **não** tem `INTERNET` (o Flutter só adiciona essa permissão nos builds de debug), `CAMERA`, `READ_MEDIA_IMAGES` nem `SCHEDULE_EXACT_ALARM`.
- O manifesto final (já com o que os pacotes acrescentam) é conferido no APK de release, na etapa de acabamento.
- Não entra pacote só para abrir as configurações do Android. A mensagem explica o caminho.

### Lembrete diário

- **Pacotes:** `flutter_local_notifications`, `timezone` e `flutter_timezone`. O plugin exige *core library desugaring* no Gradle.
- **Regra:** **uma notificação por dia, num horário sorteado entre 9h e 20h.** O horário muda todo dia. A faixa é fixa no código, e a usuária só liga ou desliga.
- **Configurações salvas na tabela `settings`:**
  - `reminder_enabled`: `"1"` ou `"0"` (padrão `"0"`);
  - `reminder_scheduled_until`: `"AAAA-MM-DD"`, o último dia que já tem notificação agendada. Fica vazio quando o lembrete está desligado.
- **Como agendar horários aleatórios:**
  - O Android não sabe repetir uma notificação em horário aleatório. Por isso, o app agenda **uma notificação avulsa para cada um dos próximos 30 dias**, cada uma com o seu horário sorteado.
  - Cada notificação usa `zonedSchedule`, sem `matchDateTimeComponents`. O id é a data como número `AAAAMMDD`; por exemplo, `20261012`.
  - O modo é `AndroidScheduleMode.inexactAllowWhileIdle`: a notificação **pode chegar alguns minutos atrasada**. Em troca, não é preciso pedir a permissão de alarme exato.
  - **O dia de hoje** só entra se ainda faltarem pelo menos 30 minutos para as 20h. Nesse caso, o horário é sorteado entre "agora + 30 min" e 20h. Senão, a contagem começa amanhã.
  - **Completar a agenda:** quando o app abre, ele agenda só os dias depois de `reminder_scheduled_until`, até hoje + 29. Um dia que já tem horário sorteado **nunca é sorteado de novo**. Isso evita duas notificações no mesmo dia.
  - **Se o app ficar mais de 30 dias sem ser aberto,** os lembretes acabam. Basta abrir o app de novo para eles voltarem.
- **Onde fica a lógica:** num `ReminderRepository`, que recebe um relógio e um gerador aleatório pelo construtor. Assim, os testes conseguem conferir:
  - quais dias são agendados;
  - se os horários ficam dentro da faixa;
  - se nenhum dia se repete.
- **Texto da notificação:** título *"Hora de revisar!"* e corpo *"Seus flashcards estão esperando por você."*
- **Canal:** `lembrete_diario`, chamado "Lembrete diário", com importância padrão.
- **Ícone pequeno:** a silhueta branca do logo (`logo_symbol_dark.svg`), convertida em recurso `drawable`.
- **Quando o agendamento muda:**

  | Evento | O que acontece |
  |---|---|
  | Ligar o lembrete | Pede a permissão e agenda os próximos 30 dias (hoje entra se houver tempo) |
  | Desligar o lembrete | Cancela todas as notificações agendadas e limpa `reminder_scheduled_until` |
  | Abrir o app | Se o lembrete estiver ligado, completa a agenda até hoje + 29 |
  | Importar backup | Cancela tudo. Se o backup tiver o lembrete ligado, agenda do zero, porque o `reminder_scheduled_until` restaurado se refere às notificações de outro aparelho |
  | Reiniciar o celular | O receiver de boot do plugin reagenda as notificações pendentes. Ele precisa estar declarado no manifesto, conforme o README do plugin |

- **Tocar na notificação:** abre o app normalmente, na lista de decks.

### Backup: exportar

1. Uma cópia consistente do banco é criada com `VACUUM INTO '<tmp>/backup/flashcards.db'`. Isso funciona com o banco aberto e exige SQLite 3.27 ou mais novo; o Android 13 já traz uma versão mais nova.
2. O app grava um `manifest.json`:
   ```json
   { "app": "my_flashcards", "formatVersion": 1, "schemaVersion": 1,
     "exportedAt": "2026-10-11T20:15:00-03:00", "decks": 3, "cards": 87 }
   ```
3. O app compacta `manifest.json`, `flashcards.db` e `media/` em `my-flashcards-backup-AAAA-MM-DD.zip`.
   - A compactação roda **num isolate separado** (`Isolate.run`), para a tela não travar.
   - Enquanto isso, aparece o diálogo *"Gerando backup…"*.
4. O `.zip` é entregue ao menu de compartilhar (`share_plus`). O destino recomendado é o **Google Drive**, porque o backup sobrevive se o celular se perder.
5. Os `.zip` antigos na pasta temporária são apagados na próxima abertura do app. Eles não são apagados logo depois de compartilhar, porque o app de destino pode ainda estar lendo o arquivo.

### Backup: importar

1. **Escolher o arquivo** com `file_picker`, filtrando por `.zip`.
2. **Extrair num isolate** para `<tmp>/import/`. Nessa extração:
   - entradas com `..` ou caminho absoluto são **recusadas**, para impedir que o zip escreva fora da pasta;
   - um arquivo que não seja um backup válido é recusado com a mensagem *"Este arquivo não é um backup do My Flashcards."*
3. **Validar o backup.** Ele precisa ter:
   - um `manifest.json` com `app == "my_flashcards"` e `formatVersion == 1`;
   - `schemaVersion` menor ou igual à versão atual do schema;
   - um `flashcards.db` que abre sem erro.
4. **Confirmar com a usuária:** *"Substituir todos os dados? O backup de 11/10/2026 tem 3 decks e 87 cards. Seus decks atuais serão apagados."* Os botões são Cancelar e Substituir.
5. **Trocar os dados sem risco de perda:**
   1. fechar o banco;
   2. mover o banco e a pasta `media/` atuais para `<tmp>/rollback/`;
   3. colocar os dados importados no lugar;
   4. abrir o banco, o que roda `onUpgrade` se o backup for de um schema mais antigo.
   - **Se tudo der certo:** a pasta de rollback é apagada.
   - **Se der erro:** os dados de rollback voltam ao lugar e aparece a mensagem *"Não foi possível importar. Seus dados não foram alterados."*
6. **Depois de importar:** o lembrete é reagendado ou cancelado conforme as configurações restauradas, e o app volta para a lista de decks, recarregada.

**Sobre o tamanho do backup:** 500 cards com imagem dão cerca de 100 MB. O Drive aceita sem problema, mas apps de mensagem podem recusar arquivos desse tamanho.

---

## Parte 4: erros, testes e etapas de implementação

### Tratamento de erros

**Princípios:**
- Repositórios e services nunca deixam uma exceção chegar à tela. As operações que podem falhar devolvem `Result<T>`.
- O ViewModel transforma um `Error` numa mensagem curta, em português, e a guarda no seu estado.
- A View mostra essa mensagem numa `SnackBar` ou num diálogo.
- Não há relatórios de erro enviados para fora, até porque o app não tem internet. Em debug, os erros vão para o console com `debugPrint`.

| Situação | O que a usuária vê | O que acontece com os dados |
|---|---|---|
| Falha ao salvar um card | *"Não foi possível salvar. Tente de novo."* | O rascunho continua aberto no editor |
| Arquivo de imagem sumido | Quadro cinza escrito *"Imagem não encontrada"* | Nada muda. Dá para editar o card e escolher outra imagem |
| Arquivo de áudio sumido | O ▶ aparece desativado, com o rótulo *"Áudio não encontrado"* | Nada muda |
| Microfone negado | Mensagem explicando como ativar | O resto do editor funciona |
| Notificações negadas | O interruptor volta para desligado e aparece uma mensagem | — |
| Backup inválido ou corrompido | *"Este arquivo não é um backup do My Flashcards."* | Nada muda |
| Erro no meio da importação | *"Não foi possível importar. Seus dados não foram alterados."* | Os dados guardados no rollback voltam ao lugar |
| Falha ao exportar (por exemplo, sem espaço) | *"Não foi possível gerar o backup."* | Nada muda, e o zip pela metade é apagado |

**Risco aceito na primeira versão:** se o Android fechar o app enquanto a câmera do sistema está aberta (acontece com pouca memória), o card que estava sendo editado se perde. Isso é raro em celulares atuais, e tratar o caso exigiria salvar o rascunho a cada alteração.

### Testes

**Método:** cada tarefa é feita com TDD. Primeiro escreve-se o teste, vê-se ele falhar, implementa-se e vê-se ele passar. Ao fim de cada etapa, `flutter analyze` não pode mostrar avisos (regras do `flutter_lints`) e `flutter test` precisa passar inteiro.

| Tipo | O que cobre | Como |
|---|---|---|
| Unidade: modelos | `CardSide.isEmpty`, conversão de e para mapa do banco | Testes Dart puros |
| Unidade: repositórios | CRUD, cascata, contador, consulta da ordem de revisão, migrações | SQLite real em memória com `sqflite_common_ffi`, que usa o `libsqlite3` do computador (3.53.4 já instalado) |
| Unidade: arquivos | Ciclo de vida das mídias: salvar, descartar, substituir, apagar deck | Pastas temporárias criadas com `Directory.systemTemp.createTemp` |
| Unidade: lembrete | Dias agendados, horários dentro da faixa, nenhum dia repetido, regra do "hoje", completar a agenda | Relógio falso, `Random` com semente fixa e um `NotificationService` falso que só registra os agendamentos |
| Unidade: backup | Exportar e importar de volta; recusa de zip-slip; manifesto inválido; rollback quando um passo falha | Pastas temporárias e falha injetada |
| Unidade: ViewModels | Ordem da revisão (menos revisados primeiro, empates embaralhados), contador uma vez por sessão, limites da navegação, fim da sessão, validação do editor, descarte, nome de deck | Repositórios falsos |
| Widget | `FlipCard`: arrastar além da metade vira, arrasto curto volta, o callback `onFlip` é chamado uma vez a cada virada completa. `CardSideView`: combinações de conteúdo e imagem sumida. Editor: quando o Salvar fica ativo. Revisão: botões | `flutter test`, com `tester.drag` e afins |
| Manual, no celular | Câmera, galeria, microfone (inclusive negar a permissão), som, notificação aparecendo e sobrevivendo a reinício, exportar para o Drive e importar, tema escuro, tamanho do APK | Checklist no fim de cada etapa que mexe com o aparelho |

Os plugins (gravador, câmera, player, notificações, compartilhar e escolher arquivo) ficam atrás dos services. Nos testes automáticos, eles são trocados por versões falsas. O comportamento real é conferido pelo checklist manual.

### Etapas de implementação

Cada etapa é uma **fatia vertical**: ao fim dela, o app compila, os testes passam e ele roda no celular com algo novo funcionando. **A partir da etapa 3, o app já é usável para revisar cards de texto.**

Cada etapa terá um plano detalhado em `docs/planos/`. O trabalho de cada etapa é feito num branch próprio (`etapa-N-nome`), que entra no `main` quando a etapa termina.

| # | Etapa | Entrega | Requisitos |
|---|---|---|---|
| 0 | Ambiente e projeto | Flutter instalado, `flutter doctor` sem erros, celular conectado por USB. Projeto criado na raiz do repositório com `applicationId` `com.sorayaferreira.myflashcards`, `minSdk 33`, nome "My Flashcards", `flutter_lints` e o ícone de `logo-f/` (a pasta `logo-f/` entra no git). Um app vazio roda no celular | RNF-01, RNF-07 |
| 1 | Dados e decks | `Result`, os modelos, o `DatabaseService` com o schema v1, o `DeckRepository`, `AppDependencies`, o tema, e a tela de decks com seu ViewModel (criar, renomear, excluir, lista vazia) | RF-01 a RF-04, RNF-05, RNF-06, RNF-08 |
| 2 | Cards de texto | `CardRepository`, tela do deck e editor só com texto, com validação, descarte e exclusão | RF-05 a RF-08 (texto), RF-11 |
| 3 | Revisão | `ReviewViewModel` (ordem, contador, navegação), `FlipCard`, tela de revisão e tela de fim de sessão | RF-12 a RF-17 |
| 4 | Imagens | `MediaFileService` (pastas `media/` e `editor_tmp/`, limpeza), `ImagePickerService`, `MediaRepository` (parte de imagens), imagem no editor e na revisão, arquivos apagados ao editar ou excluir card e deck | RF-06, RF-09, RNF-04 |
| 5 | Áudio | `AudioRecorderService`, `AudioPlayerService`, `MediaRepository` (parte de áudio), o campo de gravação, a permissão do microfone e o ▶ no editor e na revisão, parando ao virar ou trocar de card | RF-06, RF-10, RF-18 |
| 6 | Lembrete | `NotificationService`, `ReminderRepository`, tela de configurações (lembrete), ícone da notificação, manifesto e desugaring | RF-19 |
| 7 | Backup | `ZipService`, `BackupRepository` (exportar, importar, rollback), tela de configurações (backup) | RF-20, RF-21 |
| 8 | Acabamento e release | Cor do splash, revisão visual nos temas claro e escuro, conferência das permissões no APK, chave de assinatura de release (guardada **fora** do git), `flutter build apk --release --split-per-abi`, conferência do limite de 15 MB, instalação no celular, checklist manual completo, versão 1.0.0 e uma tag no git | RNF-02, RNF-04, RNF-07 |

**Por que esta ordem:** dados e decks são a base de tudo. A revisão vem antes das mídias para você já poder usar o app com texto. Imagem e áudio se apoiam no `MediaFileService`, que nasce na etapa 4. O backup fica por último entre as funcionalidades, porque precisa empacotar tudo o que as etapas anteriores criaram.

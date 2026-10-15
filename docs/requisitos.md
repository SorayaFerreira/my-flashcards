# Requisitos do My Flashcards

## Objetivo

O My Flashcards é um app pessoal, feito para uma única usuária estudar inglês com disciplina usando flashcards. Ele existe porque Quizlet e AnkiDroid não atenderam às necessidades dela. Vai ter dado certo quando ela usar o app no dia a dia no lugar deles.

Princípios: zero anúncios, zero recursos premium, app leve e visual limpo.

## Requisitos funcionais

### Decks

- **RF-01:** Criar um deck, dando um nome a ele.
- **RF-02:** Renomear um deck.
- **RF-03:** Excluir um deck, depois de uma confirmação. Os cards do deck e todos os arquivos de mídia deles são apagados junto.
- **RF-04:** Listar os decks, mostrando quantos cards cada um tem.
- Decks não têm subpastas.

### Cards

- **RF-05:** Criar um card dentro de um deck. Todo card tem frente (pergunta ou dica) e verso (resposta).
- **RF-06:** Cada lado do card pode ter **texto**, **imagem** e **áudio**, no máximo um de cada, em qualquer combinação. Um lado não pode ficar vazio.
- **RF-07:** Editar um card.
- **RF-08:** Excluir um card, depois de uma confirmação. Os arquivos de mídia dele são apagados junto.
- **RF-09:** A imagem vem da **câmera** ou da **galeria** do aparelho.
- **RF-10:** O áudio é **gravado no próprio app** pelo microfone. Dá para ouvir antes de salvar, regravar e remover. Não dá para importar arquivos de áudio.
- **RF-11:** Listar os cards de um deck.

### Revisão

- **RF-12:** Revisar um deck. Uma sessão passa por todos os cards do deck uma vez.
- **RF-13:** Ordem da sessão: os cards com **menos revisões vêm primeiro**, e os empates são embaralhados. A ordem é calculada no início da sessão e não muda durante ela.
- **RF-14:** **Arrastar o card para o lado** faz ele girar entre frente e verso, com uma animação simples.
- **RF-15:** Os botões **‹ Anterior** e **Próximo ›**, embaixo do card, trocam de card.
- **RF-16:** O contador de revisões do card sobe 1 **na primeira vez que o verso é visto**. Cada card conta no máximo uma vez por sessão: virar e desvirar, ou voltar com ‹ Anterior e ver o verso de novo, não conta outra vez.
- **RF-17:** O contador aparece pequeno no **canto inferior direito** do card, como um número de página.
- **RF-18:** Na revisão, o áudio **só toca quando a usuária aperta ▶**. Não há reprodução automática.

### Lembrete

- **RF-19:** Um lembrete diário opcional: **uma notificação por dia, num horário sorteado entre 9h e 20h**, diferente a cada dia. Ele pode ser ligado e desligado, e a usuária não escolhe o horário. A notificação pode chegar alguns minutos atrasada.

### Backup

- **RF-20:** **Exportar** todos os dados (decks, cards, mídias e configurações) num único arquivo `.zip`, entregue pelo menu de compartilhar do Android.
- **RF-21:** **Importar** um arquivo `.zip` de backup. Isso **substitui todos os dados** do app, depois de uma confirmação.

## Requisitos não funcionais

- **RNF-01:** Só Android. A versão mínima é o **Android 13 (API 33)**, porque o celular da usuária usa essa versão ou uma mais nova.
- **RNF-02:** Funciona offline, sem conta e sem nuvem. A versão de release não pede permissão de internet.
- **RNF-03:** Sem anúncios e sem recursos premium.
- **RNF-04:** Leve em armazenamento e processamento. Isso significa:
  - poucos pacotes;
  - imagens comprimidas;
  - áudio em AAC compacto;
  - APK de release para arm64 com **até 15 MB**.
- **RNF-05:** Visual simples e limpo, em Material 3. Usa as cores do logo (`#C52DC3` magenta e `#F05BD3` rosa) como destaque, sobre um fundo neutro. O tema claro ou escuro segue a configuração do sistema.
- **RNF-06:** Interface em português.
- **RNF-07:** Instalado por APK direto no celular (cabo USB ou arquivo), sem Play Store.
- **RNF-08:** Arquitetura MVVM.
- **RNF-09:** Uma única usuária, sem perfis.

## Fora de escopo (primeira versão)

- Sincronização em nuvem, contas e login.
- Subpastas dentro de decks.
- Repetição espaçada com intervalos (SRS no estilo do Anki). A única priorização é "menos revisados primeiro".
- Importar arquivos de áudio. Mais de uma imagem ou mais de um áudio por lado.
- Texto formatado (negrito, cores, tamanhos).
- Estatísticas, metas e sequências de dias.
- Leitura do texto em voz alta (TTS).
- iOS e publicação na Play Store.

## Registro de decisões de produto

| Data | Assunto | Decisão |
|---|---|---|
| 2026-10-11 | Armazenamento | Tudo local, sem conta e sem nuvem |
| 2026-10-11 | Usuários | Uma única usuária |
| 2026-10-11 | Idioma | Interface em português |
| 2026-10-11 | Estrutura | Decks sem subpastas. Cards podem ser editados e excluídos, e decks podem ser renomeados |
| 2026-10-11 | Conteúdo do lado | No máximo uma imagem e um áudio por lado, em qualquer combinação, sem lado vazio |
| 2026-10-11 | Lembretes | Entram na primeira versão. Inicialmente seria uma notificação diária num horário escolhido pela usuária |
| 2026-10-12 | Horário do lembrete | Substitui a decisão anterior: uma notificação por dia, num horário aleatório entre 9h e 20h, sem seletor de horário. Um atraso de alguns minutos é aceitável |
| 2026-10-12 | Faixa do lembrete | Confirmada: das 9h às 20h |
| 2026-10-12 | Identificador do app | `com.sorayaferreira.myflashcards` |
| 2026-10-12 | Ambiente | Usar o Flutter 3.47.5 que já está instalado pelo FVM, e não instalar outro |
| 2026-10-12 | Testes no celular | Feitos pela usuária. A execução dos planos para antes de cada checklist manual |
| 2026-10-12 | Limites de mídia | Áudio de até 60 s. Imagens com no máximo 1280 px, em JPEG com qualidade 80 |
| 2026-10-15 | Abertura do app | Mostra só o "F" do logo sobre fundo liso, na abertura nativa do Android, enquanto o app carrega. Sem tela com tempo fixo |
| 2026-10-15 | Ordem dos decks | A ordem alfabética ignora maiúsculas e também acentos, para que "Água" e "Época" não fiquem depois do Z |
| 2026-10-11 | Gestos na revisão | Arrastar para o lado vira e desvira o card. Os botões ‹ Anterior e Próximo › trocam de card |
| 2026-10-11 | Contador | Sobe 1 na primeira vez que o verso é visto, no máximo uma vez por card em cada sessão |
| 2026-10-11 | Ordem da revisão | Menos revisados primeiro, empates embaralhados. A usuária trocou de "aleatória" para esta opção |
| 2026-10-11 | Origem do áudio | Só gravação no app |
| 2026-10-11 | Reprodução do áudio | Só ao apertar ▶ |
| 2026-10-11 | Backup | Exportar e importar um `.zip` pelo menu de compartilhar |
| 2026-10-11 | Importação | Substitui todos os dados, depois de uma confirmação |
| 2026-10-11 | Tema | Segue o claro ou escuro do sistema, com as cores do logo |
| 2026-10-11 | Distribuição | APK direto, sem Play Store |
| 2026-10-11 | Versão mínima | Android 13 (API 33) |
| 2026-10-11 | Arquitetura | MVVM, seguindo o guia oficial do Flutter. Dependências passadas pelo construtor, sem `provider` |
| 2026-10-11 | Banco | `sqflite`, usando o SQLite do próprio Android |

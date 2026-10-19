# Bem-vindo ao My Flashcards! 🗲🧠

Este é o meu aplicativo de flashcards!

Sempre gostei da proposta dos flashcards para memorizar novos aprendizados de forma divertida, porém não consegui encontrar uma aplicação que me agradasse. Agora que estou tentando voltar aos meus estudos disciplinados de Inglês, decidi criar o My Flashcards para eu mesma utilizar de acordo com minhas próprias necessidades. Nessa lógica, o app tem o objetivo de atender os seguintes requisitos principais (funcionais e não funcionais):

- Disponível para dispositivos móveis;
- Zero anúncios!;
- Zero funções restritas a acesso premium;
- Aplicativo leve, ocupando pouco espaço no celular;
- Design clean e objetivo;
- Decks, flashcards com texto, imagem e áudio, lembretes para revisão dos flashcards;
- Gravador de áudio, acesso à câmera e galeria;
- Cada card guarda o número de vezes que ele já foi revisado pelo usuário;

Concorrentes do My flashcards: Quizlet e Ankidroid;

## Como gerar e instalar

Pré-requisitos: Flutter 3.47 (pelo FVM), Android SDK e a chave de assinatura em `~/.android-keys/`, apontada por `android/key.properties` (veja a tarefa 3 de `docs/planos/08-acabamento-e-release.md`).

```bash
flutter test
flutter build apk --release --split-per-abi
adb install -r build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

Antes de cada atualização, aumente o número depois do `+` em `version:` no `pubspec.yaml` (por exemplo, `1.0.1+2`) e o `appVersion` em `lib/app_version.dart`.

Instale sempre o APK `arm64-v8a` gerado com `--split-per-abi`. O Flutter soma 2000 ao número de versão dele, então um APK gerado sem essa opção teria um número menor, e o Android recusaria instalá-lo por cima.

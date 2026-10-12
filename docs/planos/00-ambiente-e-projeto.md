# Etapa 0: ambiente e projeto. Plano de implementação

> **Para agentes:** SUB-SKILL OBRIGATÓRIO: use superpowers:subagent-driven-development (recomendado) ou superpowers:executing-plans para executar este plano tarefa por tarefa. Os passos usam caixas (`- [ ]`) para acompanhamento.

**Objetivo:** deixar o Flutter instalado, o celular conectado e um projeto Flutter vazio, com o ícone do app, rodando no celular.

**Arquitetura:** o projeto Flutter é criado na raiz do repositório, ao lado de `docs/` e `logo-f/`, só com a plataforma Android. Nesta etapa, o código Dart é só um `App` com uma tela "Em construção". A arquitetura MVVM começa na etapa 1.

**Tecnologias:** Flutter 3.47.7 estável (Dart 3.13.5), Android SDK em `~/Android/Sdk`, `flutter_launcher_icons` 0.14.

**Spec:** [docs/design.md](../design.md) e [docs/requisitos.md](../requisitos.md)

**Branch:** `etapa-0-ambiente`, criado a partir do `main` depois de juntar o `planejamento` (veja o [README dos planos](README.md)).

## Restrições globais

- Só Android. `minSdk = 33` (Android 13).
- `applicationId = "com.sorayaferreira.myflashcards"`. O nome do pacote Dart é `my_flashcards` e a org é `com.sorayaferreira`.
- O nome que aparece no celular é `My Flashcards`.
- Usar Flutter 3.47.x estável. O `dart` usado precisa ser o que vem dentro do Flutter, e não o `/usr/bin/dart` do sistema.
- Nenhum pacote além dos listados em "Pacotes previstos" no design.
- `flutter analyze` sem problemas e `flutter test` passando ao fim da etapa.

## Pontos de atenção na revisão

1. **O `flutter create` pode sobrescrever o `README.md` do repositório.** O esperado é que o README continue igual. Na tarefa 3, um `git diff` confere isso, e o arquivo é restaurado se tiver mudado.
2. **Dois `dart` no PATH.** Com o `/usr/bin/dart` aparecendo antes, os comandos `dart run` usariam um SDK diferente do Flutter. O esperado é `which dart` apontar para `~/development/flutter/bin/dart`. A tarefa 1 confere isso.
3. **JDK 25 com o Gradle.** O template usa o Gradle 9.3.1, que roda no JDK 25. Se o build falhar com uma mensagem sobre a versão do Java, o esperado é seguir o passo de contingência da tarefa 5, que usa o JDK 21.
4. **Celular sem permissão no `adb`.** No Arch, `adb devices` pode mostrar `no permissions`. O esperado é instalar as regras udev do Android, como mostra a tarefa 2.
5. **Ícone monocromático ausente.** Sem a camada monocromática, o ícone temático do Android 13 aparece genérico. A tarefa 4 confere que o XML gerado contém `<monochrome>`.

---

### Tarefa 1: instalar o Flutter SDK

**Arquivos:**
- Modificar: `~/.bashrc` (fora do repositório)

- [ ] **Passo 1: baixar o Flutter 3.47.7 e conferir o checksum**

```bash
mkdir -p ~/development && cd ~/development
curl -LO https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.47.7-stable.tar.xz
echo "af7455f540df951184c7953fbe3cf884766e7541dacf8571f9f582db03dd6230  flutter_linux_3.47.7-stable.tar.xz" | sha256sum -c
```

Esperado: `flutter_linux_3.47.7-stable.tar.xz: OK`

- [ ] **Passo 2: extrair e colocar no PATH, antes do `/usr/bin`**

```bash
tar -xf flutter_linux_3.47.7-stable.tar.xz -C ~/development
rm flutter_linux_3.47.7-stable.tar.xz
echo 'export PATH="$HOME/development/flutter/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

- [ ] **Passo 3: conferir as versões e qual `dart` está sendo usado**

```bash
flutter --version
which flutter dart
```

Esperado:
- `flutter --version` mostra `Flutter 3.47.7` e `Dart 3.13.5`.
- `which` mostra `~/development/flutter/bin/flutter` e `~/development/flutter/bin/dart`.

Se `which dart` mostrar `/usr/bin/dart`, a linha do PATH não ficou antes do `/usr/bin`. Corrija o `~/.bashrc` e abra um terminal novo.

- [ ] **Passo 4: configurar o Flutter só para Android e aceitar as licenças**

```bash
flutter config --android-sdk ~/Android/Sdk
flutter config --no-enable-web --no-enable-linux-desktop
flutter config --no-analytics
flutter doctor --android-licenses
```

Responda `y` para todas as licenças.

- [ ] **Passo 5: rodar o `flutter doctor`**

```bash
flutter doctor -v
```

Esperado: `[✓] Flutter` e `[✓] Android toolchain`. Avisos sobre Chrome, Linux desktop ou Android Studio podem ser ignorados.

---

### Tarefa 2: preparar o celular

**Arquivos:** nenhum.

- [ ] **Passo 1: ativar as opções de desenvolvedor no celular**

1. Abra **Configurações › Sobre o telefone** e toque **7 vezes** em **Número da versão**. Em alguns aparelhos, esse item fica em **Informações do software**.
2. Abra **Configurações › Sistema › Opções do desenvolvedor** e ative a **Depuração USB**.

- [ ] **Passo 2: conectar por USB e autorizar**

Conecte o cabo. No celular, aceite o pedido **"Permitir depuração USB?"** e marque **"Sempre permitir deste computador"**.

```bash
adb devices
```

Esperado: uma linha com o número de série do aparelho seguido de `device`.

Se aparecer `no permissions` ou `unauthorized`:
```bash
sudo pacman -S android-udev
sudo udevadm control --reload-rules
adb kill-server && adb devices
```
Desconecte e conecte o cabo de novo, e aceite o pedido no celular.

- [ ] **Passo 3: confirmar que o Flutter vê o celular**

```bash
flutter devices
```

Esperado: o celular aparece na lista com `android-arm64`.

---

### Tarefa 3: criar o projeto Flutter na raiz do repositório

**Arquivos:**
- Criar (gerados pelo `flutter create`): `pubspec.yaml`, `analysis_options.yaml`, `.metadata`, `android/**`, `lib/main.dart`, `test/widget_test.dart`
- Modificar: `.gitignore` (gerado), `android/app/build.gradle.kts`, `android/app/src/main/AndroidManifest.xml`, `pubspec.yaml`
- Criar: `lib/app.dart`
- Substituir: `lib/main.dart`
- Testar: `test/app_test.dart`. Apagar o `test/widget_test.dart` gerado.

**Interfaces:**
- Consome: nada.
- Produz: `App` (`lib/app.dart`), um `StatelessWidget` com construtor `const App({super.key})`, que mostra uma `AppBar` com o título `My Flashcards`. A etapa 1 muda esse construtor.

- [ ] **Passo 1: criar o branch da etapa**

```bash
cd ~/Repositories/my-flashcards
git switch main && git merge --ff-only planejamento
git switch -c etapa-0-ambiente
```

- [ ] **Passo 2: gerar o projeto**

```bash
cp README.md /tmp/README.md.bak
flutter create --org com.sorayaferreira --project-name my_flashcards \
  --platforms android --description "Flashcards pessoais para estudar inglês." .
```

Esperado: `All done!`, e as pastas `android/`, `lib/` e `test/` criadas.

- [ ] **Passo 3: garantir que o README do repositório não mudou**

```bash
git diff --stat README.md
```

Esperado: nenhuma saída. Se o README mudou, restaure:
```bash
cp /tmp/README.md.bak README.md
```

- [ ] **Passo 4: ajustar o `applicationId` e o `minSdk`**

Em `android/app/build.gradle.kts`, dentro de `defaultConfig { ... }`, troque:

```kotlin
        applicationId = "com.sorayaferreira.my_flashcards"
```
por
```kotlin
        applicationId = "com.sorayaferreira.myflashcards"
```

E troque:

```kotlin
        minSdk = flutter.minSdkVersion
```
por
```kotlin
        minSdk = 33
```

Não mexa no `namespace`: ele pode continuar `com.sorayaferreira.my_flashcards`, porque é só o pacote do código Kotlin e não precisa ser igual ao `applicationId`.

- [ ] **Passo 5: ajustar o nome que aparece no celular**

Em `android/app/src/main/AndroidManifest.xml`, na tag `<application`, troque:

```xml
        android:label="my_flashcards"
```
por
```xml
        android:label="My Flashcards"
```

- [ ] **Passo 6: ajustar a versão no `pubspec.yaml`**

Troque a linha `version: 1.0.0+1` por:

```yaml
version: 0.1.0+1
```

A versão 1.0.0 fica para o release, na etapa 8.

- [ ] **Passo 7: escrever o teste do app (ele vai falhar)**

Apague o teste gerado e crie o novo:

```bash
rm test/widget_test.dart
```

`test/app_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:my_flashcards/app.dart';

void main() {
  testWidgets('mostra o nome do app na barra superior', (tester) async {
    await tester.pumpWidget(const App());

    expect(find.text('My Flashcards'), findsOneWidget);
  });
}
```

- [ ] **Passo 8: rodar o teste e ver que ele falha**

```bash
flutter test test/app_test.dart
```

Esperado: FALHA na compilação, com `Error: Error when reading 'lib/app.dart'` ou `Couldn't resolve the package`.

- [ ] **Passo 9: criar o `App` e simplificar o `main.dart`**

`lib/app.dart`:
```dart
import 'package:flutter/material.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'My Flashcards',
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(title: const Text('My Flashcards')),
        body: const Center(child: Text('Em construção')),
      ),
    );
  }
}
```

`lib/main.dart` (substitui o arquivo inteiro):
```dart
import 'package:flutter/material.dart';

import 'app.dart';

void main() {
  runApp(const App());
}
```

- [ ] **Passo 10: rodar o teste e a análise**

```bash
flutter test && flutter analyze
```

Esperado: `All tests passed!` e `No issues found!`

- [ ] **Passo 11: commit**

```bash
git add .gitignore .metadata pubspec.yaml pubspec.lock analysis_options.yaml android lib test
git commit -m "chore: cria o projeto Flutter só para Android"
```

---

### Tarefa 4: ícone do app a partir de `logo-f/`

**Arquivos:**
- Criar: `flutter_launcher_icons.yaml`
- Modificar: `pubspec.yaml` (dependência de desenvolvimento)
- Gerados: `android/app/src/main/res/mipmap-*/ic_launcher*.png`, `android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml`, `android/app/src/main/res/drawable*/ic_launcher_*.png`
- Versionar: `logo-f/` (hoje não está no git)

- [ ] **Passo 1: adicionar o gerador de ícones como dependência de desenvolvimento**

```bash
flutter pub add dev:flutter_launcher_icons
```

- [ ] **Passo 2: criar a configuração**

`flutter_launcher_icons.yaml`:
```yaml
flutter_launcher_icons:
  android: true
  ios: false
  image_path: "logo-f/icon_legacy.png"
  min_sdk_android: 33
  adaptive_icon_background: "logo-f/icon_background.png"
  adaptive_icon_foreground: "logo-f/icon_foreground.png"
  adaptive_icon_monochrome: "logo-f/icon_monochrome.png"
```

- [ ] **Passo 3: gerar os ícones**

```bash
dart run flutter_launcher_icons
```

Esperado: `Successfully generated launcher icons`.

- [ ] **Passo 4: conferir o ícone adaptativo com a camada monocromática**

```bash
cat android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml
```

Esperado: um `<adaptive-icon>` com `<background>`, `<foreground>` e `<monochrome>`.

- [ ] **Passo 5: commit**

```bash
git add flutter_launcher_icons.yaml pubspec.yaml pubspec.lock android/app/src/main/res logo-f
git commit -m "chore: gera o ícone adaptativo a partir do logo"
```

---

### Tarefa 5: rodar no celular

**Arquivos:** nenhum (só confirmação).

- [ ] **Passo 1: compilar um APK de debug**

```bash
flutter build apk --debug
```

Esperado: `✓ Built build/app/outputs/flutter-apk/app-debug.apk`.

**Contingência (só se falhar com erro de versão do Java**, por exemplo `Unsupported class file major version` ou `Unsupported Java`):
```bash
sudo pacman -S jdk21-openjdk
flutter config --jdk-dir /usr/lib/jvm/java-21-openjdk
flutter build apk --debug
```

- [ ] **Passo 2: rodar no celular**

```bash
flutter run
```

Esperado:
- o app abre no celular com a barra "My Flashcards" e o texto "Em construção";
- na gaveta de apps, o ícone é o "F" magenta;
- com o tema de ícones do Android 13 ativo, o ícone aparece monocromático.

Pressione `q` no terminal para sair.

- [ ] **Passo 3: checklist da etapa**

- [ ] `flutter doctor` sem erros nas seções Flutter e Android toolchain
- [ ] `flutter analyze` → `No issues found!`
- [ ] `flutter test` → `All tests passed!`
- [ ] O app abre no celular com o nome "My Flashcards" e o ícone do logo

- [ ] **Passo 4: juntar ao `main`**

```bash
git switch main && git merge --no-ff etapa-0-ambiente -m "Etapa 0: ambiente e projeto" && git branch -d etapa-0-ambiente
```

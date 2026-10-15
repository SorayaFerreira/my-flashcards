# Etapa 8: acabamento e release. Plano de implementação

> **Para agentes:** SUB-SKILL OBRIGATÓRIO: use superpowers:subagent-driven-development (recomendado) ou superpowers:executing-plans para executar este plano tarefa por tarefa. Os passos usam caixas (`- [ ]`) para acompanhamento.

**Objetivo:** deixar a versão 1.0.0 pronta para o dia a dia:
- splash nas cores certas;
- visual conferido nos temas claro e escuro;
- APK de release assinado com uma chave própria, com no máximo 15 MB e só as permissões previstas;
- app instalado no celular, com os dados migrados.

**Arquitetura:** não há código novo de funcionalidade. Esta etapa muda recursos Android (estilos), o Gradle (assinatura), a versão e a documentação. Também acrescenta remoções de permissões ao manifesto, se a conferência mostrar alguma indesejada.

**Tecnologias:** Gradle (Kotlin DSL), `keytool` (do JDK), `aapt2` (do Android SDK, build-tools 36.0.0).

**Spec:** [docs/design.md](../design.md), parte 2 ("Visual"), parte 3 ("Permissões") e parte 4 (etapa 8). Requisitos RNF-02, RNF-04, RNF-05 e RNF-07.

**Branch:** `etapa-8-release`

## Restrições globais

- APK de release `arm64-v8a` com **até 15 MB**.
- **Permissões permitidas no APK final:** `RECORD_AUDIO`, `POST_NOTIFICATIONS`, `RECEIVE_BOOT_COMPLETED`, `VIBRATE` (vem do plugin de notificações) e `com.sorayaferreira.myflashcards.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION` (vem do AndroidX).
- **Permissões proibidas:** `INTERNET`, `CAMERA`, `READ_MEDIA_IMAGES`, `READ_MEDIA_AUDIO`, `READ_EXTERNAL_STORAGE`, `WRITE_EXTERNAL_STORAGE`, `SCHEDULE_EXACT_ALARM` e `USE_EXACT_ALARM`.
- **A chave de assinatura e as senhas nunca entram no git.** Elas ficam em `~/.android-keys/` e no `android/key.properties`, que já é ignorado pelo `.gitignore` do template.
- A versão é `1.0.0+1`, igual no `pubspec.yaml` e em `appVersion` (um teste confere).

## Pontos de atenção na revisão

1. **O R8 do build de release apaga o ícone da notificação.** O esperado é a notificação aparecer com o "F" também no APK de release. Conferido no checklist da tarefa 5, graças ao `keep.xml` da etapa 6.
2. **Instalar o release por cima do debug.** O Android recusa, porque as assinaturas são diferentes. O esperado é seguir o roteiro exportar → desinstalar → instalar → importar da tarefa 5, sem perder nada.
3. **Chave de assinatura perdida.** Sem ela, nenhuma atualização futura instala por cima, e a única saída é desinstalar (e só não se perde nada com um backup). O esperado é ter uma cópia guardada fora do computador. Isso está na tarefa 3.
4. **Um plugin acrescenta uma permissão proibida.** O esperado é ela ser removida com `tools:node="remove"`. Tarefa 4.
5. **A versão no `pubspec.yaml` diferente da mostrada nas configurações.** O esperado é o teste de `appVersion` falhar se elas divergirem. Tarefa 2.

---

### Tarefa 1: splash nas cores do app (Android 12 ou mais novo)

> **Já feita na etapa 1 (2026-10-15)**, de outro jeito: a abertura mostra só o "F" do logo (`drawable/splash_logo.xml`) sobre a cor `surface` do tema, configurada direto em `values/` e `values-night/` (o minSdk é 33, então não precisa das pastas `-v31`). Veja "Visual" no [design](../design.md). Nesta etapa, só confira no celular que a abertura continua certa e pule para o passo de criar o branch da tarefa 2.

**Arquivos:**
- Criar: `android/app/src/main/res/values-v31/styles.xml`
- Criar: `android/app/src/main/res/values-night-v31/styles.xml`

- [ ] **Passo 1: criar o branch**

```bash
git switch main && git switch -c etapa-8-release
```

- [ ] **Passo 2: conferir os estilos gerados pelo template**

```bash
cat android/app/src/main/res/values/styles.xml
```

Esperado: dois estilos, `LaunchTheme` e `NormalTheme`, com o pai `@android:style/Theme.Light.NoTitleBar`. Os arquivos abaixo repetem os dois estilos e acrescentam a cor do splash.

- [ ] **Passo 3: criar os estilos para Android 12+**

`android/app/src/main/res/values-v31/styles.xml`:
```xml
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <style name="LaunchTheme" parent="@android:style/Theme.Light.NoTitleBar">
        <item name="android:windowSplashScreenBackground">#FFFFFFFF</item>
    </style>
    <style name="NormalTheme" parent="@android:style/Theme.Light.NoTitleBar">
        <item name="android:windowBackground">?android:colorBackground</item>
    </style>
</resources>
```

`android/app/src/main/res/values-night-v31/styles.xml`:
```xml
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <style name="LaunchTheme" parent="@android:style/Theme.Black.NoTitleBar">
        <item name="android:windowSplashScreenBackground">#FF141218</item>
    </style>
    <style name="NormalTheme" parent="@android:style/Theme.Black.NoTitleBar">
        <item name="android:windowBackground">?android:colorBackground</item>
    </style>
</resources>
```

> O ícone do splash é o ícone adaptativo do app, que o Android 12+ usa por padrão. Não é preciso nenhum pacote de splash.

- [ ] **Passo 4: conferir no celular**

```bash
flutter run
```

Feche o app (removendo-o dos recentes) e abra pelo ícone, nos modos claro e escuro do celular. Esperado: o splash mostra o "F" sobre fundo branco no claro e quase preto no escuro, sem um flash de outra cor.

- [ ] **Passo 5: commit**

```bash
git add android/app/src/main/res/values-v31 android/app/src/main/res/values-night-v31
git commit -m "chore: splash com as cores do app nos temas claro e escuro"
```

---

### Tarefa 2: versão 1.0.0 e revisão visual

**Arquivos:**
- Modificar: `pubspec.yaml` e `lib/app_version.dart`
- Testar: `test/app_version_test.dart` (já existe)

- [ ] **Passo 1: mudar a versão só no `pubspec.yaml` e ver o teste falhar**

No `pubspec.yaml`, troque `version: 0.1.0+1` por:
```yaml
version: 1.0.0+1
```

```bash
flutter test test/app_version_test.dart
```

Esperado: FALHA, com `Expected: '1.0.0'  Actual: '0.1.0'`.

- [ ] **Passo 2: atualizar `appVersion`**

`lib/app_version.dart`:
```dart
/// Keep in sync with `version:` in pubspec.yaml; a test checks it.
const appVersion = '1.0.0';
```

```bash
flutter test && flutter analyze
```

Esperado: `All tests passed!` e `No issues found!`

- [ ] **Passo 3: revisão visual no celular**

```bash
flutter run
```

Confira cada tela nos dois temas (Configurações do Android › Tela › Tema escuro) e com a fonte grande (Configurações › Tela › Tamanho da fonte, no máximo):

- [ ] Lista de decks, deck, editor, revisão, fim da revisão e configurações: nenhum texto cortado ou sobreposto, e nenhuma faixa amarela e preta de *overflow*
- [ ] No tema escuro, os botões e destaques ficam rosa (`#F05BD3`), com texto legível
- [ ] Na revisão, o contador no canto inferior direito não encosta no conteúdo, mesmo com texto longo e imagem
- [ ] Um card com texto bem longo rola dentro do card

Se aparecer *overflow*, corrija o widget afetado, normalmente com `Flexible`, `Expanded` ou `maxLines` + `overflow: TextOverflow.ellipsis`. Depois rode `flutter test` de novo e faça um commit separado: `fix: <tela> sem overflow com fonte grande`.

- [ ] **Passo 4: commit**

```bash
git add pubspec.yaml lib/app_version.dart
git commit -m "chore: versão 1.0.0"
```

---

### Tarefa 3: chave de assinatura de release

**Arquivos:**
- Criar (fora do git): `~/.android-keys/my-flashcards.jks` e `android/key.properties`
- Modificar: `android/app/build.gradle.kts`

- [ ] **Passo 1: gerar a chave**

```bash
mkdir -p ~/.android-keys
keytool -genkey -v -keystore ~/.android-keys/my-flashcards.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias my-flashcards
```

O `keytool` pede uma senha e alguns dados (nome, cidade). **Anote a senha num gerenciador de senhas.**

- [ ] **Passo 2: guardar uma cópia da chave fora do computador**

Copie `~/.android-keys/my-flashcards.jks` para um lugar seguro, por exemplo um pendrive ou uma pasta privada no Drive, junto com a senha guardada no gerenciador. **Sem essa chave, nenhuma atualização futura do app instala por cima da versão atual.**

- [ ] **Passo 3: criar o `key.properties`**

`android/key.properties` (troque `SUA_SENHA` pela senha do passo 1):
```properties
storePassword=SUA_SENHA
keyPassword=SUA_SENHA
keyAlias=my-flashcards
storeFile=/home/soraya/.android-keys/my-flashcards.jks
```

Confira que o git ignora o arquivo:
```bash
git check-ignore android/key.properties
```

Esperado: a saída `android/key.properties`. Se não sair nada, acrescente `key.properties` ao `android/.gitignore` antes de continuar.

- [ ] **Passo 4: usar a chave no build de release**

Em `android/app/build.gradle.kts`:

1. Acrescente no **topo** do arquivo, antes do bloco `plugins { ... }`:
```kotlin
import java.io.FileInputStream
import java.util.Properties

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}
```

2. Dentro de `android { ... }`, logo antes de `buildTypes`, acrescente:
```kotlin
    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String
            keyPassword = keystoreProperties["keyPassword"] as String
            storeFile = keystoreProperties["storeFile"]?.let { file(it) }
            storePassword = keystoreProperties["storePassword"] as String
        }
    }
```

3. Em `buildTypes { release { ... } }`, troque:
```kotlin
            signingConfig = signingConfigs.getByName("debug")
```
por
```kotlin
            signingConfig = signingConfigs.getByName("release")
```

- [ ] **Passo 5: compilar o release**

```bash
flutter build apk --release --split-per-abi
```

Esperado: `✓ Built build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` (e as variantes `armeabi-v7a` e `x86_64`).

- [ ] **Passo 6: conferir que o APK foi assinado com a chave nova**

```bash
~/Android/Sdk/build-tools/36.0.0/apksigner verify --print-certs \
  build/app/outputs/flutter-apk/app-arm64-v8a-release.apk | head -3
```

Esperado: `Signer #1 certificate DN:` com os dados informados no passo 1, e não `CN=Android Debug`.

- [ ] **Passo 7: commit (só o Gradle)**

```bash
git status --short
```

Confira que **nem** `key.properties` **nem** nenhum `.jks` aparecem na lista. Depois:
```bash
git add android/app/build.gradle.kts
git commit -m "chore: assina o build de release com a chave própria"
```

---

### Tarefa 4: conferir tamanho e permissões do APK

**Arquivos:**
- Modificar (só se necessário): `android/app/src/main/AndroidManifest.xml`

- [ ] **Passo 1: conferir o tamanho**

```bash
ls -lh build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

Esperado: **até 15 MB**. Se passar, investigue o que ocupa espaço:
```bash
flutter build apk --release --target-platform android-arm64 --analyze-size
```
Anote o resultado e traga para discussão antes de mudar qualquer coisa.

- [ ] **Passo 2: listar as permissões do APK final**

```bash
~/Android/Sdk/build-tools/36.0.0/aapt2 dump permissions \
  build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

Esperado: só as permissões permitidas nas Restrições globais.

- [ ] **Passo 3: remover permissões proibidas, se aparecerem**

Para **cada** permissão proibida que aparecer:

1. Na tag `<manifest` de `android/app/src/main/AndroidManifest.xml`, acrescente o atributo `xmlns:tools="http://schemas.android.com/tools"`, se ainda não existir.
2. Logo abaixo da tag `<manifest ...>`, acrescente uma linha como esta, trocando o nome:
```xml
    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" tools:node="remove" />
```

Depois recompile e confira de novo:
```bash
flutter build apk --release --split-per-abi
~/Android/Sdk/build-tools/36.0.0/aapt2 dump permissions build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

Se você removeu alguma permissão, faça um commit:
```bash
git add android/app/src/main/AndroidManifest.xml
git commit -m "chore: remove permissões que o app não usa"
```

- [ ] **Passo 4: conferir o identificador, a versão e o SDK mínimo**

```bash
~/Android/Sdk/build-tools/36.0.0/aapt2 dump badging \
  build/app/outputs/flutter-apk/app-arm64-v8a-release.apk | head -3
```

Esperado: `package: name='com.sorayaferreira.myflashcards'`, `versionName='1.0.0'` e `minSdkVersion:'33'`.

---

### Tarefa 5: instalar o release no celular, sem perder dados

**Arquivos:** nenhum.

O celular hoje tem a versão de debug, assinada com outra chave. O Android **não deixa** instalar a de release por cima. O roteiro abaixo leva os dados de uma para a outra.

- [ ] **Passo 1: exportar um backup no app de debug**

No celular: **⚙ › Exportar backup › Google Drive**. Confira que o arquivo apareceu no Drive.

- [ ] **Passo 2: desinstalar a versão de debug**

```bash
adb uninstall com.sorayaferreira.myflashcards
```

Esperado: `Success`.

- [ ] **Passo 3: instalar o release**

```bash
adb install build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

Esperado: `Success`.

- [ ] **Passo 4: importar o backup**

No celular: abra o app › **⚙ › Importar backup**, escolha o arquivo no Drive e toque em **Substituir**. Se o lembrete estava ligado, o Android pede de novo a permissão de notificações.

- [ ] **Passo 5: checklist final com o APK de release**

Requisitos funcionais:
- [ ] RF-01 a RF-04: criar, renomear, excluir e listar decks, com a contagem de cards
- [ ] RF-05 a RF-08 e RF-11: criar, editar e excluir cards, e ver a lista do deck
- [ ] RF-06: um card com os três tipos de conteúdo na frente e só imagem + áudio no verso é salvo e aparece certo
- [ ] RF-09: câmera e galeria funcionam sem pedir permissão
- [ ] RF-10: gravar, ouvir, regravar e remover áudio, com o limite de 60 s
- [ ] RF-12 a RF-17: a revisão vira o card ao arrastar, a ordem tem os menos revisados primeiro e o contador sobe uma vez por sessão no canto inferior direito
- [ ] RF-18: o áudio só toca no ▶
- [ ] RF-19: o lembrete chega entre 9h e 20h, com o ícone do "F" (repita o teste do relógio da etapa 6, **agora no APK de release**)
- [ ] RF-20 e RF-21: exportar e importar funcionaram no roteiro acima

Requisitos não funcionais:
- [ ] RNF-02: com o modo avião ligado, tudo funciona
- [ ] RNF-04: o APK arm64 tem até 15 MB, e o app abre rápido
- [ ] RNF-05: os temas claro e escuro estão conferidos
- [ ] RNF-06: nenhum texto em inglês na interface

---

### Tarefa 6: documentação, tag e fechamento

**Arquivos:**
- Modificar: `docs/README.md` e `README.md`

- [ ] **Passo 1: atualizar a situação nos docs**

Em `docs/README.md`, troque a seção "Situação atual" por:
```markdown
## Situação atual

- **Versão 1.0.0** instalada no celular em AAAA-MM-DD.
- Requisitos, design e planos das etapas 0 a 8: concluídos.
- Próximas ideias ficam em [requisitos.md](requisitos.md), na seção "Fora de escopo".
```
Troque `AAAA-MM-DD` pela data do dia.

- [ ] **Passo 2: acrescentar ao `README.md` da raiz como gerar e instalar**

Acrescente ao fim do `README.md`:
````markdown
## Como gerar e instalar

Pré-requisitos: Flutter 3.47, Android SDK e a chave de assinatura em `~/.android-keys/` (veja `docs/planos/08-acabamento-e-release.md`).

```bash
flutter test
flutter build apk --release --split-per-abi
adb install -r build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

Antes de cada atualização, aumente o número depois do `+` em `version:` no `pubspec.yaml` (por exemplo, `1.0.1+2`) e o `appVersion` em `lib/app_version.dart`.
````

- [ ] **Passo 3: commit, merge e tag**

```bash
git add docs/README.md README.md
git commit -m "docs: versão 1.0.0 e como gerar o APK"
flutter analyze && flutter test
git switch main && git merge --no-ff etapa-8-release -m "Etapa 8: acabamento e release" && git branch -d etapa-8-release
git tag -a v1.0.0 -m "My Flashcards 1.0.0"
```

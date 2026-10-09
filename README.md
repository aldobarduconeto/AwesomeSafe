# Awesome Safe

Awesome Safe é um gerenciador local de cofres para proteger arquivos em dispositivo com criptografia autenticada. Os dados ficam armazenados localmente, a senha não é persistida e o app não depende de sincronização em nuvem.

## Visão geral

- Armazena múltiplos arquivos em um único container `vault.safe` protegido por uma senha mestre
- Usa AES-256-GCM com derivação de chave PBKDF2-HMAC-SHA256
- Mantém o índice autenticado em `SharedPreferences` e a chave de autenticação em `flutter_secure_storage`
- Permite exportação e recriptografia com confirmação de senha
- Suporta seleção de diretório de armazenamento e bloqueio por inatividade
- Oferece limpeza com tentativa de sobrescrita aleatória antes da remoção

## Arquitetura

A estrutura principal do projeto foi organizada para separar responsabilidades:

```text
lib/
├── main.dart
├── models/
│   ├── container_data.dart
│   ├── safe_item.dart
├── screens/
│   ├── home_page.dart
│   ├── settings_page.dart
│   └── widgets/
│       └── loading_overlay.dart
└── services/
    ├── app_dialog_service.dart
    ├── app_theme_service.dart
    ├── vault_service.dart
    └── vault_workflow_service.dart
```

Principais responsabilidades:

- `VaultService`: autenticação, persistência, leitura, escrita, criptografia e exclusão
- `VaultWorkflowService`: fluxo de importação/exportação, MIME, diretórios e validações auxiliadas
- `AppDialogService`: diálogos de MIME, confirmação e versão do app
- `AppThemeService`: persistência e carregamento do tema
- `HomePage` e `SettingsPage`: telas de apresentação e orquestração de ações

## Requisitos

- Flutter SDK 3.3+
- Dart 3.3+
- Android SDK para Android
- Visual Studio com workload Desktop C++ para Windows
- GTK 3 e ferramentas de compilação para Linux

## Executando o projeto

Na raiz do projeto:

```bash
flutter pub get
flutter run -d windows
flutter run -d linux
flutter run -d android
```

### Builds disponíveis

```bash
flutter build apk
flutter build windows
flutter build linux
```

## Como usar

### 1. Proteger um arquivo

1. Informe uma senha com pelo menos oito caracteres.
2. Toque em **Proteger arquivo**.
3. Selecione o arquivo desejado.
4. Confirme o tipo MIME sugerido ou escolha outro.

### 2. Exportar um arquivo

1. Informe a senha do cofre.
2. Selecione o botão de exportação do item.
3. Escolha o destino da exportação.
4. O arquivo será salvo fora do cofre e a sessão será bloqueada novamente.

### 3. Alterar a senha

Acesse **Configurações > Segurança e criptografia > Alterar senha e recriptografar**.

### 4. Mover ou zerar o cofre

Em **Configurações** é possível:

- alterar a pasta do armazenamento local
- zerar o cofre e tentar sobrescrever os dados antigos
- consultar a versão e o build do app

## Segurança e limites

- Criptografia: AES-256-GCM
- Derivação de chave: PBKDF2-HMAC-SHA256 com 1.000.000 iterações
- A senha não é armazenada e não pode ser recuperada em caso de perda
- Ao excluir um item ou zerar o cofre, o app tenta sobrescrever os dados antigos com bytes aleatórios em blocos de 64 KiB
- Esse processo é uma tentativa de melhor esforço, não substitui apagamento físico certificável em SSDs, backups, snapshots ou sistemas copy-on-write

## Dependências principais

- `cryptography`: criptografia, HMAC e derivação de chaves
- `file_picker`: seleção de arquivo, diretório e destino de exportação
- `path_provider`: acesso ao diretório de suporte
- `shared_preferences`: índice e preferências do app
- `flutter_secure_storage`: persistência segura de metadados sensíveis
- `flutter_test` e `flutter_lints`: testes e qualidade de código

## Observações

O aplicativo foi pensado para uso local em dispositivos pessoais. Ele não oferece sincronização em nuvem nem biometria e não garante remoção física de dados em todos os tipos de armazenamento.
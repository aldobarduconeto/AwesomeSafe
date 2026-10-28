# Awesome Safe

## Compartilhar um arquivo protegido

1. Informe a senha do cofre e use o ícone de cadeado do item ("Salvar .safe para compartilhar").
2. Crie uma senha de compartilhamento e salve o `.safe`. Envie esse arquivo para a outra pessoa e comunique a senha por outro canal.
3. No Awesome Safe do outro dispositivo, escolha **Abrir .safe recebido**, informe essa senha, selecione o arquivo e escolha onde salvar o conteúdo descriptografado.

O arquivo portátil contém conteúdo, nome e MIME criptografados com AES-256-GCM e PBKDF2-HMAC-SHA256 (1.000.000 de iterações). Ele não depende do cofre, índice ou armazenamento seguro do dispositivo original. A senha de compartilhamento é independente da senha do cofre e não muda quando a senha do cofre é alterada.

Use a exportação portátil para enviar um item: os arquivos internos `vault.safe` e `<id>.safe` não são pacotes portáteis. Nesta versão, exportação e abertura portáteis carregam o arquivo inteiro em memória; arquivos grandes ficam sujeitos à memória disponível no dispositivo.

**Awesome Safe** é um gerenciador local de arquivos protegidos por criptografia autenticada. O aplicativo não depende de nuvem ou servidores externos; os arquivos ficam no diretório local configurado para o cofre (que pode ser uma unidade selecionada pelo usuário). A senha do cofre não é persistida pelo aplicativo.

## 🧩 Atualizações recentes na pasta `lib/`

A implementação atual em `lib/` consolidou as seguintes melhorias e integrações:

- `App` agora carrega e reaplica o tema persistido via `AppThemeService`, mantendo `light`, `dark` e `system` sincronizados com a UI.
- `HomePage` passou a controlar bloqueio por inatividade de 5 minutos, seleção de MIME customizado, validação do indicador de força da senha e ações de importação/exportação em fluxo protegido.
- `SettingsPage` inclui gerenciamento de armazenamento do cofre, mudança de senha com recriptografia, opção de zerar o cofre com tentativa de sobrescrita e exibição da versão do app.
- `VaultService` sincroniza operações de armazenamento e leitura em streaming, mantém o índice assinado com HMAC em `SharedPreferencesAsync` e usa arquivo temporário, backup e rollback na atualização do container.
- `VaultWorkflowService` centraliza importação/exportação via `file_picker`, cálculo de tamanho formatado e detecção de MIME por extensão com opções pré-definidas.
- Os arquivos do cofre são mantidos no diretório configurado pelo `VaultService`; não há dispersão persistente entre unidades. A migração usa staging temporário no próprio destino.
- `AppColors` unifica o design system monocromático em `lightTheme` e `darkTheme`, mantendo o app consistente em todos os modos visuais.

---

## 🚀 Principais Recursos e Novidades

- **Criptografia Autenticada de Arquivos**: Cifragem com **AES-256-GCM** e derivação de chave via **PBKDF2-HMAC-SHA256** com **1.000.000 de iterações** e salt criptográfico seguro de 16 bytes.
- **Manifesto Criptografado e Arquivos em Separado**: `vault.safe` guarda o manifesto criptografado do cofre; cada arquivo novo é armazenado separadamente como `<id>.safe`, em blocos autenticados. Na ausência ou corrupção do manifesto principal, o serviço tenta recuperar a cópia `vault.safe.bak`.
- **Processamento em Chunks e Streaming de Arquivos Grandes**: A gravação de novos arquivos e a leitura de arquivos no formato de chunks processam dados em blocos de até 1 MiB (`saveFileStream` e `readFileStream`), com cabeçalho `AWSAFE01`, AAD sequencial e registro final autenticado. A leitura em streaming compartilha a exclusão mútua do serviço e mantém o lock durante o consumo do stream, evitando concorrência com operações que alterem ou removam os arquivos.
- **Armazenamento no Diretório Configurado**: Os arquivos protegidos e o manifesto são mantidos no diretório selecionado, sem dispersão persistente por outras raízes. A migração usa uma pasta de staging temporária no destino.
- **Índice Anti-Tampering com Armazenamento Seguro**: O índice possui assinatura HMAC-SHA256. O segredo do HMAC é armazenado exclusivamente via `flutter_secure_storage`; se a leitura ou gravação segura falhar, operações que dependam desse segredo falham explicitamente. Não há fallback para armazenar esse segredo em `SharedPreferences`.
- **Minimização de Metadados no Índice**: O índice externo novo guarda somente identificador, tamanho e data de criação. Nome e MIME são mantidos no manifesto criptografado; índices legados podem conter campos adicionais e itens sem nome/MIME são carregados com valores genéricos.
- **Sessão Segura e Bloqueio por Inatividade**: Timeout automático de 5 minutos sem interação que limpa a senha mestre da memória e bloqueia o cofre; bloqueio de segurança imediato após qualquer operação de exportação.
- **Design System Monocromático e Suporte a Temas**: Interface limpa e minimalista em preto e branco com acentos em azul (`AppColors`), compatível com **Modo Claro**, **Modo Escuro** e **Acompanhamento do Sistema** (`ThemeMode.system`).
- **Sobrescrita de Melhor Esforço**: Ao remover arquivos ou zerar o cofre, o app tenta sobrescrever os arquivos com blocos pseudoaleatórios de 64 KiB antes da exclusão. Essa ação não garante remoção forense das cópias físicas.
- **Migração de Diretório**: A troca de local copia arquivos `.safe` por meio de uma pasta temporária de staging e tenta remover os originais; não é uma transação atômica de todo o cofre e não migra backups `.bak` nem todos os arquivos temporários.
- **Indicador de Força de Senha e Validação MIME**: Sugestão automática de MIME types baseada na extensão com opção de MIME customizado, além de validação dinâmica de entropia da senha digitada.

---

## 🏛️ Arquitetura do Projeto

A base de código segue uma estrutura modular, limpa e desacoplada em `lib/src/`:

```text
lib/
├── main.dart                               # Ponto de entrada da aplicação
└── src/
    ├── app.dart                            # Configuração global de MaterialApp e temas
    ├── models/
    │   ├── container_data.dart             # Modelo do envelope do cofre (versão, metadados e arquivos)
    │   └── safe_item.dart                  # Modelo do item protegido (id, MIME, tamanho e data)
    ├── screens/
    │   ├── home_page.dart                  # Tela principal: listagem, importação, exportação e bloqueio
    │   ├── settings_page.dart              # Tela de configurações: temas, armazenamento, re-key e sobre
    │   └── widgets/
    │       ├── colors.dart                 # Design System (paletas, contrastes e ThemeData)
    │       └── loading_overlay.dart        # Overlay animado com bloqueio de concorrência e mensagens
    └── services/
        ├── app_dialog_service.dart         # Diálogos modais (MIME types, confirmação e versão)
        ├── app_theme_service.dart          # Persistência e restauração do tema do app (SharedPreferences)
        ├── vault_service.dart              # Núcleo de criptografia, sincronização, persistência e I/O do cofre
        └── vault_workflow_service.dart     # Regras de negócio, formatações e integração com file pickers
```

### Responsabilidades dos Módulos

| Componente | Responsabilidade Principal |
| :--- | :--- |
| **`VaultService`** | Gerenciamento de chaves (PBKDF2), cifragem AES-256-GCM, persistência de manifesto e arquivos, streaming por chunks, exclusão mútua (`_exclusive`), atualização com backup/rollback e tentativa de sobrescrita (`_secureDelete`). |
| **`VaultWorkflowService`** | Orquestração de importação/exportação com `FilePicker`, mapeamento de tipos MIME por extensão, formatação de tamanhos e cálculo de força de senha. |
| **`AppDialogService`** | Diálogos modais reutilizáveis para seleção/validação de MIME customizado, diálogos de alerta e confirmação com ação destrutiva. |
| **`AppThemeService`** | Persistência da preferência de tema (`light`, `dark` ou `system`) com retrocompatibilidade com configurações antigas. |
| **`AppColors`** | Definição da identidade visual monocromática (preto/branco com azul de ação), estilos de botões e campos de entrada unificados. |
| **`LoadingOverlay`** | Interceptor de toque (`AbsorbPointer`) com animação fluida e feedback textual durante processos criptográficos demorados. |

---

## 🔒 Especificações de Segurança e Criptografia

| Parâmetro | Implementação Técnica |
| :--- | :--- |
| **Cifra Simétrica** | **AES-256-GCM** com tag de autenticação completa de 128 bits (16 bytes). |
| **Derivação de Chave (KDF)** | **PBKDF2** com função pseudoaleatória **HMAC-SHA256**, **1.000.000 iterações** e salt de 16 bytes obtido via gerador criptograficamente seguro (`Random.secure()`). |
| **Formato de Streaming** | Assinatura `AWSAFE01` (8 bytes), blocos de até 1 MiB, nonce e tag AES-GCM por registro, AAD com sequência para detectar reordenação/duplicação e registro final autenticado para detectar arquivo incompleto. Nonces aleatórios reduzem, mas não eliminam matematicamente, a possibilidade de colisão. |
| **Integridade do Índice** | **HMAC-SHA256** calculado sobre o payload JSON do índice; a MAC é armazenada junto ao payload. O segredo é mantido via `flutter_secure_storage`; a aplicação não o grava em `SharedPreferences` como fallback e interrompe operações dependentes se o armazenamento seguro falhar. |
| **Backend no Windows** | O backend Windows incluído usa `CryptProtectData` (DPAPI) com as opções padrão, protegendo os dados no contexto do usuário do Windows. Isso não é uma garantia de armazenamento em hardware; a segurança depende também da proteção da conta e do perfil do sistema operacional. |
| **Metadados do Índice** | O índice externo novo contém somente identificador, tamanho e data de criação. Nome e MIME são gravados no manifesto criptografado; índices legados podem conter metadados adicionais. Se o índice não tiver nome ou MIME, o item é carregado com valores genéricos. |
| **Persistência do Índice** | **`SharedPreferencesAsync`** armazena o registro assinado do índice. O segredo HMAC fica separado no armazenamento seguro do sistema. |
| **Atualização do Manifesto** | O manifesto é escrito em arquivo temporário com `flush()`, e o serviço mantém backup e tenta rollback se a substituição falhar. Isso não equivale a uma transação atômica de todo o cofre nem garante recuperação de qualquer interrupção ou falha física. |
| **Sobrescrita de Disco** | Uma tentativa de sobrescrita em blocos de 64 KiB com bytes aleatórios antes da exclusão (medida de melhor esforço, sem garantia de remoção física). |
| **Persistência de Segredos** | **Nenhum segredo ou senha em texto puro é gravado em disco.** Se a senha for perdida, os dados não podem ser recuperados. |

### Limites e comportamento das correções de segurança

- Novos arquivos são gravados em arquivos separados, criptografados por blocos; o caminho principal de importação não acumula o arquivo inteiro nem o codifica em Base64 dentro do JSON do container. Dados embutidos em containers legados são migrados para arquivos criptografados em blocos quando o container é atualizado.
- A leitura em streaming é sincronizada com gravações, exclusões, migrações e mudanças de senha. O lock permanece ativo até o stream ser consumido ou cancelado, evitando que essas operações substituam ou removam o arquivo durante a leitura.
- A exportação atual usa `readFile()` e carrega o arquivo descriptografado inteiro em memória antes de entregá-lo ao seletor de arquivos. `readFileStream()` permite consumo em fluxo, mas ainda não é usado pelo fluxo de exportação da interface.
- A exclusão sobrescreve arquivos como tentativa de melhor esforço. SSDs, armazenamento flash, snapshots, backups, sistemas *copy-on-write* e recursos do sistema de arquivos podem preservar cópias; a aplicação não pode garantir apagamento físico ou forense.
- A chave do HMAC não tem fallback em preferências comuns. Uma chave legada em `SharedPreferences` é migrada para o armazenamento seguro antes de remover a cópia antiga; se não for possível acessar ou gravar no armazenamento seguro, a chave não é usada como alternativa e a operação falha explicitamente.
- O índice atual minimiza metadados externos, mas versões antigas podem ter gravado nome, MIME ou outros campos em preferências. A aplicação não pode garantir que cópias antigas desses dados tenham sido removidas de backups ou snapshots do dispositivo.

### 🔍 Detalhamento Criptográfico: Por que Nonce de 12 Bytes e MAC de 16 Bytes?

Uma dúvida comum em arquiteturas criptográficas é o tamanho do nonce e da tag utilizados pelo aplicativo:

#### 1. MAC de 16 Bytes (128 bits) — Limite Máximo da Cifra
* **Implementação:** O aplicativo usa a tag AES-GCM completa de 16 bytes (128 bits). A garantia concreta de integridade depende também do protocolo, do volume processado e do número de tentativas de verificação; não deve ser resumida como uma probabilidade universal de falsificação.
* **Tamanho da tag:** A tag autenticadora do AES-GCM tem no máximo 16 bytes. O Awesome Safe usa esse tamanho completo.

#### 2. Nonce de 12 Bytes (96 bits) — tamanho recomendado para AES-GCM
* **Recomendação:** O NIST ([SP 800-38D](https://csrc.nist.gov/publications/detail/sp/800-38d/final)) recomenda IVs de 96 bits para AES-GCM. O algoritmo também define tratamento para outros comprimentos; 96 bits não é o único comprimento válido.
* **Implementação:** O formato atual usa nonces de 12 bytes, gerados pela implementação AES-GCM para cada registro criptografado. Nonces aleatórios têm probabilidade de colisão que cresce com o número de registros e não oferecem garantia matemática de unicidade.
* **Outros algoritmos:** XChaCha20-Poly1305 usa nonce de 24 bytes e oferece um espaço aleatório maior, mas também não torna colisões matematicamente impossíveis.

#### 3. Proteção via AAD Sequencial
O formato inclui o **índice numérico do registro** nos dados associados autenticados (**AAD - Additional Authenticated Data**), permitindo detectar reordenação ou duplicação de registros. O registro final autenticado e a verificação de dados extras detectam truncamento ou anexação. O AAD não evita colisões ou reutilização de nonce.

---

## 💻 Plataformas Suportadas

- **Windows** (x64 nativo)
- **Android** (Celulares e Tablets)
- **Linux** (GTK 3 nativo)

> [!NOTE]
> **Por que o navegador Web não é suportado?**
> O Awesome Safe foi concebido como um cofre de armazenamento físico offline. Ambientes de navegador Web rodam em sandbox estrita e não possuem acesso direto ao sistema de arquivos do disco rígido nem ao plugin `path_provider` (`getApplicationSupportDirectory`).

---

## 🛠️ Requisitos de Ambiente

- **Flutter SDK**: `>= 3.3.0 < 4.0.0`
- **Dart SDK**: `>= 3.3.0 < 4.0.0`
- **Windows**: Visual Studio 2022 (com workload "Desenvolvimento para Desktop com C++")
- **Android**: Android Studio e Android SDK instalados

---

## ⚙️ Como Executar o Projeto

1. Instale as dependências:
   ```bash
   flutter pub get
   ```

2. Execute na sua plataforma nativa de preferência:
   ```bash
   # Desktop Windows (Recomendado no PC)
   flutter run -d windows

   # Dispositivo Android conectado ou emulador
   flutter run -d android

   # Desktop Linux 
   flutter run -d linux
   ```

### Geração de Builds de Produção

```bash
# Executável para Windows
flutter build windows

# Pacote APK para Android
flutter build apk --release

# Pacote linux estático
flutter build linux --release
```

### Gerar Ícones do Aplicativo

Para atualizar os ícones das plataformas com base em `assets/icon/app_icon.png`:

```bash
dart run flutter_launcher_icons
```

---

## 📖 Como Usar

### 1. Proteger um Arquivo no Cofre
1. Digite a sua senha mestre no campo **Senha do cofre** (o indicador abaixo informará a qualidade da senha).
2. Clique no botão **Proteger arquivo**.
3. Selecione o arquivo desejado pelo gerenciador do sistema.
4. Confirme o tipo MIME detectado automaticamente ou especifique um personalizado no diálogo.
5. O arquivo será cifrado em blocos e salvo como arquivo separado no diretório do cofre; o manifesto criptografado (`vault.safe`) mantém os metadados necessários para listá-lo.

### 2. Exportar um Arquivo Descriptografado
1. Caso a sessão esteja bloqueada, digite a senha mestre no campo principal.
2. No card do arquivo desejado, clique no botão de download (**Exportar**).
3. Escolha o destino onde deseja salvar o arquivo restaurado.
4. **Por segurança, o cofre bloqueia a sessão imediatamente** após a exportação e limpa a senha digitada.

### 3. Excluir Arquivos
1. Clique no botão de lixeira do item.
2. Digite a senha mestre caso solicitado para autorizar a remoção e reescrever o container.
3. O item será eliminado do índice e o app tentará sobrescrever o arquivo antes da exclusão; essa tentativa não garante remoção física de cópias.

### 4. Alterar Senha e Recriptografar o Cofre
1. Vá em **Configurações** (ícone de engrenagem no topo).
2. Em **Segurança e criptografia**, clique em **Alterar senha e recriptografar**.
3. Informe a senha atual, digite a nova senha e a confirme.
4. O manifesto é atualizado e os arquivos compatíveis com o formato em chunks são recriptografados individualmente. A operação não é uma transação única para todo o cofre; mantenha uma cópia de segurança dos dados importantes antes de alterar a senha.

### 5. Alterar Pasta de Armazenamento ou Zerar o Cofre
- **Alterar pasta**: Em **Configurações > Armazenamento**, selecione uma nova pasta ou unidade. O app copia os arquivos `.safe` para uma pasta temporária no destino, depois tenta sobrescrever e excluir os arquivos de origem. A operação não é transacional e não copia backups `.bak`; confirme que o cofre abriu no destino antes de considerar a migração concluída.
- **Zerar cofre**: Exclui os arquivos e backups locais após tentativa de sobrescrita e redefine os registros de índice. A remoção física definitiva não pode ser garantida em todos os sistemas de arquivos e dispositivos.

### 6. Alternar Temas
Em **Configurações > Aparência**, escolha entre **Modo Claro**, **Modo Escuro** ou **Sistema**. A preferência é salva e aplicada instantaneamente.

---

## 📦 Dependências Principais

- [`cryptography`](https://pub.dev/packages/cryptography): Primitivas criptográficas puras (AES-GCM, PBKDF2, HMAC-SHA256).
- [`flutter_secure_storage`](https://pub.dev/packages/flutter_secure_storage): Integração com o backend de armazenamento seguro da plataforma para a chave de validação do índice. No Windows, o backend usa DPAPI no contexto do usuário, não armazenamento protegido por hardware; no Linux, a disponibilidade depende do serviço de segredos do ambiente.
- [`shared_preferences`](https://pub.dev/packages/shared_preferences): Persistência de preferências de tema e índice assinado do cofre.
- [`file_picker`](https://pub.dev/packages/file_picker): Diálogos nativos de seleção de arquivos, pastas e salvamento.
- [`path_provider`](https://pub.dev/packages/path_provider): Resolução de diretórios padrão do sistema operacional.
- [`flutter_launcher_icons`](https://pub.dev/packages/flutter_launcher_icons): Ferramenta de geração automatizada de ícones nativos.

---

## ⚠️ Considerações de Segurança e Limitações

- **Sem Recuperação de Senha**: Se a senha for esquecida, não há mecanismo de recuperação para os arquivos criptografados com ela.
- **Armazenamento Físico e SSDs**: A função de sobrescrita aleatória de arquivos é uma medida de melhor esforço (*best-effort*). Controladoras de SSDs com *wear leveling*, memórias flash, backups de sistema de arquivos e sistemas *copy-on-write* (ex: ZFS, Btrfs) podem manter fragmentos residuais físicos fora do alcance de aplicações em nível de usuário.
- **Segurança do dispositivo**: A criptografia protege o conteúdo dos arquivos armazenados, mas não substitui a segurança do sistema operacional, da conta de usuário ou contra malware em execução (*keyloggers* ou captura de tela).

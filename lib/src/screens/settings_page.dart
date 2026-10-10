import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show appBuildName, appBuildNumber;
import 'package:awesome_safe/src/services/vault_service.dart';
import 'package:awesome_safe/src/services/vault_workflow_service.dart';
import 'package:awesome_safe/src/screens/widgets/loading_overlay.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.vaultService, required this.themeMode, required this.onThemeModeChanged});

  final ThemeMode themeMode;
  final VaultService vaultService;
  final ValueChanged<ThemeMode> onThemeModeChanged;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final VaultWorkflowService _workflowService;
  late ThemeMode _currentThemeMode;
  String? _storagePath;
  bool _loading = true;
  bool _moving = false;
  String? _movingMessage;
  String? _message;

  @override
  void initState() {
    super.initState();
    _currentThemeMode = widget.themeMode;
    _workflowService = VaultWorkflowService(widget.vaultService);
    widget.vaultService.storageLocation().then((path) {
      if (mounted) {setState(() {_storagePath = path; _loading = false;});}
    });
  }

  @override
  void didUpdateWidget(covariant SettingsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.themeMode != widget.themeMode) {
      _currentThemeMode = widget.themeMode;
    }
  }

  Future<void> _runTask(
      String loadingMsg, Future<String?> Function() task) async {
    setState(() {
      _moving = true;
      _movingMessage = loadingMsg;
      _message = null;
    });
    try {
      final resultMsg = await task();
      if (mounted && resultMsg != null) setState(() => _message = resultMsg);
    } on FormatException catch (e) {
      if (mounted) setState(() => _message = e.message);
    } catch (error) {
      if (mounted) {
        setState(() => _message = 'Falha ao executar operação: $error');
      }
    } finally {
      if (mounted) {
        setState(() {
          _moving = false;
          _movingMessage = null;
        });
      }
    }
  }

  Future<bool> _confirm(String title, String content, String actionLabel,
      {bool isDestructive = false}) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(title),
            content: Text(content),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancelar')),
              FilledButton(
                style: isDestructive
                    ? FilledButton.styleFrom(
                        backgroundColor: Theme.of(ctx).colorScheme.error)
                    : null,
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(actionLabel),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _chooseStorageDirectory() async {
    final path = await _workflowService.chooseStorageDirectory();
    if (path == null || path == _storagePath || !mounted) return;
    if (!await _confirm(
        'Mover o cofre?',
        'Os arquivos cifrados existentes serão movidos para a nova pasta.',
        'Mover arquivos')) {
      return;
    }

    await _runTask('Movendo arquivos do cofre...', () async {
      await widget.vaultService.changeStorageDirectory(path);
      _storagePath = path;
      return 'Local do cofre atualizado com sucesso.';
    });
  }

  Future<void> _clearVault() async {
    if (!await _confirm(
        'Zerar o cofre?',
        'O app tentará sobrescrever os arquivos protegidos com bytes aleatórios '
            'antes de removê-los. Isso é uma medida de melhor esforço e não garante '
            'apagamento físico em SSDs, snapshots, backups ou sistemas copy-on-write.',
        'Zerar cofre',
        isDestructive: true)) {
      return;
    }

    await _runTask('Removendo dados (sobrescrita de melhor esforço)...',
        () async {
      await widget.vaultService.clearVault();
      _storagePath = await widget.vaultService.storageLocation();
      return 'Cofre removido. A sobrescrita foi tentada, mas não garante '
          'apagamento físico em todos os dispositivos.';
    });
  }

  Future<void> _changePassword() async {
    final cur = TextEditingController(),
        nw = TextEditingController(),
        cf = TextEditingController();
    final values = await showDialog<List<String>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Alterar senha'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: cur,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Senha atual')),
            const SizedBox(height: 12),
            TextField(
                controller: nw,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Nova senha')),
            const SizedBox(height: 12),
            TextField(
                controller: cf,
                obscureText: true,
                decoration:
                    const InputDecoration(labelText: 'Confirmar nova senha')),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, [cur.text, nw.text, cf.text]),
            child: const Text('Recriptografar'),
          ),
        ],
      ),
    );
    cur.dispose();
    nw.dispose();
    cf.dispose();
    if (values == null) return;
    if (values[1] != values[2]) {
      setState(() => _message = 'A confirmação da nova senha não coincide.');
      return;
    }

    await _runTask('Recriptografando o cofre...', () async {
      await widget.vaultService
          .changePassword(currentPassword: values[0], newPassword: values[1]);
      return 'Senha alterada e cofre recriptografado com sucesso.';
    });
  }

  Future<void> _showVersion() async {
    const version = appBuildName ?? 'Desconhecida';
    const buildNumber = appBuildNumber;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Versão do aplicativo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, size: 40),
            const SizedBox(height: 12),
            const Text('Awesome Safe\nVersão $version'),
            if (buildNumber != null && buildNumber.isNotEmpty)
              const Text('Build $buildNumber'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
          title: const Text('Configurações',
              style: TextStyle(fontWeight: FontWeight.w800))),
      body: LoadingOverlay(
        isLoading: _moving,
        message: _movingMessage,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
              children: [
                // ── Aparência ──
                Text('Aparência',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(
                    'Escolha entre o modo claro, escuro ou acompanhar o sistema.',
                    style: TextStyle(color: scheme.onSurfaceVariant)),
                const SizedBox(height: 12),
                Card(
                  elevation: 0,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SegmentedButton<ThemeMode>(
                          segments: const [
                            ButtonSegment(
                                value: ThemeMode.light,
                                icon: Icon(Icons.light_mode_outlined),
                                label: Text('Modo Claro')),
                            ButtonSegment(
                                value: ThemeMode.dark,
                                icon: Icon(Icons.dark_mode_outlined),
                                label: Text('Modo Escuro')),
                            ButtonSegment(
                                value: ThemeMode.system,
                                icon: Icon(Icons.brightness_auto_outlined),
                                label: Text('Sistema')),
                          ],
                          selected: {_currentThemeMode},
                          onSelectionChanged: (s) {
                            if (s.isEmpty) return;
                            setState(() => _currentThemeMode = s.first);
                            widget.onThemeModeChanged(s.first);
                          },
                        ),
                        const SizedBox(height: 10),
                        Text(
                          switch (_currentThemeMode) {
                            ThemeMode.light =>
                              'Modo claro ativado: visual brilhante e nítido.',
                            ThemeMode.dark =>
                              'Modo escuro ativado: tons escuros confortáveis para a visão.',
                            ThemeMode.system =>
                              'Modo automático: acompanha o tema do seu dispositivo.',
                          },
                          style: TextStyle(
                              fontSize: 13, color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // ── Armazenamento ──
                Text('Armazenamento',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text('Pasta onde os arquivos protegidos são mantidos.',
                    style: TextStyle(color: scheme.onSurfaceVariant)),
                const SizedBox(height: 12),
                Card(
                  elevation: 0,
                  child: ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.folder)),
                    title: const Text('Local do cofre'),
                    subtitle: _loading
                        ? const Text('Carregando...')
                        : Text(_storagePath ?? 'Local padrão'),
                    trailing: IconButton(
                      onPressed: _moving ? null : _chooseStorageDirectory,
                      icon: const Icon(Icons.drive_file_move),
                      color: scheme.primary,
                      tooltip: 'Alterar pasta',
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _moving ? null : _clearVault,
                  icon: const Icon(Icons.delete_sweep),
                  label: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: Text('Zerar cofre e armazenamento')),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: scheme.error,
                    side: BorderSide(color: scheme.error),
                  ),
                ),
                const SizedBox(height: 24),
                // ── Segurança ──
                Text('Segurança e criptografia',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text('Parâmetros criptográficos aplicados ao cofre.',
                    style: TextStyle(color: scheme.onSurfaceVariant)),
                const SizedBox(height: 12),
                const Card(
                  elevation: 0,
                  child: Column(
                    children: [
                      ListTile(
                          dense: true,
                          leading: Icon(Icons.lock),
                          title: Text('Criptografia'),
                          subtitle: Text('AES-256-GCM em blocos sequenciais')),
                      Divider(height: 1, indent: 56),
                      ListTile(
                          dense: true,
                          leading: Icon(Icons.password),
                          title: Text('Chave'),
                          subtitle:
                              Text('PBKDF2 HMAC-SHA256 (1.000.000 iterações)')),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _moving ? null : _changePassword,
                  icon: const Icon(Icons.key),
                  label: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: Text('Alterar senha e recriptografar')),
                ),
                const SizedBox(height: 24),
                Text('Sobre',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                Card(
                  elevation: 0,
                  child: ListTile(
                    leading:
                        const CircleAvatar(child: Icon(Icons.info_outline)),
                    title: const Text('Versão do aplicativo'),
                    subtitle: const Text(appBuildName ?? 'Versão desconhecida'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _showVersion,
                  ),
                ),
                if (_message != null) ...[
                  const SizedBox(height: 14),
                  Text(_message!,
                      style: TextStyle(
                          color: scheme.primary, fontWeight: FontWeight.w600)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import '../models/safe_item.dart';
import '../services/vault_service.dart';
import '../services/vault_workflow_service.dart';
import 'widgets/loading_overlay.dart';
import 'settings_page.dart';
import 'widgets/colors.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    required this.vaultService,
    required this.themeMode,
    required this.onThemeModeChanged,
    super.key,
  });

  final VaultService vaultService;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _passwordController = TextEditingController();
  late final VaultWorkflowService _workflowService;
  List<SafeItem> _items = const [];
  bool _busy = false;
  String? _busyMessage;
  bool _locked = false;
  bool _obscurePassword = true;
  String? _message;
  Timer? _idleTimer;

  @override
  void initState() {
    super.initState();
    _workflowService = VaultWorkflowService(widget.vaultService);
    _resetIdleTimer();
    _refresh();
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final items = await widget.vaultService.loadItems();
    if (mounted) setState(() => _items = items);
  }

  void _resetIdleTimer() {
    _idleTimer?.cancel();
    _idleTimer = Timer(const Duration(minutes: 5), () {
      if (!mounted) return;
      _passwordController.clear();
      setState(() {
        _locked = true;
        _message = 'Sessão bloqueada por inatividade. Informe a senha.';
      });
    });
  }

  Future<void> _runTask(
      String loadingMsg, Future<String?> Function() task) async {
    setState(() {
      _busy = true;
      _busyMessage = loadingMsg;
      _message = null;
    });
    try {
      final msg = await task();
      if (mounted && msg != null) setState(() => _message = msg);
    } on FormatException catch (e) {
      if (mounted) setState(() => _message = e.message);
    } catch (e) {
      if (mounted) setState(() => _message = 'Erro: $e');
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _busyMessage = null;
        });
      }
    }
  }

  Future<String?> _chooseMimeType(String? suggestedMimeType) async {
    final customMime = TextEditingController(text: suggestedMimeType ?? '');
    const options = VaultWorkflowService.mimeTypeOptions;
    var selected = options.values.contains(suggestedMimeType)
        ? suggestedMimeType!
        : 'custom';
    String? errorMsg;

    try {
      return await showDialog<String>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            title: const Text('Tipo do arquivo'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: selected,
                    decoration: const InputDecoration(labelText: 'Tipo'),
                    items: [
                      ...options.entries.where((e) => e.value != 'custom').map(
                          (e) => DropdownMenuItem(
                              value: e.value, child: Text(e.key))),
                      const DropdownMenuItem(
                          value: 'custom',
                          child: Text('Outro (informar MIME)')),
                    ],
                    onChanged: (v) => v == null
                        ? null
                        : setDialogState(() {
                            selected = v;
                            errorMsg = null;
                          }),
                  ),
                  if (selected == 'custom') ...[
                    const SizedBox(height: 10),
                    TextField(
                      controller: customMime,
                      decoration: const InputDecoration(
                          labelText: 'MIME type', hintText: 'application/zip'),
                      onChanged: (_) => setDialogState(() => errorMsg = null),
                    ),
                  ],
                  if (errorMsg != null) ...[
                    const SizedBox(height: 8),
                    Text(errorMsg!,
                        style: TextStyle(
                            color: Theme.of(ctx).colorScheme.error,
                            fontSize: 13)),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancelar')),
              FilledButton(
                onPressed: () {
                  final mime =
                      selected == 'custom' ? customMime.text.trim() : selected;
                  if (!RegExp(r'^[A-Za-z0-9!#$&^_.+-]+/[A-Za-z0-9!#$&^_.+-]+$')
                      .hasMatch(mime)) {
                    setDialogState(() => errorMsg =
                        'Informe um MIME válido, ex: application/zip.');
                    return;
                  }
                  Navigator.pop(ctx, mime);
                },
                child: const Text('Continuar'),
              ),
            ],
          ),
        ),
      );
    } finally {
      customMime.dispose();
    }
  }

  Future<void> _importFile() async {
    if (_locked) return;
    if (_passwordController.text.isEmpty) {
      setState(() => _message = 'Defina uma senha antes de importar.');
      return;
    }
    await _runTask('Criptografando e protegendo arquivo com AES-256...',
        () async {
      final fileName = await _workflowService.importSelectedFile(
        password: _passwordController.text,
        chooseMimeType: _chooseMimeType,
      );
      if (fileName == null) return null;
      await _refresh();
      return '$fileName protegido no cofre.';
    });
  }

  Future<void> _exportFile(SafeItem item) async {
    if (_locked) return;
    if (_passwordController.text.isEmpty) {
      setState(() => _message = 'Informe a senha para abrir este item.');
      return;
    }
    await _runTask('Descriptografando "${item.fileName}"...', () async {
      await _workflowService.exportItem(
          password: _passwordController.text, item: item);
      _passwordController.clear();
      _locked = true;
      return 'Arquivo descriptografado e exportado. Sessão bloqueada por segurança.';
    });
  }

  Future<void> _deleteFile(SafeItem item) async {
    if (_locked) return;
    final pwdCtrl = TextEditingController(text: _passwordController.text);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remover arquivo?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '"${item.fileName}" será removido do cofre. O app tentará '
              'sobrescrever os dados antigos com bytes aleatórios, mas isso '
              'não garante apagamento físico em SSDs, snapshots ou backups.',
            ),
            if (_items.length > 1 && _passwordController.text.isEmpty) ...[
              const SizedBox(height: 12),
              TextField(
                  controller: pwdCtrl,
                  obscureText: true,
                  decoration:
                      const InputDecoration(labelText: 'Senha do cofre')),
            ],
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
    final pwd =
        pwdCtrl.text.isNotEmpty ? pwdCtrl.text : _passwordController.text;
    pwdCtrl.dispose();
    if (confirmed != true) return;

    await _runTask(
        'Removendo "${item.fileName}" (sobrescrita de melhor esforço)...',
        () async {
      await widget.vaultService.deleteFile(item, password: pwd);
      await _refresh();
      return '${item.fileName} removido. A sobrescrita foi tentada, mas não '
          'garante apagamento físico em todos os dispositivos.';
    });
  }

  Widget _buildHeader(BuildContext context, ColorScheme scheme) {
    return RepaintBoundary(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Seu espaço privado',
              style: Theme.of(context)
                  .textTheme
                  .headlineMedium
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(
              'Arquivos cifrados em blocos no dispositivo. A senha não sai daqui.',
              style: TextStyle(color: scheme.onSurfaceVariant)),
          const SizedBox(height: 20),
          TextField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            onChanged: (v) {
              if (v.isNotEmpty && _locked) setState(() => _locked = false);
              _resetIdleTimer();
            },
            decoration: InputDecoration(
              labelText: 'Senha do cofre',
              prefixIcon: const Icon(Icons.key),
              suffixIcon: IconButton(
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
                icon: Icon(
                    _obscurePassword ? Icons.visibility : Icons.visibility_off),
              ),
            ),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _passwordController,
            builder: (_, val, __) => val.text.isEmpty
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.only(top: 6, left: 12),
                    child: Text(VaultWorkflowService.passwordHint(val.text),
                        style: TextStyle(
                            color: scheme.onSurfaceVariant, fontSize: 12)),
                  ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _busy || _locked ? null : _importFile,
            icon: const Icon(Icons.file_upload),
            label: const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('Proteger arquivo')),
          ),
          if (_message != null) ...[
            const SizedBox(height: 10),
            Text(_message!,
                style: TextStyle(
                    color: scheme.primary, fontWeight: FontWeight.w600)),
          ],
          const SizedBox(height: 28),
          Row(
            children: [
              Text('Arquivos protegidos',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12)),
                child: Text('${_items.length}',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: scheme.onSurfaceVariant)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_items.isEmpty)
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16)),
              child: const Column(
                children: [
                  Icon(Icons.lock, size: 38),
                  SizedBox(height: 10),
                  Text('Seu cofre está vazio',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  SizedBox(height: 4),
                  Text('Importe qualquer tipo de arquivo para começar.'),
                ],
              ),
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
        leading: const Icon(Icons.lock),
        title: const Text('Awesome Safe',
            style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
              onPressed: _busy ? null : _refresh,
              icon: const Icon(Icons.refresh),
              tooltip: 'Atualizar cofre'),
          IconButton(
            onPressed: _busy
                ? null
                : () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => SettingsPage(
                              vaultService: widget.vaultService,
                              themeMode: widget.themeMode,
                              onThemeModeChanged: widget.onThemeModeChanged)),
                    ),
            icon: const Icon(Icons.settings),
            tooltip: 'Configurações',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: LoadingOverlay(
        isLoading: _busy,
        message: _busyMessage,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
              addRepaintBoundaries: true,
              itemCount: _items.isEmpty ? 1 : _items.length + 1,
              itemBuilder: (ctx, i) {
                if (i == 0) return _buildHeader(context, scheme);
                final item = _items[i - 1];
                return _SafeItemCard(
                  key: ValueKey(item.id),
                  item: item,
                  isBusy: _busy,
                  isLocked: _locked,
                  onExport: () => _exportFile(item),
                  onDelete: () => _deleteFile(item),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _SafeItemCard extends StatelessWidget {
  const _SafeItemCard({
    required this.item,
    required this.isBusy,
    required this.isLocked,
    required this.onExport,
    required this.onDelete,
    super.key,
  });

  final SafeItem item;
  final bool isBusy;
  final bool isLocked;
  final VoidCallback onExport;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        elevation: 0,
        child: ListTile(
          dense: true,
          leading: CircleAvatar(
              child: Icon(item.isImage ? Icons.image : Icons.description)),
          title:
              Text(item.fileName, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(
              '${VaultWorkflowService.formatSize(item.byteLength)}  •  ${item.mimeType}'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                  onPressed: isBusy || isLocked ? null : onExport,
                  icon: const Icon(Icons.download),
                  color: Theme.of(context).colorScheme.primary,
                  tooltip: 'Exportar'),
              IconButton(
                  onPressed: isBusy || isLocked ? null : onDelete,
                  icon: const Icon(Icons.delete),
                  color: AppColors.deleteRed,
                  tooltip: 'Excluir'),
            ],
          ),
        ),
      ),
    );
  }
}

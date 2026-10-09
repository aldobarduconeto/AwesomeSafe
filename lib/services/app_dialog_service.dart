import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show appBuildName, appBuildNumber;

import 'vault_workflow_service.dart';

class AppDialogService {
  const AppDialogService();

  Future<String?> chooseMimeType({
    required BuildContext context,
    required String? suggestedMimeType,
  }) async {
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
                      ...options.entries
                          .where((entry) => entry.value != 'custom')
                          .map((entry) => DropdownMenuItem(
                              value: entry.value, child: Text(entry.key))),
                      const DropdownMenuItem(
                        value: 'custom',
                        child: Text('Outro (informar MIME)'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setDialogState(() {
                        selected = value;
                        errorMsg = null;
                      });
                    },
                  ),
                  if (selected == 'custom') ...[
                    const SizedBox(height: 10),
                    TextField(
                      controller: customMime,
                      decoration: const InputDecoration(
                        labelText: 'MIME type',
                        hintText: 'application/zip',
                      ),
                      onChanged: (_) => setDialogState(() => errorMsg = null),
                    ),
                  ],
                  if (errorMsg != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      errorMsg!,
                      style: TextStyle(
                        color: Theme.of(ctx).colorScheme.error,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar'),
              ),
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

  Future<bool> confirm({
    required BuildContext context,
    required String title,
    required String content,
    required String actionLabel,
    bool isDestructive = false,
  }) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(title),
            content: Text(content),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                style: isDestructive
                    ? FilledButton.styleFrom(
                        backgroundColor: Theme.of(ctx).colorScheme.error,
                      )
                    : null,
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(actionLabel),
              ),
            ],
          ),
        ) ??
        false;
    return confirmed;
  }

  Future<void> showVersionDialog(BuildContext context) async {
    const version = appBuildName ?? 'Desconhecida';
    const buildNumber = appBuildNumber;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
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
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }
}

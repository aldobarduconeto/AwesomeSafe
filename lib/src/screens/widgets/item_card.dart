import 'package:awesome_safe/src/screens/widgets/colors.dart';
import 'package:flutter/material.dart';
import 'package:awesome_safe/src/models/safe_item.dart';
import 'package:awesome_safe/src/services/vault_workflow_service.dart';

class SafeItemCard extends StatelessWidget {
  const SafeItemCard({
    super.key,
    required this.item,
    required this.isBusy,
    required this.isLocked,
    required this.onExport,
    required this.onDelete,
    required this.onShare,
  });

  final SafeItem item;
  final bool isBusy;
  final bool isLocked;
  final VoidCallback onExport;
  final VoidCallback onDelete;
  final VoidCallback onShare;

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
                  onPressed: isBusy || isLocked ? null : onShare,
                  icon: const Icon(Icons.lock_outline),
                  tooltip: 'Salvar .safe para compartilhar'),
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

import 'package:flutter/material.dart';

/// Um widget de overlay que exibe um indicador de carregamento (loading)
/// com mensagem contextual durante operações demoradas (como criptografia,
/// recriptografia, exclusão ou exportação), bloqueando interações concorrentes.
class LoadingOverlay extends StatelessWidget {
  const LoadingOverlay({required this.isLoading, required this.child, this.message, super.key});
  final bool isLoading;
  final Widget child;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    return Stack(
      children: [
        child,
        if (isLoading)
          Positioned.fill(
            child: AbsorbPointer(
              absorbing: true,
              child: AnimatedOpacity(
                opacity: isLoading ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                child: Container(
                  color: (isDark ? Colors.black : Colors.black87)
                      .withValues(alpha: 0.65),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 340),
                    child: Card(
                      elevation: 12,
                      shadowColor: Colors.black45,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(22),
                        side: BorderSide(
                          color: scheme.outlineVariant.withValues(alpha: 0.4),
                          width: 1,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 28, horizontal: 24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 48,
                              height: 48,
                              child: CircularProgressIndicator(
                                  strokeWidth: 3.5, color: scheme.primary),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'Processando...',
                              style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.2),
                              textAlign: TextAlign.center,
                            ),
                            if (message != null && message!.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Text(
                                message!,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                  height: 1.35,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

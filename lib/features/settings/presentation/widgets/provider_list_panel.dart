import 'package:baishou/core/models/ai_provider_model.dart';
import 'package:flutter/material.dart';

/// 负责渲染左侧 (或主列表) 的供应商项集合
class ProviderListPanel extends StatelessWidget {
  final List<AiProviderModel> providers;
  final String selectedProviderId;
  final bool isMobile;
  final Widget Function(ProviderType) iconBuilder;
  final void Function(String, bool) onProviderTap;

  const ProviderListPanel({
    super.key,
    required this.providers,
    required this.selectedProviderId,
    required this.isMobile,
    required this.iconBuilder,
    required this.onProviderTap,
  });

  Widget _buildProviderListItem(
    BuildContext context,
    AiProviderModel p,
    bool isMobile,
  ) {
    // 移动端仅作为入口列表，不需要高亮选中态
    final isSelected = !isMobile && selectedProviderId == p.id;
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkWell(
        onTap: () => onProviderTap(p.id, isMobile),
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: isSelected
                ? colorScheme.primaryContainer.withOpacity(0.4)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? colorScheme.primary.withOpacity(0.3)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              SizedBox(width: 32, height: 32, child: iconBuilder(p.type)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  p.name,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected
                        ? colorScheme.primary
                        : colorScheme.onSurface,
                  ),
                ),
              ),
              // 启用状态标签
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: p.isEnabled
                      ? Colors.green.withOpacity(0.1)
                      : Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  p.isEnabled ? 'ON' : 'OFF',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: p.isEnabled
                        ? Colors.green.shade700
                        : Colors.orange.shade700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (providers.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView.builder(
      padding: EdgeInsets.symmetric(vertical: isMobile ? 8 : 16),
      itemCount: providers.length,
      itemBuilder: (context, index) {
        return _buildProviderListItem(context, providers[index], isMobile);
      },
    );
  }
}

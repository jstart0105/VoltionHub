import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import '/core/common/constants/theme/app_colors.dart';
import '/data/models/transformer.dart';

class SummaryCard extends StatefulWidget {
  // Adicionamos a lista como parâmetro obrigatório
  final List<Transformer> transformers;
  final bool isLoading; // Para controlar o loading vindo do pai

  const SummaryCard({
    super.key, 
    required this.transformers,
    this.isLoading = false,
  });

  @override
  State<SummaryCard> createState() => _SummaryCardState();
}

class _SummaryCardState extends State<SummaryCard> {
  int _positionState = 0;
  
  // Variáveis computadas baseadas na lista recebida
  int get _onlineCount => widget.transformers.where((t) => t.status == 'online').length;
  int get _alertCount => widget.transformers.where((t) => t.status == 'alerta').length;
  int get _offlineCount => widget.transformers.where((t) => t.status == 'offline').length;
  int get _maintenanceCount => widget.transformers.where((t) => t.status == 'em manutencao').length;

  Alignment get _alignment {
    switch (_positionState) {
      case -1:
        return Alignment.bottomLeft;
      case 1:
        return Alignment.bottomRight;
      default:
        return Alignment.bottomCenter;
    }
  }

  // Lógica de animação de arrasto para os lados
  void _handleHorizontalDrag(DragUpdateDetails details) {
     if (details.primaryDelta!.abs() > 2) {
        if (details.primaryDelta! > 0) {
          if (_positionState != 1) setState(() => _positionState = 1);
        } else {
          if (_positionState != -1) setState(() => _positionState = -1);
        }
      }
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: _alignment,
      child: GestureDetector(
        onHorizontalDragUpdate: _handleHorizontalDrag,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (Widget child, Animation<double> animation) {
            return FadeTransition(opacity: animation, child: child);
          },
          child: _positionState == 0
              ? _buildExpandedView()
              : _buildMinimizedView(),
        ),
      ),
    );
  }

  Widget _buildExpandedView() {
    return Card(
      key: const ValueKey('expanded'),
      margin: const EdgeInsets.all(16.0),
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
      ),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        child: widget.isLoading
            ? const SizedBox(
                height: 50, 
                width: 50, 
                child: Center(child: CircularProgressIndicator())
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                mainAxisSize: MainAxisSize.max,
                children: [
                  _buildSummaryItem(context, color: AppColors.danger, count: _offlineCount, label: 'Offline'),
                  _buildSummaryItem(context, color: AppColors.alert, count: _alertCount, label: 'Em Alerta'),
                  _buildSummaryItem(context, color: AppColors.maintenance, count: _maintenanceCount, label: 'Em Manutenção'),
                  _buildSummaryItem(context, color: AppColors.success, count: _onlineCount, label: 'Online'),
                ],
              ),
      ),
    );
  }

  Widget _buildMinimizedView() {
    return Card(
      key: const ValueKey('minimized'),
      margin: const EdgeInsets.all(16.0),
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(50.0),
      ),
      elevation: 4,
      child: InkWell(
        borderRadius: BorderRadius.circular(50.0),
        onTap: () {
          setState(() {
            _positionState = 0;
          });
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: widget.isLoading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildMinimizedItem(AppColors.danger, _offlineCount),
                    const Gap(10),
                    _buildMinimizedItem(AppColors.alert, _alertCount),
                    const Gap(10),
                    _buildMinimizedItem(AppColors.maintenance, _maintenanceCount),
                    const Gap(10),
                    _buildMinimizedItem(AppColors.success, _onlineCount),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildMinimizedItem(Color color, int count) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          '$count',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryItem(
    BuildContext context, {
    required Color color,
    required int count,
    required String label,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$count',
          style: TextStyle(
            color: color,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const Gap(4),
        Text(
          label,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}
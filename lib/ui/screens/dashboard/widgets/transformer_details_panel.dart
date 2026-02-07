import 'dart:async';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import '/data/models/transformer.dart';
import '/core/common/constants/theme/app_colors.dart';
import '/data/models/transformer_metric.dart';
import '/core/services/api/api_service.dart';
import 'details_panel/action_buttons.dart';
import 'details_panel/metric_tile.dart';

class TransformerDetailsPanel extends StatefulWidget {
  final Transformer transformer;
  final VoidCallback onClose;

  const TransformerDetailsPanel({
    super.key,
    required this.transformer,
    required this.onClose,
  });

  @override
  State<TransformerDetailsPanel> createState() => _TransformerDetailsPanelState();
}

abstract class MetricState {}
class MetricLoading extends MetricState {}
class MetricError extends MetricState {
  final String message;
  MetricError(this.message);
}
class MetricSuccess extends MetricState {
  final TransformerMetric? latestMetric;
  MetricSuccess(this.latestMetric);
}

class _TransformerDetailsPanelState extends State<TransformerDetailsPanel> {
  final ApiService _apiService = ApiService();
  
  final ValueNotifier<MetricState> _metricState = ValueNotifier(MetricLoading());

  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _fetchLatestMetric();
    _startFetchingPeriodically();
  }

  void _startFetchingPeriodically() {
    _timer = Timer.periodic(const Duration(milliseconds: 4000), (timer) {
      _fetchLatestMetric(showLoading: false);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _metricState.dispose();
    super.dispose();
  }

  Future<void> _fetchLatestMetric({bool showLoading = true}) async {
    try {
      if (showLoading && mounted) {
          _metricState.value = MetricLoading();
      }

      final metric = await _apiService.getLatestMetric(widget.transformer.id);
            
      if (mounted) {
        _metricState.value = MetricSuccess(metric);
      }
    } catch (e) {
      debugPrint("ERRO NA API: $e");
      if (mounted) {
        _metricState.value = MetricError("Erro ao buscar dados: $e");
      }
    }
  }

  Color _getStatusColor(String temperatureStr) {
    if (temperatureStr == 'N/A') {
      return Theme.of(context).colorScheme.onSurface;
    }

    final temp = double.tryParse(temperatureStr.replaceAll('°C', ''));
    if (temp == null) {
      return Theme.of(context).colorScheme.onSurface;
    }

    if (temp > 105 && temp <= 115 || temp < 50) {
      return AppColors.alert;
    } else if (temp <= 105) {
        return AppColors.success;
    } else {
        return AppColors.danger;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.background,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16.0),
          topRight: Radius.circular(16.0),
        ),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      widget.transformer.id,
                      style: GoogleFonts.inter(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ValueListenableBuilder<MetricState>(
                      valueListenable: _metricState,
                      builder: (context, state, _) {
                        String temperatureValue = 'N/A';
                        if (state is MetricSuccess && state.latestMetric != null) {
                          final double? temp = state.latestMetric!.temperature;
                          temperatureValue = temp != null
                              ? '${temp.toStringAsFixed(1)}°C'
                              : 'N/A';
                        }
                        return Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: _getStatusColor(temperatureValue),
                            shape: BoxShape.circle,
                          ),
                        );
                      },
                    ),
                  ],
                ),
                IconButton(
                  icon: Icon(Icons.close, color: Theme.of(context).colorScheme.tertiary),
                  onPressed: widget.onClose,
                ),
              ],
            ),
            Divider(color: Theme.of(context).colorScheme.onSurface, height: 24),
            
            // Conteúdo
            ValueListenableBuilder<MetricState>(
              valueListenable: _metricState,
              builder: (context, state, _) {
                if (state is MetricLoading) {
                  return const Center(child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: CircularProgressIndicator(),
                  ));
                }
                
                if (state is MetricError) {
                  return Center(child: Text(state.message));
                }
                
                if (state is MetricSuccess) {
                  return _buildMetrics(state.latestMetric);
                }
                
                return Container(); 
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetrics(TransformerMetric? metric) {
    // Temperatura (Geral)
    final double? temp = metric?.temperature;
    final temperatureValue = temp != null ? '${temp.toStringAsFixed(1)}°C' : 'N/A';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Exibe temperatura primeiro pois é comum a todas as fases
        MetricTile(
          icon: Icons.thermostat_outlined,
          label: 'Temperatura',
          value: temperatureValue,
          valueColor: _getStatusColor(temperatureValue),
        ),
        const Gap(8),

        // Lógica para exibir fases dinamicamente
        // Se houver tensão ou corrente > 0 na fase, mostramos ela.
        if (_shouldShowPhase(metric?.voltageA, metric?.currentA))
           _buildPhaseSection('Fase A', metric?.voltageA, metric?.currentA, metric?.harmonicDistortionA),
           
        if (_shouldShowPhase(metric?.voltageB, metric?.currentB))
           _buildPhaseSection('Fase B', metric?.voltageB, metric?.currentB, metric?.harmonicDistortionB),
           
        if (_shouldShowPhase(metric?.voltageC, metric?.currentC))
           _buildPhaseSection('Fase C', metric?.voltageC, metric?.currentC, metric?.harmonicDistortionC),

        // Caso não haja dados em nenhuma fase (ex: offline total), mostra aviso
        if (!_anyPhaseActive(metric))
           Padding(
             padding: const EdgeInsets.symmetric(vertical: 8.0),
             child: Text("Sem dados de fase disponíveis.", style: TextStyle(color: Theme.of(context).colorScheme.onSecondary)),
           ),

        const Gap(8),
        ExpansionTile(
          title: Text(
            'Detalhes do Equipamento',
            style: GoogleFonts.inter(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w500,
            ),
          ),
          iconColor: Theme.of(context).colorScheme.onSurface,
          collapsedIconColor: Theme.of(context).colorScheme.onSurface,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Tipo: ${widget.transformer.phaseType}\nCapacidade: ${widget.transformer.capacity}\nEndereço: ${widget.transformer.address}\nÚltima Manutenção: ${widget.transformer.lastMaintenance}",
                  style: GoogleFonts.inter(
                    color: Theme.of(context).colorScheme.onSecondary,
                    height: 1.5,
                  ),
                ),
              ),
            ),
          ],
        ),
        ActionButtons(transformer: widget.transformer),
      ],
    );
  }

  // Verifica se deve exibir a fase (se tem dados válidos)
  bool _shouldShowPhase(double? voltage, double? current) {
    if (voltage != null && voltage > 0) return true;
    if (current != null && current > 0) return true;
    return false;
  }

  bool _anyPhaseActive(TransformerMetric? metric) {
    return _shouldShowPhase(metric?.voltageA, metric?.currentA) ||
           _shouldShowPhase(metric?.voltageB, metric?.currentB) ||
           _shouldShowPhase(metric?.voltageC, metric?.currentC);
  }

  Widget _buildPhaseSection(String title, double? voltage, double? current, double? hd) {
    final vVal = voltage != null ? '${voltage.toStringAsFixed(1)}V' : '0.0V';
    final cVal = current != null ? '${current.toStringAsFixed(1)}A' : '0.0A';
    final hVal = hd != null ? '${hd.toStringAsFixed(1)}%' : '0.0%';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.orange)),
        ),
        MetricTile(
          icon: Icons.flash_on_outlined,
          label: 'Tensão',
          value: vVal,
          valueColor: Theme.of(context).colorScheme.onSurface,
        ),
        MetricTile(
          icon: Icons.power_outlined,
          label: 'Corrente',
          value: cVal,
          valueColor: Theme.of(context).colorScheme.onSurface,
        ),
        MetricTile(
          icon: Icons.waves,
          label: 'Distorção',
          value: hVal,
          valueColor: Theme.of(context).colorScheme.onSurface,
        ),
        const Divider(),
      ],
    );
  }
}
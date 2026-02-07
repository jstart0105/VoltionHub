import 'dart:async';
import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '/core/common/constants/theme/app_colors.dart';
import '/core/services/api/api_service.dart';
import '/data/models/transformer.dart';
import '/data/models/transformer_metric.dart';
import '/ui/widgets/button.dart';
import '/ui/screens/analytics/detailed_analysis_screen.dart';

enum MetricType { temperature, voltage, current, distortion }

class AnalyticsScreen extends StatefulWidget {
  final Transformer transformer;

  const AnalyticsScreen({super.key, required this.transformer});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  final ApiService _apiService = ApiService();
  final ScrollController _scrollController = ScrollController();
  Timer? _refreshTimer;

  // Estado
  bool _isInitialLoading = true;
  List<TransformerMetric> _rawMetrics = [];
  List<TransformerMetric> _displayMetrics = [];

  // Datas de Início e Fim separadas para controle total de dia/hora
  late DateTime _startDateTime;
  late DateTime _endDateTime;

  MetricType _selectedType = MetricType.voltage;
  double _zoomLevel = 1.0;

  bool _showPhaseA = true;
  bool _showPhaseB = true;
  bool _showPhaseC = true;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    // Padrão: Últimas 24h exatas
    _endDateTime = now;
    _startDateTime = now.subtract(const Duration(hours: 24));

    _fetchData(isBackground: false);

    // Timer de atualização
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_isLiveMonitoring()) _fetchData(isBackground: true);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  bool _isLiveMonitoring() {
    // Considera "Ao Vivo" se o fim selecionado estiver a menos de 2 min de agora
    return _endDateTime.difference(DateTime.now()).inMinutes.abs() < 2;
  }

  Future<void> _fetchData({bool isBackground = false}) async {
    if (!isBackground) setState(() => _isInitialLoading = true);
    try {
      // Se estiver monitorando ao vivo, arrasta a janela de tempo junto
      if (isBackground && _isLiveMonitoring()) {
        final now = DateTime.now();
        final duration = _endDateTime.difference(_startDateTime);
        _endDateTime = now;
        _startDateTime = now.subtract(duration);
      }

      final data = await _apiService.getTransformerMetrics(
        widget.transformer.id,
        start: _startDateTime,
        end: _endDateTime,
      );

      if (mounted) {
        setState(() {
          _rawMetrics = data;
          _rawMetrics.sort((a, b) => a.time.compareTo(b.time));
          _processMetricsForDisplay();
          _isInitialLoading = false;
        });
      }
    } catch (e) {
      if (mounted && !isBackground) setState(() => _isInitialLoading = false);
    }
  }

  // --- Lógica de Agregação (Downsampling) ---
  void _processMetricsForDisplay() {
    if (_rawMetrics.isEmpty) {
      _displayMetrics = [];
      return;
    }

    // Ordenação garantida antes de processar
    _rawMetrics.sort((a, b) => a.time.compareTo(b.time));

    // Determina quantos pontos queremos ver na tela (resolução)
    final int targetPoints = (50 * _zoomLevel).toInt().clamp(20, 200); 
    
    final int totalDurationMs = _endDateTime.difference(_startDateTime).inMilliseconds;
    if (totalDurationMs == 0) return;

    // Tamanho da janela em MS
    final double stepMs = totalDurationMs / targetPoints;

    List<TransformerMetric> aggregated = [];
    
    // Agrupa por janelas de tempo fixas
    for (int i = 0; i < targetPoints; i++) {
      final double windowStart = _startDateTime.millisecondsSinceEpoch + (i * stepMs);
      final double windowEnd = windowStart + stepMs;

      // Pega todos os pontos que caem nesta janela
      final chunk = _rawMetrics.where((m) {
        final t = m.time.millisecondsSinceEpoch;
        return t >= windowStart && t < windowEnd;
      }).toList();

      if (chunk.isNotEmpty) {
        // O tempo do ponto será o CENTRO da janela, garantindo espaçamento visual perfeito
        final centerTime = windowStart + (stepMs / 2);
        aggregated.add(_calculateAverageMetric(chunk, centerTime.toInt()));
      }
    }
    _displayMetrics = aggregated;
  }

  // Modificado para aceitar o tempo forçado (visual limpo)
  TransformerMetric _calculateAverageMetric(List<TransformerMetric> chunk, int fixedTimeMs) {
    if (chunk.isEmpty) return _rawMetrics.first;
    
    double avgTemp = 0;
    double avgVa = 0, avgVb = 0, avgVc = 0;
    double avgCa = 0, avgCb = 0, avgCc = 0;
    double avgHa = 0, avgHb = 0, avgHc = 0;

    for (var m in chunk) {
      avgTemp += m.temperature ?? 0;
      avgVa += m.voltageA ?? 0;
      avgVb += m.voltageB ?? 0;
      avgVc += m.voltageC ?? 0;
      avgCa += m.currentA ?? 0;
      avgCb += m.currentB ?? 0;
      avgCc += m.currentC ?? 0;
      avgHa += m.harmonicDistortionA ?? 0;
      avgHb += m.harmonicDistortionB ?? 0;
      avgHc += m.harmonicDistortionC ?? 0;
    }
    final count = chunk.length;

    return TransformerMetric(
      time: DateTime.fromMillisecondsSinceEpoch(fixedTimeMs), // Usa o tempo fixo da janela
      transformerId: chunk.first.transformerId,
      temperature: avgTemp / count,
      voltageA: avgVa / count,
      voltageB: avgVb / count,
      voltageC: avgVc / count,
      currentA: avgCa / count,
      currentB: avgCb / count,
      currentC: avgCc / count,
      harmonicDistortionA: avgHa / count,
      harmonicDistortionB: avgHb / count,
      harmonicDistortionC: avgHc / count,
    );
  }

  // --- Novo Seletor de Data e Hora ---
  Future<void> _showCustomRangePicker() async {
    await showModalBottomSheet(
      context: context,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        height: 320,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Filtrar Período",
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 24),
            _buildDateTimePickerRow("Início", _startDateTime, (newDate) {
              setState(() => _startDateTime = newDate);
            }),
            const SizedBox(height: 16),
            _buildDateTimePickerRow("Fim", _endDateTime, (newDate) {
              setState(() => _endDateTime = newDate);
            }),
            const Spacer(),
            CustomButton(
              text: "Aplicar Filtro",
              onPressed: () {
                Navigator.pop(ctx);
                _fetchData(isBackground: false);
              },
            )
          ],
        ),
      ),
    );
  }

  Widget _buildDateTimePickerRow(
      String label, DateTime current, Function(DateTime) onChanged) {
    return Row(
      children: [
        SizedBox(
            width: 60,
            child: Text(label,
                style: const TextStyle(fontWeight: FontWeight.bold))),
        Expanded(
          child: InkWell(
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: current,
                firstDate: DateTime(2020),
                lastDate: DateTime.now().add(
                    const Duration(days: 1)), 
              );
              if (date != null) {
                // ignore: use_build_context_synchronously
                final time = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay.fromDateTime(current),
                );
                if (time != null) {
                  onChanged(DateTime(
                      date.year, date.month, date.day, time.hour, time.minute));
                }
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.withOpacity(0.5)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(DateFormat('dd/MM/yyyy HH:mm').format(current)),
                  const Icon(Icons.edit_calendar,
                      size: 18, color: Colors.grey),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // --- UI Principal ---
  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).colorScheme.onSurface;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Análise: ${widget.transformer.id}',
                style: const TextStyle(fontSize: 16)),
            Text(
              '${DateFormat('dd/MM HH:mm').format(_startDateTime)} até ${DateFormat('dd/MM HH:mm').format(_endDateTime)}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.analytics_outlined),
            tooltip: "Análise Detalhada",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DetailedAnalysisScreen(transformer: widget.transformer),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.tune),
            onPressed: _showCustomRangePicker,
          )
        ],
      ),
      body: _isInitialLoading
          ? const Center(child: CircularProgressIndicator())
          : _rawMetrics.isEmpty
              ? const Center(child: Text("Sem dados para o período."))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // --- Chips de Tipo ---
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: MetricType.values.map((type) {
                          final isSelected = _selectedType == type;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: ChoiceChip(
                              label: Text(_getMetricLabel(type)),
                              selected: isSelected,
                              selectedColor: AppColors.orange.withOpacity(0.2),
                              labelStyle: TextStyle(
                                  color:
                                      isSelected ? AppColors.orange : textColor,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal),
                              onSelected: (bool selected) {
                                if (selected) {
                                  setState(() => _selectedType = type);
                                }
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // --- Toggle Fases ---
                    if (_selectedType != MetricType.temperature)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildPhaseToggle('Fase A', Colors.redAccent,
                                _showPhaseA, (v) => setState(() => _showPhaseA = v)),
                            const SizedBox(width: 12),
                            _buildPhaseToggle('Fase B', Colors.green, _showPhaseB,
                                (v) => setState(() => _showPhaseB = v)),
                            const SizedBox(width: 12),
                            _buildPhaseToggle('Fase C', Colors.blueAccent,
                                _showPhaseC, (v) => setState(() => _showPhaseC = v)),
                          ],
                        ),
                      ),

                    // --- Cards Resumo ---
                    Row(
                      children: [
                        _buildSummaryCard('Pico', _getMax(_selectedType),
                            AppColors.danger,
                            isDarkCard: false),
                        const SizedBox(width: 10),
                        _buildSummaryCard('Média', _getAvg(_selectedType),
                            Colors.blue,
                            isDarkCard: true),
                        const SizedBox(width: 10),
                        _buildSummaryCard('Mínimo', _getMin(_selectedType),
                            AppColors.success,
                            isDarkCard: false),
                      ],
                    ),

                    const SizedBox(height: 30),

                    // --- Slider Zoom ---
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Evolução (Zoom)",
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        Row(
                          children: [
                            const Icon(Icons.zoom_out, size: 16),
                            SizedBox(
                              width: 150,
                              child: Slider(
                                value: _zoomLevel,
                                min: 0.5,
                                max: 5.0,
                                divisions: 9,
                                label: "${_zoomLevel}x",
                                activeColor: AppColors.orange,
                                onChanged: (value) {
                                  setState(() {
                                    _zoomLevel = value;
                                    _processMetricsForDisplay();
                                  });
                                },
                              ),
                            ),
                            const Icon(Icons.zoom_in, size: 16),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // --- GRÁFICO PRINCIPAL ---
                    Container(
                      height: 350,
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black12,
                              blurRadius: 4,
                              offset: const Offset(0, 2))
                        ],
                      ),
                      child: Row(
                        children: [
                          // Eixo Y Fixo
                          Container(
                            width: 50,
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            decoration: BoxDecoration(
                                border: Border(
                                    right: BorderSide(
                                        color: Colors.grey.withOpacity(0.2)))),
                            child: LineChart(_buildAxisChartData()),
                          ),
                          // Conteúdo Rolável
                          Expanded(
                            child: SingleChildScrollView(
                              controller: _scrollController,
                              scrollDirection: Axis.horizontal,
                              physics: const ClampingScrollPhysics(),
                              child: SizedBox(
                                // Largura dinâmica baseada no TEMPO (duração) e não nos pontos
                                // Isso garante escala linear
                                width: _calculateChartWidth(context),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 20, horizontal: 10),
                                  child: LineChart(_buildMainChartData()),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        "Exibindo ${_displayMetrics.length} pontos processados",
                        style: const TextStyle(
                            fontSize: 10,
                            color: Colors.grey,
                            fontStyle: FontStyle.italic),
                        textAlign: TextAlign.right,
                      ),
                    ),

                    const SizedBox(height: 30),
                    Text("Distribuição de Carga",
                        style: GoogleFonts.inter(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),

                    Container(
                      height: 250,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black12,
                              blurRadius: 4,
                              offset: const Offset(0, 2))
                        ],
                      ),
                      child: BarChart(_buildDistributionChart()),
                    ),
                    const SizedBox(height: 50),
                  ],
                ),
    );
  }

  // Helper para largura do gráfico:
  double _calculateChartWidth(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width - 100; // desconta eixo Y e padding
    if (_zoomLevel <= 1.0) return screenWidth;
    return screenWidth * _zoomLevel;
  }

  // --- Construção dos Gráficos ---

  // Cálculo de escala Y
  double get _minY {
    final val = _getMin(_selectedType);
    final max = _getMax(_selectedType);
    if (val == max) return val * 0.9;
    final amplitude = max - val;
    return val - (amplitude * 0.1);
  }

  double get _maxY {
    final val = _getMax(_selectedType);
    final min = _getMin(_selectedType);
    if (val == min) return val * 1.1;
    final amplitude = val - min;
    return val + (amplitude * 0.1);
  }

  // Gráfico do Eixo Y (Fixo)
  LineChartData _buildAxisChartData() {
    return LineChartData(
      minY: _minY,
      maxY: _maxY,
      gridData: FlGridData(show: false),
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(
            sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (v, m) => Text(v.toStringAsFixed(1),
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                    textAlign: TextAlign.right))),
        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
            sideTitles: SideTitles(
                showTitles: true, getTitlesWidget: (v, m) => const Text(''))),
      ),
      borderData: FlBorderData(show: false),
      lineBarsData: [],
    );
  }

  // Gráfico Principal (Scrollável)
  // --- Lógica de Intervalo Inteligente ---
  double _getIntervalForZoom() {
    const hourMs = 3600000.0;
    
    // Se o zoom for alto (5x), força intervalo de 1 hora
    if (_zoomLevel >= 4.5) return hourMs; 
    
    // Lógica padrão para outros níveis
    if (_zoomLevel <= 1.0) return hourMs * 4; 
    return hourMs * 2;
  }

  LineChartData _buildMainChartData() {
    final bool showPhases = _selectedType != MetricType.temperature;
    List<LineChartBarData> lines = [];

    final double startTime = _startDateTime.millisecondsSinceEpoch.toDouble();
    final double endTime = _endDateTime.millisecondsSinceEpoch.toDouble();

    if (showPhases) {
      if (_showPhaseA) lines.add(_createLine((m) => _getPhaseValue(m, 'A'), Colors.redAccent));
      if (_showPhaseB) lines.add(_createLine((m) => _getPhaseValue(m, 'B'), Colors.green));
      if (_showPhaseC) lines.add(_createLine((m) => _getPhaseValue(m, 'C'), Colors.blueAccent));
    } else {
      lines.add(_createLine((m) => m.temperature ?? 0, AppColors.orange));
    }

    final double dynamicInterval = _getIntervalForZoom();

    return LineChartData(
      minY: _minY,
      maxY: _maxY,
      minX: startTime,
      maxX: endTime,
      clipData: FlClipData.all(),
      gridData: FlGridData(
        show: true,
        drawVerticalLine: true,
        verticalInterval: dynamicInterval, // Respeita a lógica de 1h no 5x
        getDrawingVerticalLine: (_) => FlLine(color: Colors.grey.withOpacity(0.1), strokeWidth: 1),
        getDrawingHorizontalLine: (_) => FlLine(color: Colors.grey.withOpacity(0.1), strokeWidth: 1),
      ),
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 32,
            interval: dynamicInterval,
            getTitlesWidget: (value, meta) {
              final date = DateTime.fromMillisecondsSinceEpoch(value.toInt());
              // Se o intervalo for de 1h (zoom 5x), mostra HH:mm, senão dd/MM HH
              String format = dynamicInterval < 86400000 ? 'HH:mm' : 'dd/MM';
              
              return Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  DateFormat(format).format(date),
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
                ),
              );
            },
          ),
        ),
      ),
      borderData: FlBorderData(show: false),
      lineBarsData: lines,
      // Tooltip melhorado
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          fitInsideHorizontally: true,
          tooltipRoundedRadius: 8,
          tooltipPadding: const EdgeInsets.all(8),
          getTooltipItems: (touchedSpots) {
            return touchedSpots.map((LineBarSpot touchedSpot) {
               final date = DateTime.fromMillisecondsSinceEpoch(touchedSpot.x.toInt());
               return LineTooltipItem(
                 '${DateFormat('HH:mm:ss').format(date)}\n',
                 const TextStyle(color: Colors.white70, fontSize: 10),
                 children: [
                   TextSpan(
                     text: '${touchedSpot.y.toStringAsFixed(1)} ${_getUnit(_selectedType)}',
                     style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                   )
                 ]
               );
            }).toList();
          },
        ),
      ),
    );
  }

  LineChartBarData _createLine(
      double Function(TransformerMetric) getValue, Color color) {
    return LineChartBarData(
      // AQUI A MÁGICA: X = Timestamp (ms)
      spots: _displayMetrics.map((m) {
        return FlSpot(m.time.millisecondsSinceEpoch.toDouble(), getValue(m));
      }).toList(),
      isCurved: true,
      color: color,
      barWidth: 2,
      dotData: FlDotData(show: false),
      belowBarData: BarAreaData(show: false),
    );
  }

  // --- Widgets Auxiliares e Métodos de Apoio ---

  Widget _buildSummaryCard(String title, double value, Color color,
      {required bool isDarkCard}) {
    final bgColor =
        isDarkCard ? const Color(0xFF2C3E50) : color.withOpacity(0.1);

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
          boxShadow: isDarkCard
              ? [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2))
                ]
              : [],
        ),
        child: Column(
          children: [
            Text(title,
                style: TextStyle(
                    color: color, fontWeight: FontWeight.bold, fontSize: 12),
                textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text(
              '${value.toStringAsFixed(2)}${_getUnit(_selectedType)}',
              style: GoogleFonts.inter(
                  fontSize: 16, fontWeight: FontWeight.w800, color: color),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhaseToggle(
      String label, Color color, bool value, Function(bool) onChanged) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Row(
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: value ? color : Colors.transparent,
              border: Border.all(color: value ? color : Colors.grey, width: 2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: value
                ? const Icon(Icons.check, size: 12, color: Colors.white)
                : null,
          ),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: value
                      ? Theme.of(context).colorScheme.onSurface
                      : Colors.grey)),
        ],
      ),
    );
  }

  // --- Helpers Lógicos (Restaurados e Completos) ---

  double _getMax(MetricType type) {
    if (_rawMetrics.isEmpty) return 10;
    return _rawMetrics
        .map((m) => _getMaxValueFromMetric(m, type))
        .reduce(math.max);
  }

  double _getMin(MetricType type) {
    if (_rawMetrics.isEmpty) return 0;
    var valid = _rawMetrics
        .map((m) => _getMinValueFromMetric(m, type))
        .where((v) => v > 0);
    return valid.isEmpty ? 0 : valid.reduce(math.min);
  }

  double _getAvg(MetricType type) {
    if (_rawMetrics.isEmpty) return 0;
    final sum = _rawMetrics
        .map((m) => _getValueForType(m, type))
        .reduce((a, b) => a + b);
    return sum / _rawMetrics.length;
  }

  double _getMaxValueFromMetric(TransformerMetric m, MetricType type) {
    if (type == MetricType.temperature) return m.temperature ?? 0;
    List<double> vals = [];
    if (type == MetricType.voltage)
      vals = [
        if (_showPhaseA) m.voltageA ?? 0,
        if (_showPhaseB) m.voltageB ?? 0,
        if (_showPhaseC) m.voltageC ?? 0
      ];
    if (type == MetricType.current)
      vals = [
        if (_showPhaseA) m.currentA ?? 0,
        if (_showPhaseB) m.currentB ?? 0,
        if (_showPhaseC) m.currentC ?? 0
      ];
    if (type == MetricType.distortion)
      vals = [
        if (_showPhaseA) m.harmonicDistortionA ?? 0,
        if (_showPhaseB) m.harmonicDistortionB ?? 0,
        if (_showPhaseC) m.harmonicDistortionC ?? 0
      ];
    return vals.isEmpty ? 0 : vals.reduce(math.max);
  }

  double _getMinValueFromMetric(TransformerMetric m, MetricType type) {
    if (type == MetricType.temperature) return m.temperature ?? 0;
    List<double> vals = [];
    if (type == MetricType.voltage)
      vals = [
        if (_showPhaseA) m.voltageA ?? 0,
        if (_showPhaseB) m.voltageB ?? 0,
        if (_showPhaseC) m.voltageC ?? 0
      ];
    if (type == MetricType.current)
      vals = [
        if (_showPhaseA) m.currentA ?? 0,
        if (_showPhaseB) m.currentB ?? 0,
        if (_showPhaseC) m.currentC ?? 0
      ];
    if (type == MetricType.distortion)
      vals = [
        if (_showPhaseA) m.harmonicDistortionA ?? 0,
        if (_showPhaseB) m.harmonicDistortionB ?? 0,
        if (_showPhaseC) m.harmonicDistortionC ?? 0
      ];
    vals = vals.where((v) => v > 0).toList();
    return vals.isEmpty ? 0 : vals.reduce(math.min);
  }

  double _getValueForType(TransformerMetric m, MetricType type) {
    double total = 0;
    int count = 0;
    if (type == MetricType.temperature) return m.temperature ?? 0;
    
    void add(double? v, bool active) {
      if (active && v != null) {
        total += v;
        count++;
      }
    }

    if (type == MetricType.voltage) {
      add(m.voltageA, _showPhaseA);
      add(m.voltageB, _showPhaseB);
      add(m.voltageC, _showPhaseC);
    }
    if (type == MetricType.current) {
      add(m.currentA, _showPhaseA);
      add(m.currentB, _showPhaseB);
      add(m.currentC, _showPhaseC);
    }
    if (type == MetricType.distortion) {
      add(m.harmonicDistortionA, _showPhaseA);
      add(m.harmonicDistortionB, _showPhaseB);
      add(m.harmonicDistortionC, _showPhaseC);
    }
    return count == 0 ? 0 : total / count;
  }

  double _getPhaseValue(TransformerMetric m, String phase) {
    switch (_selectedType) {
      case MetricType.voltage:
        return phase == 'A'
            ? m.voltageA ?? 0
            : phase == 'B'
                ? m.voltageB ?? 0
                : m.voltageC ?? 0;
      case MetricType.current:
        return phase == 'A'
            ? m.currentA ?? 0
            : phase == 'B'
                ? m.currentB ?? 0
                : m.currentC ?? 0;
      case MetricType.distortion:
        return phase == 'A'
            ? m.harmonicDistortionA ?? 0
            : phase == 'B'
                ? m.harmonicDistortionB ?? 0
                : m.harmonicDistortionC ?? 0;
      default:
        return 0;
    }
  }

  String _getUnit(MetricType type) {
    switch (type) {
      case MetricType.temperature:
        return '°C';
      case MetricType.voltage:
        return 'V';
      case MetricType.current:
        return 'A';
      case MetricType.distortion:
        return '%';
    }
  }

  String _getMetricLabel(MetricType type) {
    switch (type) {
      case MetricType.temperature:
        return 'Temperatura';
      case MetricType.voltage:
        return 'Tensão (V)';
      case MetricType.current:
        return 'Corrente (A)';
      case MetricType.distortion:
        return 'Distorção Harmônica';
    }
  }

  bool _shouldUseMinuteGrouping() {
    if (_rawMetrics.isEmpty) return false;
    return _rawMetrics.last.time.difference(_rawMetrics.first.time).inHours < 2;
  }

  BarChartData _buildDistributionChart() {
    if (_displayMetrics.isEmpty) return BarChartData();

    List<BarChartGroupData> barGroups = [];
    
    // Vamos mostrar no máximo 20 barras para não ficar poluído
    // Agrupamos os _displayMetrics em blocos maiores para o gráfico de barras
    int barCount = 12;
    int itemsPerBar = (_displayMetrics.length / barCount).ceil();

    for(int i = 0; i < barCount; i++) {
        int start = i * itemsPerBar;
        int end = (start + itemsPerBar < _displayMetrics.length) ? start + itemsPerBar : _displayMetrics.length;
        
        if (start >= _displayMetrics.length) break;

        var sublist = _displayMetrics.sublist(start, end);
        if (sublist.isEmpty) continue;

        // Média da sublista
        double avgVal = sublist.map((m) => _getValueForType(m, _selectedType)).reduce((a,b)=>a+b) / sublist.length;
        // Tempo do meio para label
        double timeX = sublist[sublist.length ~/ 2].time.millisecondsSinceEpoch.toDouble();

        barGroups.add(
          BarChartGroupData(
            x: timeX.toInt(), // O X agora é o Tempo real, não índice 0-24
            barRods: [
              BarChartRodData(
                toY: avgVal,
                color: AppColors.orange,
                width: 16,
                borderRadius: BorderRadius.circular(4),
                backDrawRodData: BackgroundBarChartRodData(
                   show: true,
                   toY: _maxY, // Usa o max calculado para fundo cinza
                   color: Colors.grey.withOpacity(0.05)
                )
              )
            ]
          )
        );
    }

    return BarChartData(
      minY: _minY,
      maxY: _maxY, // Mantém escala consistente com o gráfico de cima
      gridData: FlGridData(show: false),
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: (value, meta) {
               // Formata o timestamp do eixo X da barra
               final date = DateTime.fromMillisecondsSinceEpoch(value.toInt());
               return Padding(
                 padding: const EdgeInsets.only(top: 8.0),
                 child: Text(DateFormat('HH:mm').format(date), style: const TextStyle(fontSize: 10)),
               );
            }
          )
        ),
      ),
      borderData: FlBorderData(show: false),
      barGroups: barGroups,
      barTouchData: BarTouchData(
        touchTooltipData: BarTouchTooltipData(
           getTooltipItem: (group, groupIndex, rod, rodIndex) {
             final date = DateTime.fromMillisecondsSinceEpoch(group.x);
             return BarTooltipItem(
               '${DateFormat('HH:mm').format(date)}\n',
               const TextStyle(color: Colors.white70, fontSize: 10),
               children: [
                 TextSpan(
                   text: '${rod.toY.toStringAsFixed(1)} ${_getUnit(_selectedType)}',
                   style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
                 )
               ]
             );
           }
        )
      )
    );
  }
}

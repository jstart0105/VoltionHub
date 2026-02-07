import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
// Mantenha seus imports originais aqui
import '/core/common/constants/theme/app_colors.dart';
import '/core/services/api/api_service.dart';
import '/data/models/transformer.dart';
import '/data/models/transformer_metric.dart';

class DetailedAnalysisScreen extends StatefulWidget {
  final Transformer transformer;
  const DetailedAnalysisScreen({super.key, required this.transformer});

  @override
  State<DetailedAnalysisScreen> createState() => _DetailedAnalysisScreenState();
}

class _DetailedAnalysisScreenState extends State<DetailedAnalysisScreen> {
  final ApiService _apiService = ApiService();
  
  late DateTime _start;
  late DateTime _end;
  
  List<TransformerMetric> _metrics = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Força Paisagem para melhor visualização
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeRight,
      DeviceOrientation.landscapeLeft,
    ]);

    final now = DateTime.now();
    _end = now;
    // AJUSTE 1: Padrão para últimas 24h
    _start = now.subtract(const Duration(hours: 24)); 
    _fetchData();
  }

  @override
  void dispose() {
    // Retorna para Retrato ao sair
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    super.dispose();
  }

  Future<void> _fetchData() async {
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      final data = await _apiService.getTransformerMetrics(
        widget.transformer.id,
        start: _start,
        end: _end,
      );
      
      data.sort((a, b) => a.time.compareTo(b.time));
      
      setState(() {
        _metrics = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = "Erro ao carregar: $e";
      });
    }
  }

  // Seletor de Janela de Tempo com Validação
  Future<void> _selectTimeRange() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _start,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    
    if (pickedDate != null && mounted) {
      final TimeOfDay? startTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_start),
        helpText: "Hora Início",
      );

      if (startTime != null && mounted) {
        final TimeOfDay? endTime = await showTimePicker(
          context: context,
          initialTime: TimeOfDay.fromDateTime(_end),
          // AJUSTE 2: Texto atualizado para Máx 24h
          helpText: "Hora Fim (Máx 24h de intervalo)", 
        );

        if (endTime != null) {
          final newStart = DateTime(pickedDate.year, pickedDate.month, pickedDate.day, startTime.hour, startTime.minute);
          var newEnd = DateTime(pickedDate.year, pickedDate.month, pickedDate.day, endTime.hour, endTime.minute);
          
          if (newEnd.isBefore(newStart)) {
             newEnd = newEnd.add(const Duration(days: 1));
          }

          // AJUSTE 2: Validação aumentada para 24 horas
          if (newEnd.difference(newStart).inHours > 24) { 
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Para análise detalhada, selecione um período máximo de 24 horas."), backgroundColor: Colors.red),
            );
            return;
          }

          setState(() {
            _start = newStart;
            _end = newEnd;
          });
          _fetchData();
        }
      }
    }
  }

  int _getIntervalInMinutes() {
    final durationInMinutes = _end.difference(_start).inMinutes;

    if (durationInMinutes <= 60) {
      return 5; // 1h ou menos -> cada 5 min
    } else if (durationInMinutes < 180) {
      return 10; // Menor que 3h -> cada 10 min
    } else if (durationInMinutes < 360) {
      return 15; // Menor que 6h -> cada 15 min
    } else if (durationInMinutes <= 720) {
      return 30; // 12h ou menos -> cada 30 min
    } else {
      return 60; // Padrão (até 24h) -> cada 1h
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Análise Detalhada: ${DateFormat('HH:mm').format(_start)} - ${DateFormat('HH:mm').format(_end)}"),
        actions: [
          TextButton.icon(
            onPressed: _selectTimeRange,
            icon: const Icon(Icons.timer, color: Colors.white),
            label: const Text("Alterar Período", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
            ? Center(child: Text(_errorMessage!))
            : _metrics.isEmpty
              ? const Center(child: Text("Sem dados detalhados."))
              : Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.circle, color: Colors.redAccent, size: 10), SizedBox(width: 4), Text("Fase A  "),
                          Icon(Icons.circle, color: Colors.green, size: 10), SizedBox(width: 4), Text("Fase B  "),
                          Icon(Icons.circle, color: Colors.blueAccent, size: 10), SizedBox(width: 4), Text("Fase C"),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SizedBox(
                            width: math.max(MediaQuery.of(context).size.width, _calculateChartWidth()), 
                            child: LineChart(_buildDetailedChart()),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  double _calculateChartWidth() {
    final totalMinutes = _end.difference(_start).inMinutes;
    final intervalMinutes = _getIntervalInMinutes();
    
    if (intervalMinutes == 0) return MediaQuery.of(context).size.width;

    // Quantos intervalos existem no período total?
    final numberOfIntervals = totalMinutes / intervalMinutes;

    // Reservamos cerca de 70-80 pixels de largura para cada etiqueta de hora
    // Isso garante que o texto "HH:mm" não fique encavalado
    return math.max(
      MediaQuery.of(context).size.width, 
      numberOfIntervals * 75.0
    ); 
  }

  LineChartData _buildDetailedChart() {
    // LÓGICA DINÂMICA: Converte o intervalo calculado para milissegundos
    final intervalMinutes = _getIntervalInMinutes();
    final intervalMs = intervalMinutes * 60 * 1000.0; 
    
    double maxY = 0;
    double minY = double.infinity;
    
    for(var m in _metrics) {
        final maxV = [m.voltageA??0, m.voltageB??0, m.voltageC??0].reduce(math.max);
        final minV = [m.voltageA??0, m.voltageB??0, m.voltageC??0].reduce(math.min);
        if(maxV > maxY) maxY = maxV;
        if(minV < minY && minV > 0) minY = minV;
    }
    
    // Adiciona uma margem de respiro vertical (5%)
    maxY = maxY == 0 ? 220 : maxY * 1.05; // Fallback se tudo for 0
    minY = minY == double.infinity ? 0 : minY * 0.95;

    return LineChartData(
      minX: _start.millisecondsSinceEpoch.toDouble(),
      maxX: _end.millisecondsSinceEpoch.toDouble(),
      minY: minY,
      maxY: maxY,
      clipData: FlClipData.all(),
      gridData: FlGridData(
        show: true,
        drawVerticalLine: true,
        verticalInterval: intervalMs, // Usa o intervalo dinâmico
        getDrawingVerticalLine: (_) => FlLine(color: Colors.white10, strokeWidth: 1),
      ),
      titlesData: FlTitlesData(
        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true, 
            reservedSize: 40,
            // O intervalo do Y pode ser automático ou fixo, aqui deixamos automático
            getTitlesWidget: (v, m) => Text(v.toInt().toString(), style: const TextStyle(fontSize: 10, color: Colors.grey)),
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: intervalMs, // Usa o intervalo dinâmico para as Labels
            reservedSize: 30,
            getTitlesWidget: (value, meta) {
              final date = DateTime.fromMillisecondsSinceEpoch(value.toInt());
              // Verifica se a label está muito próxima do fim para evitar corte (opcional)
              if (value == meta.max && _end.difference(date).inMinutes.abs() < intervalMinutes / 2) {
                 return const SizedBox.shrink();
              }
              
              return Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  DateFormat('HH:mm').format(date),
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                ),
              );
            },
          ),
        ),
      ),
      borderData: FlBorderData(
        show: true, 
        border: Border.all(color: Colors.white10),
      ),
      lineBarsData: [
        _buildLine('A', Colors.redAccent),
        _buildLine('B', Colors.green),
        _buildLine('C', Colors.blueAccent),
      ],
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          // Ajuste de cor de fundo se necessário
          getTooltipItems: (spots) => spots.map((s) => LineTooltipItem(
             "${DateFormat('HH:mm:ss').format(DateTime.fromMillisecondsSinceEpoch(s.x.toInt()))}\n${s.y.toStringAsFixed(1)} V",
             const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
          )).toList()
        )
      )
    );
  }

  LineChartBarData _buildLine(String phase, Color color) {
    return LineChartBarData(
      spots: _metrics.map((m) {
        final val = phase == 'A' ? m.voltageA : phase == 'B' ? m.voltageB : m.voltageC;
        return FlSpot(m.time.millisecondsSinceEpoch.toDouble(), val ?? 0);
      }).toList(),
      isCurved: true,
      color: color,
      // Pontos podem ficar muito densos em 24h, o raio 2 é discreto
      dotData: FlDotData(show: true, getDotPainter: (spot, percent, barData, index) {
        return FlDotCirclePainter(radius: 2, color: color, strokeWidth: 0);
      }),
      barWidth: 2,
    );
  }
}
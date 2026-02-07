import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:http/http.dart' as http;
import '/core/common/constants/theme/app_colors.dart';
import '/core/services/api/api_service.dart';
import '/data/models/transformer.dart';

class SummaryCard extends StatefulWidget {
  const SummaryCard({super.key});

  @override
  State<SummaryCard> createState() => _SummaryCardState();
}

class _SummaryCardState extends State<SummaryCard> {
  int _positionState = 0;
  bool _isLoading = true;
  int _onlineCount = 0;
  int _alertCount = 0;
  int _offlineCount = 0;
  int _maintenanceCount = 0;

  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _fetchTransformersData();
  }

  Future<void> _fetchTransformersData() async {
    final url = Uri.parse('${_apiService.baseUrl}/transformers');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final allTransformers = data.map((item) => Transformer(
          id: item['id']?.toString() ?? '',
          status: item['status']?.toString() ?? 'offline',
          latitude: double.tryParse(item['latitude']?.toString() ?? '') ?? 0.0,
          longitude: double.tryParse(item['longitude']?.toString() ?? '') ?? 0.0,
          capacity: item['capacity']?.toString() ?? '',
          address: item['address']?.toString() ?? '',
          lastMaintenance: item['last_maintenance']?.toString() ?? '',
          phaseType: item['phase_type']?.toString() ?? 'unidentified', // Novo campo
        )).toList();

        setState(() {
          _onlineCount = allTransformers.where((t) => t.status == 'online').length;
          _alertCount = allTransformers.where((t) => t.status == 'alerta').length;
          _offlineCount = allTransformers.where((t) => t.status == 'offline').length;
          _maintenanceCount = allTransformers.where((t) => t.status == 'em manutencao').length;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
        print('Failed to load transformers');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      print(e);
    }
  }

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

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: _alignment,
      child: GestureDetector(
        onHorizontalDragUpdate: (details) {
          if (details.primaryDelta!.abs() > 2) {
            if (details.primaryDelta! > 0) {
              if (_positionState != 1) {
                setState(() => _positionState = 1);
              }
            } else {
              if (_positionState != -1) {
                setState(() => _positionState = -1);
              }
            }
          }
        },
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
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
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
          child: _isLoading
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
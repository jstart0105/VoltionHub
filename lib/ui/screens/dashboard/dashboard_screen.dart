import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'widgets/header.dart';
import 'widgets/map.dart';
import 'widgets/summary_card.dart';
import 'widgets/transformer_details_panel.dart';
import '/core/services/api/api_service.dart';
import '/data/models/transformer.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<Transformer> transformers = [];
  bool isLoading = true; // Adicione esta variável para controlar o estado

  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _fetchTransformers();
  }

  Future<void> _fetchTransformers() async {
    setState(() => isLoading = true); // Inicia loading
    try {
      final List<dynamic> data = await _apiService.getRawTransformers();
      
      setState(() {
        transformers = data.map<Transformer>((item) {
          double lat = double.tryParse(item['latitude']?.toString() ?? '') ?? 0.0;
          double long = double.tryParse(item['longitude']?.toString() ?? '') ?? 0.0;

          return Transformer(
            id: item['id']?.toString() ?? '',
            status: item['status']?.toString() ?? 'offline',
            latitude: lat,
            longitude: long,
            capacity: item['capacity']?.toString() ?? '',
            address: item['address']?.toString() ?? '',
            lastMaintenance: item['last_maintenance']?.toString() ?? 'N/A',
            phaseType: item['phase_type']?.toString() ?? 'monophasic', 
          );
        }).toList();
        isLoading = false; // Finaliza loading
      });
      
    } catch (e, stackTrace) {
      print('Erro ao carregar transformadores: $e');
      print(stackTrace);
      setState(() => isLoading = false);
    }
  }

  void _onMarkerTapped(Transformer transformer) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return TransformerDetailsPanel(
          transformer: transformer,
          onClose: () => Navigator.of(context).pop(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const Header(),
      body: Stack(
        children: [
          MapWidget(
            transformers: transformers,
            onMarkerTapped: _onMarkerTapped,
          ),
          SummaryCard(
            transformers: transformers,
            isLoading: isLoading,
          ),
        ],
      ),
    );
  }
}
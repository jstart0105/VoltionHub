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

  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _fetchTransformers();
  }

  Future<void> _fetchTransformers() async {
    final url = Uri.parse('${_apiService.baseUrl}/transformers');
    try {
      print('Buscando transformadores em: $url'); 
      final response = await http.get(url);
      
      print('Status Code: ${response.statusCode}'); 
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        print('Dados recebidos: $data'); 

        setState(() {
          transformers = data.map((item) {
            // CONVERSÃO SEGURA:
            // 1. Garante que lat/long sejam double (converte string se necessário)
            double lat = double.tryParse(item['latitude']?.toString() ?? '') ?? 0.0;
            double long = double.tryParse(item['longitude']?.toString() ?? '') ?? 0.0;

            return Transformer(
              id: item['id']?.toString() ?? '',
              status: item['status']?.toString() ?? 'offline',
              latitude: lat,
              longitude: long,
              capacity: item['capacity']?.toString() ?? '',
              address: item['address']?.toString() ?? '',
              // Trata o nulo aqui usando 'N/A'
              lastMaintenance: item['last_maintenance']?.toString() ?? 'N/A', 
            );
          }).toList();
        });
        
        print('Transformadores processados: ${transformers.length}');
      } else {
        print('Erro na API: ${response.body}');
      }
    } catch (e, stackTrace) {
      print('Erro ao carregar transformadores: $e');
      print(stackTrace);
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
          const SummaryCard(),
        ],
      ),
    );
  }
}
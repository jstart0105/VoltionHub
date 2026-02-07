import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import '/core/services/maps_service.dart';
import '/data/models/transformer.dart';
import '/ui/screens/analytics/analytics_screen.dart';
import '/ui/screens/service_order/widgets/os_form_screen.dart';
import '/ui/screens/transformer_history/transformer_history_screen.dart';
import '/ui/widgets/button.dart';

class ActionButtons extends StatelessWidget {
  final Transformer transformer; // Adicionado para obter as coordenadas

  const ActionButtons({super.key, required this.transformer}); // Modificado

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Gap(16),
        CustomButton(
          text: 'Criar Ordem de Serviço',
          onPressed: () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const OsFormScreen()));
          },
        ),
        const Gap(12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            TextButton.icon(
              onPressed: () {
                MapsService.openMap(transformer.latitude, transformer.longitude);
              },
              icon: Icon(Icons.navigation_outlined, color: Theme.of(context).colorScheme.primary),
              label: Text(
                'Navegar até o Local',
                style: GoogleFonts.inter(color: Theme.of(context).colorScheme.onSurface),
              ),
            ),
            TextButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => TransformerHistoryScreen(transformer: transformer)),
                );
              },
              icon: Icon(Icons.history_outlined, color: Theme.of(context).colorScheme.primary),
              label: Text(
                'Ver Histórico',
                style: GoogleFonts.inter(color: Theme.of(context).colorScheme.onSurface),
              ),
            ),
          ],
        ),
        const Gap(12),
        CustomButton(
          text: 'Análise Gráfica & Métricas',
          // Use uma cor diferente se quiser, ou style outline para diferenciar
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AnalyticsScreen(transformer: transformer),
              ),
            );
          },
        ),
      ],
    );
  }
}
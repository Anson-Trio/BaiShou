import 'package:flutter/material.dart';
import 'package:baishou/i18n/strings.g.dart';

class CompressionChart extends StatelessWidget {
  const CompressionChart({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Staircase part
            _buildStairStep(
              context,
              t.common.daily,
              const Color(0xFF81D4FA), // Light Blue 200
              alignment: Alignment.centerRight,
              widthFactor: 0.25,
            ),
            _buildConnector(Alignment.centerRight, 0.25),
            _buildStairStep(
              context,
              t.common.weekly,
              const Color(0xFF4FC3F7), // Light Blue 300
              alignment: const Alignment(0.4, 0),
              widthFactor: 0.25,
            ),
            _buildConnector(const Alignment(0.4, 0), 0.25),
            _buildStairStep(
              context,
              t.common.monthly,
              const Color(0xFF29B6F6), // Light Blue 400
              alignment: const Alignment(-0.2, 0),
              widthFactor: 0.25,
            ),
            _buildConnector(const Alignment(-0.2, 0), 0.25),
            _buildStairStep(
              context,
              t.common.quarterly,
              const Color(0xFFAED581), // Light Green 300
              alignment: Alignment.centerLeft,
              widthFactor: 0.35,
            ),
            const SizedBox(height: 20),

            // Base layout
            Container(
              height: 50,
              decoration: BoxDecoration(
                color: const Color(0xFF4DD0E1), // Cyan 300
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4DD0E1).withOpacity(0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Text(
                t.common.yearly,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  letterSpacing: 4,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStairStep(
    BuildContext context,
    String label,
    Color color, {
    required Alignment alignment,
    required double widthFactor,
  }) {
    return Align(
      alignment: alignment,
      child: FractionallySizedBox(
        widthFactor: widthFactor,
        child: Container(
          height: 45,
          margin: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.4),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConnector(Alignment alignment, double widthFactor) {
    // Optional: Add connecting lines if needed, for now just empty space or generic vertical line
    // Visualization is cleaner with just floating blocks for the "concept"
    return const SizedBox(height: 4);
  }
}

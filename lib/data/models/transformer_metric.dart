class TransformerMetric {
  final DateTime time;
  final String transformerId;
  final double? temperature;
  
  // Fase A
  final double? voltageA;
  final double? currentA;
  final double? harmonicDistortionA;

  // Fase B
  final double? voltageB;
  final double? currentB;
  final double? harmonicDistortionB;

  // Fase C
  final double? voltageC;
  final double? currentC;
  final double? harmonicDistortionC;

  TransformerMetric({
    required this.time,
    required this.transformerId,
    this.temperature,
    this.voltageA,
    this.currentA,
    this.harmonicDistortionA,
    this.voltageB,
    this.currentB,
    this.harmonicDistortionB,
    this.voltageC,
    this.currentC,
    this.harmonicDistortionC,
  });

  factory TransformerMetric.fromJson(Map<String, dynamic> json) {
    // Helper para converter valores numéricos com segurança
    double? toDouble(dynamic val) {
      if (val == null) return null;
      return (val as num).toDouble();
    }

    return TransformerMetric(
      time: DateTime.parse(json['time']),
      transformerId: json['transformer_id'].toString(),
      temperature: toDouble(json['temperature']),
      
      voltageA: toDouble(json['voltage_a']),
      currentA: toDouble(json['current_a']),
      harmonicDistortionA: toDouble(json['harmonic_distortion_a']),
      
      voltageB: toDouble(json['voltage_b']),
      currentB: toDouble(json['current_b']),
      harmonicDistortionB: toDouble(json['harmonic_distortion_b']),
      
      voltageC: toDouble(json['voltage_c']),
      currentC: toDouble(json['current_c']),
      harmonicDistortionC: toDouble(json['harmonic_distortion_c']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'time': time.toIso8601String(),
      'transformer_id': transformerId,
      'temperature': temperature,
      'voltage_a': voltageA,
      'current_a': currentA,
      'harmonic_distortion_a': harmonicDistortionA,
      'voltage_b': voltageB,
      'current_b': currentB,
      'harmonic_distortion_b': harmonicDistortionB,
      'voltage_c': voltageC,
      'current_c': currentC,
      'harmonic_distortion_c': harmonicDistortionC,
    };
  }
}
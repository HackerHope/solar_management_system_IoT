/// One AI Energy Advisor message, written once a day by the `dailyInsights`
/// Cloud Function to `systems/<id>/insights/latest`.
///
/// `source` is "gemini" when the text was written by the AI model and "rules"
/// when Gemini was unavailable and a simple rule-based summary was used instead.
/// The app is read-only here: the advisor can never send a command to the device.
class AiInsight {
  final String headline;
  final String summary;
  final List<String> tips;
  final List<String> watch;
  final List<String> dataWarnings;
  final int generatedAt; // epoch milliseconds
  final String source; // "gemini" | "rules"
  final String? model;

  const AiInsight({
    required this.headline,
    required this.summary,
    this.tips = const [],
    this.watch = const [],
    this.dataWarnings = const [],
    required this.generatedAt,
    required this.source,
    this.model,
  });

  bool get isAi => source == "gemini";

  // Realtime Database returns lists as List, or as Map when keys are sparse.
  static List<String> _strings(dynamic value) {
    if (value is List) return value.whereType<String>().toList();
    if (value is Map) return value.values.whereType<String>().toList();
    return const <String>[];
  }

  factory AiInsight.fromMap(Map<dynamic, dynamic> map) {
    return AiInsight(
      headline: (map["headline"] as String?) ?? "",
      summary: (map["summary"] as String?) ?? "",
      tips: _strings(map["tips"]),
      watch: _strings(map["watch"]),
      dataWarnings: _strings(map["dataWarnings"]),
      generatedAt: (map["generatedAt"] as num?)?.toInt() ?? 0,
      source: (map["source"] as String?) ?? "rules",
      model: map["model"] as String?,
    );
  }
}

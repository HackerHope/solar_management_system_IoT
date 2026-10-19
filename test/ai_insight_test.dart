import "package:flutter_test/flutter_test.dart";
import "package:solar_iot_project/models/ai_insight.dart";

void main() {
  group("AiInsight.fromMap", () {
    test("parses a Gemini insight", () {
      final i = AiInsight.fromMap({
        "headline": "Battery ran low",
        "summary": "It dropped to 8% at 22:00.",
        "tips": ["Run the iron at noon."],
        "watch": ["Low battery twice"],
        "dataWarnings": [],
        "generatedAt": 1760000000000,
        "source": "gemini",
        "model": "gemini-2.5-flash",
      });
      expect(i.isAi, isTrue);
      expect(i.tips, ["Run the iron at noon."]);
      expect(i.watch.length, 1);
      expect(i.dataWarnings, isEmpty);
      expect(i.generatedAt, 1760000000000);
    });

    test("rule-based fallback is not shown as AI", () {
      final i = AiInsight.fromMap({"headline": "h", "summary": "s", "source": "rules", "generatedAt": 1});
      expect(i.isAi, isFalse);
    });

    test("lists stored as maps by Realtime Database are still read", () {
      final i = AiInsight.fromMap({
        "headline": "h",
        "summary": "s",
        "tips": {"0": "a", "2": "b"},
        "generatedAt": 1,
        "source": "gemini",
      });
      expect(i.tips, ["a", "b"]);
    });

    test("missing fields fall back safely", () {
      final i = AiInsight.fromMap({});
      expect(i.headline, "");
      expect(i.tips, isEmpty);
      expect(i.source, "rules");
      expect(i.isAi, isFalse);
    });
  });
}

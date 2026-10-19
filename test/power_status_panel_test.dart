import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:solar_iot_project/models/sensor_models.dart";
import "package:solar_iot_project/widgets/power_status_panel.dart";

void main() {
  testWidgets(
    "shows named relay controls and marks extra channels disconnected",
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(
              children: [
                PowerStatusPanel(
                  status: PowerStatus(
                    timestamp: DateTime.now().millisecondsSinceEpoch,
                    solarVoltage: 18,
                    solarCurrent: 2,
                    source: "grid",
                    mainsPresent: true,
                    faultTripped: false,
                    channel1: false,
                    channel2: true,
                  ),
                  channelNames: const ["Lights", "Water pump", "Future output"],
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text("Lights"), findsOneWidget);
      expect(find.text("Water pump"), findsOneWidget);
      expect(find.text("Future output"), findsOneWidget);
      expect(find.text("Not connected"), findsOneWidget);
      expect(find.byType(Switch), findsNWidgets(2));
    },
  );

  testWidgets("does not show old mains status when power data is stale", (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PowerStatusPanel(
            status: PowerStatus(
              timestamp: DateTime.now()
                  .subtract(const Duration(minutes: 1))
                  .millisecondsSinceEpoch,
              solarVoltage: 18,
              solarCurrent: 2,
              source: "grid",
              mainsPresent: true,
              faultTripped: false,
              channel1: false,
              channel2: false,
            ),
          ),
        ),
      ),
    );

    expect(find.textContaining("Power status is stale"), findsOneWidget);
    expect(find.text("Present"), findsNothing);
    expect(find.byType(Switch), findsNothing);
  });
}

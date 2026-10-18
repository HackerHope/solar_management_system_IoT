class Reading {
  final int timestamp; // ms since epoch
  final double voltage;
  final double current;
  final double temperature;
  final double batteryPercent;
  final double power;

  /// False when the device has no temperature sensor fitted and therefore
  /// leaves the field out. [temperature] is 0 in that case and must not be
  /// shown or used for alerts.
  final bool hasTemperature;

  /// Solar power in watts, when the firmware reports it (null on older firmware).
  final double? solarPower;

  // NOTE: `voltage` and `current` are the BATTERY-side measurements with the
  // power-management firmware. Solar-side values are in [PowerStatus].
  Reading({
    required this.timestamp,
    required this.voltage,
    required this.current,
    required this.temperature,
    required this.batteryPercent,
    required this.power,
    this.hasTemperature = true,
    this.solarPower,
  });

  factory Reading.fromMap(Map<dynamic, dynamic> map) {
    return Reading(
      timestamp: (map["timestamp"] as num?)?.toInt() ?? 0,
      voltage: (map["voltage"] as num?)?.toDouble() ?? 0,
      current: (map["current"] as num?)?.toDouble() ?? 0,
      temperature: (map["temperature"] as num?)?.toDouble() ?? 0,
      batteryPercent: (map["batteryPercent"] as num?)?.toDouble() ?? 0,
      power: (map["power"] as num?)?.toDouble() ?? 0,
      hasTemperature: map["temperature"] != null,
      solarPower: (map["solarPower"] as num?)?.toDouble(),
    );
  }
}

enum DeviceOnlineStatus { online, offline }

class DeviceStatus {
  final String name;
  final DeviceOnlineStatus status;

  DeviceStatus({required this.name, required this.status});
}

enum AlertLevel { info, warning, error }

AlertLevel alertLevelFromString(String? value) {
  switch (value) {
    case "warning":
      return AlertLevel.warning;
    case "error":
      return AlertLevel.error;
    default:
      return AlertLevel.info;
  }
}

class AppAlert {
  final String id;
  final int timestamp;
  final AlertLevel level;
  final String title;
  final String message;

  AppAlert({
    required this.id,
    required this.timestamp,
    required this.level,
    required this.title,
    required this.message,
  });

  factory AppAlert.fromMap(String id, Map<dynamic, dynamic> map) {
    return AppAlert(
      id: id,
      timestamp: (map["timestamp"] as num?)?.toInt() ?? 0,
      level: alertLevelFromString(map["level"] as String?),
      title: map["title"] as String? ?? "",
      message: map["message"] as String? ?? "",
    );
  }
}

class AppSettings {
  final String deviceName;
  final double tempLimitC;
  final double batteryLowPct;
  final double lowVoltageV;
  final double readingIntervalSec;
  final String mqttBrokerHost;
  final int mqttBrokerPort;
  final bool mqttUseTls;

  /// Automatic load control (runs on the device): switches off the
  /// non-essential channel when the battery is low and restores it later.
  final bool autoLoadControl;
  final double shedBelowPct;
  final double restoreAbovePct;

  /// Electricity price in kwacha per kWh used to estimate cost. 0 = not set.
  final double tariffZmwPerKwh;

  const AppSettings({
    required this.deviceName,
    required this.tempLimitC,
    required this.batteryLowPct,
    required this.lowVoltageV,
    required this.readingIntervalSec,
    required this.mqttBrokerHost,
    required this.mqttBrokerPort,
    required this.mqttUseTls,
    required this.autoLoadControl,
    required this.shedBelowPct,
    required this.restoreAbovePct,
    required this.tariffZmwPerKwh,
  });

  static const defaults = AppSettings(
    deviceName: "My Solar System",
    tempLimitC: 45,
    batteryLowPct: 20,
    lowVoltageV: 10.5,
    readingIntervalSec: 5,
    mqttBrokerHost: "",
    mqttBrokerPort: 1883,
    mqttUseTls: false,
    autoLoadControl: false,
    shedBelowPct: 20,
    restoreAbovePct: 35,
    tariffZmwPerKwh: 0,
  );

  factory AppSettings.fromMap(Map<dynamic, dynamic>? map) {
    if (map == null) return defaults;
    return AppSettings(
      deviceName: map["deviceName"] as String? ?? defaults.deviceName,
      tempLimitC: (map["tempLimitC"] as num?)?.toDouble() ?? defaults.tempLimitC,
      batteryLowPct: (map["batteryLowPct"] as num?)?.toDouble() ?? defaults.batteryLowPct,
      lowVoltageV: (map["lowVoltageV"] as num?)?.toDouble() ?? defaults.lowVoltageV,
      readingIntervalSec:
          (map["readingIntervalSec"] as num?)?.toDouble() ?? defaults.readingIntervalSec,
      mqttBrokerHost: map["mqttBrokerHost"] as String? ?? defaults.mqttBrokerHost,
      mqttBrokerPort: (map["mqttBrokerPort"] as num?)?.toInt() ?? defaults.mqttBrokerPort,
      mqttUseTls: map["mqttUseTls"] as bool? ?? defaults.mqttUseTls,
      autoLoadControl: map["autoLoadControl"] as bool? ?? defaults.autoLoadControl,
      shedBelowPct: (map["shedBelowPct"] as num?)?.toDouble() ?? defaults.shedBelowPct,
      restoreAbovePct: (map["restoreAbovePct"] as num?)?.toDouble() ?? defaults.restoreAbovePct,
      tariffZmwPerKwh: (map["tariffZmwPerKwh"] as num?)?.toDouble() ?? defaults.tariffZmwPerKwh,
    );
  }

  Map<String, dynamic> toMap() => {
        "deviceName": deviceName,
        "tempLimitC": tempLimitC,
        "batteryLowPct": batteryLowPct,
        "lowVoltageV": lowVoltageV,
        "readingIntervalSec": readingIntervalSec,
        "mqttBrokerHost": mqttBrokerHost,
        "mqttBrokerPort": mqttBrokerPort,
        "mqttUseTls": mqttUseTls,
        "autoLoadControl": autoLoadControl,
        "shedBelowPct": shedBelowPct,
        "restoreAbovePct": restoreAbovePct,
        "tariffZmwPerKwh": tariffZmwPerKwh,
      };

  AppSettings copyWith({
    String? deviceName,
    double? tempLimitC,
    double? batteryLowPct,
    double? lowVoltageV,
    double? readingIntervalSec,
    String? mqttBrokerHost,
    int? mqttBrokerPort,
    bool? mqttUseTls,
    bool? autoLoadControl,
    double? shedBelowPct,
    double? restoreAbovePct,
    double? tariffZmwPerKwh,
  }) {
    return AppSettings(
      deviceName: deviceName ?? this.deviceName,
      tempLimitC: tempLimitC ?? this.tempLimitC,
      batteryLowPct: batteryLowPct ?? this.batteryLowPct,
      lowVoltageV: lowVoltageV ?? this.lowVoltageV,
      readingIntervalSec: readingIntervalSec ?? this.readingIntervalSec,
      mqttBrokerHost: mqttBrokerHost ?? this.mqttBrokerHost,
      mqttBrokerPort: mqttBrokerPort ?? this.mqttBrokerPort,
      mqttUseTls: mqttUseTls ?? this.mqttUseTls,
      autoLoadControl: autoLoadControl ?? this.autoLoadControl,
      shedBelowPct: shedBelowPct ?? this.shedBelowPct,
      restoreAbovePct: restoreAbovePct ?? this.restoreAbovePct,
      tariffZmwPerKwh: tariffZmwPerKwh ?? this.tariffZmwPerKwh,
    );
  }
}

class CircuitPoint {
  final double current;
  final double power;
  CircuitPoint({required this.current, required this.power});

  factory CircuitPoint.fromMap(Map<dynamic, dynamic>? map) {
    if (map == null) return CircuitPoint(current: 0, power: 0);
    return CircuitPoint(
      current: (map["current"] as num?)?.toDouble() ?? 0,
      power: (map["power"] as num?)?.toDouble() ?? 0,
    );
  }
}

// One reading covering all circuits at a point in time - mirrors
// /circuits/latest and /circuits/history entries written by the firmware.
class CircuitsReading {
  final int timestamp;
  final CircuitPoint? lights;
  final CircuitPoint? fan;
  final CircuitPoint? tv;
  final CircuitPoint? fridge;

  CircuitsReading({
    required this.timestamp,
    this.lights,
    this.fan,
    this.tv,
    this.fridge,
  });

  factory CircuitsReading.fromMap(Map<dynamic, dynamic> map) {
    return CircuitsReading(
      timestamp: (map["timestamp"] as num?)?.toInt() ?? 0,
      lights: map["lights"] != null ? CircuitPoint.fromMap(map["lights"]) : null,
      fan: map["fan"] != null ? CircuitPoint.fromMap(map["fan"]) : null,
      tv: map["tv"] != null ? CircuitPoint.fromMap(map["tv"]) : null,
      fridge: map["fridge"] != null ? CircuitPoint.fromMap(map["fridge"]) : null,
    );
  }
}

class PowerStatus {
  final double solarVoltage;
  final double solarCurrent;
  final String source; // "grid" or "inverter"
  final bool mainsPresent;
  final bool faultTripped;
  final bool channel1;
  final bool channel2;

  /// Automatic load control enabled on the device.
  final bool autoMode;

  /// Channel 2 is currently off because the automation shed it (battery low).
  final bool autoShed;

  double get solarPower => solarVoltage * solarCurrent;

  PowerStatus({
    required this.solarVoltage,
    required this.solarCurrent,
    required this.source,
    required this.mainsPresent,
    required this.faultTripped,
    required this.channel1,
    required this.channel2,
    this.autoMode = false,
    this.autoShed = false,
  });

  factory PowerStatus.fromMap(Map<dynamic, dynamic> map) {
    return PowerStatus(
      solarVoltage: (map["solarVoltage"] as num?)?.toDouble() ?? 0,
      solarCurrent: (map["solarCurrent"] as num?)?.toDouble() ?? 0,
      source: map["source"] as String? ?? "grid",
      mainsPresent: map["mainsPresent"] as bool? ?? true,
      faultTripped: map["faultTripped"] as bool? ?? false,
      channel1: map["channel1"] as bool? ?? false,
      channel2: map["channel2"] as bool? ?? false,
      autoMode: map["autoMode"] as bool? ?? false,
      autoShed: map["autoShed"] as bool? ?? false,
    );
  }
}

class SolarSystem {
  final String id;
  final String name;
  SolarSystem({required this.id, required this.name});
}

/// Server-aggregated energy for one day (see functions/index.js).
class DailyEnergy {
  final String date; // yyyy-MM-dd
  final double usedWh;
  final double solarWh;
  DailyEnergy({required this.date, required this.usedWh, required this.solarWh});

  factory DailyEnergy.fromMap(String date, Map<dynamic, dynamic> map) {
    return DailyEnergy(
      date: date,
      usedWh: (map["usedWh"] as num?)?.toDouble() ?? 0,
      solarWh: (map["solarWh"] as num?)?.toDouble() ?? 0,
    );
  }
}

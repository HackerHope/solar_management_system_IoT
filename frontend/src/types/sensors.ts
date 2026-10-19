export type Reading = {
  timestamp: number; // ms since epoch
  voltage: number;
  current: number;
  batteryPercent: number;
  power: number;
};

export type DeviceStatus = {
  name: string;
  status: "Online" | "Offline";
};

export type AlertLevel = "info" | "warning" | "error";

export type Alert = {
  id: string;
  timestamp: number;
  level: AlertLevel;
  title: string;
  message: string;
};

export type Settings = {
  batteryLowPct: number;
  readingIntervalSec: number;
  lowVoltageV?: number;
};

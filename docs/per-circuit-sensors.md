# Per-Circuit Power Monitoring (Lights / Fan / TV / Fridge)

Your main system (voltage, current, temperature, battery) measures the
**total** system. To break usage down per appliance, each circuit needs its
own current sensor. Here's the practical way to do it.

## 1. Sensor choice: SCT-013-030 clamp-on CT sensor

Use a **non-invasive current transformer (CT) clamp** - it clips around one
wire of the circuit, no rewiring or cutting into mains wiring required.

Recommended: **SCT-013-030** (30A : 1V variant). It has a burden resistor
built in, so it outputs 0-1V AC directly - no separate resistor needed. If
your loads pull more than 30A, use a higher-rated variant (e.g. SCT-013-000
with an external burden resistor sized for your range).

You need **one per circuit** you want to track separately: lights, fan, TV,
fridge = 4 sensors.

**Safety note:** CT clamps go around a single conductor (live or neutral,
not both) of the AC circuit feeding that appliance - typically clamped at the
distribution board/breaker for that circuit. If you're not confident working
inside a breaker panel, have an electrician do this part; the sensor itself
is safe (it doesn't touch the conductor), but working inside a panel carries
real risk.

## 2. Signal conditioning: bias the AC signal into ADC range

A CT sensor outputs an **AC** signal centered on 0V (swinging positive and
negative). The ESP32's ADC can only read 0-3.3V (positive only), so each
sensor's output needs a bias circuit to center it around ~1.65V:

```
CT output ---[10kΩ]---+---[10kΩ]--- GND
                       |
                    ESP32 ADC pin
                       |
                     [10µF cap to GND, for smoothing]
```

This is a simple voltage divider (two 10kΩ resistors from 3.3V rail effectively
create a 1.65V midpoint) with the CT's AC signal riding on top of it, plus a
smoothing capacitor. You'll need one of these small circuits per sensor.

## 3. Why you need an external ADC (ADS1115)

Your ESP32 is already using 3 of its usable ADC pins (voltage, current,
temperature) for the main sensors. There's a real constraint here: **when
WiFi is active, only the ADC1 pins (GPIO32-39, 8 channels total) work** -
ADC2 pins conflict with the WiFi radio and become unusable. That leaves you
5 free ADC1 channels, not comfortably enough headroom for 4 more sensors
plus reliable readings.

Better solution: add an **ADS1115** breakout board (I2C, 16-bit, 4 channels,
~$2-5). It gives you 4 dedicated, higher-resolution channels over I2C (just 2
wires: SDA/SCL), completely separate from the ESP32's own ADC pins.

| ADS1115 pin | ESP32 pin |
|---|---|
| VDD | 3.3V |
| GND | GND |
| SDA | GPIO21 (default I2C SDA) |
| SCL | GPIO22 (default I2C SCL) |
| A0-A3 | one CT sensor's biased output each (lights/fan/tv/fridge) |

## 4. Measuring real (RMS) current from an AC signal

You can't just read the ADC once - AC current has to be sampled many times
per cycle and converted to an RMS (root-mean-square) value. The approach:

1. Sample each channel rapidly (100+ samples across a couple of AC cycles,
   ~30-40ms at 50/60Hz)
2. Subtract the 1.65V bias
3. Compute RMS: `sqrt(mean(sample²))`
4. Convert ADC RMS voltage to Amps using your CT sensor's ratio (30A/1V for
   the SCT-013-030)
5. Estimate power: `watts = amps_rms * mains_voltage` (this assumes a power
   factor of 1, which is close enough for resistive loads like lights and
   heating elements, but will under/overestimate for motors and electronics
   with poor power factor - fine for a hobby dashboard, not utility-grade)

The extended firmware in `esp32-firmware/firebase_solar_monitor/` implements
this RMS calculation and writes results to `/circuits/latest` and
`/circuits/history` in the same format the frontend already expects.

## 5. What "mains voltage" to use

The firmware uses a fixed constant (`MAINS_VOLTAGE`, default 230V - change to
120V if that's your region) rather than measuring it live. If you want real
AC voltage sensing too, that's a separate sensor (e.g. ZMPT101B module) -
possible to add later, but out of scope for this pass.

## Summary of what to buy
- 4x SCT-013-030 CT clamp sensors
- 1x ADS1115 breakout board
- 8x 10kΩ resistors, 4x 10µF capacitors (bias circuits)
- Breadboard/protoboard + jumper wires

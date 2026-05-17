# Hybrid, Electric & ICE Powertrain Modeling

> Forward-facing vehicle simulation comparing ICE, BEV, and series-parallel HEV architectures under real-world drive cycles, with rule-based Stateflow energy management.

**Course:** AuE6610 — Advanced and Electrified Powertrains, Clemson University | **Tools:** MATLAB, Simulink, Stateflow, Simscape

---

## Overview

This project models, simulates, and compares three powertrain architectures for a passenger sedan — conventional ICE, battery electric (BEV), and series-parallel hybrid (HEV) — within a unified forward-facing simulation framework.

The HEV model includes a complete rule-based energy management strategy implemented in Stateflow with **Economy** and **Sport** driving modes, managing engine, motor, clutch, regenerative braking, and battery charging states.

---

## Results at a Glance

| Architecture | Fuel Economy / Range | Key Config |
|---|---|---|
| **Conventional ICE** | **43 MPG** | 2.0L NA, 6-speed, BSFC-optimized shift |
| **Battery Electric (BEV)** | **181 mi range** | 40.8 kWh, BorgWarner HVH250, PID thermal |
| **Series-Parallel HEV** | **64 MPG / 819 mi** | 1.5L engine + HPEVS AC-23 motor, 90 kW combined |

---

## Architectures

### 1. Conventional ICE

- **Engine:** 2.0L naturally aspirated, modeled using BSFC maps
- **Transmission:** 6-speed automatic with gear-shift logic optimized for fuel efficiency
- **Driver model:** PID controller tracking reference velocity profile
- **Simulation:** Forward-facing longitudinal dynamics over EPA drive cycles

### 2. Battery Electric Vehicle (BEV)

- **Motor:** BorgWarner HVH250
- **Battery:** 40.8 kWh pack, RC equivalent circuit model (Thevenin)
- **Thermal control:** PID-regulated battery cooling loop
- **SOC tracking:** Coulomb counting with initial SOC = 100%
- **Range:** 181 miles under standard drive cycle

### 3. Series-Parallel HEV

- **Engine:** 1.5L, BSFC map-based fuel rate calculation
- **Motor/Generator:** HPEVS AC-23
- **Combined peak power:** 90 kW
- **Energy management:** Rule-based Stateflow controller
- **Result:** 64 MPG fuel economy, 819-mile total range

---

## Energy Management Strategy (Stateflow)

The HEV controller uses a rule-based supervisory strategy with two user-selectable modes:

### Economy Mode
```
States: EV_Only → Engine_On → Regen → Charging
Transitions governed by:
  - SOC thresholds (SOC_low, SOC_high)
  - Power demand vs. engine efficiency sweet spot
  - Vehicle speed limits for EV-only operation
  - Brake torque signal for regenerative braking activation
```

### Sport Mode
- Higher power split toward motor for faster response
- Engine engages at lower speed thresholds
- Reduced fuel economy in exchange for performance

### Controlled States
- Engine ON/OFF and torque split
- Motor torque (drive/regen)
- Clutch engagement/disengagement
- Battery charging command
- Regenerative braking activation

---

## Simulation Framework

```
Drive Cycle (velocity profile)
        ↓
Driver Block (PID speed controller)
        ↓
Supervisory Controller (Stateflow EMS)
        ↓
Powertrain Model (Engine + Motor + Transmission)
        ↓
Longitudinal Vehicle Dynamics
        ↓
Outputs: Fuel consumption, SOC, speed tracking, emissions
```

### Vehicle and Component Models

| Block | Approach |
|---|---|
| Engine | BSFC lookup map; torque vs. RPM |
| Electric motor | Efficiency map; motoring + regeneration |
| Battery | RC equivalent circuit (Thevenin); SOC + thermal |
| Transmission | Gear-shift schedule; torque converter model |
| Vehicle dynamics | Longitudinal; aerodynamic drag, rolling resistance |

---

## Drive Cycles Used

- Custom drive cycle is collected to simulate models. GPS logger app is used to collect data. Vehicle is driven from Greenville, SC to Clemson, SC about 45 miles.

---

## Key Learnings

- **BSFC-based gear shifting** is the single largest contributor to ICE fuel economy improvement — operating the engine near its efficiency island adds ~8–10 MPG over naive shifting
- **Rule-based EMS** is straightforward to tune but sensitive to SOC threshold selection; tight thresholds cause engine hunting, loose thresholds waste EV range
- **Regenerative braking** contributes approximately 15–20% of recovered energy in city cycles; the gain drops significantly in highway-dominated profiles
- **Thermal modeling** of the battery matters for range accuracy — without it, range estimates are optimistic by ~5–8%

---

## Repository Structure

```
hybrid-ev-ice-powertrain-sim/
├── models/
│   ├── ICE_vehicle.slx           # Conventional ICE Simulink model
│   ├── BEV_vehicle.slx           # Battery electric vehicle model
│   ├── HEV_series_parallel.slx   # Full HEV Simulink model
│   └── EMS_stateflow.slx         # Energy management Stateflow chart
├── data/
│   ├── BSFC_map.mat              # Engine BSFC data
│   ├── motor_efficiency.mat      # Motor efficiency map
│   ├── drive_cycles/             # FTP75, HWFET, US06
│   └── OCV_SOC.mat               # Battery OCV vs SOC curve
├── scripts/
│   ├── run_ICE.m
│   ├── run_BEV.m
│   ├── run_HEV.m
│   └── compare_architectures.m   # Side-by-side results plot
├── results/
│   └── architecture_comparison.png
└── README.md
```

---

## References

- SAE J1634: BEV Energy Consumption and Range Test Procedure
- Custom drive cycle specifications collected through GPS logger
- Guzzella & Sciarretta, *Vehicle Propulsion Systems*, Springer

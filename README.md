# hybrid-pv-wind-islanding-detection

Ride-through-compatible islanding detection for a grid-connected hybrid solar PV–wind system, using a machine-learning classifier on top of an H-infinity current controller. MATLAB/Simulink.

> **Status:** work in progress. Phases 1 to 6 are done (results below); phases 7 and 8 are planned and have no results yet.

## Problem

IEEE 1547-2018 asks an inverter-based source to do two things that pull against each other:

- stay connected through voltage sags and frequency swings (ride-through), and
- detect a real island and stop energising it within 2 seconds.

Passive detection (voltage, frequency, rate of change of frequency) has a non-detection zone when local load and generation are nearly matched, and it false-trips on ordinary disturbances. Active methods shrink that zone but inject disturbances and degrade power quality. Both problems get worse on a weak grid.

## Proposed approach

1. An **H-infinity current controller** keeps the inverter stable and well-damped across a range of grid strengths, so the test bed behaves properly on a weak grid.
2. A **machine-learning classifier** separates islanding from non-islanding disturbances using features measured at the point of common coupling.
3. Both are compared against PI control and against passive and active detection on the same test cases.

## System under study

| Item | Value |
|---|---|
| PV | Array with boost converter and P&O MPPT |
| Wind | PMSG with rectifier and boost converter |
| DC link | 800 V |
| Inverter | Three-phase two-level VSI, 10 kHz switching |
| Filter | LCL |
| Grid | 400 V, 50 Hz |

Ratings will be fixed and documented in phase 1 (the current model and the thesis disagree on the PV rating).

## Model

`hybrid_pv_wind_islanding.slx` is the corrected test bed (PI control and a passive detector; the H-infinity controller and ML detector come in later phases).

![Top level of the model](docs/model_top.png)

**Wind turbine, PMSG, rectifier, boost and optimal-torque MPPT**

![Wind turbine subsystem](docs/wind_subsystem.png)

**PV boost converter with perturb-and-observe MPPT**

![PV boost converter and MPPT](docs/pv_boost_mppt.png)

**Inverter control: PLL, DC-link and current loops**

![Inverter control](docs/inverter_control.png)

**Passive protection: voltage, frequency and rate of change of frequency**

![Passive protection](docs/passive_protection.png)

**Second inverter (Phase 5 multi-inverter cases): constant-power current references from the PCC voltage, with optional reactive drift**

![Second inverter control](docs/second_inverter.png)

Regenerate the pictures with `export_diagrams` after any model change.

## Results so far

All figures below come from `hybrid_pv_wind_islanding.slx` with PI control and the passive detector.

### Phase 1: corrected test bed

| Quantity | Original model | Corrected model |
|---|---|---|
| Steady state | None: irradiance followed a 24-hour day squeezed into 2.4 s | Reached within 0.3 s |
| PV operating point | MPPT reference capped at 50 V for a 290 V array; voltage collapsed | 10.6 kW at about 290 V |
| Wind | Torque computed from a fixed speed; power not physical | Optimal-torque MPPT; rotor speed follows wind steps |
| Frequency signal | Climbed from 44 to 489 during the run | 50.00 Hz |
| Protection | Latched at start-up and could never open the breaker | Opens the breaker and stops both boost converters |
| DC link | 805 V, 43 V ripple | 800 V, 4 V ripple |
| Grid current THD | Not measurable (no steady state) | 1.2% |
| Simulation speed | 954 s per simulated second | 40 to 70 s per simulated second |

Exported power is 18.5 kW from about 20.4 kW of generation.

### First islanding check (4.4% reactive mismatch)

![Islanding event, 4.4% reactive mismatch](docs/islanding_matched.png)

The fast passive detector trips 10.6 ms after the grid breaker opens. **Correction:** this case was first reported as a matched load, but the load was sized with Q_L = Q_C and ignored the inverter's own 813 var output, so it is really a 4.4% reactive mismatch. A properly matched island is not detected by either passive setting; see Phase 4.

### Phase 2: PI baseline against grid strength

![Open-loop Bode plot of the PI current loop](docs/pi_loop_bode.png)

Current-loop margins from the derived plant model (`scripts/plant_model.m`):

| Case | Phase margin | Gain margin | Sensitivity peak |
|---|---|---|---|
| As simulated, no control delay, SCR 20 to 2 | 86° to 89° | unlimited | 1.0 |
| With a digital delay of 1.5 switching periods | 50° to 66° | 7.8 to 8.7 dB | 1.8 to 1.9 |

Simulation with the local load removed:

| Short-circuit ratio | Result |
|---|---|
| 20, 10, 5 | Stable from a hard start; current THD 0.7 to 1.3%; PCC voltage up to 1.05 pu |
| 3 and 2, hard start at full power | Loses synchronism within 50 ms |
| 3 and 2, power ramped up after start | Stable at 17.8 kW; current THD 1.2 to 1.3%; voltage THD 2.9 to 3.6%; PCC voltage 1.07 to 1.08 pu |

The PI baseline is stable in steady state down to a short-circuit ratio of 2. It degrades in start-up at full power, in PCC voltage rise and in frequency ripple, so the case for the H-infinity controller (phase 3) rests on those and on the reduced margins once a control delay is included.

### Phase 3: H-infinity current controller

The current control is now sampled at the switching frequency with a one-sample computation delay, for both controllers. `P.ctrl.mode` selects the current controller in the same model (1 PI, 2 PID, 3 H-infinity, 4 fuzzy PI).

The controller is a structured H-infinity design (`scripts/design_hinf.m`): one order-4 controller tuned against five plants at once, at short-circuit ratios 20, 10, 5, 3 and 2.

![Sensitivity of the current loop, PI against H-infinity](docs/controller_sensitivity.png)

| Design figure (with the control delay) | PI | H-infinity |
|---|---|---|
| Gain margin | 7.9 to 8.7 dB | 11.3 to 12.4 dB |
| Phase margin | 50° to 66° | 58° to 67° |
| Sensitivity peak | 1.76 to 1.93 | 1.40 to 1.49 |

Simulation with the local load removed (`scripts/compare_controllers.m`):

| Test | PI | H-infinity |
|---|---|---|
| Hard start, SCR 20 | Stable; current THD 1.7%, voltage THD 1.7% | Stable; 1.7%, 1.3% |
| Hard start, SCR 10 | Stable; 1.0%, 1.6% | Stable; 1.4%, 1.9% |
| Hard start, SCR 5 | Stable; 0.8%, 1.4% | Stable; 1.4%, 2.9% |
| Hard start, SCR 3 | Loses synchronism | Loses synchronism |
| Power ramp, SCR 3 | Stable; 1.3%, 2.7% | Stable; 1.2%, 2.5% |
| Power ramp, SCR 2 | Stable; 1.3%, 3.4% | Stable; 1.2%, 2.9% |
| DC-link deviation after the power step | 17.8 V | 17.7 V |

The H-infinity controller has better stability margins, but it gives no practical advantage in these tests. The synthesis converged close to a lower-gain PI, which trades low-frequency disturbance rejection for robustness: distortion is slightly lower at short-circuit ratios 3 and 2 and higher at 10 and 5. Neither controller survives a hard start at a ratio of 3, which points to the PLL and not the current loop. PI therefore stays the default controller for the islanding study.

### Four current controllers compared: PI, PID, H-infinity, fuzzy PI

All four sit in the same block, "Current controller d" and "Current controller q", fed by the same error and followed by the same one-sample computation delay. `P.ctrl.mode` picks one.

| Controller | Design | Script |
|---|---|---|
| PI | Baseline gains Kp = 6, Ki = 1000 | `params.m` |
| PID | Baseline PI plus a filtered derivative, Kd = 1.26e-4, filter 100 us | `design_pid.m` |
| H-infinity | Structured synthesis on five grid strengths, order 4 | `design_hinf.m` |
| Fuzzy PI | Incremental fuzzy PI, 7 sets per input, 49 rules, scaled to equal the PI for small signals | `design_flc.m` |

`pidtune` never adds derivative action on this plant: with the 1.5-sample loop delay, every increase in derivative gain raises the worst-case sensitivity peak, and Kd = 2e-3 is unstable. The PID therefore uses the largest derivative that costs no more than 5% of the PI's robustness.

Stability margins on the discrete plant with the control delay (`margins_all.m`; the fuzzy PI by its small-signal equivalent):

| Controller | Gain margin | Phase margin | Sensitivity peak |
|---|---|---|---|
| PI | 7.5 to 8.4 dB | 50° to 66° | 1.78 to 1.96 |
| PID | 6.9 to 7.8 dB | 51° to 69° | 1.82 to 2.04 |
| H-infinity | 10.7 to 11.9 dB | 58° to 68° | 1.41 to 1.51 |
| Fuzzy PI | 9.8 to 10.7 dB | 59° to 70° | 1.53 to 1.63 |

![Sensitivity of the four controllers](docs/controllers_sensitivity.png)

Simulation (`compare_controllers.m`, local load removed, protection unarmed). Each cell is current THD / voltage THD:

| Test | PI | PID | H-infinity | Fuzzy PI |
|---|---|---|---|---|
| Hard start, SCR 20 | 1.7% / 1.7% | 1.7% / 1.7% | 1.7% / 1.3% | 1.4% / 1.8% |
| Hard start, SCR 10 | 1.0% / 1.6% | 1.0% / 1.7% | 1.4% / 1.9% | 1.0% / 1.7% |
| Hard start, SCR 5 | 0.8% / 1.4% | 0.9% / 1.7% | 1.4% / 3.0% | 0.9% / 2.0% |
| Hard start, SCR 3 | loses synchronism | loses synchronism | loses synchronism | loses synchronism |
| Power ramp, SCR 3 | 1.3% / 2.7% | 1.3% / 3.0% | 1.2% / 2.5% | **0.8% / 1.9%** |
| Power ramp, SCR 2 | 1.3% / 3.4% | 1.0% / 2.5% | 1.2% / 2.9% | **0.7% / 1.9%** |
| Irradiance step, SCR 5 | 1.7% / 2.4% | 1.0% / 1.5% | 1.4% / 1.8% | 1.0% / 1.8% |
| DC-link dip after the irradiance step | 12.9 V | 13.5 V | 13.4 V | 13.4 V |
| DC-link settling (within 2 V) | 142 ms | 142 ms | 195 ms | **135 ms** |

![Irradiance-step response of the four controllers](docs/controllers_step.png)

Reading the results:

- **Fuzzy PI is the best all-round performer.** It has the lowest distortion on the weak grids (current THD 0.7 to 0.8% against 1.0 to 1.3%, voltage THD 1.9% against 2.5 to 3.4%), the fastest DC-link recovery, and the second-best margins.
- **H-infinity is the most robust on paper** but gives the highest distortion at SCR 5 and 10 and the slowest DC-link recovery.
- **PID behaves like PI**, as the margin analysis predicts; the derivative term can only be small on this plant.
- **No controller survives a hard start at SCR 3.** The failure is in synchronisation (PLL), not the current loop.
- **Distortion figures come from single runs** and vary by a few tenths of a percent with the MPPT's perturbation, so differences below about 0.3% should not be read as significant.

### Phase 4: islanding test bench and baseline detectors

Three baseline detectors, all evaluated offline on the same logged PCC voltage and frequency (`detect_islanding.m`):

| Detector | Settings |
|---|---|
| Fast passive | Instantaneous trip: under 0.88 pu, over 1.10 pu, under 49.3 Hz, over 50.5 Hz, rate of change of frequency over 2 Hz/s |
| IEEE passive | IEEE 1547-2018 Category II default trip settings, frequencies scaled to 50 Hz: UV 0.70 pu / 10 s and 0.45 pu / 0.16 s; OV 1.10 pu / 2 s and 1.20 pu / 0.16 s; UF 48.75 Hz / 300 s and 47.08 Hz / 0.16 s; OF 51.0 Hz / 300 s and 51.67 Hz / 0.16 s |
| IEEE + AFD | The IEEE settings with active frequency drift: q-axis current reference = bias + K·(f − 50 Hz), K = −4.1 A/Hz, bias −0.41 A, limit ±12.2 A |

The sign of the drift gain matters: with K > 0 a matched island holds at 49.95 Hz and is never detected; with K < 0 its frequency runs away (`afd_sign_test.m`).

![Matched island without and with frequency drift](docs/island_matched_afd.png)

A matched island (no active or reactive mismatch) stays at 50.05 Hz and 1.0 pu, so no passive setting can see it. With frequency drift the inverter injects reactive current as soon as the frequency moves, the frequency runs to 58.4 Hz, and the IEEE OF2 element (51.67 Hz, 0.16 s) trips 191 ms after islanding. The voltage ripple with drift is partly a measurement effect: the RMS window is fixed at 50 Hz while the island runs at 58 Hz.

**Non-detection zones.** The grid breaker opens at 0.4 s with an RLC load (Q_f = 1) sized relative to the inverter's measured output (18.57 kW, 813 var), and each detector gets the 2 s IEEE 1547-2018 allows (`ndz_sweep.m`, `island_case.m`, 70 runs):

![Detection time over the mismatch plane](docs/ndz_maps.png)

**False trips.** Eleven ordinary disturbances with the grid connected; every trip is false (`false_trip_test.m`). The grid events use a programmable source; the load and capacitor are switched in at the PCC.

![Rate of change of frequency for an island and four ordinary events](docs/rocof_island_vs_events.png)

Why a threshold cannot work: the rate of change of frequency the relay sees after an island (peak 16 Hz/s) is no different in kind from what an irradiance step (4 Hz/s), a capacitor switching (10 Hz/s), a voltage sag (17 Hz/s) or a phase jump (106 Hz/s) produces. Any threshold low enough to catch the island also trips on these events.

| Event | Fast passive | IEEE passive | IEEE + AFD |
|---|---|---|---|
| Irradiance 1000 to 600 W/m² | trips (12 ms) | no trip | no trip |
| Irradiance 600 to 1000 W/m² | trips (13 ms) | no trip | no trip |
| Wind 12 to 9 m/s | no trip | no trip | no trip |
| Load switched on (+6 kW) | trips (6 ms) | no trip | no trip |
| Capacitor switched on (5 kvar) | trips (4 ms) | no trip | no trip |
| Voltage sag to 0.7 pu, 0.5 s | trips (3 ms) | no trip | no trip |
| Voltage sag to 0.5 pu, 0.2 s | trips (3 ms) | no trip | no trip |
| Voltage swell to 1.15 pu, 0.5 s | trips (4 ms) | no trip | no trip |
| Frequency ramp −2 Hz/s for 0.5 s | trips (51 ms) | no trip | no trip |
| Frequency ramp +2 Hz/s for 0.5 s | trips (76 ms) | no trip | no trip |
| Phase jump 20° | trips (2 ms) | no trip | no trip |

| Detector | Islands detected (35) | Detection time | False trips (11) |
|---|---|---|---|
| Fast passive | 34 | 7 to 52 ms | 10 |
| IEEE passive | 0 | none within 2 s | 0 |
| IEEE + AFD | 35 | 160 to 275 ms | 0 |

![Islands detected against false trips](docs/detector_summary.png)

Reading the results:

- **The trade-off the paper rests on is real.** Settings fast enough to catch islands trip on almost every ordinary disturbance; ride-through-compliant settings trip on nothing, including real islands.
- **Active frequency drift solves both in this test bed**, at SCR 10 with Q_f = 1: every island detected in under 0.3 s and no false trips. Its cost is small here: grid-connected current THD 2.08% with and without it, and about 100 var of extra reactive exchange.
- **So the case for an ML detector was not made by Phase 4 alone.** It has to come from conditions where active drift is known to struggle: weak grids, higher quality-factor loads, and several inverters whose drift can cancel. Phase 5 tests exactly these.

### Phase 5: where active frequency drift fails, and the dataset

**Stress tests of active frequency drift** (`afd_stress.m`, 23 runs, IEEE 1547-2018 settings, 2 s allowed). Two additions to the model make them possible: a second 10 kW inverter at the PCC (an averaged constant-power source whose reactive power can drift with frequency), and a weak-grid start in which the PV is held at 200 W/m² until 0.3 s (at full power from t = 0 the inverter does not synchronise on SCR 3 or 2).

| Condition | Result |
|---|---|
| Load quality factor 2.5, SCR 10, five mismatches | All detected, but slower: 225 to 488 ms (160 to 275 ms at Q_f = 1) |
| Matched island on a weak grid: SCR 3, SCR 2 (Q_f 1); SCR 3 (Q_f 2.5) | Detected in 187 ms, 185 ms and 301 ms |
| Drift running on a weak grid, five ordinary events each at SCR 3 and SCR 2 | No false trip on 9 of 10. **A 0.7 pu sag at SCR 2 goes unstable**: frequency swings 43 Hz, voltage falls to 0.33 pu, false trip at 150 ms |
| The same sag at SCR 2 without drift | Rides through: frequency within 2.9 Hz, voltage 0.73 pu, no trip |
| A second inverter with no drift | Detected, slower: 221 ms |
| A second inverter drifting the same way (1 and 2 kvar/Hz) | Detected in 197 and 188 ms |
| **A second inverter drifting the opposite way (2 kvar/Hz)** | **Not detected**: the island holds within 0.19 Hz of 50 Hz for the full 2 s |

![Active frequency drift under stress](docs/afd_stress.png)

Reading the results:

- **Two inverters can cancel each other's drift completely.** The main inverter's drift is equivalent to about 2 kvar/Hz; a neighbouring unit with the same slope and the opposite sign removes it, and a matched island is again invisible. This is the multi-inverter failure reported in the literature, reproduced here.
- **On a weak grid the drift breaks fault ride-through.** With the grid present, the drift's positive feedback is normally held down by the grid; at SCR 2 during a deep sag it is not, and the inverter trips on an event IEEE 1547-2018 requires it to ride through. Without drift the same sag is ridden through.
- Drift still copes with a higher load quality factor, but takes up to two and a half times as long (488 ms against 191 ms for the matched island at Q_f = 1).
- Together these give the ML detector its purpose: a passive detector, with no injection, that does not depend on what neighbouring inverters do and does not destabilise a weak grid.

**Dataset** (`make_dataset.m`, `operating_conditions.m`). Sixteen operating conditions, four grid strengths (SCR 20, 10, 5, 3) by four PV/wind mixes (18.6, 10.6, 11.2 and 6.8 kW at the PCC, `results/operating_points.csv`), each with 25 cases, all with frequency drift off:

- **14 islands**: Q_f 1 and 2.5, each at seven mismatches (ΔP, ΔQ) = (0, 0), (±5%, 0), (0, ±2.5%), (+15%, +5%), (−15%, −5%), with the load sized from that condition's own inverter output.
- **11 ordinary events**: the disturbances of Phase 4, scaled to each condition's irradiance and wind speed, with the same local load in place.
- Event times are spread over one 20 ms cycle so the point on the wave varies.
- Each case keeps 0.1 s before to 0.35 s after the event: PCC voltage and inverter current waveforms at 10 kHz, and frequency, RMS voltage, DC-link voltage and d/q currents at 1 kHz. 400 cases, 224 islands and 176 ordinary events; about 42 MB in `data/raw/` (not in git; index in `results/dataset_index.csv`).

![Dataset overview](docs/dataset_overview.png)

The passive relays on the dataset's own windows (`dataset_baselines.m`; within 0.35 s only the IEEE elements with 0.16 s clearing can act):

| Detector | Islands detected (224) | Median detection time | Ordinary events tripped (176) |
|---|---|---|---|
| Fast passive | 186 | 14 ms | 154 |
| IEEE passive | 0 | none within 0.35 s | 0 |

The fast relay misses 38 islands, all of them matched or nearly matched (ΔP ±5% with ΔQ = 0, and at Q_f 2.5 also ΔQ ±2.5%), and still trips on 154 of the 176 ordinary events: every load and capacitor switching, sag, swell, frequency ramp and phase jump, and most irradiance steps. Within 0.35 s the IEEE settings act on nothing. The classifier of Phase 6 has to work exactly where both relay families fail: the matched and small-mismatch islands, and the disturbances a ride-through relay must ignore.

### Phase 6: a passive classifier tested on unseen operating conditions

**How the detector works.** Every 5 ms it takes the latest window of measurements (10 ms in the chosen design) and compares it with the 40 ms before (`window_features.m`). Everything it uses is measured at the inverter's own terminals: PCC voltage, its own current, its PLL frequency, DC-link voltage and its d/q currents. There are 22 features, all changes from the baseline, so the operating point itself is never a feature:

- voltage magnitude and frequency changes, and rate of change of frequency;
- phase jump and positive- and negative-sequence voltage and current, from a least-squares fit of the 10 kHz waveforms;
- active and reactive power changes;
- voltage and current distortion, and a distortion-impedance ratio;
- DC-link voltage and d/q current deviations.

The classifier labels each window, and the detector trips once 6 windows in a row (30 ms) are labelled island.

**How it is tested.** Cases are never split between training and testing; every test case comes from an operating condition the model never saw. One family of folds holds out each grid strength in turn (SCR 20, 10, 5, 3), the other each PV/wind mix. Each test case is replayed window by window, as a relay in service would see it, and scored as a whole case (`replay_detector.m`):

- an island is detected or missed, with the time from the breaker opening to the trip;
- any trip after an ordinary event is a false trip;
- any trip before the event is a false alarm in steady operation.

Four models were trained at window lengths of 10, 20 and 40 ms: a decision tree, a random forest (bagged trees), an SVM with a Gaussian kernel, and a small neural network (`train_classifiers.m`). The setting was chosen by a rule fixed in advance and applied to the mix folds only: no steady-state alarm, at most 2% false trips, then the most islands detected. The numbers below come from the grid-strength folds, which played no part in the choice.

![Trade-off between islands detected and false trips](docs/ml_tradeoff.png)

Chosen detector: a neural network (two hidden layers, 20 and 10 neurons) on 10 ms windows, threshold 0.5, trip after 6 windows in a row. On the same 400 cases (`results/detector_cases.csv`):

| Detector | Islands detected (224) | Matched islands (32) | Ordinary events tripped (176) | Steady-state alarms (400) | Median detection time |
|---|---|---|---|---|---|
| **Neural network (unseen grid strength)** | **223** | **32** | **3** | **1** | **35 ms** (95% within 82 ms) |
| Fast relay | 186 | 16 | 154 | 0 | 14 ms |
| IEEE 1547 relay | 0 within 0.35 s | 0 | 0 | 0 | none |
| Active frequency drift (Phases 4, 5) | all tested, except with an opposing second inverter | not detected with an opposing inverter | false trip on a weak-grid sag | 0 | 160 to 488 ms |

| Grid strength held out | Islands detected | False trips | Steady-state alarms |
|---|---|---|---|
| SCR 20 | 56 of 56 | 0 of 44 | 0 |
| SCR 10 | 56 of 56 | 0 of 44 | 0 |
| SCR 5 | 56 of 56 | 0 of 44 | 0 |
| SCR 3 | 55 of 56 | 3 of 44 (two 1.15 pu swells, one 0.7 pu sag) | 1 |

![When each kind of island is detected, and the features the detector relies on](docs/ml_detection.png)

Reading the results:

- **On grid strengths inside the training range the detector made no error**: every island detected, matched ones included, with no false trip and no steady-state alarm. All four errors are on SCR 3, the weakest grid. When SCR 3 is held out the model has never seen a grid that weak, so this is extrapolation; a weak grid in the training data is the obvious remedy and will be checked.
- **It detects islands about five times faster than active frequency drift** (median 35 ms against 160 to 488 ms) without injecting anything, so it cannot be cancelled by a neighbouring inverter or destabilise a weak grid.
- **Matched islands are the slow ones** (median about 60 ms, all within 220 ms). In the first 40 ms they change almost nothing: frequency by 0.04 to 0.1 Hz and voltage by 0.007 pu. The detector picks up the small voltage wander that follows when the stiff grid is gone, which is why the largest voltage change is by far its most important feature.
- **Model choice.** The forest and the tree detect every island too but false-trip on 6 to 10% of events. The SVM is a close second (98.2% detected, 2.3% false trips, no steady alarms, median 45 ms). The network file is 9.6 kB (`ml/islanding_classifier.mat`), small enough to run inside the Simulink model.
- **Two things that did not work**, recorded so they are not tried again:
  - A distortion-impedance feature, meant to see the PCC impedance rise when the grid is lost, barely helps. At low harmonics the parallel RLC load has a lower impedance than the grid, and at the switching frequency the capacitors dominate either way.
  - An estimate of voltage sensitivity to the inverter's own power changes was flat across grid strengths, so it was removed.
- **What Phase 7 must test.** These cases are noise-free. The matched-island detections rest on small voltage changes that measurement noise could hide, and the detector has not yet tripped the breaker inside the simulation.

### Known limitations

- PI and PLL gains are a first pass, not optimised.
- PV current readings are unreliable when the PV voltage is far above its operating point, including after a trip.
- Generator stator inductance (3 mH) and rotor inertia (10 kg m²) were changed from the original so the machine can deliver 10 kW through a diode rectifier.
- The classifier has been tested on noise-free simulated measurements only; noise and closed-loop tripping are Phase 7.
- The second inverter is an averaged current source with ideal current control, not a switching model; it represents a neighbouring unit's power and reactive drift, not its control dynamics.

## Workflow

```mermaid
flowchart TD
    A["Baseline hybrid PV-wind model"] --> P1["Phase 1: Clean up model<br/>ratings, grid impedance, variable wind,<br/>frequency measurement, LCL damping"]
    P1 --> P2["Phase 2: Plant model and PI baseline<br/>transfer function, tuning, SCR sweep"]
    P2 --> P3["Phase 3: H-infinity controller<br/>uncertainty model, weights, synthesis,<br/>order reduction, discretisation"]
    P3 --> D1{"Stable across<br/>SCR 2 to 20?"}
    D1 -- No --> P3
    D1 -- Yes --> P4["Phase 4: Islanding test bench<br/>RLC load with Q = 1, scripted breaker"]
    P2 -. "PI baseline" .-> P4
    P4 --> B["Baselines: passive and active detection<br/>non-detection-zone maps"]
    P4 --> P5["Phase 5: Dataset generation<br/>islanding and non-islanding events"]
    P5 --> P6["Phase 6: Features and classifier<br/>split by operating condition, train"]
    P6 --> D2{"Accuracy and false-trip<br/>targets met on unseen cases?"}
    D2 -- No --> P5
    D2 -- Yes --> P7["Phase 7: Closed-loop validation<br/>classifier trips breaker, noise added"]
    B --> P7
    P7 --> D3{"Detection under 2 s<br/>and no false trips<br/>during ride-through?"}
    D3 -- No --> P6
    D3 -- Yes --> P8["Phase 8: Paper<br/>comparison table, draft, submission"]
```

### Phase 1 — Clean up the baseline model
- Fix one rating for PV and wind and use it everywhere.
- Replace the near-ideal grid source with a realistic impedance, parameterised by short-circuit ratio (SCR).
- Add a variable wind-speed profile and wind-side MPPT to the hybrid model.
- Correct the frequency measurement (take it from the PLL; the gain must be `1/(2*pi)`).
- Redesign the LCL damping resistor to match the design equation.
- Output: one parameter script, `scripts/params.m`, that every model reads.

### Phase 2 — Plant model and PI baseline
- Derive the transfer function of inverter + LCL filter + grid impedance.
- Tune the PI current controller properly and record its margins.
- Sweep SCR (20, 10, 5, 3, 2) and record where PI degrades.
- Output: Bode plots, stability limits, baseline distortion and DC-link response.

### Phase 3 — H-infinity controller
- Model grid inductance as an uncertain parameter over the SCR range.
- Choose weighting functions for tracking, control effort and robustness, and document the reasoning.
- Synthesise with the Robust Control Toolbox (`mixsyn` or `ncfsyn`; `musyn` for structured uncertainty).
- Reduce the controller order and discretise at the switching rate.
- Output: PI vs H-infinity on the same SCR sweep — stability margins, settling time, overshoot, current distortion.

### Phase 4 — Islanding test bench
- Add a parallel RLC load at the point of common coupling, tuned to 50 Hz with quality factor 1 (IEEE 1547.1 unintentional-islanding test).
- Script the grid breaker to open during the run.
- Implement two baselines: passive (over/under voltage, over/under frequency, rate of change of frequency) and one active method (frequency shift or reactive-power perturbation).
- Sweep active and reactive power mismatch and map the non-detection zone of each baseline.
- Output: non-detection-zone maps and detection times for the baselines.

### Phase 5 — Dataset generation (done)
- Islanding cases: seven mismatches at Q_f 1 and 2.5, four PV/wind mixes and four grid strengths.
- Non-islanding cases: irradiance and wind steps, load and capacitor switching, sags, a swell, frequency ramps and a phase jump.
- Stress tests of the active-drift baseline: quality factor, weak grid, a second inverter.
- Run sequentially by `run_phase5.m` (one simulation process fits in memory, so `parsim` was not used); finished cases are skipped on restart.
- Output: 400 labelled cases in `data/raw/`, `results/dataset_index.csv`, `results/afd_stress.csv`.

### Phase 6 — Features and classifier (done)
- 22 features over a sliding window (10, 20 or 40 ms, every 5 ms) against the 40 ms before it: voltage magnitude, frequency and rate of change of frequency, phase jump, sequence components, power changes, distortion, DC-link and d/q current deviations.
- Split by operating condition (grid strength or PV/wind mix held out), never by window or case.
- Decision tree, random forest, SVM and a small neural network; the setting chosen by a rule fixed in advance on one family of folds and reported on the other.
- Output: `ml/islanding_classifier.mat`, `results/classifier_summary.csv`, `results/detector_cases.csv`, `results/feature_importance.csv`.

### Phase 7 — Closed-loop validation
- Put the trained classifier back into Simulink so it trips the breaker itself.
- Re-run the full test set with measurement noise added.
- Report, for the proposed method and both baselines:
  - detection time against the 2-second limit,
  - non-detection zone,
  - false-trip rate during ride-through events,
  - effect on current distortion.
- Repeat with PI and with H-infinity control to show what the controller contributes.

### Phase 8 — Paper
- Comparison table against recent published methods.
- Draft, internal review by supervisors, submission.

## Repository layout

```
hybrid_pv_wind_islanding.slx   Corrected test-bed model (R2024b), built by scripts/build_model.m
MATLAB_R2018a/                 Original Simulink models, saved in R2018a (kept unchanged)
scripts/params.m               Every rating, gain and test setting in one place
scripts/build_model.m          Rebuilds the corrected model from the original, change by change
scripts/run_model.m            Runs the model and reports power, DC link, frequency, distortion, trip
scripts/run_baseline.m         Runs the original model for the before/after comparison
scripts/export_diagrams.m      Saves the model diagrams to docs/
scripts/plant_model.m          Current-loop plant: inverter, LCL filter, grid and voltage feedforward
scripts/loop_margins.m         Stability margins of the current loop
scripts/analyze_pi.m           Margins of the PI baseline at each grid strength
scripts/sweep_scr.m            Simulates the PI baseline at each grid strength
scripts/softstart_scr.m        Weak-grid test with power ramped up after start
scripts/signal_metrics.m       Power, distortion, DC-link and frequency figures from a run
scripts/plot_pi_bode.m         Draws docs/pi_loop_bode.png
scripts/plot_islanding.m       Draws docs/islanding_matched.png
scripts/design_hinf.m          Structured H-infinity current controller design
scripts/hinf_controller.mat    The designed controller, read by params.m
scripts/compare_controllers.m  All four current controllers on the same test suite
scripts/plot_controller_sensitivity.m  Draws docs/controller_sensitivity.png
scripts/design_pid.m           PID current controller (baseline PI plus filtered derivative)
scripts/design_flc.m           Fuzzy PI current controller
scripts/discrete_plant.m       Current-loop plant as the digital controller sees it
scripts/margins_all.m          Margins of all four controllers at each grid strength
scripts/plot_controller_comparison.m  Draws docs/controllers_sensitivity.png and docs/controllers_step.png
scripts/demo_hinf.m            Walk-through of the H-infinity controller for a demonstration
scripts/detect_islanding.m     Replays logged voltage and frequency through a set of relay settings
scripts/island_case.m          Sizes the RLC load for a given active/reactive mismatch
scripts/afd_sign_test.m        Matched island with no drift and with drift of each sign
scripts/ndz_sweep.m            Non-detection-zone sweep (70 runs); evaluate_ndz.m scores it
scripts/false_trip_test.m      Eleven non-islanding disturbances through every detector
scripts/plot_ndz.m            Draws docs/ndz_maps.png
scripts/plot_phase4.m          Draws the island, ROCOF and detector-summary figures
scripts/disturbance_events.m   The eleven ordinary disturbances used for false-trip tests
scripts/relay_signals.m        Voltage, frequency and ROCOF as a relay sees them
scripts/run_phase5.m           Runs every Phase 5 stage in order
scripts/operating_conditions.m The sixteen operating conditions; condition_params.m sets one up
scripts/operating_points.m     Inverter output at each condition, used to size islanding loads
scripts/afd_stress.m           Active frequency drift under high Q_f, weak grid and a second inverter
scripts/make_dataset.m         The 400-case labelled dataset in data/raw/
scripts/dataset_baselines.m    The passive relays on the dataset's windows
scripts/reduce_run.m           Keeps a run's 1 ms signals for detector replay
scripts/plot_phase5.m          Draws docs/afd_stress.png and docs/dataset_overview.png
scripts/window_features.m      The 22 features of one measurement window
scripts/extract_features.m     Sliding-window features for every case (data/features/)
scripts/train_classifiers.m    Four classifiers, tested on held-out grid strengths and PV/wind mixes
scripts/replay_detector.m      Replays classifier scores case by case as a relay, for every threshold and debounce
scripts/final_classifier.m     Feature importance and the final trained detector
scripts/plot_phase6.m          Draws docs/ml_tradeoff.png and docs/ml_detection.png
docs/                          Model diagrams and result figures
results/                       Result tables (.csv); simulation runs (.mat) are not tracked
data/raw/                      Phase 5 dataset, generated, not tracked
ml/islanding_classifier.mat    The trained detector (Phase 6) with its window, threshold and debounce
paper/                         Planned
report/, archive/              Kept locally, not tracked
```

To run an islanding case:

```matlab
addpath scripts
P = params(10);            % short-circuit ratio 10
P.tIsland = 0.5;           % open the grid breaker at 0.5 s
P.load.P = 18.4e3; P.load.QL = P.load.P; P.load.QC = P.load.P;   % matched RLC load, Qf = 1
run_model(1.0, P, 'island_matched');
```

## Requirements

- MATLAB with Simulink and Simscape Electrical (Specialized Power Systems)
- Robust Control Toolbox
- Statistics and Machine Learning Toolbox
- Parallel Computing Toolbox (optional, for batch runs)

## Authors

To be confirmed with the project team and supervisors.

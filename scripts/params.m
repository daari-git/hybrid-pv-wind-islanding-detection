function P = params(scr)
% PARAMS  Single source of truth for the hybrid PV-wind islanding test bed.
%   P = PARAMS(SCR) returns every rating, filter value, controller gain and
%   test setting used by the model and scripts. SCR is the grid short-circuit
%   ratio at the point of common coupling (default 10).
%   The model reads this struct from its model workspace as the variable P.
if nargin < 1, scr = 10; end

% ---- Ratings ----
P.Sn    = 20e3;            % inverter rating (VA): 10 kW PV + 10 kW wind
P.Vll   = 400;             % grid line-to-line RMS voltage (V)
P.fg    = 50;              % grid frequency (Hz)
P.wg    = 2*pi*P.fg;
P.Vdc   = 800;             % DC-link reference (V)
P.fsw   = 10e3;            % inverter switching frequency (Hz)
P.Ts    = 2e-6;            % simulation step (s)
P.In    = P.Sn/(sqrt(3)*P.Vll);   % rated RMS current (A)
P.Ipk   = sqrt(2)*P.In;           % rated peak current (A)
P.Vpk   = P.Vll*sqrt(2/3);        % phase voltage peak (V)
P.logDecim = 10;           % logging decimation (samples)

% ---- Per-unit bases ----
P.Zb = P.Vll^2/P.Sn;
P.Lb = P.Zb/P.wg;
P.Cb = 1/(P.wg*P.Zb);

% ---- PV array: 1Soltech 1STH-215-P, 213.15 W per module ----
P.pv.Nser  = 10;           % Vmp = 10 x 29 V = 290 V
P.pv.Npar  = 5;            % 50 modules = 10.66 kW at STC
P.pv.Vmp   = 290;
P.pv.Pstc  = P.pv.Nser*P.pv.Npar*213.15;
P.pv.G0    = 1000;  P.pv.G1 = 1000;  P.pv.tStep = 1e6;   % irradiance step (W/m^2, s)
P.pv.Gstart = 1e4;  P.pv.tStart = 0;                   % irradiance held below Gstart until tStart (weak-grid start)
P.pv.T     = 25;           % cell temperature (deg C)
P.pv.Tmppt = 10e-3;        % P&O period (s)
P.pv.dD    = 0.003;        % P&O duty step
P.pv.D0    = 1 - P.pv.Vmp/P.Vdc;   % starting duty
P.pv.Dmin  = 1 - 330/P.Vdc;      % keeps the PV voltage below about 330 V (open circuit is 363 V)
P.pv.Dmax  = 1 - 230/P.Vdc;      % and above about 230 V

% ---- Wind turbine and PMSG ----
P.wind.R      = 2.7072;    % blade radius (m)
P.wind.rho    = 1.225;     % air density (kg/m^3)
P.wind.CpMax  = 0.411;     % peak of the model's Cp(lambda) curve
P.wind.lamOpt = 7.954;     % tip-speed ratio at CpMax
P.wind.v0     = 12;  P.wind.v1 = 12;  P.wind.tStep = 1e6;  % wind step (m/s, s)
P.wind.Kopt   = 0.5*P.wind.rho*pi*P.wind.R^5*P.wind.CpMax/P.wind.lamOpt^3;  % P = Kopt*w^3
P.wind.wm0    = P.wind.lamOpt*P.wind.v0/P.wind.R;          % initial rotor speed (rad/s)
P.wind.Prated = P.wind.Kopt*(P.wind.lamOpt*12/P.wind.R)^3; % about 10 kW at 12 m/s
P.wind.J      = 10;        % rotor inertia (kg m^2)
P.wind.pp     = 4;         % pole pairs
P.wind.Ls     = 3e-3;      % stator inductance (H)
P.wind.Imax   = 90;        % boost inductor current limit (A)
P.wind.KpI    = 0.04;  P.wind.KiI = 12;   % boost current PI
P.wind.D0     = 0.76;      % starting duty

% ---- LCL filter ----
P.lcl.ripple = 0.20;                                   % ripple, fraction of rated peak current
P.lcl.L1 = round(P.Vdc/(6*P.fsw*P.lcl.ripple*P.Ipk), 4);   % inverter-side inductor (H)
P.lcl.L2 = 0.5*P.lcl.L1;                               % grid-side inductor (H)
P.lcl.Cf = 15e-6;                                      % filter capacitor (F), below 5% of Cb
P.lcl.wres = sqrt((P.lcl.L1+P.lcl.L2)/(P.lcl.L1*P.lcl.L2*P.lcl.Cf));
P.lcl.fres = P.lcl.wres/(2*pi);
P.lcl.Rd = 1/(3*P.lcl.wres*P.lcl.Cf);                  % passive damping resistor (ohm)
P.lcl.R1 = 1e-3;  P.lcl.R2 = 1e-3;                     % inductor resistances (ohm)

% ---- Grid, set by short-circuit ratio ----
P.grid.scr = scr;
P.grid.xr  = 3;                                        % X/R ratio, low-voltage feeder
Zg = P.Zb/scr;
P.grid.R = Zg/sqrt(1+P.grid.xr^2);
P.grid.L = P.grid.xr*P.grid.R/P.wg;

% ---- Inverter control (PI baseline) ----
P.pll.wn = 2*pi*30;  P.pll.zeta = 0.707;               % PLL bandwidth and damping
P.pll.Kp = 2*P.pll.zeta*P.pll.wn/P.Vpk;
P.pll.Ki = P.pll.wn^2/P.Vpk;
P.pll.Tf = 1/(2*pi*20);                                % frequency measurement filter (s)
P.ctrl.KpI  = 6;    P.ctrl.KiI = 1000;                 % current loop
P.ctrl.KpV  = 0.5;  P.ctrl.KiV = 10;                   % DC-link voltage loop
P.ctrl.Ilim = 1.5*P.Ipk;                               % current reference limit (A)
P.Tc = 1/P.fsw;                                        % current-control sampling period (s)
P.ctrl.mode = 1;                                       % current controller: 1 PI, 2 PID, 3 H-infinity, 4 fuzzy PI
P.ctrl.names = {'PI', 'PID', 'H-infinity', 'Fuzzy PI'};

% ---- Alternative current controllers, all discrete at P.Tc ----
here = fileparts(mfilename('fullpath'));
P.hinf = struct('A', 0, 'B', 0, 'C', 0, 'D', 0);       % placeholders until the designs are run
P.pid  = struct('Kp', P.ctrl.KpI, 'Ki', P.ctrl.KiI, 'Kd', 0, 'N', 1e4);
P.flc  = struct('fis', [], 'Ke', 1, 'Kde', 1, 'Ku', 0);
if exist(fullfile(here, 'hinf_controller.mat'), 'file')        % design_hinf.m
    K = load(fullfile(here, 'hinf_controller.mat'));
    P.hinf = struct('A', K.A, 'B', K.B, 'C', K.C, 'D', K.D);
end
if exist(fullfile(here, 'pid_controller.mat'), 'file')         % design_pid.m
    K = load(fullfile(here, 'pid_controller.mat'));
    P.pid = struct('Kp', K.Kp, 'Ki', K.Ki, 'Kd', K.Kd, 'N', K.N);
end
if exist(fullfile(here, 'flc_controller.mat'), 'file')         % design_flc.m
    K = load(fullfile(here, 'flc_controller.mat'));
    P.flc = struct('fis', K.fis, 'Ke', K.Ke, 'Kde', K.Kde, 'Ku', K.Ku);
end

% ---- Passive protection: baseline islanding detector ----
P.prot.uv = 0.88;  P.prot.ov = 1.10;                   % voltage limits (pu)
P.prot.uf = 49.3;  P.prot.of = 50.5;                   % frequency limits (Hz)
P.prot.rocof  = 2.0;                                   % rate-of-change-of-frequency limit (Hz/s)
P.prot.Trocof = 1e-3;                                  % ROCOF sampling period (s)
P.prot.tBlank = 0.30;                                  % start-up blanking time (s)
P.prot.tArm   = P.prot.tBlank;                         % time the model's protection is armed (set 1e6 to leave it unarmed)

% Relay settings used by detect_islanding.m. Each row: [threshold, clearing time (s)].
% 'fast'  : the model's own passive detector, instantaneous.
% 'ieee'  : IEEE 1547-2018 Category II default trip settings, frequencies
%           scaled from 60 Hz to 50 Hz. These are ride-through compatible.
P.relay.fast.uv = [0.88 0];     P.relay.fast.ov = [1.10 0];
P.relay.fast.uf = [49.3 0];     P.relay.fast.of = [50.5 0];
P.relay.fast.rocof = [2.0 0];
P.relay.ieee.uv = [0.70 10; 0.45 0.16];          % UV1, UV2 (pu, s)
P.relay.ieee.ov = [1.10 2.0; 1.20 0.16];         % OV1, OV2
P.relay.ieee.uf = [58.5 300; 56.5 0.16]*50/60;   % UF1, UF2 (Hz, s)
P.relay.ieee.of = [61.2 300; 62.0 0.16]*50/60;   % OF1, OF2
P.relay.ieee.rocof = [Inf 0];                    % no ROCOF trip by default
P.relay.tMax = 2.0;                              % islanding must be cleared within 2 s (IEEE 1547-2018)

% ---- Active frequency drift (AFD): q-axis current reference ----
% Iq* = on * clamp(bias + K*(f - fg), +/-lim), armed after the start-up blanking.
% In an island the injected reactive current shifts the load's resonance, so
% the frequency drifts further: positive feedback that pushes it out of the
% relay window. Connected to a stiff grid the frequency hardly moves, so the
% injection stays near the small bias.
P.afd.on   = 0;
P.afd.K    = -0.10*P.Ipk;                        % A per Hz; negative sign = positive feedback in an island (afd_sign_test.m)
P.afd.bias = -0.01*P.Ipk;                        % A, breaks the symmetry at exactly 50 Hz
P.afd.lim  = 0.30*P.Ipk;                         % A

% ---- Local load and islanding event (IEEE 1547.1 style RLC load) ----
P.load.Qf = 1.0;                                       % load quality factor
P.load.P  = 20e3;                                      % load active power (W)
P.load.QL = P.load.Qf*P.load.P;                        % inductive reactive power (var)
P.load.QC = P.load.Qf*P.load.P;                        % capacitive reactive power (var)
P.tIsland = 1e6;                                       % grid breaker opening time (s); 1e6 = never
P.island.Pinv = 18570;  P.island.Qinv = 813;          % inverter output at the PCC, SCR 10, grid connected (W, var)

% ---- Second inverter at the PCC (Phase 5 multi-inverter cases) ----
% An averaged constant-power source with ideal current control:
%   i = (P*v - Q*v90)/sum(v.^2), with v90 the voltage lagging by 90 degrees,
%   Q = Q0 + clamp(Kq*(f - fg), +/-Qlim) once armed (after P.prot.tBlank).
% Measured in afd_stress.m: Kq > 0 drifts the same way as the main inverter's
% AFD, Kq < 0 against it; Kq = -2000 var/Hz cancels the main inverter's drift.
P.der2.on   = 0;
P.der2.P    = 10e3;  P.der2.Q = 0;                     % injected power (W, var)
P.der2.Kq   = 0;                                       % var per Hz
P.der2.Qlim = 0.3*P.der2.P;                            % var
P.der2.Ts   = 1e-5;                                    % reference update period (s)
P.der2.tOn  = 0.02;                                    % start time (s)

% ---- Non-islanding disturbances (programmable grid source, switched equipment) ----
% P.event.entity: 'None', 'Amplitude', 'Frequency' or 'Phase'; P.event.type: 'Step',
% 'Ramp' or 'Table of time-amplitude pairs'. run_model sets these on the source.
P.event.entity = 'None';  P.event.type = 'Step';
P.event.amp    = [1 1];   P.event.time = [0 1e6];        % amplitude table (pu, s)
P.event.step   = 0;       P.event.rate = 0;              % step size (Hz or deg), ramp rate (Hz/s)
P.event.timing = [1e6 1e6];                              % start and end of a step or ramp (s)
P.event.loadP  = 0.3*P.Sn;  P.event.loadT = 1e6;         % switched load (W) and closing time (s)
P.event.capQ   = 0.25*P.Sn; P.event.capT  = 1e6;         % switched capacitor bank (var) and closing time (s)

% ---- Design checks ----
P.check.Cf_pct_of_Cb   = 100*P.lcl.Cf/P.Cb;                       % want <= 5
P.check.Ltot_pu        = (P.lcl.L1+P.lcl.L2)/P.Lb;                % want <= 0.1
P.check.fres_in_range  = P.lcl.fres > 10*P.fg && P.lcl.fres < 0.5*P.fsw;
Lg2 = P.lcl.L2 + P.grid.L;
P.check.fres_with_grid = sqrt((P.lcl.L1+Lg2)/(P.lcl.L1*Lg2*P.lcl.Cf))/(2*pi);
end

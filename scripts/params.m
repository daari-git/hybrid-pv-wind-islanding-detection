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
P.pv.T     = 25;           % cell temperature (deg C)
P.pv.Tmppt = 10e-3;        % P&O period (s)
P.pv.dD    = 0.003;        % P&O duty step
P.pv.D0    = 1 - P.pv.Vmp/P.Vdc;   % starting duty
P.pv.Dmin  = 0.45;  P.pv.Dmax = 0.80;

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

% ---- Passive protection: baseline islanding detector ----
P.prot.uv = 0.88;  P.prot.ov = 1.10;                   % voltage limits (pu)
P.prot.uf = 49.3;  P.prot.of = 50.5;                   % frequency limits (Hz)
P.prot.rocof  = 2.0;                                   % rate-of-change-of-frequency limit (Hz/s)
P.prot.Trocof = 1e-3;                                  % ROCOF sampling period (s)
P.prot.tBlank = 0.30;                                  % start-up blanking time (s)

% ---- Local load and islanding event (IEEE 1547.1 style RLC load) ----
P.load.Qf = 1.0;                                       % load quality factor
P.load.P  = 20e3;                                      % load active power (W)
P.load.QL = P.load.Qf*P.load.P;                        % inductive reactive power (var)
P.load.QC = P.load.Qf*P.load.P;                        % capacitive reactive power (var)
P.tIsland = 1e6;                                       % grid breaker opening time (s); 1e6 = never

% ---- Design checks ----
P.check.Cf_pct_of_Cb   = 100*P.lcl.Cf/P.Cb;                       % want <= 5
P.check.Ltot_pu        = (P.lcl.L1+P.lcl.L2)/P.Lb;                % want <= 0.1
P.check.fres_in_range  = P.lcl.fres > 10*P.fg && P.lcl.fres < 0.5*P.fsw;
Lg2 = P.lcl.L2 + P.grid.L;
P.check.fres_with_grid = sqrt((P.lcl.L1+Lg2)/(P.lcl.L1*Lg2*P.lcl.Cf))/(2*pi);
end

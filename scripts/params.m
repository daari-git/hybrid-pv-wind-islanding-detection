function P = params(scr)
% PARAMS  Single source of truth for the hybrid PV-wind test bed.
%   P = PARAMS(SCR) returns every rating, filter value and limit used by the
%   models and scripts. SCR is the grid short-circuit ratio at the point of
%   common coupling (default 10).
if nargin < 1, scr = 10; end

% ---- Ratings ----
P.Sn    = 20e3;            % inverter rating (VA): 10 kW PV + 10 kW wind
P.Vll   = 400;             % grid line-to-line RMS voltage (V)
P.fg    = 50;              % grid frequency (Hz)
P.wg    = 2*pi*P.fg;
P.Vdc   = 800;             % DC-link reference (V)
P.fsw   = 10e3;            % inverter switching frequency (Hz)
P.Ts    = 1e-6;            % simulation step (s)
P.In    = P.Sn/(sqrt(3)*P.Vll);   % rated RMS current (A)
P.Ipk   = sqrt(2)*P.In;           % rated peak current (A)

% ---- Per-unit bases ----
P.Zb = P.Vll^2/P.Sn;
P.Lb = P.Zb/P.wg;
P.Cb = 1/(P.wg*P.Zb);

% ---- PV array: 1Soltech 1STH-215-P, 213.15 W per module ----
P.pv.Nser  = 10;           % Vmp = 10 x 29 V = 290 V
P.pv.Npar  = 5;            % 50 modules = 10.66 kW at STC
P.pv.Pmod  = 213.15;
P.pv.Pstc  = P.pv.Nser*P.pv.Npar*P.pv.Pmod;

% ---- Wind turbine ----
P.wind.R      = 2.7072;    % blade radius (m)
P.wind.rho    = 1.225;     % air density (kg/m^3)
P.wind.CpMax  = 0.48;
P.wind.lamOpt = 8.1;
P.wind.vRated = 12;        % rated wind speed (m/s)
P.wind.Prated = 0.5*P.wind.rho*pi*P.wind.R^2*P.wind.CpMax*P.wind.vRated^3;

% ---- LCL filter ----
P.lcl.ripple = 0.20;                                   % ripple, fraction of rated peak current
P.lcl.L1 = P.Vdc/(6*P.fsw*P.lcl.ripple*P.Ipk);         % inverter-side inductor (H)
P.lcl.L1 = round(P.lcl.L1, 4);
P.lcl.L2 = 0.5*P.lcl.L1;                               % grid-side inductor (H)
P.lcl.Cf = 15e-6;                                      % filter capacitor (F), kept below 5% of Cb
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

% ---- Passive protection limits (per unit / Hz), used as the baseline detector ----
P.prot.uv = 0.88;  P.prot.ov = 1.10;
P.prot.uf = 49.3;  P.prot.of = 50.5;

% ---- Design checks ----
P.check.Cf_pct_of_Cb   = 100*P.lcl.Cf/P.Cb;                       % want <= 5
P.check.Ltot_pu        = (P.lcl.L1+P.lcl.L2)/P.Lb;                % want <= 0.1
P.check.fres_in_range  = P.lcl.fres > 10*P.fg && P.lcl.fres < 0.5*P.fsw;
Lg2 = P.lcl.L2 + P.grid.L;
P.check.fres_with_grid = sqrt((P.lcl.L1+Lg2)/(P.lcl.L1*Lg2*P.lcl.Cf))/(2*pi);
end

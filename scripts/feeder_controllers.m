function T = feeder_controllers(modes)
% FEEDER_CONTROLLERS  The four current controllers on the Pidari 400 V feeder.
%   T = FEEDER_CONTROLLERS(MODES) repeats the Phase 2-3 comparison on the
%   feeder model for controllers MODES (default 1:4: PI, PID, H-infinity,
%   fuzzy PI):
%     margins  gain and phase margin and sensitivity peak of the current loop
%              on the discrete plant (as MARGINS_ALL) with the feeder's
%              short-circuit impedance behind A1, A3 and A5 (the feeder's
%              loads, in parallel, are left out of the plant)
%     runs     each condition of FEEDER_CONDITIONS with a 2 kW household
%              load at the PCC: steady state over 0.5-0.6 s, then an
%              irradiance step to 60 % at 0.6 s (DC-link deviation and
%              settling to within 2 V)
%   Writes results/feeder_margins.csv and results/feeder_controllers.csv.
if nargin < 1 || isempty(modes), modes = 1:4; end
root = fileparts(fileparts(mfilename('fullpath')));
P0 = params(10); Tc = P0.Tc;
K = load(fullfile(root, 'scripts', 'flc_controller.mat'));
C = { pid(P0.ctrl.KpI, P0.ctrl.KiI, 0, 0, Tc, 'IFormula', 'ForwardEuler'), ...
      pid(P0.pid.Kp, P0.pid.Ki, P0.pid.Kd, 1/P0.pid.N, Tc, 'IFormula', 'ForwardEuler', 'DFormula', 'BackwardEuler'), ...
      ss(P0.hinf.A, P0.hinf.B, P0.hinf.C, P0.hinf.D, Tc), ...
      pid(K.Kp_eq, K.Ki_eq, 0, 0, Tc, 'IFormula', 'BackwardEuler') };
M = table();
for bus = [2 4 6]
    P = feeder_params(P0, 0.3, bus);
    Gd = discrete_plant(P);
    for c = modes
        L = C{c}*Gd;
        A = allmargin(L);
        M = [M; table(string(P.feeder.busName{bus}), P.grid.scr, P.grid.xr, string(P0.ctrl.names{c}), ...
            min([20*log10(A.GainMargin(A.GainMargin > 1)), Inf]), min([abs(A.PhaseMargin), Inf]), ...
            norm(feedback(1, L), inf), A.Stable, ...
            'VariableNames', {'bus', 'scr', 'xr', 'controller', 'GM_dB', 'PM_deg', 'Ms', 'stable'})]; %#ok<AGROW>
    end
end
disp(M);
writetable(M, fullfile(root, 'results', 'feeder_margins.csv'));

T = table();
for c = feeder_conditions()
    for mode = modes
        P = feeder_condition_params(c);
        P.ctrl.mode = mode;
        P.load.P = 2000; P.load.QL = 2000*tan(acos(0.95)); P.load.QC = 0;
        P.pv.G1 = 0.6*c.G; P.pv.tStep = 0.6;
        fprintf('\n##### %s, %s\n', c.id, P.ctrl.names{mode});
        S = run_model(1.0, P, '');
        R = signal_metrics(S, 0.5, 0.6);
        v = S.VDC.Data(S.VDC.Time >= 0.6);
        T = [T; table(string(c.id), string(P.ctrl.names{mode}), R.P/1e3, R.Q, R.thd, R.thdV, R.Vrms, ...
            R.fRipple, R.VdcRipple, max(abs(v - P.Vdc)), 1e3*settling(S.VDC, 0.6, P.Vdc, 2), any(S.trip.Data > 0.5), ...
            'VariableNames', {'cond', 'controller', 'P_kW', 'Q_var', 'THDi_pct', 'THDv_pct', 'Vpcc_pu', ...
            'fRipple_Hz', 'VdcRipple_V', 'VdcDev_V', 'VdcSettle_ms', 'tripped'})]; %#ok<AGROW>
    end
end
disp(T);
writetable(T, fullfile(root, 'results', 'feeder_controllers.csv'));
end

function ts = settling(x, t0, ref, band)
% Time after t0 until the 1 ms average of x stays within +/- band of ref (as COMPARE_CONTROLLERS).
t = x.Time; y = movmean(x.Data, max(1, round(1e-3/(t(2) - t(1)))));
k = find(t >= t0 & abs(y - ref) > band, 1, 'last');
if isempty(k), ts = 0; else, ts = t(k) - t0; end
end

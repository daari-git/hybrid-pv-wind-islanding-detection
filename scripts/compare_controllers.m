function T = compare_controllers(modes, tag)
% COMPARE_CONTROLLERS  Run the same test suite with each current controller.
%   T = COMPARE_CONTROLLERS(MODES, TAG) runs controllers MODES (1 PI, 2 PID,
%   3 H-infinity, 4 fuzzy PI; default all four) and writes
%   results/controller_comparison_TAG.csv. Local load almost removed and
%   protection unarmed, so the weak grid carries the full export.
%     hard   start at full power, SCR 20, 10, 5 and 3
%     ramp   start at low power, step irradiance and wind to rated at 0.5 s, SCR 3 and 2
%     step   irradiance step 1000 -> 600 W/m2 at 0.4 s, SCR 5
if nargin < 1 || isempty(modes), modes = 1:4; end
if nargin < 2, tag = 'all'; end
root = fileparts(fileparts(mfilename('fullpath')));
T = table();
for mode = modes
    name = params().ctrl.names{mode};
    for scr = [20 10 5 3]
        P = base(scr, mode);
        fprintf('\n##### %s, hard start, SCR %g\n', name, scr);
        S = get_run(1.2, P, sprintf('cmp_%d_hard_%g', mode, scr));
        T = [T; row(name, 'hard', scr, S, 1.0, 1.2, NaN, NaN)]; %#ok<AGROW>
    end
    for scr = [3 2]
        P = base(scr, mode);
        P.pv.G0 = 200;  P.pv.G1 = 1000; P.pv.tStep = 0.5;
        P.wind.v0 = 6;  P.wind.v1 = 12; P.wind.tStep = 0.5;
        P.wind.wm0 = P.wind.lamOpt*P.wind.v0/P.wind.R;
        fprintf('\n##### %s, ramp, SCR %g\n', name, scr);
        S = get_run(2.5, P, sprintf('cmp_%d_ramp_%g', mode, scr));
        v = S.VDC.Data(S.VDC.Time >= 0.5 & S.VDC.Time <= 1.0);
        T = [T; row(name, 'ramp', scr, S, 2.3, 2.5, max(abs(v - P.Vdc)), NaN)]; %#ok<AGROW>
    end
    P = base(5, mode);
    P.pv.G1 = 600; P.pv.tStep = 0.4;
    fprintf('\n##### %s, irradiance step, SCR 5\n', name);
    S = get_run(0.7, P, sprintf('cmp_%d_step_5', mode));
    v = S.VDC.Data(S.VDC.Time >= 0.4 & S.VDC.Time <= 0.7);
    T = [T; row(name, 'step', 5, S, 0.5, 0.7, max(abs(v - P.Vdc)), settling(S.VDC, 0.4, P.Vdc, 2))]; %#ok<AGROW>
end
disp(T);
writetable(T, fullfile(root, 'results', ['controller_comparison_' tag '.csv']));
end

function P = base(scr, mode)
P = params(scr);
P.ctrl.mode = mode;
P.prot.tBlank = 1e6;
P.load.P = 200; P.load.QL = 200; P.load.QC = 200;
end

function ts = settling(x, t0, ref, band)
% Time after t0 until the 1 ms average of x stays within +/- band of ref.
t = x.Time; y = movmean(x.Data, max(1, round(1e-3/(t(2) - t(1)))));
k = find(t >= t0 & abs(y - ref) > band, 1, 'last');
if isempty(k), ts = 0; else, ts = t(k) - t0; end
end

function r = row(name, test, scr, S, t1, t2, dVdc, tset)
M = signal_metrics(S, t1, t2);
ok = M.Vrms < 1.2 && M.Vdc < 900 && M.thd < 10;      % still synchronised and in control
r = table(string(name), string(test), scr, ok, M.P/1e3, M.thd, M.thdV, M.Vrms, M.fRipple, M.VdcRipple, dVdc, 1e3*tset, ...
    'VariableNames', {'controller','test','scr','stable','P_kW','THDi_pct','THDv_pct','Vpcc_pu','fRipple_Hz', ...
    'VdcRipple_V','VdcDev_V','VdcSettle_ms'});
end

function S = get_run(stopTime, P, tag)
% Reuse a saved run when it was made with the current model and the same test
% settings; otherwise simulate.
root = fileparts(fileparts(mfilename('fullpath')));
f = fullfile(root, 'results', [tag '.mat']);
if exist(f, 'file')
    d = dir(f); m = dir(fullfile(root, 'hybrid_pv_wind_islanding.slx'));
    S = load(f);
    key = @(Q) [Q.ctrl.mode Q.grid.scr Q.pv.G0 Q.pv.G1 Q.pv.tStep Q.wind.v0 Q.wind.v1 Q.wind.tStep Q.load.P Q.prot.tBlank];
    if d.datenum > m.datenum && isfield(S, 'P') && isequal(key(S.P), key(P)) && S.Igrid.Time(end) >= stopTime - 1e-6
        fprintf('Reusing saved run %s\n', tag);
        return
    end
end
S = run_model(stopTime, P, tag);
end

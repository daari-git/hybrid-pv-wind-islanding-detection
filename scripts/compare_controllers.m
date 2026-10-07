function T = compare_controllers()
% COMPARE_CONTROLLERS  Phase 3: PI against H-infinity current control in simulation.
%   Local load almost removed and protection unarmed, so the weak grid carries
%   the full export. Three tests per controller:
%     hard   start at full power, SCR 20, 10, 5 and 3
%     ramp   start at low power, step irradiance and wind to rated at 0.5 s, SCR 3 and 2
root = fileparts(fileparts(mfilename('fullpath')));
names = {'PI', 'Hinf'};
T = table();
for c = 1:2
    for scr = [20 10 5 3]
        P = base(scr, c - 1);
        fprintf('\n##### %s, hard start, SCR %g\n', names{c}, scr);
        S = run_model(1.2, P, sprintf('cmp_%s_hard_%g', names{c}, scr));
        T = [T; row(names{c}, 'hard', scr, S, 1.0, 1.2, NaN)]; %#ok<AGROW>
    end
    for scr = [3 2]
        P = base(scr, c - 1);
        P.pv.G0 = 200;  P.pv.G1 = 1000; P.pv.tStep = 0.5;
        P.wind.v0 = 6;  P.wind.v1 = 12; P.wind.tStep = 0.5;
        P.wind.wm0 = P.wind.lamOpt*P.wind.v0/P.wind.R;
        fprintf('\n##### %s, ramp, SCR %g\n', names{c}, scr);
        S = run_model(2.5, P, sprintf('cmp_%s_ramp_%g', names{c}, scr));
        v = S.VDC.Data(S.VDC.Time >= 0.5 & S.VDC.Time <= 1.0);
        T = [T; row(names{c}, 'ramp', scr, S, 2.3, 2.5, max(abs(v - P.Vdc)))]; %#ok<AGROW>
    end
end
disp(T);
writetable(T, fullfile(root, 'results', 'controller_comparison.csv'));
end

function P = base(scr, useHinf)
P = params(scr);
P.ctrl.useHinf = useHinf;
P.prot.tBlank = 1e6;
P.load.P = 200; P.load.QL = 200; P.load.QC = 200;
end

function r = row(name, test, scr, S, t1, t2, dVdc)
M = signal_metrics(S, t1, t2);
ok = M.Vrms < 1.2 && M.Vdc < 900 && M.thd < 10;      % still synchronised and in control
r = table(string(name), string(test), scr, ok, M.P/1e3, M.thd, M.thdV, M.Vrms, M.fRipple, M.VdcRipple, dVdc, ...
    'VariableNames', {'controller','test','scr','stable','P_kW','THDi_pct','THDv_pct','Vpcc_pu','fRipple_Hz','VdcRipple_V','VdcStepDev_V'});
end

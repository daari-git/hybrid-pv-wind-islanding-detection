function T = operating_points()
% OPERATING_POINTS  Phase 5: grid-connected steady state of every operating condition.
%   Runs each condition of OPERATING_CONDITIONS up to its event time with a
%   negligible local load and measures the inverter's output at the PCC over
%   the last 0.1 s. Islanding loads are sized from these values. Writes
%   results/operating_points.csv. SCR 2 at full power is added for the
%   weak-grid tests of active frequency drift (AFD_STRESS).
root = fileparts(fileparts(mfilename('fullpath')));
C = operating_conditions();
C(end+1) = struct('id', 'scr2_full', 'scr', 2, 'mix', 'full', 'G', 1000, 'v', 12, 'tEvent', 0.8);   % for the weak-grid AFD tests
T = table();
for k = 1:numel(C)
    P = condition_params(C(k));
    P.load.P = 200; P.load.QL = 200; P.load.QC = 200;
    fprintf('\n##### %s\n', C(k).id);
    S = run_model(C(k).tEvent, P, '');
    t2 = C(k).tEvent; M = signal_metrics(S, t2 - 0.1, t2);
    v = S.VDC.Data(S.VDC.Time > t2 - 0.1);
    T = [T; table(string(C(k).id), C(k).scr, string(C(k).mix), C(k).G, C(k).v, round(M.P), round(M.Q), ...
        M.Vrms, M.thd, M.thdV, M.Vdc, max(abs(v - P.Vdc)), M.fRipple, ...
        'VariableNames', {'id','scr','mix','G','v','Pinv_W','Qinv_var','Vpcc_pu','THDi_pct','THDv_pct', ...
        'Vdc_V','VdcDev_V','fRipple_Hz'})]; %#ok<AGROW>
end
disp(T);
writetable(T, fullfile(root, 'results', 'operating_points.csv'));
end

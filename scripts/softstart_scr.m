function T = softstart_scr(scrs, stopTime)
% SOFTSTART_SCR  Phase 2: weak-grid test with power ramped up after start.
%   Starts at low irradiance and wind, then steps both to rated at 0.5 s, so
%   a failure reflects the operating point and not the start-up transient.
%   The local load is almost removed and the protection is left unarmed.
if nargin < 1 || isempty(scrs), scrs = [3 2]; end
if nargin < 2, stopTime = 2.5; end
root = fileparts(fileparts(mfilename('fullpath')));
T = table();
for scr = scrs
    P = params(scr);
    P.prot.tBlank = 1e6;
    P.load.P = 200; P.load.QL = 200; P.load.QC = 200;
    P.pv.G0 = 200;  P.pv.G1 = 1000; P.pv.tStep = 0.5;
    P.wind.v0 = 6;  P.wind.v1 = 12; P.wind.tStep = 0.5;
    P.wind.wm0 = P.wind.lamOpt*P.wind.v0/P.wind.R;
    fprintf('\n##### SCR = %g, soft start\n', scr);
    S = run_model(stopTime, P, sprintf('softstart_%g', scr));
    for w = [0.3 0.5; stopTime-0.2 stopTime]'
        M = signal_metrics(S, w(1), w(2));
        T = [T; table(scr, w(1), M.P/1e3, M.thd, M.thdV, M.Vrms, M.Vdc, M.fRipple, M.Ipk/P.Ipk, ...
            'VariableNames', {'scr','from_s','P_kW','THDi_pct','THDv_pct','Vpcc_pu','Vdc_V','fRipple_Hz','Ipk_pu'})]; %#ok<AGROW>
    end
end
disp(T);
writetable(T, fullfile(root, 'results', 'softstart_scr.csv'));
end

function T = sweep_scr(scrs, stopTime, loadP, tag)
% SWEEP_SCR  Phase 2: run the PI baseline at several grid strengths.
%   The protection is left unarmed so an unstable case shows itself instead
%   of being cut off by a trip.
if nargin < 1 || isempty(scrs), scrs = [20 10 5 3 2]; end
if nargin < 2 || isempty(stopTime), stopTime = 1.2; end
if nargin < 3, loadP = []; end          % local load (W); empty keeps the default
if nargin < 4, tag = 'scr_sweep'; end
root = fileparts(fileparts(mfilename('fullpath')));
T = table();
for scr = scrs
    P = params(scr);
    P.prot.tBlank = 1e6;
    if ~isempty(loadP), P.load.P = loadP; P.load.QL = loadP; P.load.QC = loadP; end
    fprintf('\n##### SCR = %g  (Rg = %.3f ohm, Lg = %.2f mH)\n', scr, P.grid.R, 1e3*P.grid.L);
    S = run_model(stopTime, P, sprintf('%s_%g', tag, scr));
    M = signal_metrics(S, stopTime - 0.2, stopTime);
    T = [T; table(scr, M.P/1e3, M.I1, M.thd, M.thdV, M.Vrms, M.Vdc, M.VdcRipple, M.fRipple, M.Ipk/P.Ipk, ...
        'VariableNames', {'scr','P_kW','I1_A','THDi_pct','THDv_pct','Vpcc_pu','Vdc_V','VdcRipple_V','fRipple_Hz','Ipk_pu'})]; %#ok<AGROW>
end
disp(T);
writetable(T, fullfile(root, 'results', [tag '.csv']));
end

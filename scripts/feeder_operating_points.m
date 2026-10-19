function feeder_operating_points(C)
% FEEDER_OPERATING_POINTS  Grid-connected flows of feeder conditions, for sizing islanding loads.
%   FEEDER_OPERATING_POINTS(C) runs every condition of C (FEEDER_CONDITIONS or
%   FEEDER_TRAIN_CONDITIONS) that is not yet in
%   results/feeder_operating_points.csv twice with a negligible local load:
%   with the unit alone and with the other generation at B3 on. It records
%   the unit's output and PCC voltage and the power drawn through the
%   transformer (FEEDER_CONDITION_PARAMS reads them back). A condition with
%   DER2P = NaN gets other generation that brings the feeder's generation to
%   1.3 times its consumption, rounded up to 1 kW.
root = fileparts(fileparts(mfilename('fullpath')));
f = fullfile(root, 'results', 'feeder_operating_points.csv');
if exist(f, 'file'), T = readtable(f, 'TextType', 'string'); else, T = table(); end
for c = C
    if ~isempty(T) && any(T.id == c.id), continue; end
    m = zeros(2, 7);
    der2P = c.der2P;
    for d2 = 0:1
        P = feeder_condition_params(c);
        P.load.P = 200; P.load.QL = 200; P.load.QC = 200;
        P.der2.on = d2; P.der2.P = max(der2P, 0); P.der2.Qlim = 0.3*P.der2.P;   % max: 0 while still unsized (NaN)
        fprintf('\n##### operating point %s, other generation %s\n', c.id, string(d2 == 1));
        S = run_model(c.tEvent, P, '');
        M = signal_metrics(true_current(S), c.tEvent - 0.1, c.tEvent);
        D = S; D.Vabc = S.Vdt; D.Igrid = S.Idt;
        Md = signal_metrics(D, c.tEvent - 0.1, c.tEvent);
        m(d2 + 1, :) = [M.P M.Q M.Vrms M.thd -Md.P -Md.Q ...
            mean(sqrt(mean(S.Vder2.Data(S.Vder2.Time > c.tEvent - 0.1, :).^2, 2)))*sqrt(3)/P.Vll];
        if d2 == 0 && isnan(der2P)                           % consumption = unit's output + import
            der2P = max(2e3, ceil((1.3*(M.P - Md.P) - M.P)/1e3)*1e3);
        end
    end
    T = [T; table(string(c.id), c.load, c.pcc, c.G, c.v, round(m(1,1)), round(m(1,2)), m(1,3), m(1,4), ...
        round(m(1,5)), round(m(1,6)), der2P, round(m(2,5)), round(m(2,6)), m(2,3), m(2,7), ...
        'VariableNames', {'id', 'load', 'pcc', 'G', 'v', 'Pinv_W', 'Qinv_var', 'Vpcc_pu', 'THDi_pct', ...
        'Pdt_W', 'Qdt_var', 'der2P_W', 'Pdt2_W', 'Qdt2_var', 'Vpcc2_pu', 'Vb3_2_pu'})]; %#ok<AGROW>
    writetable(T, f);
end
end

function S = true_current(S)
S.Igrid = S.Igrid_true;
end

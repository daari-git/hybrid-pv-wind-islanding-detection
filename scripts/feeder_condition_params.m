function P = feeder_condition_params(c)
% FEEDER_CONDITION_PARAMS  Parameter struct for one condition of FEEDER_CONDITIONS.
%   Irradiance, wind and background distortion as CONDITION_PARAMS, the
%   feeder at the condition's loading with the unit at its bus, and the
%   grid-connected flows used to size islanding loads (P.island, from
%   results/feeder_operating_points.csv once FEEDER_CLOSED_LOOP has measured
%   them): the unit's output at its PCC (Pinv, Qinv) and the power drawn
%   through the transformer with a negligible local load, with the unit
%   alone (Pdt, Qdt) and with the other generation on (Pdt2, Qdt2).
P = condition_params(c);
P = feeder_params(P, c.load, c.pcc);
P = feeder_der2(P, 9);                                 % other generation lumped at B3
P.der2.P = c.der2P;  P.der2.Qlim = 0.3*P.der2.P;
f = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'results', 'feeder_operating_points.csv');
if exist(f, 'file')
    T = readtable(f, 'TextType', 'string');
    r = T(T.id == c.id, :);
    if height(r) == 1
        P.island.Pinv = r.Pinv_W;  P.island.Qinv = r.Qinv_var;
        P.island.Pdt = r.Pdt_W;  P.island.Qdt = r.Qdt_var;  P.island.Vpcc = r.Vpcc_pu;
        P.island.Pdt2 = r.Pdt2_W;  P.island.Qdt2 = r.Qdt2_var;  P.island.Vpcc2 = r.Vpcc2_pu;
        if isnan(c.der2P), P.der2.P = r.der2P_W; P.der2.Qlim = 0.3*P.der2.P; end   % sized by FEEDER_OPERATING_POINTS
    end
end
end

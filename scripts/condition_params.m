function P = condition_params(c)
% CONDITION_PARAMS  Parameter struct for one operating condition (see OPERATING_CONDITIONS).
%   Sets the grid strength, irradiance and wind speed, the weak-grid start,
%   and the inverter output used to size islanding loads (P.island.Pinv and
%   Qinv, from results/operating_points.csv once OPERATING_POINTS has run).
%   The model's own protection is left unarmed; detectors are evaluated offline.
P = params(c.scr);
P.pv.G0 = c.G;  P.pv.G1 = c.G;
P.wind.v0 = c.v;  P.wind.v1 = c.v;  P.wind.wm0 = P.wind.lamOpt*c.v/P.wind.R;
if c.scr < 5, P.pv.Gstart = 200; P.pv.tStart = 0.3; end
P.prot.tArm = 1e6;
if isfield(c, 'harm') && c.harm                         % background grid distortion (TEST_CONDITIONS)
    P.grid.harmA = [5 0.02 0 2]; P.grid.harmB = [7 0.015 0 1];
end
for f = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'results', {'operating_points.csv', 'operating_points_test.csv'})
    if ~exist(f{1}, 'file'), continue; end
    T = readtable(f{1}, 'TextType', 'string');
    r = T(T.id == c.id, :);
    if height(r) == 1, P.island.Pinv = r.Pinv_W; P.island.Qinv = r.Qinv_var; end
end
end

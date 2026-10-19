function T = feeder_screening(Pdg)
% FEEDER_SCREENING  Where on the Pidari 400 V feeder to connect the PV-wind unit.
%   T = FEEDER_SCREENING(Pdg) screens every bus of the feeder of
%   NEA_LV_FEEDER_DATA (Real_model/) as the connection point of a unit that
%   exports Pdg watts at unity power factor (default 20e3, the inverter
%   rating). For each bus it gives the grid strength seen by the unit
%   (short-circuit level, SCR on the inverter rating, X/R), the voltage with
%   and without the unit at light load and at the recorded peak, the change
%   in feeder losses, and the hosting capacity: the largest export that keeps
%   every bus at or below 1.05 pu at light load and every line, and the
%   transformer, within rating (FEEDER_LOADFLOW). It then prints the
%   operating window: the voltage at the ends of the two distributors against
%   loading, without and with the unit at the feeder's PCC.
if nargin < 1, Pdg = 20e3; end
root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root, 'Real_model'));
light = 0.3;        % daytime minimum as a fraction of the recorded peak [ASSUMED]
Vmax = 1.05;        % upper voltage limit (pu), ANSI C84.1 range A
P = params();

mL = nea_lv_feeder_data(light);
mP = nea_lv_feeder_data(1);
nb = numel(mL.busName);
rL0 = feeder_loadflow(mL);  rP0 = feeder_loadflow(mP);
row = cell(nb, 1);
for b = 1:nb
    zp = rL0.zth(b);
    rL = feeder_loadflow(mL, Pdg, b);  rP = feeder_loadflow(mP, Pdg, b);
    hc = fzero(@(x) margin(mL, mP, x, b, Vmax), [0 500e3]);   % margin falls through zero
    row{b} = {mL.busName{b}, P.Vll^2/abs(zp)/1e3, P.Vll^2/abs(zp)/P.Sn, imag(zp)/real(zp), ...
              rL0.Vpu(b), rL.Vpu(b), max(rL.Vpu), rP0.Vpu(b), rP.Vpu(b), ...
              rL.loss - rL0.loss, rP.loss - rP0.loss, hc/1e3, limitName(mL, mP, hc, b, Vmax)};
end
T = cell2table(vertcat(row{:}), 'VariableNames', {'Bus', 'Ssc_kVA', 'SCR', 'XR', ...
    'Vlight_noDG', 'Vlight_DG', 'VmaxFeeder_light_DG', 'Vpeak_noDG', 'Vpeak_DG', ...
    'dLoss_light_kW', 'dLoss_peak_kW', 'Hosting_kW', 'Limit'});
T.Ssc_kVA = round(T.Ssc_kVA);
fprintf('\n%s; unit %.0f kW at unity power factor\n', mL.title, Pdg/1e3);
fprintf('Light load %.0f %% of peak (%.1f kW on the transformer), peak %.1f kW\n', ...
        100*light, real(mL.Sdt)/1e3, real(mP.Sdt)/1e3);
disp(T)
writetable(T, fullfile(root, 'results', 'feeder_screening.csv'));

% Operating window (IEEE 1547-2018 lets a DER enter service only between
% 0.917 and 1.05 pu)
fprintf('\nLoading  Source   DT bus   %s: no unit / unit   B3: no unit / unit\n', mL.busName{mL.pccBus});
W = zeros(0, 7);
for s = 0.2:0.1:1
    m = nea_lv_feeder_data(s);
    r0 = feeder_loadflow(m);  r1 = feeder_loadflow(m, Pdg, m.pccBus);
    W(end+1, :) = [s m.Vsource r0.Vpu(1) r0.Vpu(m.pccBus) r1.Vpu(m.pccBus) r0.Vpu(end) r1.Vpu(end)]; %#ok<AGROW>
    fprintf('%5.0f %%  %6.3f   %6.3f      %6.3f / %6.3f          %6.3f / %6.3f\n', 100*W(end, 1), W(end, 2:end));
end
writetable(array2table(W, 'VariableNames', {'loadScale', 'Vsource', 'Vdt', 'Vpcc_noDG', 'Vpcc_DG', 'Vb3_noDG', 'Vb3_DG'}), ...
           fullfile(root, 'results', 'feeder_operating_window.csv'));
end

% -------------------------------------------------------------------------
function m = margin(mL, mP, x, b, Vmax)
% Smallest headroom over voltage at light load and line and transformer
% loading at both load levels; negative once a limit is broken.
rL = feeder_loadflow(mL, x, b);  rP = feeder_loadflow(mP, x, b);
m = min([Vmax - max(rL.Vpu), 1 - max([rL.load; rP.load])]);
end

function s = limitName(mL, mP, x, b, Vmax)
x = 1.001*x;
rL = feeder_loadflow(mL, x, b);  rP = feeder_loadflow(mP, x, b);
if max(rL.Vpu) > Vmax
    [~, k] = max(rL.Vpu); s = sprintf('voltage at %s', mL.busName{k});
else
    [~, k] = max(max(rL.load, rP.load));
    if k > size(mL.line, 1), s = 'transformer rating';
    else, s = sprintf('line %s-%s rating', mL.busName{mL.line(k,1)}, mL.busName{mL.line(k,2)}); end
end
end

% EXPORT_FEEDER_DATA  Feeder data behind the paper's feeder figures, as CSV in paper/figdata.
%   feeder11.csv   the Pidari 11 kV feeder (NEA_FEEDER_DATA('rural')): every
%                  bus with its parent, section length and conductor, installed
%                  transformer kVA, and load-flow voltage at the recorded peak
%                  and at 30 % of it
%   feeder_lv.csv  the 400 V feeder of the 100 kVA transformer at Khajuri
%                  Chanha (NEA_LV_FEEDER_DATA): every pole with its parent,
%                  span, conductor, load at 30 %, and voltage at 30 % without
%                  and with the 20 kW unit at A5 (FEEDER_LOADFLOW)
% Run from the repository root: matlab -batch "run('paper/export_feeder_data.m')"
root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root, 'scripts'), fullfile(root, 'Real_model'));
out = fullfile(root, 'paper', 'figdata');

m = nea_feeder_data('rural');
r1 = nea_loadflow(m); r3 = nea_loadflow(m, struct('loadScale', 0.3));
nb = numel(m.busKV);
parent = zeros(nb, 1); len = zeros(nb, 1); cond = strings(nb, 1);
for k = 1:size(m.line, 1)
    b = m.line(k, 2); parent(b) = m.line(k, 1); len(b) = m.line(k, 3); cond(b) = m.cond(m.line(k, 4)).name;
end
parent(2) = 1; cond(2) = "33/11 kV transformer";
T = table((1:nb)', string(m.busName(:)), m.busKV(:), parent, len, cond, m.dtKVA(:), r1.Vpu(:), r3.Vpu(:), ...
    'VariableNames', {'bus', 'name', 'kV', 'parent', 'km', 'conductor', 'dtKVA', 'V_peak', 'V_30'});
writetable(T, fullfile(out, 'feeder11.csv'));

lv = nea_lv_feeder_data(0.3);
a = feeder_loadflow(lv); b = feeder_loadflow(lv, 20e3, lv.pccBus);
nb = numel(lv.busName);
parent = zeros(nb, 1); len = zeros(nb, 1); cond = strings(nb, 1);
for k = 1:size(lv.line, 1)
    j = lv.line(k, 2); parent(j) = lv.line(k, 1); len(j) = 1e3*lv.line(k, 3); cond(j) = lv.cond(lv.line(k, 4)).name;
end
T = table((1:nb)', string(lv.busName(:)), parent, len, cond, real(lv.Sload(:))/1e3, a.Vpu(:), b.Vpu(:), ...
    'VariableNames', {'bus', 'name', 'parent', 'm', 'conductor', 'P30_kW', 'V30', 'V30_unit'});
writetable(T, fullfile(out, 'feeder_lv.csv'));
fprintf('Source behind the LV bus: %.4f%+.4fj ohm (11 kV part %.4f%+.4fj, transformer %.4f%+.4fj)\n', ...
    real(lv.Zsrc), imag(lv.Zsrc), real(lv.Zsrc11), imag(lv.Zsrc11), real(lv.Zdt), imag(lv.Zdt));
fprintf('11 kV at Khajuri Chanha: %.3f pu at peak, %.3f pu at 30 %%; feeder head %.0f A\n', ...
    r1.Vpu(18), r3.Vpu(18), r1.feederHeadAmp);

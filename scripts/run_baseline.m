function run_baseline(stopTime)
% RUN_BASELINE  Simulate the unmodified hybrid PV-wind model and record
% reference metrics. The model is changed in memory only and is not saved.
if nargin < 1, stopTime = 1.0; end
root = fileparts(fileparts(mfilename('fullpath')));
mdl  = 'pv_and_wind_completed';
load_system(fullfile(root, 'MATLAB_R2018a', [mdl '.slx']));
c = onCleanup(@() close_system(mdl, 0));

tags = {'Vabc','Iabc','VDC','ID','IQ','wt','freq','Vpcc_rms','VPV','IPV'};
for k = 1:numel(tags)
    f = sprintf('%s/log_from_%s', mdl, tags{k});
    w = sprintf('%s/log_tw_%s',   mdl, tags{k});
    add_block('simulink/Signal Routing/From', f, 'GotoTag', tags{k}, ...
        'Position', [3000 100*k 3040 100*k+20]);
    add_block('simulink/Sinks/To Workspace', w, 'VariableName', ['log_' tags{k}], ...
        'SaveFormat', 'Timeseries', 'Decimation', '10', ...
        'Position', [3100 100*k 3180 100*k+20]);
    add_line(mdl, ['log_from_' tags{k} '/1'], ['log_tw_' tags{k} '/1']);
end
add_block('simulink/Sinks/To Workspace', [mdl '/log_tw_trip'], 'VariableName', 'log_trip', ...
    'SaveFormat', 'Timeseries', 'Decimation', '10', 'Position', [3100 1200 3180 1220]);
add_line(mdl, 'Passive Anti-Islanding Protection/1', 'log_tw_trip/1');

t0  = tic;
out = sim(mdl, 'StopTime', num2str(stopTime), 'ReturnWorkspaceOutputs', 'on');
fprintf('Simulated %.2f s in %.0f s of wall time\n', stopTime, toc(t0));

S = struct();
for k = 1:numel(tags), S.(tags{k}) = out.get(['log_' tags{k}]); end
S.trip = out.get('log_trip');
if ~exist(fullfile(root,'results'),'dir'), mkdir(fullfile(root,'results')); end
save(fullfile(root, 'results', 'baseline.mat'), '-struct', 'S');

% ---- metrics over the last 10 fundamental cycles ----
f1 = 50; T = 10/f1;
t  = S.Iabc.Time; win = t >= t(end) - T;
ia = S.Iabc.Data(win,1); va = S.Vabc.Data(win,1);
[thdI, I1, h] = harmonics(ia, t(win), f1, 50);
fprintf('\n--- Baseline, last 10 cycles ---\n');
fprintf('Grid current fundamental (peak) : %.2f A\n', I1);
fprintf('Grid current THD (to 50th)      : %.2f %%\n', thdI);
fprintf('Harmonics 2..7 (%% of fund.)     : %s\n', mat2str(round(h(2:7),2)));
v = S.Vabc.Data(win,:); i = S.Iabc.Data(win,:);
P = mean(sum(v.*i,2));
fprintf('Mean active power at PCC        : %.2f kW\n', P/1e3);
fprintf('Phase voltage peak              : %.1f V\n', max(abs(va)));
vdc = S.VDC.Data; tv = S.VDC.Time;
fprintf('DC link: peak %.0f V, final mean %.0f V, final ripple %.1f V p-p\n', ...
    max(vdc), mean(vdc(tv>=tv(end)-T)), range(vdc(tv>=tv(end)-T)));
fr = S.freq.Data; tf = S.freq.Time;
fprintf('"freq" signal: at 0.1 s = %.1f, at end = %.1f (should be ~50)\n', ...
    interp1(tf, fr, 0.1), fr(end));
tr = double(S.trip.Data(:)); tt = S.trip.Time;
if any(tr > 0.5), fprintf('Anti-islanding trip asserted at t = %.4f s\n', tt(find(tr>0.5,1)));
else, fprintf('Anti-islanding trip never asserted\n'); end
fprintf('Vpcc_rms (pu) at end: %.3f\n', S.Vpcc_rms.Data(end));
fprintf('PV: V = %.0f V, I = %.1f A, P = %.2f kW at end\n', S.VPV.Data(end), S.IPV.Data(end), ...
    S.VPV.Data(end)*S.IPV.Data(end)/1e3);
end

function [thd, A1, hpct] = harmonics(x, t, f1, nmax)
% Fourier coefficients by direct projection over an integer number of cycles.
x = x(:); t = t(:) - t(1);
A = zeros(nmax,1);
for n = 1:nmax
    a = 2*mean(x.*cos(2*pi*n*f1*t)); b = 2*mean(x.*sin(2*pi*n*f1*t));
    A(n) = hypot(a,b);
end
A1 = A(1); hpct = 100*A/A1; thd = 100*sqrt(sum(A(2:end).^2))/A1;
end

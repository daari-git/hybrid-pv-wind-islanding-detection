function S = run_model(stopTime, P, tag)
% RUN_MODEL  Simulate hybrid_pv_wind_islanding and report key metrics.
%   S = RUN_MODEL(STOPTIME, P, TAG) runs the model for STOPTIME seconds with
%   the parameter struct P (default PARAMS()) and saves the logged signals to
%   results/TAG.mat. The model file itself is not changed.
if nargin < 1 || isempty(stopTime), stopTime = 1.0; end
if nargin < 2 || isempty(P), P = params(); end
if nargin < 3, tag = 'run'; end
root = fileparts(fileparts(mfilename('fullpath')));
mdl  = 'hybrid_pv_wind_islanding';
load_system(fullfile(root, [mdl '.slx']));

in = Simulink.SimulationInput(mdl);
in = in.setVariable('P', P, 'Workspace', mdl);
in = in.setModelParameter('StopTime', num2str(stopTime));
sc = [find_system(mdl, 'BlockType', 'Scope'); find_system(mdl, 'BlockType', 'Display')];
for k = 1:numel(sc), in = in.setBlockParameter(sc{k}, 'Commented', 'on'); end   % scopes off for this run only
t0 = tic; out = sim(in);
fprintf('Simulated %.2f s in %.0f s of wall time\n', stopTime, toc(t0));

tags = {'Vabc','Igrid','Iabc','VDC','ID','IQ','freq','Vpcc_rms','VPV','IPV','trip','wm_wind'};
S = struct('P', P);
for k = 1:numel(tags), S.(tags{k}) = out.get(['log_' tags{k}]); end
if ~exist(fullfile(root, 'results'), 'dir'), mkdir(fullfile(root, 'results')); end
save(fullfile(root, 'results', [tag '.mat']), '-struct', 'S');
report(S);
end

function report(S)
P = S.P; f1 = P.fg; T = 10/f1;
t = S.Igrid.Time; tend = t(end);
ts = unique(min(tend, [0.05 0.1 0.2 0.3 0.4 0.5 0.75 1.0 1.5 2.0 tend]));
at = @(x) interp1(x.Time, double(x.Data(:,1)), ts);
p  = -sum(S.Vabc.Data .* S.Igrid.Data, 2);   % positive = exported by the inverter
w  = max(1, round((1/f1)/(t(2)-t(1))));
pm = movmean(p, [w-1 0]);
row = @(n, v, fmt) fprintf('%-9s %s\n', n, sprintf(fmt, v));
fprintf('\n'); row('t (s)', ts, '%8.2f');
row('P (kW)',   interp1(t, pm, ts)/1e3, '%8.2f');
row('Vdc (V)',  at(S.VDC), '%8.1f');
row('Vpv (V)',  at(S.VPV), '%8.1f');
row('Ppv (kW)', at(S.VPV).*at(S.IPV)/1e3, '%8.2f');
row('wm (r/s)', at(S.wm_wind), '%8.2f');
row('f (Hz)',   at(S.freq), '%8.3f');
row('V (pu)',   at(S.Vpcc_rms), '%8.3f');
row('Id (A)',   at(S.ID), '%8.1f');
row('Iq (A)',   at(S.IQ), '%8.1f');
row('trip',     at(S.trip), '%8.0f');

M = signal_metrics(S, tend - T, tend + 1e-9);
fprintf('\nLast 10 cycles: grid current %.2f A peak, THD %.2f %% (to 50th)\n', M.I1, M.thd);
fprintf('Harmonics 2..7 (%% of fundamental): %s\n', mat2str(round(M.h2to7, 2)));
fprintf('DC link: peak %.0f V over the run, final mean %.1f V, ripple %.1f V p-p\n', ...
    max(S.VDC.Data), M.Vdc, M.VdcRipple);
tr = double(S.trip.Data(:));
if any(tr > 0.5), fprintf('Protection tripped at t = %.4f s\n', S.trip.Time(find(tr > 0.5, 1)));
else, fprintf('Protection did not trip\n'); end
end

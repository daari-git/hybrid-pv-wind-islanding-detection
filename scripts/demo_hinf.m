function demo_hinf(showModel)
% DEMO_HINF  Walk through the H-infinity current controller, start to finish.
%   Run from the project folder:
%       addpath scripts
%       demo_hinf
%   Step 1 opens the model where the controller sits.
%   Step 2 prints the controller and its stability margins against PI.
%   Step 3 runs the same disturbance with each controller and plots both.
%   DEMO_HINF(false) skips opening the model (used for unattended runs).
if nargin < 1, showModel = true; end
root = fileparts(fileparts(mfilename('fullpath')));
mdl  = 'hybrid_pv_wind_islanding';

%% Step 1: where the controller is in the model
if showModel
    open_system(fullfile(root, [mdl '.slx']));
    open_system([mdl '/Inverter Control Logic']);
    open_system([mdl '/Inverter Control Logic/Current controller d']);
    hilite_system([mdl '/Inverter Control Logic/Current controller d/H-infinity']);
    fprintf('Step 1: the model is open at "Current controller d". The orange block is the\n');
    fprintf('        H-infinity controller; the selector picks PI, PID, H-infinity or fuzzy PI.\n\n');
end

%% Step 2: the controller and its margins
K  = load(fullfile(root, 'scripts', 'hinf_controller.mat'));
P0 = params(10); s = tf('s');
Kd = ss(K.A, K.B, K.C, K.D, K.Tc);
fprintf('Step 2: structured H-infinity controller, order %d, sampled at %g kHz\n', K.order, 1e-3/K.Tc);
fprintf('        tuned values: Kp = %.2f, Ki = %.0f, second-order section at %.0f Hz, low-pass at %.0f Hz\n', ...
    K.tuned.Kp, K.tuned.Ki, K.tuned.fn_Hz, K.tuned.fp_Hz);
fprintf('        design weights: sensitivity peak <= %.1f, bandwidth %.0f Hz\n\n', K.weights.Ms, K.weights.wb/(2*pi));
[n, d] = pade(1.5*P0.Tc, 2); D = tf(n, d); Kc = d2c(Kd, 'tustin');
fprintf('%5s | %-26s | %-26s\n', 'SCR', 'PI: GM (dB), PM (deg), Ms', 'H-inf: GM (dB), PM (deg), Ms');
for scr = [20 10 5 3 2]
    P = params(scr); G = plant_model(P)*D;
    a = marg((P.ctrl.KpI + P.ctrl.KiI/s)*G); b = marg(Kc*G);
    fprintf('%5g | %8.1f %8.0f %7.2f | %8.1f %8.0f %7.2f\n', scr, a(1), a(2), a(3), b(1), b(2), b(3));
end

%% Step 3: same disturbance, both controllers
fprintf('\nStep 3: irradiance step 1000 -> 600 W/m2 at 0.4 s, SCR 5, no local load. Two runs, about a minute each.\n');
names = {'PI', 'H-infinity'}; S = cell(1, 2); thd = zeros(1, 2);
for c = 1:2
    P = params(5);
    P.ctrl.mode = 2*c - 1;                                 % 1 = PI, 3 = H-infinity
    P.prot.tBlank = 1e6;                                   % protection unarmed for this test
    P.load.P = 200; P.load.QL = 200; P.load.QC = 200;
    P.pv.G1 = 600; P.pv.tStep = 0.4;
    S{c} = run_model(0.7, P, sprintf('demo_%d', c));
    M = signal_metrics(S{c}, 0.5, 0.7); thd(c) = M.thd;
end
col = [0 114 178; 213 94 0]/255; sty = {'-', '--'};
fig = figure('Color', 'w', 'Position', [100 100 900 620], 'Visible', onoff(showModel));
tl = tiledlayout(fig, 2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
sig = {'ID', 'd-axis current (A), 1 ms moving average, negative = exporting'; 'VDC', 'DC-link voltage (V)'};
for k = 1:2
    ax = nexttile(tl); hold(ax, 'on');
    for c = 1:2
        x = S{c}.(sig{k,1});
        yv = x.Data;
        if k == 1, yv = movmean(yv, round(1e-3/(x.Time(2) - x.Time(1)))); end   % hide switching ripple
        plot(ax, 1e3*x.Time, yv, sty{c}, 'Color', col(c,:), 'LineWidth', 1.3, ...
            'DisplayName', sprintf('%s (current THD %.2f%%)', names{c}, thd(c)));
    end
    xline(ax, 400, ':', 'Color', [0.4 0.4 0.4], 'HandleVisibility', 'off');
    xlim(ax, [350 650]);
    title(ax, sig{k,2}, 'FontWeight', 'normal', 'FontSize', 10); ax.TitleHorizontalAlignment = 'left';
    set(ax, 'Box', 'off', 'FontSize', 10, 'YGrid', 'on', 'GridColor', [0.85 0.85 0.85], 'GridAlpha', 1);
    if k == 1, legend(ax, 'Location', 'southeast', 'Box', 'off'); ax.XTickLabel = []; end
end
xlabel(ax, 'Time (ms)');
title(tl, 'PI against H-infinity: irradiance step at 400 ms, short-circuit ratio 5', 'FontSize', 12);
exportgraphics(fig, fullfile(root, 'docs', 'hinf_demo.png'), 'Resolution', 150);
if ~showModel, close(fig); end
fprintf('\nCurrent THD after the step: PI %.2f %%, H-infinity %.2f %%\n', thd(1), thd(2));
fprintf('Figure saved to docs/hinf_demo.png\n');
end

function m = marg(L)
A = allmargin(L);
m = [min([20*log10(A.GainMargin(A.GainMargin > 1)), Inf]), min([abs(A.PhaseMargin), Inf]), norm(feedback(1, L), inf)];
end

function v = onoff(tf)
if tf, v = 'on'; else, v = 'off'; end
end

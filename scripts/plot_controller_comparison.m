function plot_controller_comparison()
% PLOT_CONTROLLER_COMPARISON  Figures for the four current controllers.
%   docs/controllers_sensitivity.png  sensitivity |S| at SCR 20 and SCR 2
%   docs/controllers_step.png         irradiance-step response at SCR 5
%                                     (needs results/cmp_<mode>_step_5.mat from compare_controllers)
root = fileparts(fileparts(mfilename('fullpath')));
P0 = params(10); Tc = P0.Tc;
names = P0.ctrl.names;
col = [0 114 178; 213 94 0; 0 158 115; 204 121 167]/255;   % Okabe-Ito: blue, vermillion, green, purple
sty = {'-', '--', '-.', ':'};
K = load(fullfile(root, 'scripts', 'flc_controller.mat'));
C = { pid(P0.ctrl.KpI, P0.ctrl.KiI, 0, 0, Tc, 'IFormula', 'ForwardEuler'), ...
      pid(P0.pid.Kp, P0.pid.Ki, P0.pid.Kd, 1/P0.pid.N, Tc, 'IFormula', 'ForwardEuler', 'DFormula', 'BackwardEuler'), ...
      ss(P0.hinf.A, P0.hinf.B, P0.hinf.C, P0.hinf.D, Tc), ...
      pid(K.Kp_eq, K.Ki_eq, 0, 0, Tc, 'IFormula', 'BackwardEuler') };
lbl = names; lbl{4} = 'Fuzzy PI (small-signal)';

% ---- sensitivity ----
f = logspace(1, log10(4500), 900); w = 2*pi*f;
fig = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 950 430]);
tl = tiledlayout(fig, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
for scr = [20 2]
    Gd = discrete_plant(params(scr));
    ax = nexttile(tl); hold(ax, 'on');
    for c = 1:4
        S = feedback(1, C{c}*Gd);
        mag = squeeze(abs(freqresp(S, w)));
        plot(ax, f, 20*log10(mag), sty{c}, 'Color', col(c,:), 'LineWidth', 1.7, ...
            'DisplayName', sprintf('%s, peak %.2f', lbl{c}, max(mag)));
    end
    yline(ax, 0, '-', 'Color', [0.45 0.45 0.45], 'HandleVisibility', 'off');
    set(ax, 'XScale', 'log', 'XLim', [10 4500], 'YLim', [-40 10], 'Box', 'off', 'FontSize', 10, ...
        'XGrid', 'on', 'YGrid', 'on', 'GridColor', [0.82 0.82 0.82], 'GridAlpha', 1, 'MinorGridLineStyle', 'none');
    title(ax, sprintf('Short-circuit ratio %g', scr), 'FontWeight', 'normal');
    xlabel(ax, 'Frequency (Hz)');
    if scr == 20, ylabel(ax, 'Sensitivity |S| (dB)'); end
    legend(ax, 'Location', 'southeast', 'Box', 'off', 'FontSize', 9);
end
title(tl, 'Current-loop sensitivity of the four controllers (lower peak = more robust)', 'FontSize', 11);
exportgraphics(fig, fullfile(root, 'docs', 'controllers_sensitivity.png'), 'Resolution', 150);
close(fig);

% ---- irradiance step ----
fig = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 950 640]);
tl = tiledlayout(fig, 2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
sig = {'ID', 'd-axis current (A), 1 ms moving average, negative = exporting'; 'VDC', 'DC-link voltage (V)'};
for k = 1:2
    ax = nexttile(tl); hold(ax, 'on');
    for c = 1:4
        fn = fullfile(root, 'results', sprintf('cmp_%d_step_5.mat', c));
        if ~exist(fn, 'file'), continue; end
        S = load(fn, sig{k,1}); x = S.(sig{k,1});
        y = movmean(x.Data, max(1, round(1e-3/(x.Time(2) - x.Time(1)))));
        plot(ax, 1e3*x.Time, y, sty{c}, 'Color', col(c,:), 'LineWidth', 1.4, 'DisplayName', names{c});
    end
    xline(ax, 400, ':', 'Color', [0.4 0.4 0.4], 'HandleVisibility', 'off');
    xlim(ax, [350 700]);
    title(ax, sig{k,2}, 'FontWeight', 'normal', 'FontSize', 10); ax.TitleHorizontalAlignment = 'left';
    set(ax, 'Box', 'off', 'FontSize', 10, 'YGrid', 'on', 'GridColor', [0.85 0.85 0.85], 'GridAlpha', 1);
    if k == 1, legend(ax, 'Location', 'southeast', 'Box', 'off'); ax.XTickLabel = []; end
end
xlabel(ax, 'Time (ms)');
title(tl, 'Irradiance step 1000 to 600 W/m^2 at 400 ms, short-circuit ratio 5', 'FontSize', 11);
exportgraphics(fig, fullfile(root, 'docs', 'controllers_step.png'), 'Resolution', 150);
close(fig);
end

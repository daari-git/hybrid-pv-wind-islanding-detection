function plot_controller_sensitivity()
% PLOT_CONTROLLER_SENSITIVITY  Sensitivity |S| of the current loop, PI against
% H-infinity, at the strongest and weakest grid. Both include the 1.5-sample delay.
P0 = params(10); Td = 1.5*P0.Tc; s = tf('s');
[n, d] = pade(Td, 2); D = tf(n, d);
K  = load(fullfile(fileparts(mfilename('fullpath')), 'hinf_controller.mat'));
Kh = d2c(ss(K.A, K.B, K.C, K.D, K.Tc), 'tustin');
f = logspace(1, log10(4000), 1200); w = 2*pi*f;
col = [0 114 178; 213 94 0]/255;            % blue = PI, vermillion = H-infinity (colour-blind safe pair)
sty = {'-', '--'}; names = {'PI', 'H-infinity'};
scrs = [20 2];
fig = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 900 420]);
tl = tiledlayout(fig, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
for k = 1:2
    P = params(scrs(k)); G = plant_model(P)*D;
    C = {P.ctrl.KpI + P.ctrl.KiI/s, Kh};
    ax = nexttile(tl); hold(ax, 'on');
    for c = 1:2
        Sf = feedback(1, C{c}*G);
        mag = squeeze(bode(Sf, w));
        plot(ax, f, 20*log10(mag), sty{c}, 'Color', col(c,:), 'LineWidth', 1.8, ...
            'DisplayName', sprintf('%s (peak %.2f)', names{c}, max(mag)));
    end
    yline(ax, 0, '-', 'Color', [0.45 0.45 0.45], 'HandleVisibility', 'off');
    set(ax, 'XScale', 'log', 'XLim', [10 4000], 'YLim', [-40 10], 'Box', 'off', 'FontSize', 11, ...
        'XGrid', 'on', 'YGrid', 'on', 'GridColor', [0.8 0.8 0.8], 'GridAlpha', 1, 'MinorGridLineStyle', 'none');
    title(ax, sprintf('Short-circuit ratio %g', scrs(k)), 'FontWeight', 'normal');
    xlabel(ax, 'Frequency (Hz)');
    if k == 1, ylabel(ax, 'Sensitivity |S| (dB)'); end
    legend(ax, 'Location', 'southeast', 'Box', 'off');
end
title(tl, 'Current-loop sensitivity: lower peak means more robust, lower curve means better disturbance rejection', 'FontSize', 11);
root = fileparts(fileparts(mfilename('fullpath')));
exportgraphics(fig, fullfile(root, 'docs', 'controller_sensitivity.png'), 'Resolution', 150);
close(fig);
end

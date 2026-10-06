function plot_pi_bode()
% PLOT_PI_BODE  Open-loop Bode plot of the PI current loop at each grid strength.
%   Uses the digital-controller case (1.5/fsw delay), where the margins are finite.
scrs = [20 10 5 3 2];
col  = [107 174 214; 66 146 198; 33 113 181; 8 81 156; 8 48 107]/255;   % one hue, light to dark = strong to weak grid
P0 = params(10); Td = 1.5/P0.fsw;
f = logspace(1, log10(5000), 1500); w = 2*pi*f;
fig = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 900 620]);
ax1 = subplot(2,1,1); hold(ax1, 'on'); ax2 = subplot(2,1,2); hold(ax2, 'on');
for k = 1:numel(scrs)
    P = params(scrs(k));
    M = loop_margins(P, P.ctrl.KpI, P.ctrl.KiI, Td);
    [mag, ph] = bode(M.L, w); mag = squeeze(mag); ph = squeeze(ph);
    ph = ph - 360*round((ph(1) + 90)/360);          % start every curve near -90 deg
    plot(ax1, f, 20*log10(mag), 'Color', col(k,:), 'LineWidth', 1.6, ...
        'DisplayName', sprintf('SCR %g  (PM %.0f%s, GM %.1f dB)', scrs(k), M.pm, char(176), M.gm));
    plot(ax2, f, ph, 'Color', col(k,:), 'LineWidth', 1.6);
end
grey = [0.45 0.45 0.45];
yline(ax1, 0, '-', 'Color', grey, 'HandleVisibility', 'off');
yline(ax2, -180, '-', 'Color', grey, 'HandleVisibility', 'off');
set([ax1 ax2], 'XScale', 'log', 'XLim', [10 5000], 'Box', 'off', 'FontSize', 11, ...
    'GridColor', [0.8 0.8 0.8], 'GridAlpha', 1, 'MinorGridLineStyle', 'none', 'XGrid', 'on', 'YGrid', 'on');
ylabel(ax1, 'Magnitude (dB)'); ylabel(ax2, 'Phase (deg)'); xlabel(ax2, 'Frequency (Hz)');
ylim(ax1, [-40 60]); ylim(ax2, [-540 0]); yticks(ax2, -540:90:0);
title(ax1, sprintf('PI current loop, open-loop response (K_p = %g, K_i = %g, delay 1.5/f_{sw})', ...
    P0.ctrl.KpI, P0.ctrl.KiI), 'FontWeight', 'normal');
legend(ax1, 'Location', 'northeast', 'Box', 'off');
root = fileparts(fileparts(mfilename('fullpath')));
exportgraphics(fig, fullfile(root, 'docs', 'pi_loop_bode.png'), 'Resolution', 150);
close(fig);
end

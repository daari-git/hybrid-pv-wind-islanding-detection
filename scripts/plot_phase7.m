function plot_phase7(parts)
% PLOT_PHASE7  Figures for Phase 7.
%   docs/noise_robustness.png   islands detected and false trips against sensor
%                               noise, for the Phase 6 detector (trained without
%                               noise) and the Phase 7 detector (trained with it),
%                               grid strengths held out
%   docs/closed_loop_traces.png the detector in the loop: an island that defeats
%                               active frequency drift, and a voltage sag it rides
%                               through, weak grid (SCR 4), sensor noise on
%   docs/closed_loop_summary.png detection times in the loop with PI and with
%                               H-infinity control, and the non-detection-zone grid
%   PARTS selects figures by number (default 1:3).
root = fileparts(fileparts(mfilename('fullpath')));
okabe = [0 114 178; 213 94 0; 0 158 115; 204 121 167; 230 159 0; 86 180 233]/255;
grey = [0.45 0.45 0.45]; ink = [0.15 0.15 0.15];
style = @(ax) set(ax, 'Box', 'off', 'FontSize', 10, 'XGrid', 'on', 'YGrid', 'on', 'GridColor', [0.85 0.85 0.85], 'GridAlpha', 1);
P0 = params(10);
if nargin < 1, parts = 1:3; end

%% 1. Noise robustness
if any(parts == 1)
S = readtable(fullfile(root, 'results', 'classifier_summary_noise.csv'), 'TextType', 'string');
p = split(S.model, "_"); S.base = p(:,1); S.train = p(:,2); S.level = double(extractAfter(p(:,3), 1));
Sel = readtable(fullfile(root, 'results', 'detector_selection.csv'), 'TextType', 'string');
Sel = Sel(Sel.model == "nn" & Sel.training == "noisy", :);
det = {"clean", 10, 0.5, 6, 'trained without noise (the Phase 6 design)', 'o', '-'; ...
       "noisy", Sel.W_ms(1), Sel.threshold(1), Sel.debounce(1), 'trained with noise (Phase 7)', 's', '-'};
fig = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 1250 450]);
tl = tiledlayout(fig, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
ax1 = nexttile(tl); hold(ax1, 'on'); ax2 = nexttile(tl); hold(ax2, 'on');
for k = 1:size(det, 1)
    r = S(S.base == "nn" & S.train == det{k,1} & S.W_ms == det{k,2} & S.family == "scr" & ...
        abs(S.threshold - det{k,3}) < 1e-9 & S.debounce == det{k,4}, :);
    r = sortrows(r, 'level');
    plot(ax1, r.level, r.detected_pct, [det{k,7} det{k,6}], 'Color', okabe(k,:), 'LineWidth', 1.8, ...
        'MarkerFaceColor', okabe(k,:), 'MarkerSize', 8, 'DisplayName', [det{k,5} ', all islands']);
    plot(ax1, r.level, r.detected_matched_pct, ['--' det{k,6}], 'Color', okabe(k,:), 'LineWidth', 1.5, ...
        'MarkerFaceColor', 'w', 'MarkerSize', 8, 'DisplayName', [det{k,5} ', matched islands']);
    plot(ax2, r.level, r.falseTrip_pct, [det{k,7} det{k,6}], 'Color', okabe(k,:), 'LineWidth', 1.8, ...
        'MarkerFaceColor', okabe(k,:), 'MarkerSize', 8, 'DisplayName', det{k,5});
end
for ax = [ax1 ax2]
    style(ax); set(ax, 'XLim', [-0.1 2.1], 'XTick', 0:2, 'XTickLabel', {'none', 'nominal sensors', 'twice nominal'});
    xlabel(ax, 'Sensor noise in the test cases');
end
set(ax1, 'YLim', [0 103]); ylabel(ax1, 'Islands detected within 0.35 s (%)');
legend(ax1, 'Location', 'southoutside', 'NumColumns', 2, 'Box', 'off', 'FontSize', 9);
title(ax1, 'Islands detected', 'FontWeight', 'normal', 'FontSize', 10);
set(ax2, 'YLim', [0 10]); ylabel(ax2, 'Ordinary events that tripped the detector (%)');
title(ax2, 'False trips', 'FontWeight', 'normal', 'FontSize', 10);
legend(ax2, 'Location', 'southoutside', 'NumColumns', 1, 'Box', 'off', 'FontSize', 9);
title(tl, {'Neural-network detectors with sensor noise, on grid strengths they were not trained on (400 cases)', ...
    sprintf('Without noise: %d ms windows, 6 in a row above 0.5. With noise: %d ms windows, %d in a row above %.1f', ...
    det{1,2}, det{2,2}, det{2,4}, det{2,3})}, 'FontSize', 11);
exportgraphics(fig, fullfile(root, 'docs', 'noise_robustness.png'), 'Resolution', 150);
close(fig);

end

%% 2. Closed-loop traces
if any(parts == 2)
d = fullfile(root, 'data', 'closedloop', 'pi');
A = load(fullfile(d, 'scr4_t3_afd_island_der2_Kq-2000.mat'));
M = load(fullfile(d, 'scr4_t3_island_der2_Kq-2000.mat'));
E = load(fullfile(d, 'scr4_t3_event06.mat'));
Ea = load(fullfile(d, 'scr4_t3_afd_event06.mat'));
fig = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 1250 760]);
tl = tiledlayout(fig, 3, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
rel = @(R, x) x.Time - R.tEvent;
cases = {M, A, 'Island with a second inverter that works against frequency drift'; ...
         E, Ea, 'Voltage sag to 0.7 pu for 0.5 s (ordinary event, must ride through)'};
for col = 1:2
    R = cases{col,1}; Rb = cases{col,2};
    xl = [-0.1 0.8];
    tCut = Inf; if isfinite(R.tTrip), tCut = R.tTrip; end   % after a trip the inverter is off
    shade = @(ax, yl) patch(ax, [tCut xl(2) xl(2) tCut], yl([1 1 2 2]), [0.93 0.93 0.93], 'EdgeColor', 'none', 'HandleVisibility', 'off');
    ax = nexttile(tl, col); hold(ax, 'on');
    if col == 1
        yl = [49.4 50.8]; shade(ax, yl);
        text(ax, tCut + 0.02, yl(2) - 0.12, 'inverter disconnected by the detector', 'Color', grey, 'FontSize', 9);
        plot(ax, rel(Rb, Rb.freq), Rb.freq.Data, '--', 'Color', okabe(2,:), 'LineWidth', 1.5, 'DisplayName', 'Frequency drift on, no ML detector: not detected');
        k = rel(R, R.freq) <= tCut; tf = rel(R, R.freq);
        plot(ax, tf(k), R.freq.Data(k), '-', 'Color', okabe(1,:), 'LineWidth', 1.5, 'DisplayName', 'ML detector in the loop: trips');
        ylim(ax, yl); ylabel(ax, 'Frequency (Hz)');
        legend(ax, 'Location', 'southeast', 'Box', 'off', 'FontSize', 9);
    else
        plot(ax, rel(Rb, Rb.Vpcc_rms), Rb.Vpcc_rms.Data, '--', 'Color', okabe(2,:), 'LineWidth', 1.5, 'DisplayName', 'Frequency drift on, no ML detector');
        plot(ax, rel(R, R.Vpcc_rms), R.Vpcc_rms.Data, '-', 'Color', okabe(1,:), 'LineWidth', 1.5, 'DisplayName', 'ML detector in the loop: rides through');
        ylim(ax, [0.45 1.1]); ylabel(ax, 'PCC voltage (pu)');
        legend(ax, 'Location', 'southeast', 'Box', 'off', 'FontSize', 9);
    end
    style(ax); xlim(ax, xl);
    title(ax, cases{col,3}, 'FontWeight', 'normal', 'FontSize', 10);
    ax = nexttile(tl, col + 2); hold(ax, 'on');
    if isfinite(tCut), shade(ax, [-0.03 1.05]); end
    k = R.ml_score.Time >= R.tEvent - 0.25 + 0.06 & R.ml_score.Time - R.tEvent <= tCut;
    stairs(ax, R.ml_score.Time(k) - R.tEvent, R.ml_score.Data(k), '-', 'Color', okabe(1,:), 'LineWidth', 1.3, 'HandleVisibility', 'off');
    yline(ax, R.P.ml.threshold, '--', 'Color', grey, 'HandleVisibility', 'off');
    text(ax, xl(2) - 0.01, R.P.ml.threshold + 0.06, 'threshold', 'HorizontalAlignment', 'right', 'Color', grey, 'FontSize', 9);
    if isfinite(R.tTrip)
        xline(ax, R.tTrip, '-', 'Color', ink, 'HandleVisibility', 'off');
        text(ax, R.tTrip + 0.01, 0.2, sprintf('trip at %.0f ms', 1e3*R.tTrip), 'Color', ink, 'FontSize', 9);
    else
        text(ax, 0.02, 0.85, 'no trip', 'Color', ink, 'FontSize', 9);
    end
    style(ax); xlim(ax, xl); ylim(ax, [-0.03 1.05]); ylabel(ax, 'Island score');
    ax = nexttile(tl, col + 4); hold(ax, 'on');
    if isfinite(tCut), shade(ax, [-40 40]); end
    tw = R.tw(1) + (0:size(R.Igrid, 1) - 1)'/1e4 - R.tEvent;
    plot(ax, tw, R.Igrid(:,1), '-', 'Color', okabe(1,:), 'LineWidth', 0.8, 'HandleVisibility', 'off');
    style(ax); xlim(ax, xl); ylim(ax, [-40 40]); ylabel(ax, 'Inverter current, phase a (A)');
    xlabel(ax, 'Time after the event (s)');
end
title(tl, 'The detector inside the model, weak grid (SCR 4), sensor noise on, an operating condition it never saw', 'FontSize', 11);
exportgraphics(fig, fullfile(root, 'docs', 'closed_loop_traces.png'), 'Resolution', 150);
close(fig);

end

%% 3. Closed-loop summary
if any(parts == 3)
T = readtable(fullfile(root, 'results', 'closed_loop_pi.csv'), 'TextType', 'string');
H = readtable(fullfile(root, 'results', 'closed_loop_hinfinity.csv'), 'TextType', 'string');
fig = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 1250 470]);
tl = tiledlayout(fig, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
ax = nexttile(tl); hold(ax, 'on');
src = {T(T.group == "cases" & T.island == 1, :), 'PI', '-'; H(H.group == "cases" & H.island == 1, :), 'H-infinity', '--'};
for k = 1:2
    s = src{k,1}; t = sort(s.tTrip_ms(s.detected == 1));
    stairs(ax, [0; t; 400], 100*[0; (1:numel(t))'; numel(t)]/height(s), src{k,3}, 'Color', okabe(k,:), 'LineWidth', 1.8, ...
        'DisplayName', sprintf('ML detector, %s: %d of %d', src{k,2}, numel(t), height(s)));
end
a = T(T.group == "afd" & T.island == 1, :);
t = sort(a.tTrip_ms(a.detected == 1));
stairs(ax, [0; t; 400], 100*[0; (1:numel(t))'; numel(t)]/height(a), ':', 'Color', okabe(3,:), 'LineWidth', 1.8, ...
    'DisplayName', sprintf('Drift + IEEE relay: %d of %d', numel(t), height(a)));
text(ax, 210, 30, sprintf('misses the %d islands with an opposing\nsecond inverter (not detected in 2 s)', height(a) - numel(t)), ...
    'Color', okabe(3,:)*0.7, 'FontSize', 9, 'VerticalAlignment', 'top');
style(ax); set(ax, 'XLim', [0 400], 'YLim', [0 102]);
xlabel(ax, 'Time after the grid breaker opens (ms)'); ylabel(ax, 'Islands detected (%)');
legend(ax, 'Location', 'east', 'Box', 'off', 'FontSize', 9);
title(ax, 'Detection time on the three unseen conditions', 'FontWeight', 'normal', 'FontSize', 10);

ax = nexttile(tl);
n = T(T.group == "ndz", :);
dP = unique(n.dP_pct); dQ = unique(n.dQ_pct);
Z = nan(numel(dQ), numel(dP));
for i = 1:height(n)
    Z(dQ == n.dQ_pct(i), dP == n.dP_pct(i)) = n.tTrip_ms(i);
end
imagesc(ax, 1:numel(dP), 1:numel(dQ), Z, 'AlphaData', ~isnan(Z));
cmap = interp1([0 1], [0.93 0.96 1; 0 0.3 0.6], linspace(0, 1, 64)); colormap(ax, cmap);
cb = colorbar(ax); cb.Label.String = 'Detection time (ms)';
for i = 1:numel(dQ)
    for j = 1:numel(dP)
        if isfinite(Z(i,j)), s = sprintf('%.0f', Z(i,j)); else, s = 'missed'; end
        c = ink; if Z(i,j) > 0.6*max(Z(:)), c = 'w'; end
        text(ax, j, i, s, 'HorizontalAlignment', 'center', 'FontSize', 9, 'Color', c);
    end
end
set(ax, 'YDir', 'normal', 'XTick', 1:numel(dP), 'XTickLabel', compose('%+g', dP), 'YTick', 1:numel(dQ), ...
    'YTickLabel', compose('%+g', dQ), 'FontSize', 10, 'Box', 'off');
xlabel(ax, 'Active power mismatch \DeltaP (%)'); ylabel(ax, 'Reactive power mismatch \DeltaQ (%)');
title(ax, sprintf('Non-detection-zone grid, SCR 7, Q_f 1: %d of %d islands detected', sum(n.detected == 1), height(n)), ...
    'FontWeight', 'normal', 'FontSize', 10);
title(tl, 'The detector inside the model with sensor noise, on operating conditions it never saw', 'FontSize', 11);
exportgraphics(fig, fullfile(root, 'docs', 'closed_loop_summary.png'), 'Resolution', 150);
close(fig);
end
end

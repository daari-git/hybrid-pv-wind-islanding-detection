function plot_phase6()
% PLOT_PHASE6  Figures for Phase 6.
%   docs/ml_tradeoff.png   islands detected against false trips on ordinary
%                          events, every threshold and debounce of the four
%                          models, with the two relays on the same cases
%   docs/ml_detection.png  detection time of the network at its best setting
%                          in hindsight (10 ms, 0.5, 6) by kind of island, and
%                          the features it relies on
%   All classifier numbers are for grid strengths the model was not trained
%   on (each SCR held out in turn).
root = fileparts(fileparts(mfilename('fullpath')));
okabe = [0 114 178; 213 94 0; 0 158 115; 204 121 167; 230 159 0; 86 180 233]/255;
grey = [0.45 0.45 0.45]; ink = [0.15 0.15 0.15];
style = @(ax) set(ax, 'Box', 'off', 'FontSize', 10, 'XGrid', 'on', 'YGrid', 'on', 'GridColor', [0.85 0.85 0.85], 'GridAlpha', 1);
S = readtable(fullfile(root, 'results', 'classifier_summary.csv'), 'TextType', 'string');
B = readtable(fullfile(root, 'results', 'dataset_baselines.csv'), 'TextType', 'string', 'VariableNamingRule', 'preserve');
pick = {"tree", 20, 's', 'Decision tree, 20 ms'; "forest", 40, 'd', 'Random forest, 40 ms'; ...
        "svm", 20, 'v', 'SVM, 20 ms'; "nn", 10, 'o', 'Neural network, 10 ms'};
% the rule's choice for the network (picked on the mix folds) and, for reference, the best
% setting on the grid-strength folds, which is picked with hindsight
ruled = S(S.model == "nn" & S.W_ms == 20 & S.family == "scr" & abs(S.threshold - 0.5) < 1e-9 & S.debounce == 4, :);
chosen = S(S.model == "nn" & S.W_ms == 10 & S.family == "scr" & abs(S.threshold - 0.5) < 1e-9 & S.debounce == 6, :);
rel = {"Fast passive", 'Fast relay'; "IEEE passive", 'IEEE 1547 relay'};
relPt = zeros(2, 2);
for k = 1:2
    b = B(B.detector == rel{k,1}, :);
    relPt(k,:) = [100*mean(b.trip(b.label == 0) == 1), 100*mean(b.trip(b.label == 1) == 1)];
end

%% 1. Trade-off
fig = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 1250 470]);
tl = tiledlayout(fig, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
for p = 1:2
    ax = nexttile(tl); hold(ax, 'on');
    for k = 1:size(pick, 1)
        s = S(S.model == pick{k,1} & S.W_ms == pick{k,2} & S.family == "scr", :);
        scatter(ax, s.falseTrip_pct, s.detected_pct, 30, okabe(k,:), pick{k,3}, 'filled', ...
            'MarkerFaceAlpha', 0.75, 'DisplayName', pick{k,4});
    end
    plot(ax, ruled.falseTrip_pct, ruled.detected_pct, 's', 'MarkerSize', 14, 'LineWidth', 1.5, ...
        'Color', ink, 'DisplayName', 'Network, the rule''s choice (20 ms)');
    plot(ax, chosen.falseTrip_pct, chosen.detected_pct, 'o', 'MarkerSize', 14, 'LineWidth', 1.5, ...
        'Color', grey, 'DisplayName', 'Network, best in hindsight (10 ms)');
    for k = 1:2
        plot(ax, relPt(k,1), relPt(k,2), 'p', 'MarkerSize', 13, 'MarkerFaceColor', grey, 'MarkerEdgeColor', ink, ...
            'HandleVisibility', 'off');
    end
    style(ax);
    xlabel(ax, 'Ordinary events that tripped the detector (%)');
    if p == 1
        ylabel(ax, 'Islands detected within 0.35 s (%)');
        set(ax, 'XLim', [-3 100], 'YLim', [-3 103]);
        text(ax, relPt(1,1) - 2, relPt(1,2) - 5, sprintf('%s:\n%.0f%% detected, %.0f%% false trips', rel{1,2}, relPt(1,2), relPt(1,1)), ...
            'HorizontalAlignment', 'right', 'FontSize', 9, 'Color', ink);
        text(ax, relPt(2,1) + 3, relPt(2,2) + 4, sprintf('%s: nothing within 0.35 s', rel{2,2}), 'FontSize', 9, 'Color', ink);
        rectangle(ax, 'Position', [0 85 20 15], 'EdgeColor', grey, 'LineStyle', '--');
        text(ax, 21, 86, 'enlarged on the right', 'FontSize', 9, 'Color', grey);
        title(ax, 'Every threshold and debounce setting of four classifiers, and the two relays', 'FontWeight', 'normal', 'FontSize', 10);
        legend(ax, 'Location', 'southeast', 'Box', 'off');
    else
        set(ax, 'XLim', [0 20], 'YLim', [85 100.5]);
        plot(ax, [chosen.falseTrip_pct + 0.3, 7.8], [chosen.detected_pct - 0.3, 91.6], '-', 'Color', ink, ...
            'LineWidth', 0.8, 'HandleVisibility', 'off');
        text(ax, 8, 91.2, sprintf('Best in hindsight: %.1f%% detected, %.1f%% false trips,\nmedian %.0f ms (10 ms, threshold 0.5, 6 windows in a row)', ...
            chosen.detected_pct, chosen.falseTrip_pct, chosen.median_ms), 'FontSize', 9, 'Color', ink, 'BackgroundColor', 'w');
        text(ax, ruled.falseTrip_pct + 0.6, ruled.detected_pct - 2.2, sprintf('Rule''s choice: %.1f%% detected,\n%.1f%% false trips, median %.0f ms\n(20 ms, threshold 0.5, 4 in a row)', ...
            ruled.detected_pct, ruled.falseTrip_pct, ruled.median_ms), 'FontSize', 9, 'Color', ink, 'BackgroundColor', 'w');
        title(ax, 'Enlarged: the better corner is top left', 'FontWeight', 'normal', 'FontSize', 10);
    end
end
title(tl, 'Islanding classifiers on grid strengths they were not trained on (400 cases, each SCR held out in turn)', 'FontSize', 11);
exportgraphics(fig, fullfile(root, 'docs', 'ml_tradeoff.png'), 'Resolution', 150);
close(fig);

%% 2. Detection time and features
C = readtable(fullfile(root, 'results', 'classifier_cases.csv'), 'TextType', 'string', 'VariableNamingRule', 'preserve');
c = C(C.model == "nn" & C.W_ms == 10 & C.family == "scr" & abs(C.threshold - 0.5) < 1e-9 & C.debounce == 6 & C.island == 1, :);
grp = {'matched', @(n) contains(n, "dP+00_dQ+0.0"), '-'; ...
       '\DeltaP \pm5%, \DeltaQ = 0', @(n) ~contains(n, "dP+00") & contains(n, "dQ+0.0") & ~contains(n, "dP+15") & ~contains(n, "dP-15"), '--'; ...
       '\DeltaP = 0, \DeltaQ \pm2.5%', @(n) contains(n, "dP+00") & ~contains(n, "dQ+0.0"), ':'; ...
       '\pm15% P and \pm5% Q', @(n) contains(n, "dP+15") | contains(n, "dP-15"), '-.'};
fig = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 1250 470]);
tl = tiledlayout(fig, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
ax = nexttile(tl); hold(ax, 'on');
patch(ax, [160 350 350 160], [0 0 100 100], [0.93 0.93 0.93], 'EdgeColor', 'none', 'HandleVisibility', 'off');
text(ax, 255, 55, sprintf('active frequency drift\ndetects in 160 to 488 ms\n(Phases 4 and 5)'), 'HorizontalAlignment', 'center', 'FontSize', 9, 'Color', grey);
for k = 1:size(grp, 1)
    s = c(grp{k,2}(c.("case")), :);
    t = sort(s.tTrip_ms(s.detected == 1));
    stairs(ax, [0; t; 350], 100*[0; (1:numel(t))'; numel(t)]/height(s), grp{k,3}, 'Color', okabe(k,:), 'LineWidth', 1.8, ...
        'DisplayName', sprintf('%s (%d islands)', grp{k,1}, height(s)));
end
b = B(B.detector == "Fast passive" & B.label == 1, :);
t = sort(b.t_ms(b.trip == 1));
stairs(ax, [0; t; 350], 100*[0; (1:numel(t))'; numel(t)]/height(b), '-', 'Color', grey, 'LineWidth', 1.2, ...
    'DisplayName', 'Fast relay, all islands');
set(ax, 'XLim', [0 350], 'YLim', [0 102]); style(ax);
xlabel(ax, 'Time after the grid breaker opens (ms)'); ylabel(ax, 'Islands detected (%)');
legend(ax, 'Location', 'southeast', 'Box', 'off', 'FontSize', 9);
title(ax, 'Best setting in hindsight: when each kind of island is detected', 'FontWeight', 'normal', 'FontSize', 10);

ax = nexttile(tl);
F = readtable(fullfile(root, 'results', 'feature_importance_noisefree.csv'), 'TextType', 'string');
F = F(1:12, :);
plain = containers.Map( ...
  {'dV_max','phase_jump','dV_pos','df_max','df_end','dI_pos','Zh_ratio','dTHD_v','dV_mean','dVdc_max','dP','dV_neg', ...
   'rocof_peak','rocof_fit','dV_max_n','df_max_n','dTHD_i','dQ','dI_neg','dId_max','P_slope','dIq_max'}, ...
  {'Largest voltage change','Phase jump','Positive-sequence voltage change','Largest frequency change', ...
   'Frequency change at window end','Inverter current change','Distortion impedance ratio','Voltage distortion change', ...
   'Mean voltage change','DC-link voltage deviation','Active power change','Negative-sequence voltage change', ...
   'Peak rate of change of frequency','Fitted rate of change of frequency','Voltage change / baseline noise', ...
   'Frequency change / baseline noise','Current distortion change','Reactive power change','Negative-sequence current change', ...
   'd-axis current deviation','Power slope','q-axis current deviation'});
lab = arrayfun(@(f) string(plain(char(f))), F.feature);
barh(ax, flipud(F.mean_drop), 0.6, 'FaceColor', okabe(1,:), 'EdgeColor', 'none');
set(ax, 'YTick', 1:height(F), 'YTickLabel', flipud(lab), 'FontSize', 9);
style(ax); ax.YGrid = 'off';
xlabel(ax, 'Fall in balanced accuracy when the feature is shuffled');
title(ax, 'What the detector relies on (12 of 22 features)', 'FontWeight', 'normal', 'FontSize', 10);
title(tl, 'Neural network on 10 ms windows, trip after 6 windows in a row (30 ms), unseen grid strengths', 'FontSize', 11);
exportgraphics(fig, fullfile(root, 'docs', 'ml_detection.png'), 'Resolution', 150);
close(fig);
end

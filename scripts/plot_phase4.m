function plot_phase4()
% PLOT_PHASE4  Islanding figures for Phase 4.
%   docs/island_matched_afd.png   matched island without and with frequency drift
%   docs/rocof_island_vs_events.png  relay ROCOF for an island and four ordinary events
%   docs/detector_summary.png     islands detected against false trips
%   The four event runs are simulated once and kept in results/ft_<k>.mat.
root = fileparts(fileparts(mfilename('fullpath')));
blue = [0 114 178]/255; verm = [213 94 0]/255; grey = [0.45 0.45 0.45];
P0 = params(10);
nd = @(afd, dP, dQ) load(fullfile(root, 'results', 'ndz', sprintf('afd%d_dP%+04.0f_dQ%+05.1f.mat', afd, dP, dQ)));
style = @(ax) set(ax, 'Box', 'off', 'FontSize', 10, 'YGrid', 'on', 'GridColor', [0.85 0.85 0.85], 'GridAlpha', 1);

%% 1. Matched island, without and with active frequency drift
R = {nd(0, 0, 0), nd(1, 0, 0)};
D = detect_islanding(R{2}, P0.relay.ieee, R{2}.P.tIsland);
tI = R{1}.P.tIsland; tD = tI + D.t;
fig = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 950 720]);
tl = tiledlayout(fig, 3, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
sig = {'freq', 'Frequency (Hz)'; 'Vpcc_rms', 'PCC voltage (pu RMS, 20 ms average; the RMS window is fixed at 50 Hz)'; 'IQ', 'q-axis current (A), the drift injection'};
lbl = {'Without frequency drift', 'With frequency drift'}; sty = {'-', '--'}; col = [blue; verm];
for k = 1:3
    ax = nexttile(tl); hold(ax, 'on');
    for c = 1:2
        x = R{c}.(sig{k,1});
        y = x.Data; if k == 2, y = movmean(y, 20); elseif k == 3, y = movmean(y, 5); end
        plot(ax, x.Time, y, sty{c}, 'Color', col(c,:), 'LineWidth', 1.5, 'DisplayName', lbl{c});
    end
    xline(ax, tI, ':', 'Color', grey, 'HandleVisibility', 'off');
    xline(ax, tD, '-', 'Color', grey, 'HandleVisibility', 'off');
    if k == 1
        yline(ax, P0.relay.ieee.of(2,1), '--', sprintf('OF2 %.2f Hz, 0.16 s', P0.relay.ieee.of(2,1)), ...
            'Color', grey, 'LabelHorizontalAlignment', 'right', 'LabelVerticalAlignment', 'top', 'FontSize', 9, 'HandleVisibility', 'off');
        ylim(ax, [48.5 60]);
        text(ax, tI, 59.3, ' grid breaker opens', 'Color', grey, 'FontSize', 9);
        text(ax, tD, 56.5, sprintf(' IEEE relay trips, %.0f ms after islanding', 1e3*D.t), 'Color', grey, 'FontSize', 9);
        legend(ax, 'Location', 'east', 'Box', 'off');
    end
    xlim(ax, [0.3 2.45]); title(ax, sig{k,2}, 'FontWeight', 'normal', 'FontSize', 10);
    ax.TitleHorizontalAlignment = 'left'; style(ax);
    if k < 3, ax.XTickLabel = []; end
end
xlabel(ax, 'Time (s)');
title(tl, 'Matched island (\DeltaP = \DeltaQ = 0, Q_f = 1): no passive setting detects it; frequency drift does', 'FontSize', 11);
exportgraphics(fig, fullfile(root, 'docs', 'island_matched_afd.png'), 'Resolution', 150);
close(fig);

%% 2. ROCOF seen by the relay: an island against ordinary events
ev = disturbance_events();
pick = [1 5 6 11];                                   % irradiance down, capacitor, sag 0.7 pu, phase jump
runs = cell(1, numel(pick));
for k = 1:numel(pick)
    f = fullfile(root, 'results', sprintf('ft_%d.mat', pick(k)));
    if exist(f, 'file'), runs{k} = load(f); continue; end
    P = ev(pick(k)).set(params(10)); P.prot.tArm = 1e6;
    runs{k} = run_model(1.2, P, sprintf('ft_%d', pick(k)));
end
cases = [{nd(0, 0, 2.5)}, runs];
names = [{'Island, \DeltaQ = +2.5%'}, {ev(pick).name}];
t0 = [R{1}.P.tIsland, 0.5*ones(1, numel(pick))];
thr = P0.relay.fast.rocof(1);
fig = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 1250 360]);
tl = tiledlayout(fig, 1, numel(cases), 'TileSpacing', 'compact', 'Padding', 'compact');
for k = 1:numel(cases)
    [t, ~, ~, r] = relay_signals(cases{k});
    ax = nexttile(tl); hold(ax, 'on');
    c = blue; if k == 1, c = verm; end
    plot(ax, 1e3*(t - t0(k)), max(r, 0.05), 'Color', c, 'LineWidth', 1.4);
    yline(ax, thr, '--', sprintf('%g Hz/s trip', thr), 'Color', grey, 'FontSize', 9, 'LabelHorizontalAlignment', 'right', 'LabelVerticalAlignment', 'bottom');
    w = t >= t0(k) & t <= t0(k) + 0.3;
    title(ax, sprintf('%s\npeak %.1f Hz/s', names{k}, max(r(w))), 'FontWeight', 'normal', 'FontSize', 9.5);
    set(ax, 'YScale', 'log', 'YLim', [0.05 200], 'XLim', [-50 300], 'YTick', [0.1 1 10 100]);
    style(ax); xlabel(ax, 'Time after event (ms)');
    if k == 1, ylabel(ax, '|df/dt| seen by the relay (Hz/s)'); else, ax.YTickLabel = []; end
end
title(tl, 'Rate of change of frequency: an island (orange) and four ordinary events (blue) all cross the 2 Hz/s threshold', 'FontSize', 11);
exportgraphics(fig, fullfile(root, 'docs', 'rocof_island_vs_events.png'), 'Resolution', 150);
close(fig);

%% 3. Detector summary
N = readtable(fullfile(root, 'results', 'ndz_sweep.csv'), 'TextType', 'string');
F = readtable(fullfile(root, 'results', 'false_trips.csv'), 'TextType', 'string');
dets = ["Fast passive", "IEEE passive", "IEEE + AFD"];
fig = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 900 360]);
ax = axes(fig); hold(ax, 'on');
for d = 1:3
    n = N(N.detector == dets(d), :); f = F(F.detector == dets(d), :);
    a = [sum(n.detected) height(n)]; b = [sum(f.falseTrip) height(f)];
    y = 4 - d;
    barh(ax, y + 0.18, 100*a(1)/a(2), 0.32, 'FaceColor', blue, 'EdgeColor', 'none');
    barh(ax, y - 0.18, 100*b(1)/b(2), 0.32, 'FaceColor', verm, 'EdgeColor', 'none');
    text(ax, 100*a(1)/a(2) + 1.5, y + 0.18, sprintf('%d of %d islands detected', a), 'FontSize', 9.5, 'VerticalAlignment', 'middle');
    text(ax, 100*b(1)/b(2) + 1.5, y - 0.18, sprintf('%d of %d ordinary events tripped (false)', b), 'FontSize', 9.5, 'VerticalAlignment', 'middle');
end
set(ax, 'YTick', 1:3, 'YTickLabel', fliplr(dets), 'XLim', [0 135], 'XTick', 0:25:100, 'YLim', [0.4 3.6], ...
    'Box', 'off', 'FontSize', 10, 'XGrid', 'on', 'GridColor', [0.85 0.85 0.85], 'GridAlpha', 1);
xlabel(ax, 'Share of cases (%)');
title(ax, 'Islands detected within 2 s (blue, higher is better) and false trips (orange, lower is better)', ...
    'FontWeight', 'normal', 'FontSize', 11);
exportgraphics(fig, fullfile(root, 'docs', 'detector_summary.png'), 'Resolution', 150);
close(fig);
end

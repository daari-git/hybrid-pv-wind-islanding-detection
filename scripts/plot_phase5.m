function plot_phase5()
% PLOT_PHASE5  Figures for Phase 5.
%   docs/afd_stress.png        frequency after a matched island when active
%                              frequency drift is stressed: quality factor,
%                              weak grid, a second inverter
%   docs/dataset_overview.png  what the dataset holds, and how islands and
%                              ordinary events overlap in the first 100 ms
root = fileparts(fileparts(mfilename('fullpath')));
okabe = [0 114 178; 213 94 0; 0 158 115; 204 121 167; 86 180 233; 230 159 0]/255;
grey = [0.45 0.45 0.45];
style = @(ax) set(ax, 'Box', 'off', 'FontSize', 10, 'YGrid', 'on', 'GridColor', [0.85 0.85 0.85], 'GridAlpha', 1);
P0 = params(10); ieee = P0.relay.ieee;
st = @(n) load(fullfile(root, 'results', 'stress', [n '.mat']));
nd = load(fullfile(root, 'results', 'ndz', 'afd1_dP+000_dQ+00.0.mat'));    % Phase 4: SCR 10, Q_f 1, matched

%% 1. Active frequency drift under stress
panels = { ...
  'Load quality factor (SCR 10)', {nd, 'Q_f = 1'; st('qf2.5_dP+0_dQ+0.0'), 'Q_f = 2.5'}; ...
  'Grid strength before islanding (Q_f = 1)', {nd, 'SCR 10'; st('scr3_matched'), 'SCR 3'; st('scr2_matched'), 'SCR 2'}; ...
  'A second 10 kW inverter (SCR 10, Q_f = 1)', {st('der2_Kq+0000'), 'no drift'; st('der2_Kq+1000'), 'same direction, 1 kvar/Hz'; ...
        st('der2_Kq+2000'), 'same direction, 2 kvar/Hz'; st('der2_Kq-2000'), 'opposite direction, 2 kvar/Hz'}};
sty = {'-', '--', ':', '-.'};
fig = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 1300 400]);
tl = tiledlayout(fig, 1, 3, 'TileSpacing', 'compact', 'Padding', 'compact');
for p = 1:3
    ax = nexttile(tl); hold(ax, 'on');
    R = panels{p, 2};
    for k = 1:size(R, 1)
        S = R{k, 1}; tI = S.P.tIsland;
        D = detect_islanding(S, ieee, tI);
        t = S.freq.Time - tI;
        lbl = R{k, 2};
        if D.trip && D.t <= P0.relay.tMax, lbl = sprintf('%s: trips in %.0f ms', lbl, 1e3*D.t);
        else, lbl = sprintf('%s: not detected', lbl); end
        plot(ax, t, S.freq.Data, sty{k}, 'Color', okabe(k,:), 'LineWidth', 1.5, 'DisplayName', lbl);
    end
    yline(ax, ieee.of(2,1), '--', 'Color', grey, 'HandleVisibility', 'off');
    text(ax, 1.98, ieee.of(2,1), sprintf('OF2 trip, %.2f Hz', ieee.of(2,1)), 'Color', grey, 'FontSize', 8.5, 'HorizontalAlignment', 'right', 'VerticalAlignment', 'bottom');
    set(ax, 'XLim', [-0.1 2.0], 'YLim', [46 60]);
    style(ax); xlabel(ax, 'Time after the grid breaker opens (s)');
    if p == 1, ylabel(ax, 'Frequency (Hz)'); else, ax.YTickLabel = []; end
    title(ax, panels{p, 1}, 'FontWeight', 'normal', 'FontSize', 10);
    legend(ax, 'Location', 'southeast', 'Box', 'off', 'FontSize', 8.5);
end
title(tl, 'Matched island (\DeltaP = \DeltaQ = 0) with IEEE 1547-2018 settings and active frequency drift', 'FontSize', 11);
exportgraphics(fig, fullfile(root, 'docs', 'afd_stress.png'), 'Resolution', 150);
close(fig);

%% 2. Dataset: islands against ordinary events in the first 100 ms
T = readtable(fullfile(root, 'results', 'dataset_index.csv'), 'TextType', 'string', 'VariableNamingRule', 'preserve');
df = nan(height(T), 1); dv = df;
for k = 1:height(T)
    D = load(fullfile(root, 'data', 'raw', T.("case")(k) + ".mat"), 'freq', 'Vpcc_rms');
    w0 = 1:100; w1 = 101:200;                       % 100 ms before and after the event (1 kHz)
    df(k) = max(abs(D.freq(w1) - mean(D.freq(w0))));
    dv(k) = max(abs(D.Vpcc_rms(w1) - mean(D.Vpcc_rms(w0))));
end
fig = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 1300 540]);
tl = tiledlayout(fig, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
ax = nexttile(tl); hold(ax, 'on');
isl = T.label == 1;
scatter(ax, max(df(~isl), 1e-3), max(dv(~isl), 1e-4), 28, okabe(1,:), 'filled', 'MarkerFaceAlpha', 0.6, 'DisplayName', sprintf('Ordinary events (%d)', sum(~isl)));
scatter(ax, max(df(isl), 1e-3), max(dv(isl), 1e-4), 28, okabe(2,:), '^', 'filled', 'MarkerFaceAlpha', 0.6, 'DisplayName', sprintf('Islands (%d)', sum(isl)));
set(ax, 'XScale', 'log', 'YScale', 'log'); style(ax); ax.XGrid = 'on';
xlabel(ax, 'Largest frequency change in the first 100 ms (Hz)');
ylabel(ax, 'Largest PCC voltage change in the first 100 ms (pu)');
legend(ax, 'Location', 'northwest', 'Box', 'off');
title(ax, 'The two classes overlap: no pair of thresholds separates them', 'FontWeight', 'normal', 'FontSize', 10);
ax = nexttile(tl); hold(ax, 'on');
% one row per kind of case; events numbered as in DISTURBANCE_EVENTS
evNames = ["Irradiance down 40%", "Irradiance up 67%", "Wind down 25%", "Load on, +6 kW", "Capacitor on, 5 kvar", ...
    "Sag to 0.7 pu", "Sag to 0.5 pu", "Swell to 1.15 pu", "Frequency ramp -2 Hz/s", "Frequency ramp +2 Hz/s", "Phase jump 20 deg"];
evNo = zeros(height(T), 1); evNo(~isl) = double(extractAfter(T.("case")(~isl), "_event"));
grp = zeros(height(T), 1);
grp(isl & T.dP == 0 & T.dQ == 0) = 1;
grp(isl & T.dP ~= 0 & T.dQ == 0) = 2;
grp(isl & T.dP == 0 & T.dQ ~= 0) = 3;
grp(isl & T.dP ~= 0 & T.dQ ~= 0) = 4;
grp(~isl) = 4 + evNo(~isl);
names = ["Island, matched", "Island, \DeltaP \pm5%", "Island, \DeltaQ \pm2.5%", "Island, \pm15% P and \pm5% Q", evNames];
for g = 1:numel(names)
    s = grp == g; y = g + 0.5*(mod(find(s), 7)/6 - 0.5);       % small vertical spread so points do not hide each other
    c = okabe(1,:); mk = 'o'; if g <= 4, c = okabe(2,:); mk = '^'; end
    scatter(ax, max(df(s), 1e-3), y, 18, c, mk, 'filled', 'MarkerFaceAlpha', 0.6);
end
set(ax, 'XScale', 'log', 'YDir', 'reverse', 'YTick', 1:numel(names), 'YTickLabel', names, 'YLim', [0.4 numel(names) + 0.6], 'FontSize', 9);
style(ax); ax.XGrid = 'on'; ax.YGrid = 'off';
xlabel(ax, 'Largest frequency change in the first 100 ms (Hz)');
title(ax, 'Matched islands move the frequency less than most ordinary events', 'FontWeight', 'normal', 'FontSize', 10);
title(tl, sprintf('Dataset: %d cases (%d islands, %d ordinary events), 16 operating conditions, frequency drift off', height(T), sum(isl), sum(~isl)), 'FontSize', 11);
exportgraphics(fig, fullfile(root, 'docs', 'dataset_overview.png'), 'Resolution', 150);
close(fig);
end

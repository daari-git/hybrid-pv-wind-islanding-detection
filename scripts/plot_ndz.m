function plot_ndz()
% PLOT_NDZ  Detection-time maps of the three baseline detectors over the
% active/reactive power mismatch plane. Grey cells marked "ND" are inside the
% non-detection zone (no trip within the 2 s IEEE 1547-2018 allows).
root = fileparts(fileparts(mfilename('fullpath')));
T = readtable(fullfile(root, 'results', 'ndz_sweep.csv'), 'TextType', 'string');
dets = ["Fast passive", "IEEE passive", "IEEE + AFD"];
dPs = unique(T.dP_pct); dQs = unique(T.dQ_pct);
% one-hue sequential ramp, light (fast) to dark (slow), on a log time scale
ramp = [222 235 247; 158 202 225; 107 174 214; 49 130 189; 8 81 156; 8 48 107]/255;
cmap = interp1(linspace(0, 1, size(ramp, 1)), ramp, linspace(0, 1, 256));
lo = log10(5); hi = log10(2000);                          % 5 ms to 2 s
fig = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 1250 470]);
tl = tiledlayout(fig, 1, 3, 'TileSpacing', 'compact', 'Padding', 'compact');
for d = 1:3
    ax = nexttile(tl); hold(ax, 'on');
    r = T(T.detector == dets(d), :);
    for i = 1:numel(dPs)
        for j = 1:numel(dQs)
            k = find(r.dP_pct == dPs(i) & r.dQ_pct == dQs(j), 1);
            x = i; y = j;
            if isempty(k), continue; end
            if r.detected(k)
                v = (log10(max(r.t_ms(k), 5)) - lo)/(hi - lo);
                c = cmap(1 + round(255*min(max(v, 0), 1)), :);
                label = sprintf('%.0f', r.t_ms(k));
            else
                c = [0.86 0.86 0.86]; label = 'ND';
            end
            rectangle(ax, 'Position', [x-0.5+0.03 y-0.5+0.03 0.94 0.94], 'FaceColor', c, 'EdgeColor', 'none');
            ink = [0.1 0.1 0.1]; if r.detected(k) && v > 0.55, ink = [1 1 1]; end
            text(ax, x, y, label, 'HorizontalAlignment', 'center', 'FontSize', 8.5, 'Color', ink);
        end
    end
    set(ax, 'XLim', [0.5 numel(dPs)+0.5], 'YLim', [0.5 numel(dQs)+0.5], 'XTick', 1:numel(dPs), ...
        'XTickLabel', signed(dPs), 'YTick', 1:numel(dQs), 'YTickLabel', signed(dQs), ...
        'FontSize', 10, 'Box', 'off', 'TickLength', [0 0]);
    axis(ax, 'square');
    xlabel(ax, 'Active power mismatch \DeltaP (%)');
    if d == 1, ylabel(ax, 'Reactive power mismatch \DeltaQ (%)'); end
    nd = sum(~r.detected);
    title(ax, sprintf('%s  (%d of %d not detected)', dets(d), nd, height(r)), 'FontWeight', 'normal');
end
colormap(fig, cmap);
cb = colorbar(ax); cb.Layout.Tile = 'east';
clim(ax, [0 1]);
set(cb, 'Limits', [0 1], 'Ticks', (log10([5 20 100 500 2000]) - lo)/(hi - lo), ...
    'TickLabels', {'5', '20', '100', '500', '2000'});
cb.Label.String = 'Detection time (ms), cell text in ms';
title(tl, 'Islanding detection time over the mismatch plane (matched point = 0, 0; Q_f = 1; SCR 10)', 'FontSize', 11);
exportgraphics(fig, fullfile(root, 'docs', 'ndz_maps.png'), 'Resolution', 150);
close(fig);
end

function c = signed(v)
% Tick labels with an explicit sign, and a plain 0.
c = compose('%+g', v); c(v == 0) = {'0'};
end

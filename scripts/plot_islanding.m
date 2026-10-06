function plot_islanding()
% PLOT_ISLANDING  Run one islanding case with a matched RLC load and plot it.
P = params(10);
P.tIsland = 0.5;
P.load.P = 18.5e3; P.load.QL = P.load.P; P.load.QC = P.load.P;   % matched to generation, Qf = 1
root0 = fileparts(fileparts(mfilename('fullpath')));
saved = fullfile(root0, 'results', 'island_matched.mat');
if exist(saved, 'file') && nargin == 0 && isequaln(getfield(load(saved, 'P'), 'P'), P)
    S = load(saved);                       % same settings as the saved run
else
    S = run_model(0.62, P, 'island_matched');
end
tr = S.trip.Time(find(S.trip.Data(:) > 0.5, 1));
ink = [0.13 0.44 0.71]; grey = [0.4 0.4 0.4];
fig = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 900 820]);
tl = tiledlayout(fig, 4, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
sig = {S.Vabc.Time, S.Vabc.Data(:,1),    'PCC voltage, phase a', 'V'; ...
       S.Igrid.Time, -S.Igrid.Data(:,1), 'Inverter current, phase a', 'A'; ...
       S.freq.Time, S.freq.Data,         'Measured frequency', 'Hz'; ...
       S.Vpcc_rms.Time, S.Vpcc_rms.Data, 'PCC voltage, RMS', 'pu'};
for k = 1:4
    ax = nexttile(tl); hold(ax, 'on');
    plot(ax, 1e3*sig{k,1}, sig{k,2}, 'Color', ink, 'LineWidth', 1.2);
    xline(ax, 1e3*P.tIsland, '--', 'Color', grey);
    if ~isempty(tr), xline(ax, 1e3*tr, '-', 'Color', grey); end
    xlim(ax, [440 620]); ylabel(ax, sig{k,4});
    title(ax, sig{k,3}, 'FontWeight', 'normal', 'FontSize', 10);
    ax.TitleHorizontalAlignment = 'left';
    set(ax, 'Box', 'off', 'FontSize', 10, 'YGrid', 'on', 'GridColor', [0.85 0.85 0.85], 'GridAlpha', 1);
    if k < 4, ax.XTickLabel = []; end
    if k == 3
        ylim(ax, [48 51]);
        text(ax, 1e3*P.tIsland - 1, 50.9, 'grid breaker opens ', 'HorizontalAlignment', 'right', ...
            'VerticalAlignment', 'top', 'Color', grey, 'FontSize', 10);
        if ~isempty(tr)
            text(ax, 1e3*tr + 1, 50.9, sprintf(' protection trips, %.1f ms later', 1e3*(tr - P.tIsland)), ...
                'VerticalAlignment', 'top', 'Color', grey, 'FontSize', 10);
        end
    end
end
xlabel(ax, 'Time (ms)');
title(tl, 'Islanding with a matched RLC load (Q_f = 1), passive detector, SCR 10', 'FontSize', 12);
root = fileparts(fileparts(mfilename('fullpath')));
exportgraphics(fig, fullfile(root, 'docs', 'islanding_matched.png'), 'Resolution', 150);
close(fig);
if ~isempty(tr), fprintf('Trip %.1f ms after islanding\n', 1e3*(tr - P.tIsland)); else, disp('No trip'); end
end

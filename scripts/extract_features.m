function T = extract_features(W, Wb, step)
% EXTRACT_FEATURES  Phase 6: sliding-window features for every case in data/raw/.
%   T = EXTRACT_FEATURES(W, WB, STEP) slides a window of W seconds (default
%   0.02) in steps of STEP (default 5 ms) over each case's record, each with
%   a baseline of the WB seconds before it (default 0.04), and returns one
%   row per window: the case's identity, the window's start and end times
%   relative to the event (te < 0 is before it), and the features of
%   WINDOW_FEATURES. A detector in service would do the same, one window
%   every STEP.
%   Training label y: 1 for windows of an island case that start no earlier
%   than W/2 before the grid breaker opens; 0 for every window of an
%   ordinary event and for windows that end before the event; NaN for the
%   few island windows that straddle the opening and are left out of
%   training (they are still used when a detector is evaluated).
%   Saves data/features/features_W<ms>.mat.
if nargin < 1 || isempty(W), W = 0.02; end
if nargin < 2 || isempty(Wb), Wb = 0.04; end
if nargin < 3 || isempty(step), step = 0.005; end
root = fileparts(fileparts(mfilename('fullpath')));
I = readtable(fullfile(root, 'results', 'dataset_index.csv'), 'TextType', 'string', 'VariableNamingRule', 'preserve');
P = params(10);
rows = cell(height(I), 1);
for k = 1:height(I)
    D = load(fullfile(root, 'data', 'raw', I.("case")(k) + ".mat"));
    tE = D.meta.tEvent - D.t0;                               % event time within the record (0.1 s)
    tEnd = (numel(D.freq) - 1)/D.fs;
    ts = (Wb:step:tEnd - W + 1e-9)';
    X = zeros(numel(ts), 22);
    for j = 1:numel(ts), [X(j,:), names] = window_features(D, ts(j), W, Wb, P); end
    te = ts + W - tE;  t0 = ts - tE;
    y = zeros(size(ts));
    if I.label(k) == 1
        y(t0 >= -W/2) = 1;
        y(te > 1e-9 & t0 < -W/2) = NaN;
    end
    n = numel(ts);
    rows{k} = [table(repmat(k, n, 1), repmat(I.("case")(k), n, 1), repmat(I.cond(k), n, 1), ...
        repmat(I.scr(k), n, 1), repmat(I.mix(k), n, 1), repmat(I.label(k), n, 1), repmat(I.event(k), n, 1), ...
        round(1e3*t0, 6), round(1e3*te, 6), y, ...
        'VariableNames', {'caseNo', 'case', 'cond', 'scr', 'mix', 'label', 'event', 'tStart_ms', 'tEnd_ms', 'y'}), ...
        array2table(X, 'VariableNames', names)];
end
T = vertcat(rows{:});
out = fullfile(root, 'data', 'features');
if ~exist(out, 'dir'), mkdir(out); end
save(fullfile(out, sprintf('features_W%02d.mat', round(1e3*W))), 'T', 'W', 'Wb', 'step');
fprintf('W = %g ms: %d windows from %d cases (%d island, %d not, %d left out of training)\n', ...
    1e3*W, height(T), height(I), sum(T.y == 1), sum(T.y == 0), sum(isnan(T.y)));
end

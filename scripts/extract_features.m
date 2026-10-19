function T = extract_features(W, Wb, step, level, set)
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
%
%   T = EXTRACT_FEATURES(W, WB, STEP, LEVEL) with LEVEL > 0 (Phase 7) first
%   adds measured sensor noise to every signal of every case: a randomly
%   placed stretch of one of the noise records of NOISE_CALIBRATION (chosen
%   at random per case), scaled by LEVEL (1 = the sensors of P.noise). The
%   windows are the same as without noise, row for row. Saves
%   data/features/features_W<ms>_noise<LEVEL>.mat.
%
%   T = EXTRACT_FEATURES(W, WB, STEP, LEVEL, 'feeder') does the same for the
%   feeder cases of FEEDER_DATASET (data/raw_feeder/), saving
%   data/features/feeder_features_W<ms>[_noise<LEVEL>].mat.
if nargin < 1 || isempty(W), W = 0.02; end
if nargin < 2 || isempty(Wb), Wb = 0.04; end
if nargin < 3 || isempty(step), step = 0.005; end
if nargin < 4 || isempty(level), level = 0; end
if nargin < 5, set = ''; end
root = fileparts(fileparts(mfilename('fullpath')));
src = struct('index', 'dataset_index.csv', 'raw', 'raw', 'prefix', '');
if strcmp(set, 'feeder'), src = struct('index', 'feeder_dataset_index.csv', 'raw', 'raw_feeder', 'prefix', 'feeder_'); end
I = readtable(fullfile(root, 'results', src.index), 'TextType', 'string', 'VariableNamingRule', 'preserve');
P = params(10);
if level > 0
    nf = dir(fullfile(root, 'data', 'noise', '*.mat'));
    N = arrayfun(@(f) load(fullfile(f.folder, f.name)), nf);
end
rows = cell(height(I), 1);
for k = 1:height(I)
    D = load(fullfile(root, 'data', src.raw, I.("case")(k) + ".mat"));
    if level > 0
        rng(1000*level + k);
        D = add_noise(D, N(randi(numel(N))), level);
    end
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
f = sprintf('%sfeatures_W%02d.mat', src.prefix, round(1e3*W));
if level > 0, f = sprintf('%sfeatures_W%02d_noise%g.mat', src.prefix, round(1e3*W), level); end
save(fullfile(out, f), 'T', 'W', 'Wb', 'step', 'level');
fprintf('W = %g ms, noise %g: %d windows from %d cases (%d island, %d not, %d left out of training)\n', ...
    1e3*W, level, height(T), height(I), sum(T.y == 1), sum(T.y == 0), sum(isnan(T.y)));
end

function D = add_noise(D, N, level)
% A random stretch of the noise record N, scaled by LEVEL, added to every signal.
n = numel(D.freq);
o = randi(numel(N.freq) - n + 1) - 1;                     % offset in ms, the same for both rates
r = D.fsWave/D.fs;
for s = {'freq', 'Vpcc_rms', 'VDC', 'ID', 'IQ'}
    D.(s{1}) = D.(s{1}) + level*N.(s{1})(o + (1:n));
end
nw = size(D.Vabc, 1);
for s = {'Vabc', 'Igrid'}
    D.(s{1}) = D.(s{1}) + level*N.(s{1})(r*o + (1:nw), :);
end
end

function S = train_classifiers(Ws, models, H)
% TRAIN_CLASSIFIERS  Phase 6: train and test islanding classifiers on unseen operating conditions.
%   S = TRAIN_CLASSIFIERS(WS, MODELS, H) uses the sliding-window features of
%   EXTRACT_FEATURES for each window length in WS (default [10 20 40] ms)
%   and each model in MODELS (default all four):
%     tree     one decision tree (minimum leaf 50 windows)
%     forest   bagged trees (100 trees, minimum leaf 5)
%     svm      support vector machine, Gaussian kernel, trained on 6000 windows
%     nn       neural network, two hidden layers of 20 and 10
%   Training uses the island windows that start within H ms after the grid
%   breaker opens (default 100): that is when a detector must act, and a
%   matched island seen much later looks like steady operation, which would
%   only teach the model to flag steady windows. All windows are kept for
%   testing.
%   Cases are never split: every test case comes from an operating condition
%   the model was not trained on. Two families of folds:
%     scr      hold out one grid strength (SCR 20, 10, 5 or 3) at a time
%     mix      hold out one PV/wind mix at a time
%   The window scores of every test case are saved to data/features/ and
%   replayed by REPLAY_DETECTOR for a range of decision thresholds and
%   debounce counts. Writes results/classifier_summary.csv.
if nargin < 1 || isempty(Ws), Ws = [10 20 40]; end
if nargin < 2 || isempty(models), models = {'tree', 'forest', 'svm', 'nn'}; end
if nargin < 3 || isempty(H), H = 100; end
root = fileparts(fileparts(mfilename('fullpath')));
for W = Ws
    L = load(fullfile(root, 'data', 'features', sprintf('features_W%02d.mat', W)));
    T = L.T; names = T.Properties.VariableNames(11:end);
    X = T{:, names};
    y = T.y; y(T.label == 1 & T.tStart_ms > H) = NaN;
    folds = [arrayfun(@(s) struct('family', "scr", 'name', "SCR " + s, 'test', T.scr == s), [20 10 5 3]), ...
             arrayfun(@(m) struct('family', "mix", 'name', m, 'test', T.mix == m), ["full" "pv" "wind" "low"])];
    for m = string(models)
        score = nan(height(T), 2);                 % columns: scr family, mix family
        for fo = folds
            rng(1);
            tr = ~fo.test & ~isnan(y);
            mdl = fit_detector(m, X(tr,:), y(tr));
            [~, sc] = predict(mdl, X(fo.test,:));
            score(fo.test, 1 + (fo.family == "mix")) = sc(:, 2);
            fprintf('W %2d ms  %-6s  %-8s done\n', W, m, fo.name);
        end
        save(fullfile(root, 'data', 'features', sprintf('scores_W%02d_%s.mat', W, m)), 'score', 'H');
    end
end
S = replay_detector(Ws, models);
end

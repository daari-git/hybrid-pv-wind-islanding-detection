function S = noise_study(Ws, models, levels, H)
% NOISE_STUDY  Phase 7: the classifiers with sensor noise, trained without and with it.
%   S = NOISE_STUDY(WS, MODELS, LEVELS, H) uses the folds of
%   TRAIN_CLASSIFIERS (one grid strength or one PV/wind mix held out at a
%   time, island windows within H ms of the breaker opening, default 100)
%   for each window length in WS (default [10 20 40] ms) and each model in
%   MODELS (default nn and svm), trained two ways:
%     clean   on the noise-free windows only, as in Phase 6
%     noisy   on the noise-free windows and the same windows with sensor
%             noise at level 1 (EXTRACT_FEATURES with LEVEL = 1)
%   Every held-out case is then scored at each noise level in LEVELS
%   (default [0 1 2] times the sensors of P.noise). Scores are saved to
%   data/features/scores_W<ms>_<model>_<training>_n<level>.mat and replayed
%   case by case by REPLAY_DETECTOR into results/classifier_summary_noise.csv
%   (the model column names model, training and test noise level).
if nargin < 1 || isempty(Ws), Ws = [10 20 40]; end
if nargin < 2 || isempty(models), models = {'nn', 'svm'}; end
if nargin < 3 || isempty(levels), levels = [0 1 2]; end
if nargin < 4 || isempty(H), H = 100; end
root = fileparts(fileparts(mfilename('fullpath')));
fd = fullfile(root, 'data', 'features');
names = {};
for W = Ws
    L = load(fullfile(fd, sprintf('features_W%02d.mat', W)));
    T = L.T; fn = T.Properties.VariableNames(11:end);
    X = cell(1, numel(levels));
    for j = 1:numel(levels)
        if levels(j) == 0, X{j} = T{:, fn}; continue; end
        Ln = load(fullfile(fd, sprintf('features_W%02d_noise%g.mat', W, levels(j))));
        assert(isequal(Ln.T.tEnd_ms, T.tEnd_ms) && isequal(Ln.T.caseNo, T.caseNo));
        X{j} = Ln.T{:, fn};
    end
    X1 = X{levels == 1};
    y = T.y; y(T.label == 1 & T.tStart_ms > H) = NaN;
    folds = [arrayfun(@(s) struct('family', "scr", 'name', "SCR " + s, 'test', T.scr == s), [20 10 5 3]), ...
             arrayfun(@(m) struct('family', "mix", 'name', m, 'test', T.mix == m), ["full" "pv" "wind" "low"])];
    for m = string(models)
        for train = ["clean", "noisy"]
            sc = repmat({nan(height(T), 2)}, 1, numel(levels));
            for fo = folds
                rng(1);
                tr = ~fo.test & ~isnan(y);
                if train == "clean", mdl = fit_detector(m, X{levels == 0}(tr,:), y(tr));
                else, mdl = fit_detector(m, [X{levels == 0}(tr,:); X1(tr,:)], [y(tr); y(tr)]); end
                for j = 1:numel(levels)
                    [~, p] = predict(mdl, X{j}(fo.test,:));
                    sc{j}(fo.test, 1 + (fo.family == "mix")) = p(:, 2);
                end
                fprintf('W %2d ms  %-4s  trained %-5s  %-8s done\n', W, m, train, fo.name);
            end
            for j = 1:numel(levels)
                nm = sprintf('%s_%s_n%g', m, train, levels(j));
                score = sc{j}; save(fullfile(fd, sprintf('scores_W%02d_%s.mat', W, nm)), 'score', 'H');
                names{end+1} = nm; %#ok<AGROW>
            end
        end
    end
end
S = replay_detector(Ws, unique(names), [], [], '_noise');
end

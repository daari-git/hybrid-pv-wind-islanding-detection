function final_classifier(W, thr, deb, H)
% FINAL_CLASSIFIER  Phase 6: the chosen detector, its feature importance, and the trained model.
%   FINAL_CLASSIFIER(W, THR, DEB, H) uses the neural network on W ms windows
%   (default 10) with decision threshold THR (default 0.5) and a trip after
%   DEB windows in a row (default 6), the setting chosen by the rule in the
%   README: among the settings with no steady-state alarm and at most 2%
%   false trips when one PV/wind mix at a time is held out, the one that
%   detects most islands.
%   1. Permutation importance: for each grid strength held out in turn, the
%      network is trained on the other three and each feature is shuffled
%      across the held-out windows; the fall in balanced accuracy over those
%      windows is the feature's importance (results/feature_importance.csv).
%   2. The final network is trained on all 400 cases and saved, with the
%      settings a relay needs, to ml/islanding_classifier.mat. The
%      chosen setting's replay of every case goes to results/detector_cases.csv.
if nargin < 1 || isempty(W), W = 10; end
if nargin < 2 || isempty(thr), thr = 0.5; end
if nargin < 3 || isempty(deb), deb = 6; end
if nargin < 4 || isempty(H), H = 100; end
root = fileparts(fileparts(mfilename('fullpath')));
L = load(fullfile(root, 'data', 'features', sprintf('features_W%02d.mat', W)));
T = L.T; names = T.Properties.VariableNames(11:end);
X = T{:, names};
y = T.y; y(T.label == 1 & T.tStart_ms > H) = NaN;
fit = @(X, y) fitcnet(X, y, 'LayerSizes', [20 10], 'Standardize', true, 'IterationLimit', 500);
bacc = @(yt, p) 0.5*(mean(p(yt == 1)) + mean(~p(yt == 0)));

imp = zeros(numel(names), 4); base = zeros(1, 4);
scrs = [20 10 5 3];
for k = 1:4
    rng(1);
    te = T.scr == scrs(k);
    tr = ~te & ~isnan(y); ts = te & ~isnan(y);
    mdl = fit(X(tr,:), y(tr));
    [~, s] = predict(mdl, X(ts,:)); base(k) = bacc(y(ts), s(:,2) > thr);
    for j = 1:numel(names)
        Xp = X(ts,:); Xp(:, j) = Xp(randperm(size(Xp, 1)), j);
        [~, s] = predict(mdl, Xp);
        imp(j, k) = base(k) - bacc(y(ts), s(:,2) > thr);
    end
    fprintf('SCR %d held out: balanced accuracy %.3f\n', scrs(k), base(k));
end
F = table(string(names'), mean(imp, 2), imp(:,1), imp(:,2), imp(:,3), imp(:,4), ...
    'VariableNames', {'feature', 'mean_drop', 'scr20', 'scr10', 'scr5', 'scr3'});
F = sortrows(F, 'mean_drop', 'descend');
disp(F);
writetable(F, fullfile(root, 'results', 'feature_importance.csv'));

% the chosen setting's result for every case, from the replay (grid strength held out)
C = readtable(fullfile(root, 'results', 'classifier_cases.csv'), 'TextType', 'string', 'VariableNamingRule', 'preserve');
C = C(C.model == "nn" & C.W_ms == W & C.family == "scr" & abs(C.threshold - thr) < 1e-9 & C.debounce == deb, :);
writetable(C, fullfile(root, 'results', 'detector_cases.csv'));

rng(1);
ok = ~isnan(y);
net = compact(fit(X(ok,:), y(ok)));
detector = struct('model', net, 'features', {names}, 'W', L.W, 'Wb', L.Wb, 'step', L.step, ...
    'threshold', thr, 'debounce', deb, 'trainedOn', '400 cases of data/raw (16 operating conditions)', ...
    'labelHorizon_ms', H);
out = fullfile(root, 'ml');
if ~exist(out, 'dir'), mkdir(out); end
save(fullfile(out, 'islanding_classifier.mat'), '-struct', 'detector');
fprintf('Saved ml/islanding_classifier.mat\n');
end

function final_classifier(W, thr, deb, H, noisy)
% FINAL_CLASSIFIER  The chosen detector, its feature importance, and the trained model.
%   FINAL_CLASSIFIER(W, THR, DEB, H, NOISY) uses the neural network on W ms
%   windows with decision threshold THR and a trip after DEB windows in a
%   row, the setting chosen by the rule in the README: among the settings
%   with no steady-state alarm and at most 2% false trips when one PV/wind
%   mix at a time is held out, the one that detects most islands.
%     NOISY = false (Phase 6): trained on the noise-free windows; defaults
%             W = 10, THR = 0.5, DEB = 6. Saved to
%             ml/islanding_classifier_noisefree.mat.
%     NOISY = true (Phase 7, the default): trained on the noise-free windows
%             and the same windows with sensor noise (level 1), importance and
%             replay on the noisy windows; W, THR and DEB from the Phase 7
%             choice. Saved to ml/islanding_classifier.mat, which the model's
%             detector block runs.
%   1. Permutation importance: for each grid strength held out in turn, the
%      network is trained on the other three and each feature is shuffled
%      across the held-out windows; the fall in balanced accuracy over those
%      windows is the feature's importance (results/feature_importance.csv,
%      or feature_importance_noisefree.csv).
%   2. The final network is trained on all 400 cases and saved with the
%      settings a relay needs. The chosen setting's replay of every case goes
%      to results/detector_cases.csv (detector_cases_noisefree.csv).
if nargin < 5 || isempty(noisy), noisy = true; end
d = [10 0.5 6];
root = fileparts(fileparts(mfilename('fullpath')));
if noisy                                                  % the choice of SELECT_DETECTOR
    Sel = readtable(fullfile(root, 'results', 'detector_selection.csv'), 'TextType', 'string');
    Sel = Sel(Sel.model == "nn" & Sel.training == "noisy", :);
    d = [Sel.W_ms(1) Sel.threshold(1) Sel.debounce(1)];
end
if nargin < 1 || isempty(W), W = d(1); end
if nargin < 2 || isempty(thr), thr = d(2); end
if nargin < 3 || isempty(deb), deb = d(3); end
if nargin < 4 || isempty(H), H = 100; end
fd = fullfile(root, 'data', 'features');
L = load(fullfile(fd, sprintf('features_W%02d.mat', W)));
T = L.T; names = T.Properties.VariableNames(11:end);
X = T{:, names}; Xt = X;
y = T.y; y(T.label == 1 & T.tStart_ms > H) = NaN;
sfx = '_noisefree'; trainedOn = '400 cases of data/raw (16 operating conditions), noise-free';
if noisy
    Ln = load(fullfile(fd, sprintf('features_W%02d_noise1.mat', W)));
    Xt = Ln.T{:, names};                                   % tested with noise
    sfx = ''; trainedOn = '400 cases of data/raw (16 operating conditions), noise-free and with sensor noise';
end
trainX = @(k) X(k,:); trainY = @(k) y(k);
if noisy, trainX = @(k) [X(k,:); Xt(k,:)]; trainY = @(k) [y(k); y(k)]; end
fit = @(X, y) fitcnet(X, y, 'LayerSizes', [20 10], 'Standardize', true, 'IterationLimit', 500);
bacc = @(yt, p) 0.5*(mean(p(yt == 1)) + mean(~p(yt == 0)));

imp = zeros(numel(names), 4); base = zeros(1, 4);
scrs = [20 10 5 3];
for k = 1:4
    rng(1);
    te = T.scr == scrs(k);
    tr = ~te & ~isnan(y); ts = te & ~isnan(y);
    mdl = fit(trainX(tr), trainY(tr));
    [~, s] = predict(mdl, Xt(ts,:)); base(k) = bacc(y(ts), s(:,2) > thr);
    for j = 1:numel(names)
        Xp = Xt(ts,:); Xp(:, j) = Xp(randperm(size(Xp, 1)), j);
        [~, s] = predict(mdl, Xp);
        imp(j, k) = base(k) - bacc(y(ts), s(:,2) > thr);
    end
    fprintf('SCR %d held out: balanced accuracy %.3f\n', scrs(k), base(k));
end
F = table(string(names'), mean(imp, 2), imp(:,1), imp(:,2), imp(:,3), imp(:,4), ...
    'VariableNames', {'feature', 'mean_drop', 'scr20', 'scr10', 'scr5', 'scr3'});
F = sortrows(F, 'mean_drop', 'descend');
disp(F);
writetable(F, fullfile(root, 'results', ['feature_importance' sfx '.csv']));

% the chosen setting's result for every case, from the replay (grid strength held out)
if noisy
    C = readtable(fullfile(root, 'results', 'classifier_cases_noise.csv'), 'TextType', 'string', 'VariableNamingRule', 'preserve');
    C = C(C.model == "nn_noisy_n1", :);
else
    C = readtable(fullfile(root, 'results', 'classifier_cases.csv'), 'TextType', 'string', 'VariableNamingRule', 'preserve');
    C = C(C.model == "nn", :);
end
C = C(C.W_ms == W & C.family == "scr" & abs(C.threshold - thr) < 1e-9 & C.debounce == deb, :);
writetable(C, fullfile(root, 'results', ['detector_cases' sfx '.csv']));

rng(1);
ok = ~isnan(y);
net = compact(fit(trainX(ok), trainY(ok)));
detector = struct('model', net, 'features', {names}, 'W', L.W, 'Wb', L.Wb, 'step', L.step, ...
    'threshold', thr, 'debounce', deb, 'trainedOn', trainedOn, 'labelHorizon_ms', H);
out = fullfile(root, 'ml');
if ~exist(out, 'dir'), mkdir(out); end
f = ['islanding_classifier' sfx '.mat'];
save(fullfile(out, f), '-struct', 'detector');
fprintf('Saved ml/%s\n', f);
end

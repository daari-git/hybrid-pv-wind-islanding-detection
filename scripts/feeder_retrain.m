function S = feeder_retrain(H)
% FEEDER_RETRAIN  The detector retrained with feeder cases (the feeder's Phases 6 and 7).
%   S = FEEDER_RETRAIN(H) trains the network of FINAL_CLASSIFIER, with the
%   same windows, threshold and debounce (not re-tuned), on the 400 test-bed
%   cases and the feeder cases of FEEDER_DATASET, each noise-free and with
%   sensor noise (level 1), island windows within H ms of the opening
%   (default 100). Every evaluation is a case-by-case replay at nominal
%   noise, as REPLAY_DETECTOR scores cases:
%     original   the Phase 7 detector (ml/islanding_classifier.mat) on the
%                feeder cases: how far it transfers without retraining
%     scr        one test-bed grid strength held out at a time, all feeder
%                cases in training: does adding the feeder cost anything
%                on the test bed (compare TABLE XI of the paper)
%     feeder     one feeder training condition held out at a time, all
%                test-bed cases in training
%   The network trained on everything is saved to
%   ml/islanding_classifier_feeder.mat (USE_DETECTOR runs it in the model).
%   Writes results/feeder_retrain_summary.csv and feeder_retrain_cases.csv.
%   Needs data/features/{feeder_}features_W<ms>{,_noise1}.mat (EXTRACT_FEATURES).
if nargin < 1 || isempty(H), H = 100; end
root = fileparts(fileparts(mfilename('fullpath')));
fd = fullfile(root, 'data', 'features');
M0 = load(fullfile(root, 'ml', 'islanding_classifier.mat'));
W = round(1e3*M0.W); thr = M0.threshold; deb = M0.debounce;
A = load(fullfile(fd, sprintf('features_W%02d.mat', W))).T;
A1 = load(fullfile(fd, sprintf('features_W%02d_noise1.mat', W))).T;
B = load(fullfile(fd, sprintf('feeder_features_W%02d.mat', W))).T;
B1 = load(fullfile(fd, sprintf('feeder_features_W%02d_noise1.mat', W))).T;
names = A.Properties.VariableNames(11:end);
yA = A.y; yA(A.label == 1 & A.tStart_ms > H) = NaN;
yB = B.y; yB(B.label == 1 & B.tStart_ms > H) = NaN;
XA = A{:, names}; XA1 = A1{:, names}; XB = B{:, names}; XB1 = B1{:, names};
fit = @(X, y) fitcnet(X, y, 'LayerSizes', [20 10], 'Standardize', true, 'IterationLimit', 500);
train = @(ka, kb) fit([XA(ka,:); XA1(ka,:); XB(kb,:); XB1(kb,:)], [yA(ka); yA(ka); yB(kb); yB(kb)]);
okA = ~isnan(yA); okB = ~isnan(yB);

C = table();
% the Phase 7 detector, unchanged, on the feeder cases
[~, s] = predict(M0.model, XB1);
C = [C; replay(B, s(:,2) > thr, deb, "original", "all feeder cases")];
% test-bed grid strengths held out, feeder cases in training
for scr = [20 10 5 3]
    rng(1);
    te = A.scr == scr;
    mdl = train(~te & okA, okB);
    [~, s] = predict(mdl, XA1(te,:));
    C = [C; replay(A(te,:), s(:,2) > thr, deb, "scr", "SCR " + scr)]; %#ok<AGROW>
    fprintf('SCR %d held out done\n', scr);
end
% feeder training conditions held out, all test-bed cases in training
conds = unique(B.cond, 'stable');
for k = 1:numel(conds)
    rng(1);
    te = B.cond == conds(k);
    mdl = train(okA, ~te & okB);
    [~, s] = predict(mdl, XB1(te,:));
    C = [C; replay(B(te,:), s(:,2) > thr, deb, "feeder", conds(k))]; %#ok<AGROW>
    fprintf('%s held out done\n', conds(k));
end
writetable(C, fullfile(root, 'results', 'feeder_retrain_cases.csv'));
S = summarise(C);
disp(S);
writetable(S, fullfile(root, 'results', 'feeder_retrain_summary.csv'));
fprintf('\nFalse trips by event:\n'); disp(groupcounts(C(C.falseTrip, :), {'evaluation', 'event'}));

rng(1);
net = compact(train(okA, okB));
detector = struct('model', net, 'features', {names}, 'W', M0.W, 'Wb', M0.Wb, 'step', M0.step, ...
    'threshold', thr, 'debounce', deb, 'labelHorizon_ms', H, 'trainedOn', sprintf(['400 test-bed cases ' ...
    '(data/raw) and %d feeder cases (data/raw_feeder), noise-free and with sensor noise'], numel(unique(B.caseNo))));
save(fullfile(root, 'ml', 'islanding_classifier_feeder.mat'), '-struct', 'detector');
fprintf('Saved ml/islanding_classifier_feeder.mat\n');
end

function R = replay(T, pos, d, evaluation, fold)
% Case by case, as REPLAY_DETECTOR: a trip once D windows in a row score above the threshold.
[g, ~] = findgroups(T.caseNo);
n = max(g); tTrip = inf(n, 1); first = zeros(n, 1);
for k = 1:n
    r = find(g == k);
    [te, o] = sort(T.tEnd_ms(r)); p = double(pos(r(o)));
    run = filter(ones(1, d), 1, p);
    c = find(run >= d, 1);
    if ~isempty(c), tTrip(k) = te(c); end
    first(k) = r(1);
end
isl = T.label(first) == 1;
R = table(repmat(evaluation, n, 1), repmat(string(fold), n, 1), T.("case")(first), T.cond(first), ...
    isl, string(T.event(first)), tTrip, tTrip <= 0, isl & isfinite(tTrip) & tTrip > 0, ...
    ~isl & isfinite(tTrip) & tTrip > 0, contains(T.("case")(first), "dP+00_dQ+0.0") & isl, ...
    'VariableNames', {'evaluation', 'fold', 'case', 'cond', 'island', 'event', 'tTrip_ms', ...
    'steadyAlarm', 'detected', 'falseTrip', 'matched'});
end

function S = summarise(C)
[g, ev, fo] = findgroups(C.evaluation, C.fold);
S = table(ev, fo, 'VariableNames', {'evaluation', 'fold'});
for k = 1:max(g)
    c = C(g == k, :); isl = c.island;
    S.cases(k) = height(c); S.islands(k) = sum(isl);
    S.detected_pct(k) = 100*mean(c.detected(isl));
    S.matched_pct(k) = 100*mean(c.detected(c.matched));
    S.falseTrip_pct(k) = 100*mean(c.falseTrip(~isl));
    S.steadyAlarm_pct(k) = 100*mean(c.steadyAlarm);
    S.median_ms(k) = median(c.tTrip_ms(c.detected));
end
for e = unique(C.evaluation, 'stable')'                    % totals over the folds of each evaluation
    c = C(C.evaluation == e, :); isl = c.island;
    S = [S; table(e, "total", height(c), sum(isl), 100*mean(c.detected(isl)), 100*mean(c.detected(c.matched)), ...
        100*mean(c.falseTrip(~isl)), 100*mean(c.steadyAlarm), median(c.tTrip_ms(c.detected)), ...
        'VariableNames', S.Properties.VariableNames)]; %#ok<AGROW>
end
end

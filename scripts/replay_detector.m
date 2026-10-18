function S = replay_detector(Ws, models, thr, deb, tag)
% REPLAY_DETECTOR  Phase 6: run saved classifier scores as a relay would, case by case.
%   S = REPLAY_DETECTOR(WS, MODELS, THR, DEB) takes the test scores saved by
%   TRAIN_CLASSIFIERS and, for every decision threshold in THR (default
%   0.5:0.1:0.9) and debounce count in DEB (default [2 3 4 6 8 10]), replays each
%   test case one window at a time (a window every 5 ms): the detector trips
%   once DEB windows in a row score above THR. For every case:
%     island          detected if the trip comes after the breaker opens,
%                     with the detection time measured to the end of the
%                     window that confirmed it
%     ordinary event  a trip after the event is a false trip
%     either          a trip before the event is a false alarm in steady
%                     operation
%   Writes results/classifier_cases.csv (every case, every setting) and
%   results/classifier_summary.csv (one row per window length, model, fold
%   family, threshold and debounce). With TAG (Phase 7) the outputs are
%   classifier_cases<TAG>.csv and classifier_summary<TAG>.csv.
if nargin < 3 || isempty(thr), thr = 0.5:0.1:0.9; end
if nargin < 4 || isempty(deb), deb = [2 3 4 6 8 10]; end
if nargin < 5, tag = ''; end
root = fileparts(fileparts(mfilename('fullpath')));
C = cell(0, 1);
for W = Ws
    L = load(fullfile(root, 'data', 'features', sprintf('features_W%02d.mat', W)));
    T = L.T(:, 1:10);
    [g, ~] = findgroups(T.caseNo);
    for m = string(models)
        f = fullfile(root, 'data', 'features', sprintf('scores_W%02d_%s.mat', W, m));
        if ~exist(f, 'file'), continue; end
        sc = load(f).score;
        for fam = ["scr", "mix"]
            s = sc(:, 1 + (fam == "mix"));
            for th = thr
                for d = deb
                    C{end+1} = replay(T, g, s > th, W, m, fam, th, d); %#ok<AGROW>
                end
            end
        end
    end
end
C = vertcat(C{:});
writetable(C, fullfile(root, 'results', ['classifier_cases' tag '.csv']));
S = summarise(C);
writetable(S, fullfile(root, 'results', ['classifier_summary' tag '.csv']));
end

function R = replay(T, g, pos, W, m, fam, th, d)
n = max(g);
tTrip = inf(n, 1); first = zeros(n, 1);
for k = 1:n
    r = find(g == k);
    [te, o] = sort(T.tEnd_ms(r)); p = double(pos(r(o)));
    run = filter(ones(1, d), 1, p);                 % windows in a row above threshold
    c = find(run >= d, 1);
    if ~isempty(c), tTrip(k) = te(c); end
    first(k) = r(1);
end
isl = T.label(first) == 1;
R = table(repmat(W, n, 1), repmat(m, n, 1), repmat(fam, n, 1), repmat(th, n, 1), repmat(d, n, 1), ...
    T.("case")(first), T.scr(first), T.mix(first), isl, T.event(first), tTrip, ...
    tTrip <= 0, isl & isfinite(tTrip) & tTrip > 0, ~isl & isfinite(tTrip) & tTrip > 0, ...
    'VariableNames', {'W_ms', 'model', 'family', 'threshold', 'debounce', 'case', 'scr', 'mix', ...
    'island', 'event', 'tTrip_ms', 'steadyAlarm', 'detected', 'falseTrip'});
end

function S = summarise(C)
[g, W, m, fam, th, d] = findgroups(C.W_ms, C.model, C.family, C.threshold, C.debounce);
S = table(W, m, fam, th, d, 'VariableNames', {'W_ms', 'model', 'family', 'threshold', 'debounce'});
for k = 1:max(g)
    c = C(g == k, :); isl = c.island;
    t = c.tTrip_ms(c.detected);
    matched = isl & contains(c.("case"), "dP+00_dQ+0.0");
    S.detected_pct(k)        = 100*mean(c.detected(isl));
    S.detected_unmatched_pct(k) = 100*mean(c.detected(isl & ~matched));
    S.detected_matched_pct(k)   = 100*mean(c.detected(matched));
    S.falseTrip_pct(k)       = 100*mean(c.falseTrip(~isl));
    S.steadyAlarm_pct(k)     = 100*mean(c.steadyAlarm);
    S.median_ms(k)           = median(t);
    S.p95_ms(k)              = prctile(t, 95);
end
end

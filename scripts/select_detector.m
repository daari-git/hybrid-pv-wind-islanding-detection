function T = select_detector()
% SELECT_DETECTOR  Phase 7: the choice of detector, by the rule fixed in Phase 6.
%   T = SELECT_DETECTOR() reads results/classifier_summary_noise.csv
%   (NOISE_STUDY) and, for each model and training (without or with noise),
%   applies the rule to the PV/wind-mix folds at the nominal noise level: no
%   steady-state alarm, at most 2% false trips, then the most islands
%   detected (ties: the shorter median detection time). The chosen setting
%   is then reported on the grid-strength folds, which played no part in the
%   choice, at every noise level. Only the neural network can run inside the
%   model; the SVM is reported for comparison. Writes
%   results/detector_selection.csv.
root = fileparts(fileparts(mfilename('fullpath')));
S = readtable(fullfile(root, 'results', 'classifier_summary_noise.csv'), 'TextType', 'string');
p = split(S.model, "_"); S.base = p(:,1); S.train = p(:,2); S.level = double(extractAfter(p(:,3), 1));
T = table();
for base = ["nn", "svm"]
    for tr = ["clean", "noisy"]
        m = S(S.base == base & S.train == tr & S.level == 1 & S.family == "mix" & ...
            S.steadyAlarm_pct == 0 & S.falseTrip_pct <= 2, :);
        if isempty(m), continue; end
        m = sortrows(m, {'detected_pct', 'median_ms'}, {'descend', 'ascend'});
        b = m(1,:);
        r = S(S.base == base & S.train == tr & S.W_ms == b.W_ms & S.family == "scr" & ...
            abs(S.threshold - b.threshold) < 1e-9 & S.debounce == b.debounce, :);
        r = sortrows(r, 'level');
        T = [T; r(:, {'W_ms', 'base', 'train', 'threshold', 'debounce', 'level', 'detected_pct', ...
            'detected_matched_pct', 'falseTrip_pct', 'steadyAlarm_pct', 'median_ms', 'p95_ms'})]; %#ok<AGROW>
    end
end
T = renamevars(T, {'base', 'train', 'level'}, {'model', 'training', 'noise_level'});
disp(T);
writetable(T, fullfile(root, 'results', 'detector_selection.csv'));
end

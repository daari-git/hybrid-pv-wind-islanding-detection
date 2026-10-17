function T = evaluate_ndz(dPs, dQs)
% EVALUATE_NDZ  Replay the saved islanding runs through each baseline detector.
%   Writes results/ndz_sweep.csv with one row per mismatch pair and detector.
root = fileparts(fileparts(mfilename('fullpath')));
P0 = params(10);
det = {'Fast passive', 0, P0.relay.fast; 'IEEE passive', 0, P0.relay.ieee; 'IEEE + AFD', 1, P0.relay.ieee};
T = table();
for d = 1:size(det, 1)
    for dP = dPs
        for dQ = dQs
            f = fullfile(root, 'results', 'ndz', sprintf('afd%d_dP%+04.0f_dQ%+05.1f.mat', det{d,2}, 100*dP, 100*dQ));
            if ~exist(f, 'file'), continue; end
            R = load(f);
            D = detect_islanding(R, det{d,3}, R.P.tIsland);
            detected = D.trip && D.t <= P0.relay.tMax;
            T = [T; table(string(det{d,1}), 100*dP, 100*dQ, detected, 1e3*D.t, string(D.element), ...
                1e3*(D.falseTrip - R.P.tIsland), R.pre.thd, R.pre.Q, ...
                'VariableNames', {'detector','dP_pct','dQ_pct','detected','t_ms','element','falseTrip_ms','THDi_pre_pct','Q_pre_var'})]; %#ok<AGROW>
        end
    end
end
writetable(T, fullfile(root, 'results', 'ndz_sweep.csv'));
for d = 1:size(det, 1)
    r = T(T.detector == det{d,1}, :);
    fprintf('%-13s detected %2d of %2d, median time %.0f ms\n', det{d,1}, sum(r.detected), height(r), ...
        median(r.t_ms(r.detected)));
end
end

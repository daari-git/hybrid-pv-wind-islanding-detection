function T = ndz_sweep(dPs, dQs)
% NDZ_SWEEP  Phase 4: non-detection zones of the baseline islanding detectors.
%   For every active/reactive mismatch pair, the grid breaker opens at 0.4 s
%   and the run continues for the 2 s that IEEE 1547-2018 allows. Each run is
%   made twice, without and with active frequency drift (AFD). Three detectors
%   are then evaluated offline on the logged signals:
%     fast passive   instantaneous V/f/ROCOF trip (the model's own settings)
%     IEEE passive   IEEE 1547-2018 Category II trip settings, no AFD
%     IEEE + AFD     the same settings with active frequency drift running
%   Reduced signals (1 ms) are kept in results/ndz/ so other relay settings can
%   be evaluated later without simulating again. Finished points are skipped.
if nargin < 1 || isempty(dPs), dPs = [-0.20 -0.10 -0.05 0 0.05 0.10 0.20]; end
if nargin < 2 || isempty(dQs), dQs = [-0.05 -0.025 0 0.025 0.05]; end
root = fileparts(fileparts(mfilename('fullpath')));
out  = fullfile(root, 'results', 'ndz');
if ~exist(out, 'dir'), mkdir(out); end
tI = 0.4; tEnd = tI + 2.05;
P0 = params(10);
for afd = [0 1]
    for dP = dPs
        for dQ = dQs
            f = fullfile(out, sprintf('afd%d_dP%+04.0f_dQ%+05.1f.mat', afd, 100*dP, 100*dQ));
            if exist(f, 'file'), continue; end
            P = island_case(P0, dP, dQ, tI);
            P.afd.on = afd;
            fprintf('\n##### AFD %d, dP %+.1f %%, dQ %+.1f %%\n', afd, 100*dP, 100*dQ);
            S = run_model(tEnd, P, '');
            R = reduce_run(S, 0.2, 0.4);           % 1 ms signals; power quality before the island
            save(f, '-struct', 'R');
        end
    end
end
T = evaluate_ndz(dPs, dQs);
end

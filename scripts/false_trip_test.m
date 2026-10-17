function T = false_trip_test()
% FALSE_TRIP_TEST  Phase 4: do the baseline detectors trip when there is no island?
%   Eleven ordinary disturbances, each at 0.5 s with the grid connected, run
%   without and with active frequency drift. Every detector trip is a false
%   trip. Most of these events are ones IEEE 1547-2018 requires a DER to ride
%   through. Writes results/false_trips.csv.
root = fileparts(fileparts(mfilename('fullpath')));
ev = disturbance_events();
P0 = params(10);
det = {'Fast passive', 0, P0.relay.fast; 'IEEE passive', 0, P0.relay.ieee; 'IEEE + AFD', 1, P0.relay.ieee};
T = table();
for afd = [0 1]
    for k = 1:numel(ev)
        P = ev(k).set(params(10));
        P.prot.tArm = 1e6;  P.afd.on = afd;
        fprintf('\n##### AFD %d, %s\n', afd, ev(k).name);
        S = run_model(2.45, P, '');
        for d = find([det{:,2}] == afd)
            D = detect_islanding(S, det{d,3}, Inf);        % no island: any trip is false
            M = signal_metrics(S, 2.25, 2.45);
            T = [T; table(string(det{d,1}), string(ev(k).name), ~isnan(D.falseTrip), ...
                1e3*(D.falseTrip - 0.5), min(S.Vpcc_rms.Data(S.Vpcc_rms.Time > 0.4)), ...
                max(abs(S.freq.Data(S.freq.Time > 0.4) - 50)), M.thd, ...
                'VariableNames', {'detector','event','falseTrip','t_ms','Vmin_pu','maxDf_Hz','THDi_end_pct'})]; %#ok<AGROW>
        end
    end
end
writetable(T, fullfile(root, 'results', 'false_trips.csv'));
for d = 1:size(det, 1)
    r = T(T.detector == det{d,1}, :);
    fprintf('%-13s false trips on %d of %d events\n', det{d,1}, sum(r.falseTrip), height(r));
end
end

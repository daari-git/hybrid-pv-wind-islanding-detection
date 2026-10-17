function T = false_trip_test()
% FALSE_TRIP_TEST  Phase 4: do the baseline detectors trip when there is no island?
%   Eleven ordinary disturbances, each at 0.5 s with the grid connected, run
%   without and with active frequency drift. Every detector trip is a false
%   trip. Most of these events are ones IEEE 1547-2018 requires a DER to ride
%   through. Writes results/false_trips.csv.
root = fileparts(fileparts(mfilename('fullpath')));
ev = events();
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

function ev = events()
e = @(name, f) struct('name', name, 'set', f);
ev = [ ...
 e('Irradiance 1000 to 600 W/m2',  @(P) setf(P, 'pv', struct('G1', 600, 'tStep', 0.5))), ...
 e('Irradiance 600 to 1000 W/m2',  @(P) setf(P, 'pv', struct('G0', 600, 'G1', 1000, 'tStep', 0.5))), ...
 e('Wind 12 to 9 m/s',             @(P) setf(P, 'wind', struct('v1', 9, 'tStep', 0.5))), ...
 e('Load switched on (+6 kW)',     @(P) setf(P, 'event', struct('loadT', 0.5))), ...
 e('Capacitor switched on (5 kvar)', @(P) setf(P, 'event', struct('capT', 0.5))), ...
 e('Voltage sag to 0.7 pu, 0.5 s', @(P) setf(P, 'event', struct('entity', 'Amplitude', 'type', 'Table of time-amplitude pairs', 'amp', [1 0.7 1], 'time', [0 0.5 1.0]))), ...
 e('Voltage sag to 0.5 pu, 0.2 s', @(P) setf(P, 'event', struct('entity', 'Amplitude', 'type', 'Table of time-amplitude pairs', 'amp', [1 0.5 1], 'time', [0 0.5 0.7]))), ...
 e('Voltage swell to 1.15 pu, 0.5 s', @(P) setf(P, 'event', struct('entity', 'Amplitude', 'type', 'Table of time-amplitude pairs', 'amp', [1 1.15 1], 'time', [0 0.5 1.0]))), ...
 e('Frequency ramp -2 Hz/s for 0.5 s', @(P) setf(P, 'event', struct('entity', 'Frequency', 'type', 'Ramp', 'rate', -2, 'timing', [0.5 1.0]))), ...
 e('Frequency ramp +2 Hz/s for 0.5 s', @(P) setf(P, 'event', struct('entity', 'Frequency', 'type', 'Ramp', 'rate', 2, 'timing', [0.5 1.0]))), ...
 e('Phase jump 20 deg',            @(P) setf(P, 'event', struct('entity', 'Phase', 'type', 'Step', 'step', 20, 'timing', [0.5 1e6]))) ];
end

function P = setf(P, group, vals)
% Overwrite the named fields of P.(group).
f = fieldnames(vals);
for k = 1:numel(f), P.(group).(f{k}) = vals.(f{k}); end
if strcmp(group, 'wind') && isfield(vals, 'v0'), P.wind.wm0 = P.wind.lamOpt*P.wind.v0/P.wind.R; end
end

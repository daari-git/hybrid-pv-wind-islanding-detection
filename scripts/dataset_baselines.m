function T = dataset_baselines()
% DATASET_BASELINES  Phase 5: the passive relays on the dataset's own windows.
%   Replays every case in data/raw/ (0.1 s before to 0.35 s after the event)
%   through the fast passive settings and the IEEE 1547-2018 settings. Within
%   0.35 s only the IEEE elements with short clearing times (0.16 s) can act.
%   A trip after the event is a detection for an island and a false trip for
%   an ordinary event. This is the baseline the classifier of Phase 6 has to
%   beat on the same cases. Writes results/dataset_baselines.csv.
root = fileparts(fileparts(mfilename('fullpath')));
I = readtable(fullfile(root, 'results', 'dataset_index.csv'), 'TextType', 'string', 'VariableNamingRule', 'preserve');
P0 = params(10);
det = {'Fast passive', P0.relay.fast; 'IEEE passive', P0.relay.ieee};
T = table();
for k = 1:height(I)
    D = load(fullfile(root, 'data', 'raw', I.("case")(k) + ".mat"));
    t = D.t0 + (0:numel(D.freq) - 1)'/D.fs;
    S.P.prot.tBlank = D.t0;
    S.freq = timeseries(double(D.freq), t);
    S.Vpcc_rms = timeseries(double(D.Vpcc_rms), t);
    for d = 1:size(det, 1)
        R = detect_islanding(S, det{d,2}, D.meta.tEvent);
        T = [T; table(I.("case")(k), I.cond(k), I.scr(k), I.label(k), I.event(k), string(det{d,1}), ...
            R.trip, 1e3*R.t, string(R.element), ...
            'VariableNames', {'case','cond','scr','label','event','detector','trip','t_ms','element'})]; %#ok<AGROW>
    end
end
writetable(T, fullfile(root, 'results', 'dataset_baselines.csv'));
for d = 1:size(det, 1)
    r = T(T.detector == det{d,1}, :);
    isl = r.label == 1;
    fprintf('%-13s islands detected %d of %d (median %.0f ms); ordinary events tripped %d of %d\n', det{d,1}, ...
        sum(r.trip(isl)), sum(isl), median(r.t_ms(isl & r.trip)), sum(r.trip(~isl)), sum(~isl));
end
end

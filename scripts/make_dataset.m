function T = make_dataset(which)
% MAKE_DATASET  Phase 5: labelled islanding and non-islanding events for the classifier.
%   For each operating condition (OPERATING_CONDITIONS, or the indices in
%   WHICH) the dataset holds 25 cases, all with active frequency drift off,
%   since the detector to be trained is passive:
%     14 islands   Q_f 1 and 2.5, each at seven active/reactive mismatches
%                  (dP, dQ in %): (0,0) (+5,0) (-5,0) (0,+2.5) (0,-2.5)
%                  (+15,+5) (-15,-5)
%     11 events    the ordinary disturbances of DISTURBANCE_EVENTS, with the
%                  same local load as a matched island (Q_f alternating 1, 2.5)
%   Event times are spread over one 20 ms cycle so the point on the wave
%   varies. Each case is saved to data/raw/<case>.mat with a META struct
%   (label 1 = island) and the signals from 0.1 s before to 0.35 s after
%   the event: PCC voltage and inverter current waveforms at 10 kHz, and
%   frequency, RMS voltage, DC-link voltage and d/q currents at 1 kHz.
%   Finished cases are skipped. The index is written to data/raw/index.csv
%   and results/dataset_index.csv.
root = fileparts(fileparts(mfilename('fullpath')));
out = fullfile(root, 'data', 'raw');
if ~exist(out, 'dir'), mkdir(out); end
C = operating_conditions();
if nargin < 1 || isempty(which), which = 1:numel(C); end
mm = [0 0; 5 0; -5 0; 0 2.5; 0 -2.5; 15 5; -15 -5]/100;
pre = 0.1; post = 0.35;
n = 0;
for ci = which
    c = C(ci);
    cases = struct('name', {}, 'label', {}, 'Qf', {}, 'dP', {}, 'dQ', {}, 'event', {});
    for Qf = [1 2.5]
        for j = 1:size(mm, 1)
            cases(end+1) = struct('name', sprintf('%s_island_qf%g_dP%+03.0f_dQ%+04.1f', c.id, Qf, 100*mm(j,1), 100*mm(j,2)), ...
                'label', 1, 'Qf', Qf, 'dP', mm(j,1), 'dQ', mm(j,2), 'event', 0); %#ok<AGROW>
        end
    end
    for e = 1:11
        cases(end+1) = struct('name', sprintf('%s_event%02d', c.id, e), 'label', 0, ...
            'Qf', 1 + 1.5*(mod(e, 2) == 0), 'dP', 0, 'dQ', 0, 'event', e); %#ok<AGROW>
    end
    for k = 1:numel(cases)
        q = cases(k); f = fullfile(out, [q.name '.mat']);
        n = n + 1;
        if exist(f, 'file'), continue; end
        tE = c.tEvent + 0.02*mod(0.618034*(k + 25*ci), 1);   % point on the wave varies over one cycle
        P = condition_params(c);
        P.load.Qf = q.Qf; P.afd.on = 0;
        ev = disturbance_events(tE, c.G, c.v);
        if q.label == 1
            P = island_case(P, q.dP, q.dQ, tE); evName = 'Island';
        else
            P = island_case(P, 0, 0, 1e6); P = ev(q.event).set(P); evName = ev(q.event).name;
        end
        fprintf('\n##### [%d] %s\n', n, q.name);
        S = run_model(tE + post + 1e-3, P, '');
        meta = struct('case', q.name, 'cond', c.id, 'scr', c.scr, 'mix', c.mix, 'G', c.G, 'v', c.v, ...
            'label', q.label, 'event', evName, 'Qf', q.Qf, 'dP', q.dP, 'dQ', q.dQ, 'tEvent', tE, ...
            'Pinv', P.island.Pinv, 'Qinv', P.island.Qinv, 'Pload', P.load.P);
        D = window(S, tE, pre, post);
        D.meta = meta;
        for attempt = 1:5                                % a refused write is retried; a partial file is removed
            try, save(f, '-struct', 'D'); break; catch err
                if exist(f, 'file'), delete(f); end
                if attempt == 5, rethrow(err); end
                pause(5);
            end
        end
    end
end
T = write_index(root, out);
end

function D = window(S, tE, pre, post)
% Signals from tE - pre to tE + post: waveforms at 10 kHz, the rest at 1 kHz.
tw = (tE - pre:1e-4:tE + post)';
D.t0 = tE - pre; D.fsWave = 1e4; D.fs = 1e3;
D.Vabc  = single(interp1(S.Vabc.Time,  double(S.Vabc.Data),  tw));
D.Igrid = single(interp1(S.Igrid.Time, double(S.Igrid.Data), tw));
ts = (tE - pre:1e-3:tE + post)';
for n = {'freq', 'Vpcc_rms', 'VDC', 'ID', 'IQ'}
    x = S.(n{1});
    D.(n{1}) = single(interp1(x.Time, double(x.Data(:,1)), ts));
end
end

function T = write_index(root, out)
fl = dir(fullfile(out, '*.mat'));
m = cell(numel(fl), 1);
for k = 1:numel(fl)
    s = load(fullfile(out, fl(k).name), 'meta'); m{k} = s.meta;
end
T = struct2table([m{:}]);
writetable(T, fullfile(out, 'index.csv'));
writetable(T, fullfile(root, 'results', 'dataset_index.csv'));
fprintf('Dataset: %d cases (%d islands, %d other events)\n', height(T), sum(T.label == 1), sum(T.label == 0));
end

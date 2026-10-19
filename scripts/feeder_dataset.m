function T = feeder_dataset()
% FEEDER_DATASET  Labelled feeder cases for training the detector (the feeder's Phase 5).
%   For each condition of FEEDER_TRAIN_CONDITIONS, 32 cases with active
%   frequency drift and sensor noise off, recorded as MAKE_DATASET records
%   them (0.1 s before to 0.35 s after the event) in data/raw_feeder/:
%     8 islands at the unit's breaker   Q_f 1 and 2.5 at (dP, dQ) in % of
%                  (0, 0), (+5, 0), (0, -2.5), (-15, -5), local load sized as
%                  in FEEDER_CLOSED_LOOP
%     6 islands of the whole feeder     with the other generation at B3,
%                  Q_f 1 and 2.5 at (0, 0), (-5, 0), (0, +2.5) (FEEDER_ISLAND_CASE)
%     1 natural feeder island           the unit alone, no local load
%     11 ordinary events of DISTURBANCE_EVENTS, with a 2 kW household load
%                  (odd events) or no local load (even events)
%     3 feeder events                   a load at B3 switched on (5 and 15 kW)
%                  and a 10 kW load switched off, household load at the PCC
%     2 steady runs                     no event, household load or none
%   The index goes to data/raw_feeder/index.csv and
%   results/feeder_dataset_index.csv. Finished cases are skipped.
root = fileparts(fileparts(mfilename('fullpath')));
out = fullfile(root, 'data', 'raw_feeder');
if ~exist(out, 'dir'), mkdir(out); end
C = feeder_train_conditions();
feeder_operating_points(C);
pre = 0.1; post = 0.35;
svc = [1 0 0; 1 5 0; 1 0 -2.5; 1 -15 -5; 2.5 0 0; 2.5 5 0; 2.5 0 -2.5; 2.5 -15 -5];
dt = [1 0 0; 1 -5 0; 1 0 2.5; 2.5 0 0; 2.5 -5 0; 2.5 0 2.5];
nm = @(c, kind, r) sprintf('%s_%s_island_qf%g_dP%+03.0f_dQ%+04.1f', c.id, kind, r(1), r(2), r(3));
n = 0;
for ci = 1:numel(C)
    c = C(ci);
    Q = struct('name', {}, 'label', {}, 'kind', {}, 'Qf', {}, 'dP', {}, 'dQ', {}, 'event', {}, 'local', {});
    for j = 1:size(svc, 1)
        Q(end+1) = struct('name', nm(c, 'svc', svc(j,:)), 'label', 1, 'kind', 'svc', 'Qf', svc(j,1), ...
            'dP', svc(j,2)/100, 'dQ', svc(j,3)/100, 'event', 0, 'local', 'matched'); %#ok<AGROW>
    end
    for j = 1:size(dt, 1)
        Q(end+1) = struct('name', nm(c, 'dt', dt(j,:)), 'label', 1, 'kind', 'dt', 'Qf', dt(j,1), ...
            'dP', dt(j,2)/100, 'dQ', dt(j,3)/100, 'event', 0, 'local', 'matched'); %#ok<AGROW>
    end
    Q(end+1) = struct('name', [c.id '_dt_island_natural'], 'label', 1, 'kind', 'dt', 'Qf', 0, 'dP', 0, 'dQ', 0, ...
        'event', 0, 'local', 'none'); %#ok<AGROW>
    for e = 1:14
        loc = 'household'; if e <= 11 && mod(e, 2) == 0, loc = 'none'; end
        Q(end+1) = struct('name', sprintf('%s_event%02d', c.id, e), 'label', 0, 'kind', 'none', 'Qf', NaN, ...
            'dP', 0, 'dQ', 0, 'event', e, 'local', loc); %#ok<AGROW>
    end
    for loc = {'household', 'none'}
        Q(end+1) = struct('name', sprintf('%s_steady_%s', c.id, loc{1}), 'label', 0, 'kind', 'none', 'Qf', NaN, ...
            'dP', 0, 'dQ', 0, 'event', 0, 'local', loc{1}); %#ok<AGROW>
    end
    for k = 1:numel(Q)
        q = Q(k); f = fullfile(out, [q.name '.mat']);
        n = n + 1;
        if exist(f, 'file'), continue; end
        tE = c.tEvent + 0.02*mod(0.618034*(k + 32*ci), 1);   % point on the wave varies over one cycle
        P = feeder_condition_params(c);
        P.afd.on = 0;
        switch q.kind
            case 'svc'
                P.load.Qf = q.Qf; P = at_pcc_voltage(island_case(P, q.dP, q.dQ, tE));
            case 'dt'
                P.der2.on = double(q.Qf > 0);
                P = feeder_island_case(P, q.dP, q.dQ, q.Qf, tE);
            otherwise
                P = island_case(P, 0, 0, 1e6);
                if strcmp(q.local, 'household')
                    P.load.P = 2000; P.load.QL = 2000*tan(acos(0.95)); P.load.QC = 0;
                else
                    P.load.P = 200; P.load.QL = 200; P.load.QC = 200;
                end
                [P, evName] = feeder_train_event(P, q.event, tE, c);
        end
        if q.label == 1, evName = 'Island'; end
        fprintf('\n##### [%d] %s\n', n, q.name);
        S = run_model(tE + post + 1e-3, P, '');
        meta = struct('case', q.name, 'cond', c.id, 'scr', P.grid.scr, 'mix', c.mix, 'G', c.G, 'v', c.v, ...
            'label', q.label, 'event', evName, 'Qf', q.Qf, 'dP', q.dP, 'dQ', q.dQ, 'tEvent', tE, ...
            'Pinv', P.island.Pinv, 'Qinv', P.island.Qinv, 'Pload', P.load.P, 'kind', q.kind, ...
            'local', q.local, 'pcc', c.pcc, 'load', c.load);
        D = window(S, tE, pre, post);
        D.meta = meta;
        save(f, '-struct', 'D');
    end
end
T = write_index(root, out);
end

function P = at_pcc_voltage(P)
% As in FEEDER_CLOSED_LOOP: the local load's 400 V ratings scaled to the feeder's voltage at the PCC.
V = P.feeder.Vlf(P.feeder.pcc);
P.load.P = P.load.P/V^2; P.load.QL = P.load.QL/V^2; P.load.QC = P.load.QC/V^2;
end

function [P, name] = feeder_train_event(P, e, tE, c)
% Events 1-11 of DISTURBANCE_EVENTS; 12, 13: a 5 or 15 kW load at B3 switched
% on; 14: a 10 kW load at B3 switched off; 0: no event.
pf = tan(acos(0.85));
switch e
    case 0
        name = 'none';
    case num2cell(1:11)
        ev = disturbance_events(tE, c.G, c.v); P = ev(e).set(P); name = ev(e).name;
    case {12, 13}
        P.feeder.swP = 5e3 + 10e3*(e == 13); P.feeder.swQ = P.feeder.swP*pf; P.feeder.swT = [tE 1e6];
        name = sprintf('Feeder load at B3 switched on (+%g kW)', P.feeder.swP/1e3);
    otherwise
        P.feeder.swP = 10e3; P.feeder.swQ = 10e3*pf; P.feeder.swT = [0.05 tE];
        name = 'Feeder load at B3 switched off (-10 kW)';
end
end

function D = window(S, tE, pre, post)
% Signals from tE - pre to tE + post, as MAKE_DATASET records them.
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
writetable(T, fullfile(root, 'results', 'feeder_dataset_index.csv'));
fprintf('Feeder dataset: %d cases (%d islands, %d other events)\n', height(T), sum(T.label == 1), sum(T.label == 0));
end

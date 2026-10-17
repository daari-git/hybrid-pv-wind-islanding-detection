function T = afd_stress()
% AFD_STRESS  Phase 5: conditions in which active frequency drift is known to struggle.
%   Phase 4 found that the IEEE 1547-2018 settings with active frequency drift
%   (AFD) detect every island at SCR 10 with Q_f = 1. This tests it where the
%   literature says it weakens:
%     qf      load quality factor 2.5 (SCR 10, five mismatches)
%     weak    matched island on a weak grid (SCR 3 and 2, Q_f 1; SCR 3, Q_f 2.5)
%     weakft  AFD running on a weak grid, five ordinary events: false trips?
%     multi   a second 10 kW inverter at the PCC whose reactive power follows
%             the frequency at Kq var/Hz: 0 (no drift), +1000 and +2000 (the
%             same direction as the main inverter's drift) and -2000 (the
%             opposite direction, equal in size to the main inverter's drift)
%     control the weak-grid case that tripped, repeated without drift
%   Every case uses the IEEE settings and allows 2 s after the event. Reduced
%   runs go to results/stress/; finished cases are skipped. Writes
%   results/afd_stress.csv.
root = fileparts(fileparts(mfilename('fullpath')));
out = fullfile(root, 'results', 'stress');
if ~exist(out, 'dir'), mkdir(out); end
C = operating_conditions(); full10 = C(strcmp({C.id}, 'scr10_full'));
full3 = C(strcmp({C.id}, 'scr3_full'));
full2 = struct('id', 'scr2_full', 'scr', 2, 'mix', 'full', 'G', 1000, 'v', 12, 'tEvent', 0.8);

K = struct('group', {}, 'name', {}, 'c', {}, 'Qf', {}, 'dP', {}, 'dQ', {}, 'event', {}, 'Kq', {}, 'afd', {});
add = @(K, g, n, c, Qf, dP, dQ, e, Kq) [K, struct('group', g, 'name', n, 'c', c, 'Qf', Qf, 'dP', dP, 'dQ', dQ, 'event', e, 'Kq', Kq, 'afd', 1)];
for m = [0 0; 0 0.025; 0 -0.025; 0.05 0; -0.05 0]'
    K = add(K, 'qf', sprintf('qf2.5_dP%+.0f_dQ%+.1f', 100*m(1), 100*m(2)), full10, 2.5, m(1), m(2), 0, NaN);
end
K = add(K, 'weak', 'scr3_matched', full3, 1, 0, 0, 0, NaN);
K = add(K, 'weak', 'scr2_matched', full2, 1, 0, 0, 0, NaN);
K = add(K, 'weak', 'scr3_qf2.5_matched', full3, 2.5, 0, 0, 0, NaN);
for c = [full3 full2]
    for e = [1 5 6 10 11]
        K = add(K, 'weakft', sprintf('%s_event%02d', c.id, e), c, 1, 0, 0, e, NaN);
    end
end
for Kq = [0 -2000 1000 2000]
    K = add(K, 'multi', sprintf('der2_Kq%+05d', Kq), full10, 1, 0, 0, 0, Kq);
end
K = add(K, 'control', 'scr2_full_event06_noafd', full2, 1, 0, 0, 6, NaN); K(end).afd = 0;

P10 = params(10); relay = P10.relay.ieee; tMax = P10.relay.tMax;
T = table();
for k = 1:numel(K)
    q = K(k); f = fullfile(out, [q.name '.mat']);
    tE = q.c.tEvent;
    if ~exist(f, 'file')
        P = condition_params(q.c);
        P.load.Qf = q.Qf; P.afd.on = q.afd;
        if ~isnan(q.Kq), P.der2.on = 1; P.der2.Kq = q.Kq; end
        if q.event == 0
            P = island_case(P, q.dP, q.dQ, tE);
        else
            P = island_case(P, 0, 0, 1e6);                     % same load, grid never lost
            ev = disturbance_events(tE, q.c.G, q.c.v); P = ev(q.event).set(P);
        end
        fprintf('\n##### %s\n', q.name);
        S = run_model(tE + 2.05, P, '');
        R = reduce_run(S, tE - 0.15, tE);
        save(f, '-struct', 'R');
    end
    R = load(f);
    island = q.event == 0;
    if island, D = detect_islanding(R, relay, tE); else, D = detect_islanding(R, relay, Inf); end
    w = R.freq.Time > tE;
    evName = "island";
    if ~island, ev = disturbance_events(tE, q.c.G, q.c.v); evName = string(ev(q.event).name); end
    T = [T; table(string(q.group), string(q.name), q.c.scr, q.Qf, q.Kq, q.afd, evName, island, ...
        island & D.trip & D.t <= tMax, 1e3*D.t, string(D.element), ~isnan(D.falseTrip), 1e3*(D.falseTrip - tE), ...
        max(abs(R.freq.Data(w) - 50)), min(R.Vpcc_rms.Data(w)), R.pre.thd, R.pre.Q, ...
        'VariableNames', {'group','case','scr','Qf','Kq2','afd','event','island','detected','t_ms','element', ...
        'falseTrip','tFalse_ms','maxDf_Hz','Vmin_pu','preTHD_pct','preQ_var'})]; %#ok<AGROW>
end
disp(T);
writetable(T, fullfile(root, 'results', 'afd_stress.csv'));
end

function T = closed_loop_test(groups, mode)
% CLOSED_LOOP_TEST  Phase 7: the detector inside the model, tripping the inverter itself.
%   T = CLOSED_LOOP_TEST(GROUPS, MODE) runs the cases of GROUPS (default all
%   of 'cases', 'steady', 'afd', 'ndz') with current controller MODE (1 PI,
%   the default; 3 H-infinity; see P.ctrl.mode). Every run has sensor noise
%   on (P.noise) and the operating conditions of TEST_CONDITIONS, which the
%   detector never saw in training:
%     cases   per condition: 8 islands (Q_f 1 and 1.8, mismatches (dP, dQ) in %
%             of (0, 0), (+3, 0), (0, +1.5), (-10, -3)); 2 islands with a
%             second 10 kW inverter at the PCC, one whose reactive power
%             drifts against active frequency drift (Kq = -2000 var/Hz, Q_f 1)
%             and one without drift (Q_f 1.8); the 11 ordinary events of
%             DISTURBANCE_EVENTS. The detector is armed 0.25 s before the
%             event and trips the inverter's breaker.
%     steady  per condition: 2.5 s of steady operation, no event, and 1 s with
%             a negligible local load (the dataset always had one)
%     afd     the baseline it replaces: active frequency drift with the IEEE
%             1547-2018 relay (evaluated on the logged signals), the
%             detector off; per condition the matched islands at Q_f 1 and
%             1.8, the island with the opposing second inverter, and the
%             0.7 pu and 0.5 pu sags
%     ndz     the non-detection-zone grid of Phase 4 (dP -20..+20 %, dQ
%             -5..+5 %, Q_f 1) on scr7_t2
%   An island not cleared within 0.5 s is run again for the 2 s IEEE
%   1547-2018 allows. Reduced runs are saved to data/closedloop/<controller>/
%   (finished cases are skipped) and the results, with the fast and IEEE
%   relays evaluated on the same signals up to the detector's trip, to
%   results/closed_loop_<controller>.csv.
if nargin < 1 || isempty(groups), groups = {'cases', 'steady', 'afd', 'ndz'}; end
if nargin < 2 || isempty(mode), mode = 1; end
root = fileparts(fileparts(mfilename('fullpath')));
P0 = params(10);
ctrl = lower(strrep(P0.ctrl.names{mode}, '-', ''));     % pi, hinfinity, ...
out = fullfile(root, 'data', 'closedloop', ctrl);
if ~exist(out, 'dir'), mkdir(out); end
C = test_conditions();
test_operating_points(root, C);
Q = case_list(C, groups);
T = table();
for k = 1:numel(Q)
    q = Q(k); f = fullfile(out, [q.name '.mat']);
    if ~exist(f, 'file')
        R = run_case(q, mode, q.post, k);
        if q.island && ~isfinite(R.tTrip) && q.post < 2      % not cleared: allow the full 2 s
            R = run_case(q, mode, 2.05, k);
        end
        save(f, '-struct', 'R');
    end
    R = load(f);
    T = [T; score_case(q, R, P0)]; %#ok<AGROW>
end
disp(T(:, {'group', 'case', 'island', 'detector', 'tTrip_ms', 'detected', 'falseTrip', 'steadyAlarm', 'fast_ms', 'ieee_ms'}));
writetable(T, fullfile(root, 'results', sprintf('closed_loop_%s.csv', ctrl)));
end

function Q = case_list(C, groups)
Q = struct('group', {}, 'name', {}, 'c', {}, 'island', {}, 'Qf', {}, 'dP', {}, 'dQ', {}, ...
    'event', {}, 'Kq', {}, 'afd', {}, 'post', {});
add = @(Q, g, n, c, isl, Qf, dP, dQ, e, Kq, afd, post) [Q, struct('group', g, 'name', n, 'c', c, ...
    'island', isl, 'Qf', Qf, 'dP', dP, 'dQ', dQ, 'event', e, 'Kq', Kq, 'afd', afd, 'post', post)];
mm = [0 0; 3 0; 0 1.5; -10 -3]/100;
for c = C
    if any(strcmp(groups, 'cases'))
        for Qf = [1 1.8]
            for j = 1:size(mm, 1)
                Q = add(Q, 'cases', sprintf('%s_island_qf%g_dP%+03.0f_dQ%+04.1f', c.id, Qf, 100*mm(j,1), 100*mm(j,2)), ...
                    c, true, Qf, mm(j,1), mm(j,2), 0, NaN, 0, 0.5);
            end
        end
        Q = add(Q, 'cases', [c.id '_island_der2_Kq-2000'], c, true, 1, 0, 0, 0, -2000, 0, 0.5);
        Q = add(Q, 'cases', [c.id '_island_der2_Kq0_qf1.8'], c, true, 1.8, 0, 0, 0, 0, 0, 0.5);
        for e = 1:11
            Q = add(Q, 'cases', sprintf('%s_event%02d', c.id, e), c, false, 1 + 0.8*(mod(e, 2) == 0), 0, 0, e, NaN, 0, 0.8);
        end
    end
    if any(strcmp(groups, 'steady'))
        Q = add(Q, 'steady', [c.id '_steady'], c, false, 1, 0, 0, 0, NaN, 0, 2.5 - (c.tEvent - 0.6));
        Q = add(Q, 'steady', [c.id '_steady_noload'], c, false, 0, 0, 0, 0, NaN, 0, 1.0);   % Q_f 0: no local load
    end
    if any(strcmp(groups, 'afd'))
        Q = add(Q, 'afd', [c.id '_afd_island_qf1'], c, true, 1, 0, 0, 0, NaN, 1, 2.05);
        Q = add(Q, 'afd', [c.id '_afd_island_qf1.8'], c, true, 1.8, 0, 0, 0, NaN, 1, 2.05);
        Q = add(Q, 'afd', [c.id '_afd_island_der2_Kq-2000'], c, true, 1, 0, 0, 0, -2000, 1, 2.05);
        Q = add(Q, 'afd', [c.id '_afd_event06'], c, false, 1.8, 0, 0, 6, NaN, 1, 0.8);
        Q = add(Q, 'afd', [c.id '_afd_event07'], c, false, 1, 0, 0, 7, NaN, 1, 0.8);
    end
end
if any(strcmp(groups, 'ndz'))
    c = C(strcmp({C.id}, 'scr7_t2'));
    for dP = [-0.20 -0.10 -0.05 0 0.05 0.10 0.20]
        for dQ = [-0.05 -0.025 0 0.025 0.05]
            Q = add(Q, 'ndz', sprintf('%s_ndz_dP%+04.0f_dQ%+05.1f', c.id, 100*dP, 100*dQ), c, true, 1, dP, dQ, 0, NaN, 0, 0.5);
        end
    end
end
end

function R = run_case(q, mode, post, k)
c = q.c; tE = c.tEvent;
P = condition_params(c);
P.ctrl.mode = mode;
P.noise.on = 1; P.noise.seed = k;
P.load.Qf = q.Qf; P.afd.on = q.afd;
if isfinite(q.Kq), P.der2.on = 1; P.der2.Kq = q.Kq; end
if q.island
    P = island_case(P, q.dP, q.dQ, tE);
else
    P = island_case(P, 0, 0, 1e6);                        % same load, grid never lost
    if q.Qf == 0, P.load.P = 200; P.load.QL = 200; P.load.QC = 200; end   % negligible local load
    if q.event > 0, ev = disturbance_events(tE, c.G, c.v); P = ev(q.event).set(P); end
end
if ~q.afd, P.ml.tArm = tE - 0.25; end                     % the detector replaces drift
fprintf('\n##### %s (%s)\n', q.name, P.ctrl.names{mode});
S = run_model(tE + post, P, '');
t = (0:1e-3:S.freq.Time(end))';
R.P = P; R.tEvent = tE;
for n = {'Vpcc_rms', 'freq', 'VDC', 'ml_score', 'trip'}
    R.(n{1}) = timeseries(interp1(S.(n{1}).Time, double(S.(n{1}).Data(:,1)), t, 'previous'), t);
end
tw = (tE - 0.1:1e-4:S.Igrid_true.Time(end))';
R.tw = tw([1 end]);
R.Igrid = single(interp1(S.Igrid_true.Time, double(S.Igrid_true.Data), tw));   % true inverter current
tr = find(S.trip.Data(:) > 0.5, 1);
R.tTrip = Inf; if ~isempty(tr), R.tTrip = S.trip.Time(tr) - tE; end
M = signal_metrics(true_current(S), tE - 0.15, tE);        % grid-connected power quality, true current
R.pre = struct('P', M.P, 'Q', M.Q, 'thd', M.thd);
end

function S = true_current(S)
S.Igrid = S.Igrid_true;
end

function r = score_case(q, R, P0)
tE = R.tEvent; tT = R.tTrip;
ml = ~q.afd;
% relays on the same signals, up to the detector's trip (after it the inverter is off)
S.P.prot.tBlank = tE - 0.25; tEnd = R.freq.Time(end);
if ml && isfinite(tT), tEnd = min(tEnd, tE + tT - 1e-3); end
for n = {'Vpcc_rms', 'freq'}
    x = R.(n{1}); k = x.Time <= tEnd; S.(n{1}) = timeseries(x.Data(k), x.Time(k));
end
Df = detect_islanding(S, P0.relay.fast, tE); Di = detect_islanding(S, P0.relay.ieee, tE);   % a trip after tE
% current left 40 ms after the detector's trip (the inverter should have ceased)
Iafter = NaN;
if ml && isfinite(tT)
    tw = (R.tw(1):1e-4:R.tw(1) + 1e-4*(size(R.Igrid, 1) - 1))';
    k = tw > tE + tT + 0.03 & tw <= tE + tT + 0.05;
    if any(k), Iafter = sqrt(mean(double(R.Igrid(k,:)).^2, 'all')); end
end
det = "ML (in the loop)"; tDet = tT;
if q.afd, det = "AFD + IEEE"; tDet = Di.t; end           % drift runs: the IEEE relay is the detector
evName = "island";
if q.event > 0, ev = disturbance_events(tE, q.c.G, q.c.v); evName = string(ev(q.event).name); end
if strcmp(q.group, 'steady'), evName = "none"; end
r = table(string(q.group), string(q.name), string(q.c.id), q.c.scr, q.island, evName, q.Qf, 100*q.dP, 100*q.dQ, ...
    q.Kq, q.afd, det, 1e3*tDet, q.island & tDet > 0 & tDet <= 2, ~q.island & tDet > 0 & isfinite(tDet), ...
    (ml && tT <= 0) || (~ml && ~isnan(Di.falseTrip)), ...
    1e3*Df.t, 1e3*Di.t, R.pre.thd, R.pre.Q, Iafter, max(R.ml_score.Data(R.ml_score.Time < tE)), ...
    'VariableNames', {'group', 'case', 'cond', 'scr', 'island', 'event', 'Qf', 'dP_pct', 'dQ_pct', 'Kq2', 'afd', ...
    'detector', 'tTrip_ms', 'detected', 'falseTrip', 'steadyAlarm', 'fast_ms', 'ieee_ms', 'preTHD_pct', 'preQ_var', ...
    'Iafter_A', 'maxScorePre'});
end

function test_operating_points(root, C)
% Grid-connected output of each test condition, for sizing islanding loads (as OPERATING_POINTS).
f = fullfile(root, 'results', 'operating_points_test.csv');
if exist(f, 'file'), T = readtable(f, 'TextType', 'string'); else, T = table(); end
for c = C
    if ~isempty(T) && any(T.id == c.id), continue; end
    P = condition_params(c);
    P.load.P = 200; P.load.QL = 200; P.load.QC = 200;
    fprintf('\n##### operating point %s\n', c.id);
    S = run_model(c.tEvent, P, '');
    M = signal_metrics(true_current(S), c.tEvent - 0.1, c.tEvent);
    T = [T; table(string(c.id), c.scr, string(c.mix), c.G, c.v, round(M.P), round(M.Q), M.Vrms, M.thd, ...
        'VariableNames', {'id', 'scr', 'mix', 'G', 'v', 'Pinv_W', 'Qinv_var', 'Vpcc_pu', 'THDi_pct'})]; %#ok<AGROW>
    writetable(T, f);
end
end

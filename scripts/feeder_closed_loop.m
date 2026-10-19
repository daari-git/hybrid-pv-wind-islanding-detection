function T = feeder_closed_loop(groups, mode, only, detector)
% FEEDER_CLOSED_LOOP  The Phase 7 detector, unchanged, on the Pidari 400 V feeder.
%   T = FEEDER_CLOSED_LOOP(GROUPS, MODE, ONLY) runs the cases of GROUPS
%   (default all of 'cases', 'steady', 'afd', 'ndz') on hybrid_pv_wind_feeder
%   (BUILD_FEEDER_MODEL) with current controller MODE (1 PI, the default;
%   3 H-infinity). ONLY, a cell array of case names, runs just those. Every
%   run has sensor noise on and the conditions of FEEDER_CONDITIONS. The
%   detector was trained on the test bed's single impedance (X/R 3) and
%   never saw this feeder; it is armed 0.25 s before the event and trips
%   the unit's breaker.
%     cases   per condition:
%             4 islands of the unit and its local load, opened at the unit's
%               breaker (svc): Q_f 1 and 1.8, matched and 3 % / 1.5 % off;
%             5 islands of the whole feeder, opened at the transformer (dt):
%               the feeder as it is, unit alone, no local load (natural), and
%               balanced with the other generation at B3 (Q_f 1 and 1.8,
%               matched and 3 % / 1.5 % off; FEEDER_ISLAND_CASE);
%             1 balanced feeder island whose other generation drifts its
%               reactive power against active frequency drift (Kq -2000);
%             13 ordinary events: the 11 of DISTURBANCE_EVENTS and a 10 kW
%               load at B3 switched on and off, with a 2 kW household load
%               at the PCC
%     steady  per condition: 2.5 s with the household load, 1.5 s with a
%             local load that matches the unit (Q_f 1)
%     afd     the baseline, active frequency drift with the IEEE 1547-2018
%             relay (evaluated on the logged signals), detector off: feeder
%             islands at Q_f 1 and 2.5, the unit's island at Q_f 1, the
%             feeder island with the opposing drift, the 0.7 and 0.5 pu sags
%     ndz     feeder islands on f30_t1 over dP -20..+20 %, dQ -5..+5 %, Q_f 1
%   As CLOSED_LOOP_TEST: an island not cleared in 0.5 s is run again for 2 s,
%   runs are saved to data/feeder/<controller>/ (finished cases are skipped)
%   and results, with the fast and IEEE relays on the same signals, to
%   results/feeder_closed_loop_<controller>.csv.
%   T = FEEDER_CLOSED_LOOP(GROUPS, MODE, ONLY, DETECTOR) runs another trained
%   detector (USE_DETECTOR, e.g. 'islanding_classifier_feeder'), saving to
%   data/feeder/<controller>_<DETECTOR>/ and
%   results/feeder_closed_loop_<controller>_<DETECTOR>.csv.
if nargin < 1 || isempty(groups), groups = {'cases', 'steady', 'afd', 'ndz'}; end
if nargin < 2 || isempty(mode), mode = 1; end
if nargin < 3, only = {}; end
if nargin < 4, detector = ''; end
root = fileparts(fileparts(mfilename('fullpath')));
P0 = params(10);
ctrl = lower(strrep(P0.ctrl.names{mode}, '-', ''));
if ~isempty(detector), ctrl = [ctrl '_' detector]; end
out = fullfile(root, 'data', 'feeder', ctrl);
if ~exist(out, 'dir'), mkdir(out); end
C = feeder_conditions();
feeder_operating_points(root, C);
Q = case_list(C, groups);
if ~isempty(only), Q = Q(ismember({Q.name}, only)); end
T = table();
for k = 1:numel(Q)
    q = Q(k); f = fullfile(out, [q.name '.mat']);
    if ~exist(f, 'file')
        R = run_case(q, mode, q.post, k, detector);
        if q.island && ~isfinite(R.tTrip) && q.post < 2
            R = run_case(q, mode, 2.05, k, detector);
        end
        save(f, '-struct', 'R');
    end
    R = load(f);
    T = [T; score_case(q, R, P0)]; %#ok<AGROW>
end
disp(T(:, {'case', 'detector', 'tTrip_ms', 'detected', 'falseTrip', 'steadyAlarm', 'fast_ms', 'ieee_ms', 'Pdt_pre_W'}));
if isempty(only), writetable(T, fullfile(root, 'results', sprintf('feeder_closed_loop_%s.csv', ctrl))); end
end

function Q = case_list(C, groups)
Q = struct('group', {}, 'name', {}, 'c', {}, 'island', {}, 'kind', {}, 'Qf', {}, 'dP', {}, 'dQ', {}, ...
    'event', {}, 'der2', {}, 'Kq', {}, 'afd', {}, 'local', {}, 'post', {});
add = @(Q, g, n, c, kind, Qf, dP, dQ, e, der2, Kq, afd, local, post) [Q, struct('group', g, 'name', n, 'c', c, ...
    'island', ~strcmp(kind, 'none'), 'kind', kind, 'Qf', Qf, 'dP', dP, 'dQ', dQ, 'event', e, 'der2', der2, ...
    'Kq', Kq, 'afd', afd, 'local', local, 'post', post)];
mm = [1 0 0; 1 3 0; 1.8 0 0; 1.8 0 1.5];               % [Q_f dP(%) dQ(%)]
dt = [1 0 0; 1.8 0 0; 1 3 0; 1 0 1.5];
nm = @(c, kind, Qf, dP, dQ) sprintf('%s_%s_island_qf%g_dP%+03.0f_dQ%+04.1f', c.id, kind, Qf, dP, dQ);
for c = C
    if any(strcmp(groups, 'cases'))
        for j = 1:size(mm, 1)
            Q = add(Q, 'cases', nm(c, 'svc', mm(j,1), mm(j,2), mm(j,3)), c, 'svc', mm(j,1), mm(j,2)/100, mm(j,3)/100, 0, 0, 0, 0, 'matched', 0.5);
        end
        Q = add(Q, 'cases', [c.id '_dt_island_natural'], c, 'dt', 0, 0, 0, 0, 0, 0, 0, 'none', 0.5);
        for j = 1:size(dt, 1)
            Q = add(Q, 'cases', nm(c, 'dt', dt(j,1), dt(j,2), dt(j,3)), c, 'dt', dt(j,1), dt(j,2)/100, dt(j,3)/100, 0, 1, 0, 0, 'matched', 0.5);
        end
        Q = add(Q, 'cases', [c.id '_dt_island_der2_Kq-2000'], c, 'dt', 1, 0, 0, 0, 1, -2000, 0, 'matched', 0.5);
        for e = 1:13
            Q = add(Q, 'cases', sprintf('%s_event%02d', c.id, e), c, 'none', NaN, 0, 0, e, 0, 0, 0, 'household', 0.8);
        end
    end
    if any(strcmp(groups, 'steady'))
        Q = add(Q, 'steady', [c.id '_steady_household'], c, 'none', NaN, 0, 0, 0, 0, 0, 0, 'household', 2.5);
        Q = add(Q, 'steady', [c.id '_steady_matched'], c, 'none', 1, 0, 0, 0, 0, 0, 0, 'matched', 1.5);
    end
    if any(strcmp(groups, 'afd'))
        Q = add(Q, 'afd', [c.id '_afd_dt_island_qf1'], c, 'dt', 1, 0, 0, 0, 1, 0, 1, 'matched', 2.05);
        Q = add(Q, 'afd', [c.id '_afd_dt_island_qf2.5'], c, 'dt', 2.5, 0, 0, 0, 1, 0, 1, 'matched', 2.05);
        Q = add(Q, 'afd', [c.id '_afd_svc_island_qf1'], c, 'svc', 1, 0, 0, 0, 0, 0, 1, 'matched', 2.05);
        Q = add(Q, 'afd', [c.id '_afd_dt_island_der2_Kq-2000'], c, 'dt', 1, 0, 0, 0, 1, -2000, 1, 'matched', 2.05);
        Q = add(Q, 'afd', [c.id '_afd_event06'], c, 'none', NaN, 0, 0, 6, 0, 0, 1, 'household', 0.8);
        Q = add(Q, 'afd', [c.id '_afd_event07'], c, 'none', NaN, 0, 0, 7, 0, 0, 1, 'household', 0.8);
    end
end
if any(strcmp(groups, 'ndz'))
    c = C(1);
    for dP = [-20 -10 -5 0 5 10 20]
        for dQ = [-5 -2.5 0 2.5 5]
            Q = add(Q, 'ndz', strrep(nm(c, 'dt_ndz', 1, dP, dQ), '_island', ''), c, 'dt', 1, dP/100, dQ/100, 0, 1, 0, 0, 'matched', 0.5);
        end
    end
end
end

function R = run_case(q, mode, post, k, detector)
c = q.c; tE = c.tEvent;
P = feeder_condition_params(c);
if ~isempty(detector), P = use_detector(P, detector); end
P.ctrl.mode = mode;
P.noise.on = 1; P.noise.seed = k;
P.afd.on = q.afd;
if q.der2, P.der2.on = 1; P.der2.Kq = q.Kq; end
switch q.kind
    case 'svc'
        P.load.Qf = q.Qf; P = at_pcc_voltage(island_case(P, q.dP, q.dQ, tE));
    case 'dt'
        P = feeder_island_case(P, q.dP, q.dQ, q.Qf, tE);
    otherwise
        if ~strcmp(q.local, 'household'), P.load.Qf = q.Qf; end
        P = at_pcc_voltage(island_case(P, 0, 0, 1e6));    % same load, grid never lost
        if strcmp(q.local, 'household')                   % 2 kW at power factor 0.95
            P.load.P = 2000; P.load.QL = 2000*tan(acos(0.95)); P.load.QC = 0;
        end
        P = feeder_event(P, q.event, tE, c);
end
if ~q.afd, P.ml.tArm = tE - 0.25; end
fprintf('\n##### %s (%s)\n', q.name, P.ctrl.names{mode});
S = run_model(tE + post, P, '');
t = (0:1e-3:S.freq.Time(end))';
R.P = P; R.tEvent = tE;
for n = {'Vpcc_rms', 'freq', 'VDC', 'ml_score', 'trip'}
    R.(n{1}) = timeseries(interp1(S.(n{1}).Time, double(S.(n{1}).Data(:,1)), t, 'previous'), t);
end
tw = (tE - 0.1:1e-4:S.Igrid_true.Time(end))';
R.tw = tw([1 end]);
R.Igrid = single(interp1(S.Igrid_true.Time, double(S.Igrid_true.Data), tw));
tr = find(S.trip.Data(:) > 0.5, 1);
R.tTrip = Inf; if ~isempty(tr), R.tTrip = S.trip.Time(tr) - tE; end
M = signal_metrics(true_current(S), tE - 0.15, tE);
D = dt_meter(S); Md = signal_metrics(D, tE - 0.15, tE);
R.pre = struct('P', M.P, 'Q', M.Q, 'thd', M.thd, 'V', M.Vrms, 'Pdt', -Md.P, 'Qdt', -Md.Q);
end

function P = at_pcc_voltage(P)
% ISLAND_CASE sizes the local load at 400 V. A load that absorbs the unit's
% output leaves the PCC at the feeder's own voltage there (the load flow
% without the unit), so the constant-impedance ratings are scaled to it.
V = P.feeder.Vlf(P.feeder.pcc);
P.load.P = P.load.P/V^2; P.load.QL = P.load.QL/V^2; P.load.QC = P.load.QC/V^2;
end

function P = feeder_event(P, e, tE, c)
% The 11 events of DISTURBANCE_EVENTS, then the switched load at B3 on (12) and off (13).
if e == 0, return, end
if e <= 11
    ev = disturbance_events(tE, c.G, c.v); P = ev(e).set(P);
elseif e == 12
    P.feeder.swT = [tE 1e6];
else
    P.feeder.swT = [0.05 tE];
end
end

function n = event_name(e, c)
if e <= 11
    ev = disturbance_events(0.6, c.G, c.v); n = ev(e).name;
elseif e == 12
    n = 'Feeder load at B3 switched on (+10 kW)';
else
    n = 'Feeder load at B3 switched off (-10 kW)';
end
end

function S = true_current(S)
S.Igrid = S.Igrid_true;
end

function D = dt_meter(S)
% The transformer's meter in place of the PCC's; signal_metrics then gives
% minus the power drawn by the feeder through the transformer.
D = S; D.Vabc = S.Vdt; D.Igrid = S.Idt;
end

function r = score_case(q, R, P0)
tE = R.tEvent; tT = R.tTrip;
ml = ~q.afd;
S.P.prot.tBlank = tE - 0.25; tEnd = R.freq.Time(end);
if ml && isfinite(tT), tEnd = min(tEnd, tE + tT - 1e-3); end
for n = {'Vpcc_rms', 'freq'}
    x = R.(n{1}); k = x.Time <= tEnd; S.(n{1}) = timeseries(x.Data(k), x.Time(k));
end
Df = detect_islanding(S, P0.relay.fast, tE); Di = detect_islanding(S, P0.relay.ieee, tE);
Iafter = NaN;
if ml && isfinite(tT)
    tw = (R.tw(1):1e-4:R.tw(1) + 1e-4*(size(R.Igrid, 1) - 1))';
    k = tw > tE + tT + 0.03 & tw <= tE + tT + 0.05;
    if any(k), Iafter = sqrt(mean(double(R.Igrid(k,:)).^2, 'all')); end
end
det = "ML (in the loop)"; tDet = tT;
if q.afd, det = "AFD + IEEE"; tDet = Di.t; end
evName = string(q.kind) + " island";
if q.event > 0, evName = string(event_name(q.event, q.c)); end
if strcmp(q.group, 'steady'), evName = "none"; end
r = table(string(q.group), string(q.name), string(q.c.id), q.c.load, q.c.pcc, q.island, string(q.kind), evName, ...
    string(q.local), q.Qf, 100*q.dP, 100*q.dQ, q.der2, q.Kq, q.afd, det, 1e3*tDet, ...
    q.island & tDet > 0 & tDet <= 2, ~q.island & tDet > 0 & isfinite(tDet), ...
    (ml && tT <= 0) || (~ml && ~isnan(Di.falseTrip)), 1e3*Df.t, 1e3*Di.t, ...
    R.pre.thd, R.pre.P, R.pre.Q, R.pre.V, R.pre.Pdt, R.pre.Qdt, Iafter, max(R.ml_score.Data(R.ml_score.Time < tE)), ...
    'VariableNames', {'group', 'case', 'cond', 'load', 'pcc', 'island', 'kind', 'event', 'local', 'Qf', 'dP_pct', 'dQ_pct', ...
    'der2', 'Kq2', 'afd', 'detector', 'tTrip_ms', 'detected', 'falseTrip', 'steadyAlarm', 'fast_ms', 'ieee_ms', ...
    'preTHD_pct', 'preP_W', 'preQ_var', 'preV_pu', 'Pdt_pre_W', 'Qdt_pre_var', 'Iafter_A', 'maxScorePre'});
end

function feeder_operating_points(root, C)
% Grid-connected flows of each condition with a negligible local load: the
% unit's output and the power drawn through the transformer, with the unit
% alone and with the other generation at B3 on (FEEDER_CONDITION_PARAMS).
f = fullfile(root, 'results', 'feeder_operating_points.csv');
if exist(f, 'file'), T = readtable(f, 'TextType', 'string'); else, T = table(); end
for c = C
    if ~isempty(T) && any(T.id == c.id), continue; end
    m = zeros(2, 7);
    for d2 = 0:1
        P = feeder_condition_params(c);
        P.load.P = 200; P.load.QL = 200; P.load.QC = 200;
        P.der2.on = d2;
        fprintf('\n##### operating point %s, other generation %s\n', c.id, string(d2 == 1));
        S = run_model(c.tEvent, P, '');
        M = signal_metrics(true_current(S), c.tEvent - 0.1, c.tEvent);
        Md = signal_metrics(dt_meter(S), c.tEvent - 0.1, c.tEvent);
        m(d2 + 1, :) = [M.P M.Q M.Vrms M.thd -Md.P -Md.Q mean(sqrt(mean(S.Vder2.Data(S.Vder2.Time > c.tEvent - 0.1, :).^2, 2)))*sqrt(3)/P.Vll];
    end
    T = [T; table(string(c.id), c.load, c.pcc, c.G, c.v, round(m(1,1)), round(m(1,2)), m(1,3), m(1,4), ...
        round(m(1,5)), round(m(1,6)), c.der2P, round(m(2,5)), round(m(2,6)), m(2,3), m(2,7), ...
        'VariableNames', {'id', 'load', 'pcc', 'G', 'v', 'Pinv_W', 'Qinv_var', 'Vpcc_pu', 'THDi_pct', ...
        'Pdt_W', 'Qdt_var', 'der2P_W', 'Pdt2_W', 'Qdt2_var', 'Vpcc2_pu', 'Vb3_2_pu'})]; %#ok<AGROW>
    writetable(T, f);
end
end

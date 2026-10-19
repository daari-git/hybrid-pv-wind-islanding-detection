function export_figure_data()
% EXPORT_FIGURE_DATA  Signals behind the paper's figures, as CSV files in paper/figdata.
%   Reads the logged runs that the README figures are drawn from (Phases 4,
%   5 and 7) and writes the traces at 1 ms (10 kHz for the inverter
%   current), so make_figures.py can draw them at journal size.
root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root, 'scripts'));
out = fullfile(root, 'paper', 'figdata');
if ~exist(out, 'dir'), mkdir(out); end
P0 = params(10); ieee = P0.relay.ieee;

%% Rate of change of frequency: an island and four ordinary events (Phase 4)
nd = @(afd, dP, dQ) load(fullfile(root, 'results', 'ndz', sprintf('afd%d_dP%+04.0f_dQ%+05.1f.mat', afd, dP, dQ)));
ev = disturbance_events();
pick = [1 5 6 11];
runs = [{nd(0, 0, 2.5)}, arrayfun(@(k) load(fullfile(root, 'results', sprintf('ft_%d.mat', k))), pick, 'UniformOutput', false)];
names = [{'island'}, {ev(pick).name}];
t0 = [runs{1}.P.tIsland, 0.5*ones(1, numel(pick))];
T = table();
for k = 1:numel(runs)
    [t, ~, ~, r] = relay_signals(runs{k});
    w = t - t0(k) >= -0.05 & t - t0(k) <= 0.3;
    T = [T; table(repmat(string(names{k}), nnz(w), 1), 1e3*(t(w) - t0(k)), r(w), ...
        'VariableNames', {'case', 't_ms', 'rocof'})]; %#ok<AGROW>
end
writetable(T, fullfile(out, 'rocof.csv'));

%% Active frequency drift under stress (Phase 5)
st = @(n) load(fullfile(root, 'results', 'stress', [n '.mat']));
list = {'qf1', nd(1, 0, 0); 'qf2.5', st('qf2.5_dP+0_dQ+0.0'); 'scr3', st('scr3_matched'); 'scr2', st('scr2_matched'); ...
        'der2_0', st('der2_Kq+0000'); 'der2_p1000', st('der2_Kq+1000'); 'der2_p2000', st('der2_Kq+2000'); ...
        'der2_m2000', st('der2_Kq-2000')};
T = table(); Tr = table();
for k = 1:size(list, 1)
    S = list{k, 2}; tI = S.P.tIsland;
    D = detect_islanding(S, ieee, tI);
    t = (tI - 0.1:1e-3:min(tI + 2.0, S.freq.Time(end)))';
    f = interp1(S.freq.Time, double(S.freq.Data(:,1)), t);
    T = [T; table(repmat(string(list{k,1}), numel(t), 1), t - tI, f, 'VariableNames', {'case', 't_s', 'f_Hz'})]; %#ok<AGROW>
    Tr = [Tr; table(string(list{k,1}), D.trip & D.t <= P0.relay.tMax, 1e3*D.t, 'VariableNames', {'case', 'trip', 't_ms'})]; %#ok<AGROW>
end
writetable(T, fullfile(out, 'afd_stress.csv'));
writetable(Tr, fullfile(out, 'afd_stress_trips.csv'));

% the 0.7 pu sag at SCR 2, with and without drift
T = table(); Tr = table();
for nm = ["scr2_full_event06", "scr2_full_event06_noafd"]
    S = st(char(nm));
    tE = S.P.event.time(find(S.P.event.amp < 1, 1));
    D = detect_islanding(S, ieee, tE);
    t = (tE - 0.1:1e-3:min(tE + 1.0, S.freq.Time(end)))';
    f = interp1(S.freq.Time, double(S.freq.Data(:,1)), t);
    v = interp1(S.Vpcc_rms.Time, double(S.Vpcc_rms.Data(:,1)), t);
    T = [T; table(repmat(nm, numel(t), 1), t - tE, f, v, 'VariableNames', {'case', 't_s', 'f_Hz', 'V_pu'})]; %#ok<AGROW>
    Tr = [Tr; table(nm, tE, D.trip, 1e3*D.t, 'VariableNames', {'case', 'tEvent', 'trip', 't_ms'})]; %#ok<AGROW>
end
writetable(T, fullfile(out, 'scr2_sag.csv'));
writetable(Tr, fullfile(out, 'scr2_sag_trips.csv'));
disp(Tr);

%% The detector in the loop (Phase 7): island with an opposing inverter, 0.7 pu sag, SCR 4
d = fullfile(root, 'data', 'closedloop', 'pi');
L = {'island_ml', 'scr4_t3_island_der2_Kq-2000'; 'island_afd', 'scr4_t3_afd_island_der2_Kq-2000'; ...
     'sag_ml', 'scr4_t3_event06'; 'sag_afd', 'scr4_t3_afd_event06'};
T = table(); Ts = table(); Ti = table(); Tm = table();
for k = 1:size(L, 1)
    R = load(fullfile(d, [L{k,2} '.mat']));
    t = (R.tEvent - 0.1:1e-3:min(R.tEvent + 0.8, R.freq.Time(end)))';
    f = interp1(R.freq.Time, double(R.freq.Data(:,1)), t);
    v = interp1(R.Vpcc_rms.Time, double(R.Vpcc_rms.Data(:,1)), t);
    T = [T; table(repmat(string(L{k,1}), numel(t), 1), t - R.tEvent, f, v, 'VariableNames', {'case', 't_s', 'f_Hz', 'V_pu'})]; %#ok<AGROW>
    if any(strcmp(L{k,1}, {'island_ml', 'sag_ml'}))
        w = R.ml_score.Time >= R.tEvent - 0.19 & R.ml_score.Time <= R.tEvent + 0.8;
        Ts = [Ts; table(repmat(string(L{k,1}), nnz(w), 1), R.ml_score.Time(w) - R.tEvent, double(R.ml_score.Data(w)), ...
            'VariableNames', {'case', 't_s', 'score'})]; %#ok<AGROW>
        tw = R.tw(1) + (0:size(R.Igrid, 1) - 1)'/1e4 - R.tEvent;
        w = tw >= -0.1 & tw <= 0.8;
        Ti = [Ti; table(repmat(string(L{k,1}), nnz(w), 1), tw(w), double(R.Igrid(w,1)), 'VariableNames', {'case', 't_s', 'ia_A'})]; %#ok<AGROW>
    end
    Tm = [Tm; table(string(L{k,1}), R.tEvent, R.tTrip, R.P.ml.threshold, 'VariableNames', {'case', 'tEvent', 'tTrip', 'threshold'})]; %#ok<AGROW>
end
writetable(T, fullfile(out, 'cl_traces.csv'));
writetable(Ts, fullfile(out, 'cl_score.csv'));
writetable(Ti, fullfile(out, 'cl_current.csv'));
writetable(Tm, fullfile(out, 'cl_meta.csv'));
disp(Tm);
end

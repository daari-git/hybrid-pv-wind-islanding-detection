function T = noise_calibration(ids, tEnd)
% NOISE_CALIBRATION  Phase 7: how sensor noise reaches the detector's inputs.
%   T = NOISE_CALIBRATION(IDS, TEND) runs each operating condition in IDS
%   (default scr10_full and scr3_low) twice in steady state up to TEND
%   seconds (default 1.6), once with sensor noise off and once on
%   (P.noise), with the Phase 6 detector scoring every window from 0.35 s
%   (0.7 s at SCR 3) but not tripping. The difference between the two runs is
%   the noise as the detector sees it: white on the waveforms, but filtered by
%   the PLL, the RMS measurement and the control loops on frequency, RMS
%   voltage, DC-link voltage and d/q currents. It is saved, in the dataset's
%   format, to data/noise/<id>.mat for EXTRACT_FEATURES to add to the
%   noise-free cases. Writes results/noise_calibration.csv: the standard
%   deviation of each signal's noise and the detector's highest steady-state
%   score, and longest run of windows above threshold, with and without noise.
%   The local load is the dataset's (matched, Q_f 1) with the grid kept.
if nargin < 1 || isempty(ids), ids = {'scr10_full', 'scr3_low'}; end
if nargin < 2 || isempty(tEnd), tEnd = 1.6; end
root = fileparts(fileparts(mfilename('fullpath')));
out = fullfile(root, 'data', 'noise');
if ~exist(out, 'dir'), mkdir(out); end
C = operating_conditions();
T = table();
for k = 1:numel(ids)
    c = C(strcmp({C.id}, ids{k}));
    t1 = 0.35 + 0.35*(c.scr < 5);                         % after start-up
    R = cell(1, 2);
    for nz = [0 1]
        P = condition_params(c);
        P = island_case(P, 0, 0, 1e6);                     % the dataset's matched local load, Q_f 1, grid kept
        P.noise.on = nz; P.ml.tArm = t1; P.ml.trip = 0;
        fprintf('\n##### %s, noise %d\n', c.id, nz);
        S = run_model(tEnd, P, '');
        R{nz + 1} = resample_run(S, t1, tEnd);
        R{nz + 1}.score = interp1(S.ml_score.Time, double(S.ml_score.Data), (t1 + 0.06:0.005:tEnd - 0.005)', 'previous');
    end
    N = struct('fs', 1e3, 'fsWave', 1e4, 'cond', c.id, 'scr', c.scr, 'noise', P.noise, ...
        'score_clean', R{1}.score, 'score_noisy', R{2}.score);
    for n = {'Vabc', 'Igrid', 'freq', 'Vpcc_rms', 'VDC', 'ID', 'IQ'}
        N.(n{1}) = single(R{2}.(n{1}) - R{1}.(n{1}));
    end
    save(fullfile(out, [c.id '.mat']), '-struct', 'N');
    P0 = params(c.scr);
    T = [T; table(string(c.id), c.scr, std(N.Vabc(:))/P0.Vpk, std(N.Igrid(:))/P0.Ipk, std(N.freq), ...
        std(N.Vpcc_rms), std(N.VDC), std(N.ID), std(N.IQ), max(R{1}.score), max(R{2}.score), ...
        longest_run(R{1}.score > P.ml.threshold), longest_run(R{2}.score > P.ml.threshold), ...
        'VariableNames', {'cond', 'scr', 'v_pu', 'i_pu', 'freq_Hz', 'Vrms_pu', 'Vdc_V', 'Id_A', 'Iq_A', ...
        'maxScore_clean', 'maxScore_noisy', 'longestRun_clean', 'longestRun_noisy'})]; %#ok<AGROW>
end
disp(T);
writetable(T, fullfile(root, 'results', 'noise_calibration.csv'));
end

function D = resample_run(S, t1, t2)
% Waveforms at 10 kHz and the other signals at 1 kHz, from t1 to t2.
t2 = min(t2, S.freq.Time(end)) - 1e-3;
tw = (t1:1e-4:t2)'; ts = (t1:1e-3:t2)';
D.Vabc = interp1(S.Vabc.Time, double(S.Vabc.Data), tw);
D.Igrid = interp1(S.Igrid.Time, double(S.Igrid.Data), tw);
for n = {'freq', 'Vpcc_rms', 'VDC', 'ID', 'IQ'}
    D.(n{1}) = interp1(S.(n{1}).Time, double(S.(n{1}).Data(:,1)), ts);
end
end

function n = longest_run(x)
% Longest stretch of consecutive true values (windows above threshold).
d = diff([0; x(:); 0]); n = max([0; find(d == -1) - find(d == 1)]);
end

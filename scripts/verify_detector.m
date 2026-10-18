function d = verify_detector(name)
% VERIFY_DETECTOR  Check that the detector inside the model computes what the offline code does.
%   D = VERIFY_DETECTOR(NAME) re-runs dataset case NAME (default the matched
%   island at SCR 10, full power, Q_f 1) with the model's detector scoring
%   every window but not tripping, computes the same windows offline from
%   the run's logged signals with WINDOW_FEATURES and the trained network of
%   ml/islanding_classifier.mat, and returns the largest difference between
%   the two scores. It stops with an error above 1e-6.
if nargin < 1, name = 'scr10_full_island_qf1_dP+00_dQ+0.0'; end
root = fileparts(fileparts(mfilename('fullpath')));
D0 = load(fullfile(root, 'data', 'raw', [name '.mat'])); q = D0.meta; tE = q.tEvent;
C = operating_conditions(); c = C(strcmp({C.id}, q.cond));
P = condition_params(c); P.load.Qf = q.Qf; P.afd.on = 0;
if q.label == 1, P = island_case(P, q.dP, q.dQ, tE); else, error('Use an island case.'); end
P.ml.tArm = tE - 0.25; P.ml.trip = 0;
S = run_model(tE + 0.351, P, '');
M = load(fullfile(root, 'ml', 'islanding_classifier.mat'));
te = (ceil((tE - 0.25)/0.005) + 1:floor((tE + 0.35)/0.005))'*0.005;   % the model evaluates every 5 ms of simulation time
sc = interp1(S.ml_score.Time, double(S.ml_score.Data), te + 1e-7, 'previous');
R.fs = 1e3; R.fsWave = 1e4;
t1 = (0:1e-3:te(end))'; t10 = (0:1e-4:te(end))';
R.Vabc = interp1(S.Vabc.Time, double(S.Vabc.Data), t10); R.Igrid = interp1(S.Igrid.Time, double(S.Igrid.Data), t10);
for n = {'freq', 'Vpcc_rms', 'VDC', 'ID', 'IQ'}, R.(n{1}) = interp1(S.(n{1}).Time, double(S.(n{1}).Data(:,1)), t1); end
X = zeros(numel(te), numel(M.features));
for j = 1:numel(te), X(j,:) = window_features(R, te(j) - M.W, M.W, M.Wb, P); end
[~, s] = predict(M.model, X);
d = max(abs(sc - s(:,2)));
fprintf('In-model and offline scores over %d windows: largest difference %.3g\n', numel(te), d);
assert(d < 1e-6, 'The detector inside the model does not match the offline computation.');
end

function confirm_check()
% CONFIRM_CHECK  Step 9: rebuild both models and check the confirmation stage.
%   1. BUILD_MODEL and BUILD_FEEDER_MODEL with the confirmation in the detector.
%   2. A saved feeder run of step 8.5 (retrained detector, PI, the 6 kW load
%      switched on at the PCC, F1) is repeated with the confirmation off: its
%      score and trip time must be the same as before the change.
%   3. The same run with the confirmation on and no threshold: the detector
%      must nudge, report the angle response, and trip at the end of the nudge.
root = fileparts(fileparts(mfilename('fullpath')));
build_model(10);
build_feeder_model();
R0 = load(fullfile(root, 'data', 'feeder', 'pi_islanding_classifier_feeder', 'f30_t1_event04.mat'));
D = params(10);
P = R0.P; P.ml.confirm = D.ml.confirm;
stop = R0.freq.Time(end);
S = run_model(stop, P, '');
t = R0.ml_score.Time;
sc = interp1(S.ml_score.Time, double(S.ml_score.Data(:,1)), t, 'previous');
tr = S.trip.Time(find(S.trip.Data(:) > 0.5, 1)) - R0.tEvent;
fprintf('Confirmation off: max score difference %.3g, trip %.1f ms (saved %.1f ms)\n', ...
    max(abs(sc - R0.ml_score.Data)), 1e3*tr, 1e3*R0.tTrip);
P.ml.confirm.on = 1; P.ml.confirm.thr = -Inf;
S = run_model(stop, P, '');
k = find(S.ml_nudge.Data(:) ~= 0);
tr = S.trip.Time(find(S.trip.Data(:) > 0.5, 1)) - R0.tEvent;
fprintf('Confirmation on: nudge %.1f A from %.1f to %.1f ms, trip %.1f ms, resp %.4f rad, raw %.4f rad\n', ...
    S.ml_nudge.Data(k(1)), 1e3*(S.ml_nudge.Time(k(1)) - R0.tEvent), 1e3*(S.ml_nudge.Time(k(end)) - R0.tEvent), ...
    1e3*tr, S.ml_resp.Data(end), S.ml_raw.Data(end));
end

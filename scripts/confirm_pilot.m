function T = confirm_pilot()
% CONFIRM_PILOT  Step 9: the angle response that sets the confirmation's threshold.
%   Runs the feeder-retrained detector with the confirmation on and no
%   threshold (every alarm trips at the end of its nudge), so each run reports
%   the PCC voltage angle response of its first confirmation:
%     feeder, PI     the 8 load-switching events that tripped in step 8.5, and
%                    per condition the unit's matched island at Q_f 1.8, the
%                    natural, matched (Q_f 1 and 1.8) and opposing-drift feeder
%                    islands, plus the slowest island of step 8.5
%     test bed, PI   the islands with a second inverter (opposing drift, and no
%                    drift at Q_f 1.8)
%     test bed, H-infinity  the no-load steady run that tripped in step 8.7
%   Saves results/confirm_pilot.csv. Runs go to data/feeder/pi_<det>_pilot/ and
%   data/closedloop/<controller>_<det>_pilot/ (finished runs are skipped).
root = fileparts(fileparts(mfilename('fullpath')));
det = 'islanding_classifier_feeder';
c = struct('tag', 'pilot', 'thr', -Inf, 'sign', 0, 'mode', 1);
fc = {'f30_t1', 'f50_t2', 'f60a3_t3'};
f = {'f30_t1_event04', 'f30_t1_event12', 'f30_t1_event13', 'f50_t2_event04', 'f50_t2_event12', ...
     'f60a3_t3_event04', 'f60a3_t3_event12', 'f60a3_t3_event13', 'f50_t2_dt_island_qf1_dP+03_dQ+0.0'};
for k = 1:numel(fc)
    f = [f, strcat(fc{k}, {'_svc_island_qf1.8_dP+00_dQ+0.0', '_dt_island_natural', '_dt_island_qf1_dP+00_dQ+0.0', ...
                           '_dt_island_qf1.8_dP+00_dQ+0.0', '_dt_island_der2_Kq-2000'})]; %#ok<AGROW>
end
tc = {'scr15_t1', 'scr7_t2', 'scr4_t3'};
b = [strcat(tc, '_island_der2_Kq-2000'), strcat(tc, '_island_der2_Kq0_qf1.8')];
cols = {'case', 'island', 'tTrip_ms', 'nConfirm', 'tConfirm_ms', 'resp_rad', 'raw_rad'};
A = feeder_closed_loop({'cases'}, 1, f, det, c);
B = closed_loop_test({'cases'}, 1, det, c, b);
H = closed_loop_test({'steady'}, 3, det, c, {'scr7_t2_steady_noload'});
T = [addcol(A(:, cols), "feeder PI"); addcol(B(:, cols), "test bed PI"); addcol(H(:, cols), "test bed H-infinity")];
writetable(T, fullfile(root, 'results', 'confirm_pilot.csv'));
disp(T);
end

function T = addcol(T, set)
T.set = repmat(set, height(T), 1);
end

function run_feeder(stages)
% RUN_FEEDER  Every stage of the real-feeder study in order.
%   STAGES is any of the names below (default all). Simulation stages skip
%   cases already saved, so the run can be restarted.
%     screen       connection-bus screening and operating window (FEEDER_SCREENING)
%     build        hybrid_pv_wind_feeder.slx from the test bed (BUILD_FEEDER_MODEL)
%     closedloop   the Phase 7 detector, unchanged, on the feeder, PI control,
%                  with the AFD baseline and the mismatch grid (FEEDER_CLOSED_LOOP)
%     dataset      feeder training cases at four other conditions (FEEDER_DATASET)
%     features     their window features, without and with sensor noise
%     retrain      the detector retrained with them, and its offline checks (FEEDER_RETRAIN)
%     retrained    the retrained detector on the feeder: PI with the mismatch
%                  grid, then H-infinity
%     testbed      the retrained detector on the test-bed conditions of Phase 7,
%                  PI and H-infinity
%     controllers  the four current controllers on the feeder (FEEDER_CONTROLLERS)
%     pilot        step 9: the confirmation's angle response on the cases that
%                  set its threshold (CONFIRM_PILOT; needs the step 9 build)
%     confirm      step 9: the retrained detector with the confirmation, on the
%                  feeder (PI with the mismatch grid, then H-infinity) and on
%                  the test-bed conditions (PI and H-infinity)
if nargin < 1
    stages = {'screen', 'build', 'closedloop', 'dataset', 'features', 'retrain', 'retrained', 'testbed', 'controllers', ...
              'pilot', 'confirm'};
end
det = 'islanding_classifier_feeder';
if any(strcmp(stages, 'screen')), feeder_screening(); end
if any(strcmp(stages, 'build')), build_feeder_model(); end
if any(strcmp(stages, 'closedloop')), feeder_closed_loop({'cases', 'steady', 'afd', 'ndz'}, 1); end
if any(strcmp(stages, 'dataset')), feeder_dataset(); end
if any(strcmp(stages, 'features'))
    M = load(fullfile(fileparts(fileparts(mfilename('fullpath'))), 'ml', 'islanding_classifier.mat'));
    for level = [0 1], extract_features(M.W, M.Wb, M.step, level, 'feeder'); end
end
if any(strcmp(stages, 'retrain')), feeder_retrain(); end
if any(strcmp(stages, 'retrained'))
    feeder_closed_loop({'cases', 'steady', 'ndz'}, 1, {}, det);
    feeder_closed_loop({'cases', 'steady'}, 3, {}, det);
end
if any(strcmp(stages, 'testbed'))
    closed_loop_test({'cases', 'steady'}, 1, det);
    closed_loop_test({'cases', 'steady'}, 3, det);
end
if any(strcmp(stages, 'controllers')), feeder_controllers(); end
if any(strcmp(stages, 'pilot')), confirm_pilot(); end
if any(strcmp(stages, 'confirm'))
    c = struct('tag', 'confirm');                       % the settings of P.ml.confirm
    feeder_closed_loop({'cases', 'steady', 'ndz'}, 1, {}, det, c);
    feeder_closed_loop({'cases', 'steady'}, 3, {}, det, c);
    closed_loop_test({'cases', 'steady'}, 1, det, c);
    closed_loop_test({'cases', 'steady'}, 3, det, c);
end
end

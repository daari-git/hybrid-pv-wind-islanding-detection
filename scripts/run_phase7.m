function run_phase7(stages)
% RUN_PHASE7  Every Phase 7 stage in order.
%   STAGES is any of 'calibrate', 'features', 'noise', 'final', 'build', 'verify',
%   'closedloop', 'hinf', 'plots' (default all). Simulation stages skip
%   cases already saved, so the run can be restarted.
%     calibrate   sensor noise as the detector sees it (NOISE_CALIBRATION)
%     features    the dataset's windows without noise and with that noise added (levels 1, 2)
%     noise       the classifiers trained without and with noise (NOISE_STUDY)
%     final       the noise-trained detector on all 400 cases (FINAL_CLASSIFIER)
%     build       rebuild the model around the final detector
%     verify      the detector inside the model against the offline code (VERIFY_DETECTOR)
%     closedloop  the detector in the loop on unseen conditions, PI control
%     hinf        the same cases with H-infinity current control
%     plots       PLOT_PHASE7
if nargin < 1, stages = {'calibrate', 'features', 'noise', 'final', 'build', 'verify', 'closedloop', 'hinf', 'plots'}; end
root = fileparts(fileparts(mfilename('fullpath')));
if any(strcmp(stages, 'calibrate')), noise_calibration(); end
if any(strcmp(stages, 'features'))
    for W = [0.01 0.02 0.04]
        for level = [0 1 2], extract_features(W, 0.04, 0.005, level); end
    end
end
if any(strcmp(stages, 'noise')), noise_study(); select_detector(); end
if any(strcmp(stages, 'final')), final_classifier(); end
if any(strcmp(stages, 'build'))
    build_model(10);
    b = fullfile(root, 'hybrid_pv_wind_islanding.slx.r2018a');
    if exist(b, 'file'), delete(b); end
end
if any(strcmp(stages, 'verify')), verify_detector(); end
if any(strcmp(stages, 'closedloop')), closed_loop_test({'cases', 'steady', 'afd', 'ndz'}, 1); end
if any(strcmp(stages, 'hinf')), closed_loop_test({'cases', 'steady'}, 3); end
if any(strcmp(stages, 'plots')), plot_phase7(); end
end

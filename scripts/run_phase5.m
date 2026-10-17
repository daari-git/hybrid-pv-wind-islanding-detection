function run_phase5(stages)
% RUN_PHASE5  Rebuild the model and run every Phase 5 stage in order.
%   STAGES is any of 'build', 'points', 'stress', 'dataset', 'baselines',
%   'plots' (default all).
%   Each stage skips work already saved, so the run can be restarted.
if nargin < 1, stages = {'build', 'points', 'stress', 'dataset', 'baselines', 'plots'}; end
root = fileparts(fileparts(mfilename('fullpath')));
if any(strcmp(stages, 'build'))
    build_model(10);
    b = fullfile(root, 'hybrid_pv_wind_islanding.slx.r2018a');
    if exist(b, 'file'), delete(b); end
end
if any(strcmp(stages, 'points')), operating_points(); end
if any(strcmp(stages, 'stress')), afd_stress(); end
if any(strcmp(stages, 'dataset')), make_dataset(); end
if any(strcmp(stages, 'baselines')), dataset_baselines(); end
if any(strcmp(stages, 'plots')), plot_phase5(); end
end

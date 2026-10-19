function P = use_detector(P, name)
% USE_DETECTOR  Run the model with another trained detector.
%   P = USE_DETECTOR(P, NAME) loads ml/NAME.mat (as saved by FINAL_CLASSIFIER
%   or FEEDER_RETRAIN) into P.ml. The model's detector block fixes its buffer
%   and layer sizes when it is built, so the detector must have the same
%   windows and network shape as ml/islanding_classifier.mat.
root = fileparts(fileparts(mfilename('fullpath')));
M = load(fullfile(root, 'ml', [name '.mat']));
[theta, layers] = ml_pack(M.model);
assert(isequal(layers, P.ml.layers) && M.W == P.ml.W && M.Wb == P.ml.Wb && M.step == P.ml.step, ...
    'use_detector:shape', 'ml/%s.mat does not fit the model''s detector block.', name);
P.ml.theta = theta; P.ml.threshold = M.threshold; P.ml.debounce = M.debounce;
end

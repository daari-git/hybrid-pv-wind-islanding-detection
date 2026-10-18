function [theta, layers] = ml_pack(net)
% ML_PACK  A trained network as one parameter vector, for the detector inside the model.
%   [THETA, LAYERS] = ML_PACK(NET) packs a two-hidden-layer network of
%   FITCNET (ReLU hidden layers, softmax output, standardised inputs) as
%       [Mu; Sigma; W1(:); b1; W2(:); b2; W3(:); b3]
%   and returns its layer sizes [inputs hidden1 hidden2 outputs]. The model's
%   'Machine-learning islanding detector' block unpacks it in this order.
assert(numel(net.LayerSizes) == 2 && strcmp(net.Activations, 'relu'), ...
    'The in-model detector expects two ReLU hidden layers.');
W = net.LayerWeights; b = net.LayerBiases;
theta = [net.Mu(:); net.Sigma(:); W{1}(:); b{1}(:); W{2}(:); b{2}(:); W{3}(:); b{3}(:)];
layers = [size(W{1}, 2) size(W{1}, 1) size(W{2}, 1) size(W{3}, 1)];
end

function mdl = fit_detector(m, X, y)
% FIT_DETECTOR  Train one of the islanding classifiers of Phase 6 on windows X with labels y.
%   M is 'tree' (one decision tree, minimum leaf 50 windows), 'forest' (100
%   bagged trees, minimum leaf 5), 'svm' (Gaussian kernel, 6000 windows drawn
%   at random) or 'nn' (neural network, hidden layers of 20 and 10).
switch m
    case 'tree'
        mdl = fitctree(X, y, 'MinLeafSize', 50);
    case 'forest'
        mdl = fitcensemble(X, y, 'Method', 'Bag', 'NumLearningCycles', 100, ...
            'Learners', templateTree('MinLeafSize', 5));
    case 'svm'
        k = randperm(numel(y), min(6000, numel(y)));
        mdl = fitcsvm(X(k,:), y(k), 'KernelFunction', 'gaussian', 'KernelScale', 'auto', ...
            'Standardize', true, 'CacheSize', 'maximal');
        mdl = fitPosterior(mdl);
    case 'nn'
        mdl = fitcnet(X, y, 'LayerSizes', [20 10], 'Standardize', true, 'IterationLimit', 500);
end
end

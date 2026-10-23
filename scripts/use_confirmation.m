function P = use_confirmation(P, c)
% USE_CONFIRMATION  Run the model with the ML-triggered confirmation of step 9.
%   P = USE_CONFIRMATION(P, C) sets P.ml.confirm.on = 1 and copies every other
%   field of the struct C except 'tag' (e.g. thr, sign, mode, amp, T) into
%   P.ml.confirm. The model needs a build since step 9 (BUILD_MODEL, then
%   BUILD_FEEDER_MODEL).
P.ml.confirm.on = 1;
f = setdiff(fieldnames(c), {'tag'});
for k = 1:numel(f)
    P.ml.confirm.(f{k}) = c.(f{k});
end
end

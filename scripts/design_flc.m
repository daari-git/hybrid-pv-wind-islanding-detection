function F = design_flc(verbose)
% DESIGN_FLC  Fuzzy PI current controller (incremental form).
%   Inputs : normalised error e/Ke and its change per sample de/Kde, each with
%            seven triangular sets NB NM NS ZE PS PM PB on [-1, 1].
%   Rules  : the standard 49-rule table, output set index = i + j - 4.
%   Output : change in controller output, Sugeno singletons with a smaller
%            gain near zero error and full gain for large errors.
%   Control law: u(k) = u(k-1) + Ku * FLC(e/Ke, de/Kde).
%   The scaling factors are set so that, for small signals with a linear rule
%   output, the controller equals the baseline PI:
%       Ku/(2*Kde) = Kp   and   Ku/(2*Ke) = Ki*Tc.
%   Saved to scripts/flc_controller.mat.
if nargin < 1, verbose = true; end
P = params(10);
Kde = 4;                                   % change of error per sample that saturates the input (A)
Ku  = 2*Kde*P.ctrl.KpI;                    % output scaling (V per sample)
Ke  = Ku/(2*P.ctrl.KiI*P.Tc);              % error that saturates the input (A)

fis = sugfis('Name', 'fuzzy_pi_current');
labels = {'NB','NM','NS','ZE','PS','PM','PB'};
c = linspace(-1, 1, 7); w = c(2) - c(1);
fis = addInput(fis, [-1 1], 'Name', 'e');
fis = addInput(fis, [-1 1], 'Name', 'de');
for k = 1:7
    mf = [c(k)-w c(k) c(k)+w];
    fis = addMF(fis, 'e',  'trimf', mf, 'Name', labels{k});
    fis = addMF(fis, 'de', 'trimf', mf, 'Name', labels{k});
end
fis = addOutput(fis, [-1 1], 'Name', 'du');
out = [-1 -0.6 -0.25 0 0.25 0.6 1];       % compressed near zero, full at the ends
for k = 1:7
    fis = addMF(fis, 'du', 'constant', out(k), 'Name', labels{k});
end
rules = zeros(49, 5); r = 0;
for i = 1:7
    for j = 1:7
        r = r + 1;
        rules(r, :) = [i j min(max(i + j - 4, 1), 7) 1 1];
    end
end
fis = addRule(fis, rules);
fis.AndMethod = 'prod';

F.fis = fis; F.Ke = Ke; F.Kde = Kde; F.Ku = Ku; F.Tc = P.Tc;
F.smallSignalGain = out(5)/c(5);           % slope of the output map near zero
F.Kp_eq = F.smallSignalGain*Ku/(2*Kde);
F.Ki_eq = F.smallSignalGain*Ku/(2*Ke*P.Tc);
root = fileparts(fileparts(mfilename('fullpath')));
save(fullfile(root, 'scripts', 'flc_controller.mat'), '-struct', 'F');
if verbose
    fprintf('Fuzzy PI: Ke = %.0f A, Kde = %.1f A/sample, Ku = %.0f V/sample, 49 rules\n', Ke, Kde, Ku);
    fprintf('Small-signal equivalent PI: Kp = %.2f, Ki = %.0f (baseline PI: %g, %g)\n', ...
        F.Kp_eq, F.Ki_eq, P.ctrl.KpI, P.ctrl.KiI);
end
end

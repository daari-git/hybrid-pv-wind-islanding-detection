function C = design_pid(verbose)
% DESIGN_PID  PID current controller: the baseline PI plus a filtered derivative.
%   pidtune never adds derivative action on this plant: with the 1.5-sample
%   loop delay the derivative's phase lead arrives too late and its gain
%   raises the LCL resonance peak. A grid search confirms it: the worst-case
%   sensitivity peak over SCR 20, 10, 5, 3 and 2 grows with every increase in
%   derivative gain, so the most robust PID is the PI itself.
%   To give the comparison a real PID, the PI gains are kept from the baseline
%   and the derivative is set to the largest value that costs no more than 5%
%   of the PI's worst-case robustness. Saved to scripts/pid_controller.mat.
if nargin < 1, verbose = true; end
P0 = params(10); Tc = P0.Tc; scrs = [20 10 5 3 2];
G = cell(1, numel(scrs));
for k = 1:numel(scrs), G{k} = discrete_plant(params(scrs(k))); end
Kds = [0 logspace(-5, -2.5, 26)];
Tfs = [1 2 4 8]*Tc;
best = struct('Ms', Inf);
res = nan(numel(Kds), numel(Tfs));
for i = 1:numel(Kds)
    for j = 1:numel(Tfs)
        Cd = pid(P0.ctrl.KpI, P0.ctrl.KiI, Kds(i), Tfs(j), Tc, 'IFormula', 'ForwardEuler', 'DFormula', 'BackwardEuler');
        Ms = 0;
        for k = 1:numel(scrs)
            L = Cd*G{k};
            if ~isstable(feedback(L, 1)), Ms = Inf; break; end
            Ms = max(Ms, norm(feedback(1, L), inf));
        end
        res(i, j) = Ms;
        if Ms < best.Ms, best = struct('Ms', Ms, 'Kd', Kds(i), 'Tf', Tfs(j)); end
    end
end
[~, jb] = min(min(res, [], 1));                          % best filter time constant
ok = find(res(:, jb) <= 1.05*res(1, 1), 1, 'last');      % largest Kd within 5% of the PI's peak
C.Kp = P0.ctrl.KpI; C.Ki = P0.ctrl.KiI; C.Kd = Kds(ok); C.Tf = Tfs(jb); C.N = 1/Tfs(jb);
C.Tc = Tc; C.worstMs = res(ok, jb); C.worstMs_PI = res(1, 1); C.searchKd = Kds; C.searchMs = res(:, jb)';
root = fileparts(fileparts(mfilename('fullpath')));
save(fullfile(root, 'scripts', 'pid_controller.mat'), '-struct', 'C');
if verbose
    fprintf('PID: Kp = %g, Ki = %g, Kd = %.3g, derivative filter Tf = %.3g s (N = %.0f rad/s)\n', C.Kp, C.Ki, C.Kd, C.Tf, C.N);
    fprintf('Worst-case sensitivity peak over SCR 20..2: PI %.2f, PID %.2f\n', C.worstMs_PI, C.worstMs);
    fprintf('Worst-case peak against Kd (Tf = %.0f us):\n', 1e6*Tfs(jb));
    for i = 1:3:numel(Kds), fprintf('   Kd %.2e -> %.2f\n', Kds(i), res(i, jb)); end
end
end

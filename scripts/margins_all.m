function T = margins_all()
% MARGINS_ALL  Current-loop stability margins of every controller at each grid strength.
%   Evaluated on the discrete plant (zero-order hold plus one sample of
%   computation delay). The fuzzy PI is nonlinear; it is represented by its
%   small-signal equivalent PI, which governs behaviour near steady state.
scrs = [20 10 5 3 2];
P0 = params(10); Tc = P0.Tc;
K = load(fullfile(fileparts(mfilename('fullpath')), 'flc_controller.mat'));
C = { pid(P0.ctrl.KpI, P0.ctrl.KiI, 0, 0, Tc, 'IFormula', 'ForwardEuler'), ...
      pid(P0.pid.Kp, P0.pid.Ki, P0.pid.Kd, 1/P0.pid.N, Tc, 'IFormula', 'ForwardEuler', 'DFormula', 'BackwardEuler'), ...
      ss(P0.hinf.A, P0.hinf.B, P0.hinf.C, P0.hinf.D, Tc), ...
      pid(K.Kp_eq, K.Ki_eq, 0, 0, Tc, 'IFormula', 'BackwardEuler') };
names = {'PI', 'PID', 'H-infinity', 'Fuzzy PI (small-signal)'};
T = table();
for k = 1:numel(scrs)
    Gd = discrete_plant(params(scrs(k)));
    for c = 1:numel(C)
        L = C{c}*Gd;
        A = allmargin(L);
        gm = min([20*log10(A.GainMargin(A.GainMargin > 1)), Inf]);
        pm = min([abs(A.PhaseMargin), Inf]);
        Ms = norm(feedback(1, L), inf);
        T = [T; table(string(names{c}), scrs(k), gm, pm, Ms, A.Stable, ...
            'VariableNames', {'controller','scr','GM_dB','PM_deg','Ms','stable'})]; %#ok<AGROW>
    end
end
root = fileparts(fileparts(mfilename('fullpath')));
writetable(T, fullfile(root, 'results', 'margins_all.csv'));
fprintf('%-24s %s\n', 'Controller', 'Gain margin (dB) / phase margin (deg) / sensitivity peak at SCR 20, 10, 5, 3, 2');
for c = 1:numel(names)
    r = T(T.controller == names{c}, :);
    fprintf('%-24s', names{c});
    for k = 1:height(r), fprintf('  %4.1f/%3.0f/%4.2f', r.GM_dB(k), r.PM_deg(k), r.Ms(k)); end
    fprintf('\n');
end
end

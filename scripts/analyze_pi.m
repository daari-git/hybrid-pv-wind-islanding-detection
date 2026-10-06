function T = analyze_pi()
% ANALYZE_PI  Phase 2: current-loop margins of the PI baseline against grid strength.
scrs = [20 10 5 3 2];
P0 = params(10);
cases = {'Model (no loop delay)', 0; 'Digital controller (1.5/fsw delay)', 1.5/P0.fsw};
T = table();
for c = 1:size(cases, 1)
    fprintf('\n%s, Kp = %g, Ki = %g\n', cases{c,1}, P0.ctrl.KpI, P0.ctrl.KiI);
    fprintf('%5s %9s %9s %8s %8s %6s %7s\n', 'SCR', 'fres(Hz)', 'fc(Hz)', 'PM(deg)', 'GM(dB)', 'Ms', 'stable');
    for scr = scrs
        P = params(scr);
        M = loop_margins(P, P.ctrl.KpI, P.ctrl.KiI, cases{c,2});
        fprintf('%5g %9.0f %9.0f %8.1f %8.1f %6.2f %7d\n', M.scr, M.fres, M.fc, M.pm, M.gm, M.Ms, M.stable);
        T = [T; table(string(cases{c,1}), M.scr, M.fres, M.fc, M.pm, M.gm, M.Ms, M.stable, ...
            'VariableNames', {'case','scr','fres_Hz','fc_Hz','PM_deg','GM_dB','Ms','stable'})]; %#ok<AGROW>
    end
end
% outer loops, from the same parameters
P = P0; s = tf('s');
Lv = (P.ctrl.KpV + P.ctrl.KiV/s) * (1.5*P.Vpk/(3227e-6*P.Vdc)) / s;      % DC-link voltage loop
[~, pmv, ~, wv] = margin(Lv);
Lp = (P.pll.Kp + P.pll.Ki/s) * P.Vpk / s;                                 % PLL
[~, pmp, ~, wp] = margin(Lp);
fprintf('\nDC-link voltage loop: crossover %.1f Hz, phase margin %.0f deg\n', wv/(2*pi), pmv);
fprintf('PLL: crossover %.1f Hz, phase margin %.0f deg\n', wp/(2*pi), pmp);
root = fileparts(fileparts(mfilename('fullpath')));
writetable(T, fullfile(root, 'results', 'pi_margins.csv'));
end

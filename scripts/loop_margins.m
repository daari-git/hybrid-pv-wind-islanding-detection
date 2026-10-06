function M = loop_margins(P, Kp, Ki, Td)
% LOOP_MARGINS  Stability margins of the current loop for one operating point.
%   M = LOOP_MARGINS(P, KP, KI, TD) uses the PI gains KP, KI and an optional
%   loop delay TD in seconds (0 matches the Simulink model, which samples at
%   the simulation step; 1.5/fsw represents a real digital controller).
if nargin < 4, Td = 0; end
[G, info] = plant_model(P);
s = tf('s');
C = Kp + Ki/s;
L = C*G;
if Td > 0, [n, d] = pade(Td, 3); L = L*tf(n, d); end
[gm, pm, ~, wcp] = margin(L);
M.scr   = P.grid.scr;
M.fres  = info.fres;
M.fc    = wcp/(2*pi);                       % crossover (Hz)
M.pm    = pm;                               % phase margin (deg)
M.gm    = 20*log10(gm);                     % gain margin (dB)
M.Ms    = norm(feedback(1, L), inf);        % sensitivity peak
M.stable = isstable(feedback(L, 1));
M.L = L;
end

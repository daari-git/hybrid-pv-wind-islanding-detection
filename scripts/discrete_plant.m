function Gd = discrete_plant(P)
% DISCRETE_PLANT  Current-loop plant as the digital controller sees it.
%   Zero-order hold at the control period P.Tc plus one sample of
%   computation delay, which together give the 1.5-sample loop delay.
Gd = c2d(ss(plant_model(P)), P.Tc, 'zoh') * tf(1, [1 0], P.Tc);
end

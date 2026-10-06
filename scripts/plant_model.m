function [G, info] = plant_model(P, feedforward)
% PLANT_MODEL  Current-loop plant of the inverter with LCL filter and grid.
%   G = PLANT_MODEL(P) returns the transfer function from the controller
%   output u (V) to the inverter-side inductor current i1 (A), which is the
%   current the model's controller measures.
%
%   The model adds the measured PCC voltage to the controller output
%   (voltage feedforward), so the plant is derived with that path closed:
%       v_inv = u + F*v_pcc,   F = 1 (default) or 0 for no feedforward.
%
%   Per phase, with current flowing from inverter to grid and v_grid = 0:
%       Z1 = sL1 + R1          inverter-side inductor
%       Zc = Rd + 1/(sCf)      damped filter capacitor
%       Z2 = sL2 + R2          grid-side inductor
%       Zg = sLg + Rg          grid impedance from the short-circuit ratio
%       G  = 1 / ( Z1 + Zc*(Z2 + (1-F)*Zg) / (Zc + Z2 + Zg) )
if nargin < 2, feedforward = 1; end
s  = tf('s');
Z1 = s*P.lcl.L1 + P.lcl.R1;
Zc = P.lcl.Rd + 1/(s*P.lcl.Cf);
Z2 = s*P.lcl.L2 + P.lcl.R2;
Zg = s*P.grid.L + P.grid.R;
G  = minreal(1/(Z1 + Zc*(Z2 + (1-feedforward)*Zg)/(Zc + Z2 + Zg)), 1e-6);
info.fres = sqrt((P.lcl.L1 + P.lcl.L2 + P.grid.L)/(P.lcl.L1*(P.lcl.L2 + P.grid.L)*P.lcl.Cf))/(2*pi);
info.Lg   = P.grid.L;
end

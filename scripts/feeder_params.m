function P = feeder_params(P, loadScale, pcc)
% FEEDER_PARAMS  Settings of the real-feeder model, hybrid_pv_wind_feeder.
%   P = FEEDER_PARAMS(P, LOADSCALE, PCC) points the run scripts at the feeder
%   model and adds P.feeder for the Pidari 400 V feeder of NEA_LV_FEEDER_DATA
%   (Real_model/) loaded to LOADSCALE times its recorded peak (default 0.3),
%   with the PV-wind unit connected at bus PCC (default the feeder's PCC, A5).
%   Feeder loads are constant impedances that draw their share of the load
%   at the load-flow voltages without the unit, as in build_nea_lv_feeder.m.
%   P.grid.R, P.grid.L and P.grid.scr become the short-circuit impedance
%   behind the PCC, for the plant and loop-margin scripts.
%
%   Switches, all off by default:
%     P.feeder.tIsland   opening time of the transformer breaker: the whole
%                        400 V feeder islands with the unit (the transformer's
%                        11 kV drop-out fuse, or the 11 kV feeder breaker)
%     P.feeder.der2Bus   bus of the second inverter; 0 = at the unit's PCC,
%                        on the unit's side of its breaker (as in the test bed)
%     P.feeder.swP/swQ/swT  switched load at the end of distributor B (B3):
%                        closes at swT(1), opens again at swT(2)
if nargin < 2 || isempty(loadScale), loadScale = 0.3; end
root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root, 'Real_model'));
m = nea_lv_feeder_data(loadScale);
if nargin < 3 || isempty(pcc), pcc = m.pccBus; end
r = feeder_loadflow(m);
nb = numel(m.busName);
w = 2*pi*m.freq;

P.model = 'hybrid_pv_wind_feeder';
F.loadScale = loadScale;
F.busName = m.busName;
F.line = m.line(:, 1:2);
F.pcc = pcc;
F.Vsrc = m.Vsource;                                  % pu of 400 V, behind the upstream equivalent
F.Rsrc = real(m.Zsrc);  F.Lsrc = imag(m.Zsrc)/w;     % 11 kV network and transformer, at 400 V
F.lineR = real(r.z).';  F.lineL = imag(r.z).'/w;
Snom = m.Sload ./ r.Vpu.^2;                          % constant impedance, power at 400 V
F.loadP = real(Snom).';  F.loadQL = imag(Snom).';
F.Sload = m.Sload.';
F.Vlf = r.Vpu.';                                     % load-flow voltages without the unit
F.rConn = 1e6*ones(1, nb);  F.rConn(pcc) = 1e-3;     % the unit's service connection (ohm)
F.der2Bus = 0;
F.tIsland = 1e6;
F.swP = 10e3;  F.swQ = 10e3*tan(acos(m.pf));  F.swT = [1e6 2e6];
P.feeder = F;
P = feeder_der2(P, 0);

zth = r.zth(pcc);
P.grid.R = real(zth);  P.grid.L = imag(zth)/w;
P.grid.xr = imag(zth)/real(zth);
P.grid.scr = P.Vll^2/abs(zth)/P.Sn;
end

function P = island_case(P, dP, dQ, tIsland)
% ISLAND_CASE  Set the local RLC load for an islanding test with a given mismatch.
%   P = ISLAND_CASE(P, DP, DQ, TISLAND) sizes the load relative to the inverter's
%   output at the PCC (P.island.Pinv, P.island.Qinv, measured with the grid
%   connected) and opens the grid breaker at TISLAND:
%       DP = (P_load - P_inv)/P_inv            active power mismatch
%       DQ = (Q_load - Q_inv)/P_inv            reactive power mismatch
%   where Q_load = QL - QC is the load's net reactive absorption at 50 Hz.
%   DP = DQ = 0 is the IEEE 1547.1 worst case. The quality factor is P.load.Qf.
%   The protection is left unarmed so the detectors can be evaluated offline.
PL = P.island.Pinv*(1 + dP);
Qnet = P.island.Qinv + dQ*P.island.Pinv;
P.load.P  = PL;
P.load.QC = P.load.Qf*PL;
P.load.QL = P.load.QC + Qnet;
P.tIsland = tIsland;
P.prot.tArm = 1e6;            % model protection unarmed; detectors are evaluated offline
end

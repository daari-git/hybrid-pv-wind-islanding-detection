function P = feeder_island_case(P, dP, dQ, Qf, tIsland)
% FEEDER_ISLAND_CASE  Island the whole 400 V feeder with a given power mismatch.
%   P = FEEDER_ISLAND_CASE(P, DP, DQ, QF, TISLAND) opens the transformer
%   breaker at TISLAND and sizes the local RLC load at the unit's PCC so that
%   the island (unit, other generation if P.der2.on, feeder loads and local
%   load) has the mismatch, as in ISLAND_CASE, relative to its generation Pg:
%       DP = (P_load - Pg)/Pg,   DQ = (Q_load - Q_gen)/Pg
%   with the feeder's own consumption taken from the power it draws through
%   the transformer with a negligible local load (P.island.Pdt, Qdt, or
%   Pdt2, Qdt2 with the other generation on). The feeder loads have no
%   capacitance, so all of the island's capacitance is in the local load,
%   QC = QF*P_load, which makes QF the island's quality factor. Errors if
%   the local load would have to generate (the feeder alone draws more than
%   the generation can supply at that mismatch).
%   QF = 0: no local load (200 W), the island as the feeder happens to be.
%   The protection is left unarmed, as in ISLAND_CASE.
%   The RLC load is a constant impedance rated at 400 V, and on the feeder the
%   PCC is well above 1 pu, so its ratings are divided by the square of the
%   PCC voltage measured with the grid connected (P.island.Vpcc, Vpcc2).
Pg = P.island.Pinv + P.der2.on*P.der2.P;
if P.der2.on
    Pdt = P.island.Pdt2; Qdt = P.island.Qdt2; V = P.island.Vpcc2;
else
    Pdt = P.island.Pdt; Qdt = P.island.Qdt; V = P.island.Vpcc;
end
P.feeder.tIsland = tIsland;
P.prot.tArm = 1e6;
if Qf == 0
    P.load.P = 200; P.load.QL = 200; P.load.QC = 200;
    return
end
PL = dP*Pg - Pdt;                                      % local load that leaves the island DP short
QnetL = dQ*Pg - Qdt;
QC = Qf*Pg*(1 + dP);
QL = QC + QnetL;
assert(PL > 100 && QL > 0, 'feeder_island_case:infeasible', ...
    'No passive local load gives dP %+g, dQ %+g, Qf %g: the feeder draws %.0f W and %.0f var through the transformer.', ...
    dP, dQ, Qf, Pdt, Qdt);
P.load.P = PL/V^2; P.load.QC = QC/V^2; P.load.QL = QL/V^2;
end

function P = feeder_der2(P, bus)
% FEEDER_DER2  Place the second inverter on the feeder model.
%   P = FEEDER_DER2(P, BUS) connects it at feeder bus BUS, or at the unit's
%   PCC (on the unit's side of its breaker) for BUS = 0. It still runs only
%   with P.der2.on.
P.feeder.der2Bus = bus;
P.feeder.rDer2 = 1e6*ones(1, numel(P.feeder.busName) + 1);
P.feeder.rDer2(bus + 1) = 1e-3;
end

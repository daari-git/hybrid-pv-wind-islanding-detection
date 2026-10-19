function r = feeder_loadflow(m, Pdg, bDG)
% FEEDER_LOADFLOW  Load flow of the Pidari 400 V feeder with an exporting unit.
%   r = FEEDER_LOADFLOW(m, Pdg, bDG) solves the feeder m of NEA_LV_FEEDER_DATA
%   with constant-power loads (backward/forward sweep, as in
%   Real_model/build_nea_lv_feeder.m) and a unit exporting Pdg watts at unity
%   power factor at bus bDG (Pdg = 0: no unit). Returns bus voltages r.Vpu,
%   line impedances r.z (ohm), losses r.loss (kW, lines and transformer),
%   line and transformer currents per unit of their ratings r.load, and the
%   short-circuit impedance r.zth (ohm) behind every bus.
if nargin < 2, Pdg = 0; bDG = 1; end
nb = numel(m.busName); nl = size(m.line, 1);
tempK = 1 + 0.00403*(m.condTempC - 20);
z = zeros(nl, 1);
for k = 1:nl
    c = m.cond(m.line(k, 4));
    z(k) = (c.r20*tempK + 1i*c.x)*m.line(k, 3);
end
Vs = m.Vsource*m.Vnom/sqrt(3);
S = m.Sload/3;  S(bDG) = S(bDG) - Pdg/3;
V = Vs*ones(nb, 1);
for it = 1:200
    I = conj(S./V);
    Ib = zeros(nl, 1); Iacc = I;
    for k = nl:-1:1                                  % lines are listed parent first
        Ib(k) = Iacc(m.line(k, 2));
        Iacc(m.line(k, 1)) = Iacc(m.line(k, 1)) + Ib(k);
    end
    Vold = V;
    V(1) = Vs - m.Zsrc*Iacc(1);
    for k = 1:nl, V(m.line(k, 2)) = V(m.line(k, 1)) - z(k)*Ib(k); end
    if max(abs(V - Vold)) < 1e-9, break, end
end
r.V = V; r.Vpu = abs(V)*sqrt(3)/m.Vnom; r.z = z;
r.Idt = abs(Iacc(1));
r.loss = 3*(sum(real(z).*abs(Ib).^2) + real(m.Zdt)*abs(Iacc(1))^2)/1e3;
amp = [m.cond(m.line(:, 4)).amp]';
r.load = [abs(Ib)./amp; abs(Iacc(1))/(m.dt.kVA*1e3/(sqrt(3)*m.dt.Vlv))];
r.zth = zeros(nb, 1);
for b = 1:nb
    zp = m.Zsrc; k = b;
    while k ~= 1
        j = find(m.line(:, 2) == k, 1); zp = zp + z(j); k = m.line(j, 1);
    end
    r.zth(b) = zp;
end
end

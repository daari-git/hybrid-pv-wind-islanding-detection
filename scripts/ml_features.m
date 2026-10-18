function x = ml_features(v, i, f, dc, id, iq, nW, nWw, Vpk, Ipk, Sn, fs, fw)
% ML_FEATURES  The 22 detector features from buffers that end at the window's end.
%   X = ML_FEATURES(V, I, F, DC, ID, IQ, NW, NWW, VPK, IPK, SN, FS, FW)
%   is the computation of WINDOW_FEATURES on plain buffers, so the same code
%   runs offline and inside the Simulink model (it is code-generation safe):
%     V, I        PCC voltage and inverter current waveforms (n x 3) at FW Hz
%     F, DC, ID, IQ   frequency, DC-link voltage and d/q currents (m x 1) at FS Hz
%   Each buffer holds the baseline followed by the window, the two sharing
%   one sample: the window is the last NW + 1 samples at FS (NWW + 1 at FW),
%   the baseline everything before and including the window's first sample.
%   VPK, IPK and SN are the ratings used to express quantities in per unit.
%
%   The voltage magnitude behind dV_mean, dV_max and dV_max_n is computed
%   here, every 1 ms, as the positive-sequence phasor of the voltage over the
%   last cycle at the measured frequency. Phase 6 used the model's RMS
%   measurement instead, which averages over a fixed 20 ms: off 50 Hz it
%   ripples at twice the grid frequency (tenfold at 49 Hz), which the
%   detector took for the voltage wander of an island.
m = numel(f); n = size(v, 1);
b = 1:m - nW;  w = m - nW:m;                         % 1 kHz signals
bw = 1:n - nWw; ww = n - nWw:n;                       % waveforms

fb = mean(f(b));
tw = (0:nW)'/fs;
pf = [tw ones(nW + 1, 1)] \ f(w);

vc = ((2*v(:,1) - v(:,2) - v(:,3))/3 + 1j*(v(:,2) - v(:,3))/sqrt(3))/Vpk;   % space vectors, pu
ic = ((2*i(:,1) - i(:,2) - i(:,3))/3 + 1j*(i(:,2) - i(:,3))/sqrt(3))/Ipk;
om = 2*pi*fb;
k = (0:n - 1)'/fw;
E = [exp(1j*om*k) exp(-1j*om*k)];                     % positive- and negative-sequence phasors

% voltage magnitude every 1 ms (samples aligned with the 1 kHz signals)
N = round(fw/50);                                     % one nominal cycle, as the RMS measurement
cz = [0; cumsum(vc.*conj(E(:,1)))];
r = round(fw/fs);
idx = n - r*(m - 1:-1:0)';
ok = idx >= N;
V = zeros(m, 1);
V(ok) = abs(cz(idx(ok) + 1) - cz(idx(ok) - N + 1))/N;
bv = b(ok(b));                                        % baseline samples with a full cycle behind them
Vb = mean(V(bv));
vB = E(bw,:) \ vc(bw); vW = E(ww,:) \ vc(ww);
iB = E(bw,:) \ ic(bw); iW = E(ww,:) \ ic(ww);
rvB = sqrt(mean(abs(vc(bw) - E(bw,:)*vB).^2)); rvW = sqrt(mean(abs(vc(ww) - E(ww,:)*vW).^2));
riB = sqrt(mean(abs(ic(bw) - E(bw,:)*iB).^2)); riW = sqrt(mean(abs(ic(ww) - E(ww,:)*iW).^2));

% inverter output power (I is positive into the inverter), pu of rating
s = -1.5*Vpk*Ipk*vc.*conj(ic)/Sn;
pB = mean(real(s(bw))); pW = mean(real(s(ww)));
qB = mean(-imag(s(bw))); qW = mean(-imag(s(ww)));
tpw = (0:nWw)'/fw;
pp = [tpw ones(nWw + 1, 1)] \ real(s(ww));

x = [ ...
    mean(V(w)) - Vb, ...
    max(abs(V(w) - Vb)), ...
    f(w(end)) - fb, ...
    max(abs(f(w) - fb)), ...
    pf(1), ...
    max(abs(diff(f(w))))*fs, ...
    angle(vW(1)/vB(1))*180/pi, ...
    abs(vW(1)) - abs(vB(1)), ...
    abs(vW(2)) - abs(vB(2)), ...
    abs(iW(1)) - abs(iB(1)), ...
    abs(iW(2)) - abs(iB(2)), ...
    pW - pB, ...
    qW - qB, ...
    pp(1), ...
    100*(rvW - rvB), ...
    100*(riW - riB), ...
    max(abs(dc(w) - mean(dc(b)))), ...
    max(abs(id(w) - mean(id(b)))), ...
    max(abs(iq(w) - mean(iq(b)))), ...
    log10((rvW/riW)/(rvB/riB)), ...
    max(abs(f(w) - fb))/(std(f(b)) + 1e-3), ...
    max(abs(V(w) - Vb))/(std(V(bv)) + 1e-4)];
end

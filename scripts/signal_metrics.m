function M = signal_metrics(S, t1, t2)
% SIGNAL_METRICS  Steady-state figures from a run's logged signals over [t1, t2].
%   The window is trimmed to a whole number of fundamental cycles.
P = S.P; f1 = P.fg;
t2 = t1 + floor((t2 - t1)*f1)/f1;
t = S.Igrid.Time; w = t >= t1 & t < t2;
ig = S.Igrid.Data(w, :); vg = S.Vabc.Data(w, :);
[M.thd, M.I1, h] = harmonics(ig(:,1), t(w), f1, 50);
M.h2to7 = h(2:7)';
M.P     = -mean(sum(vg.*ig, 2));                     % W, positive = exported
M.Ipk   = max(abs(ig(:)));                           % largest instantaneous current (A)
M.Vrms  = mean(S.Vpcc_rms.Data(S.Vpcc_rms.Time >= t1 & S.Vpcc_rms.Time < t2));
[M.thdV, M.V1] = harmonics(vg(:,1), t(w), f1, 50);
v = S.VDC.Data(S.VDC.Time >= t1 & S.VDC.Time < t2);
M.Vdc = mean(v); M.VdcRipple = max(v) - min(v);
f = S.freq.Data(S.freq.Time >= t1 & S.freq.Time < t2);
M.f = mean(f); M.fRipple = max(f) - min(f);
M.tripped = any(S.trip.Data(:) > 0.5);
end

function [thd, A1, hpct] = harmonics(x, t, f1, nmax)
% Fourier coefficients by direct projection over an integer number of cycles.
x = x(:); t = t(:) - t(1); A = zeros(nmax, 1);
for n = 1:nmax
    A(n) = hypot(2*mean(x.*cos(2*pi*n*f1*t)), 2*mean(x.*sin(2*pi*n*f1*t)));
end
A1 = A(1); hpct = 100*A/A1; thd = 100*sqrt(sum(A(2:end).^2))/A1;
end

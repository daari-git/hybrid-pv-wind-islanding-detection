function K = design_hinf(verbose)
% DESIGN_HINF  Phase 3: structured H-infinity current controller for the LCL inverter.
%   Fixed-structure mixed-sensitivity synthesis (hinfstruct) on the current-loop
%   plant: inverter, LCL filter, grid impedance, voltage feedforward and a
%   1.5-sample control delay. One controller is tuned against five plants at
%   once, at short-circuit ratios 20, 10, 5, 3 and 2, so the grid inductance
%   uncertainty is handled by the synthesis itself and no order reduction is needed.
%   Controller: PI in series with a second-order section and a low-pass (order 4 in total),
%   every parameter bounded.
%   The discretised controller is saved to scripts/hinf_controller.mat.
if nargin < 1, verbose = true; end
P0 = params(10); Tc = 1/P0.fsw; Td = 1.5*Tc;
s  = tf('s');
[n, d] = pade(Td, 2); D = tf(n, d);
scrs = [20 10 5 3 2];

% ---- plant set ----
G = cell(1, numel(scrs));
for k = 1:numel(scrs), G{k} = ss(plant_model(params(scrs(k))) * D); end
Garr = stack(1, G{:});

% ---- weights ----
Ms = 1.5; wb = 2*pi*220; e0 = 1e-4;            % sensitivity: peak <= Ms, bandwidth wb, near-integral action
W1 = (s/Ms + wb)/(s + wb*e0);
W2 = (1/40)*(s/(2*pi*800) + 1)/(s/(2*pi*20e3) + 1);   % control effort: limit high-frequency gain
Mt = 1.3; wt = 2*pi*1500;                      % complementary sensitivity: roll off above wt
W3 = (s + wt/Mt)/(1e-3*s + wt);

% ---- tunable controller: PI, a notch-type second-order section and a low-pass ----
% Every parameter is bounded so the filter cannot cancel the integrator or
% place dynamics below the fundamental frequency.
Cpi = tunablePID('PI', 'PI');
Cpi.Kp.Value = P0.ctrl.KpI;  Cpi.Kp.Minimum = 0.5;  Cpi.Kp.Maximum = 40;
Cpi.Ki.Value = P0.ctrl.KiI;  Cpi.Ki.Minimum = 500;  Cpi.Ki.Maximum = 2e4;
wn = realp('wn', 2*pi*700);   wn.Minimum = 2*pi*250;  wn.Maximum = 2*pi*3000;
zn = realp('zn', 0.3);        zn.Minimum = 0.02;      zn.Maximum = 3;      % numerator damping
zd = realp('zd', 0.7);        zd.Minimum = 0.3;       zd.Maximum = 3;      % denominator damping
wp = realp('wp', 2*pi*3000);  wp.Minimum = 2*pi*800;  wp.Maximum = 2*pi*8000;
F  = tf([1 2*zn*wn wn^2], [1 2*zd*wn wn^2]) * tf(wp, [1 wp]);
C0 = Cpi*F;
Sg  = feedback(1, Garr*C0);
CL0 = [W1*Sg; W2*C0*Sg; W3*(1 - Sg)];
rng(1);
[CL, gam] = hinfstruct(CL0, hinfstructOptions('Display', 'off', 'RandomStart', 8));
Kc = tf(getValue(C0, CL.Blocks));
Kd = c2d(ss(Kc), Tc, 'tustin');
K.A = Kd.A; K.B = Kd.B; K.C = Kd.C; K.D = Kd.D; K.Tc = Tc; K.gamma = gam; K.order = order(Kd);
K.weights = struct('Ms', Ms, 'wb', wb, 'Mt', Mt, 'wt', wt);
[K.num, K.den] = tfdata(Kc, 'v');
pid = getBlockValue(CL, 'PI');
gv = @(n) getBlockValue(CL, n);
K.tuned = struct('Kp', pid.Kp, 'Ki', pid.Ki, 'fn_Hz', gv('wn')/(2*pi), 'zn', gv('zn'), ...
    'zd', gv('zd'), 'fp_Hz', gv('wp')/(2*pi));
root = fileparts(fileparts(mfilename('fullpath')));
save(fullfile(root, 'scripts', 'hinf_controller.mat'), '-struct', 'K');

if verbose
    disp(K.tuned);
    fprintf('hinfstruct: worst-case weighted norm = %.3f over %d plants, controller order %d\n', gam, numel(scrs), order(Kd));
    fprintf('\n%5s | %27s | %27s\n', 'SCR', 'PI (Kp, Ki from params)', 'H-infinity (discretised)');
    fprintf('%5s | %7s %7s %5s %5s | %7s %7s %5s %5s\n', '', 'PM', 'GM dB', 'Ms', 'ok', 'PM', 'GM dB', 'Ms', 'ok');
    Kchk = d2c(Kd, 'tustin');
    for scr = scrs
        P = params(scr); Gk = plant_model(P)*D;
        a = margins_of((P.ctrl.KpI + P.ctrl.KiI/s)*Gk);
        b = margins_of(Kchk*Gk);
        fprintf('%5g | %7.1f %7.1f %5.2f %5d | %7.1f %7.1f %5.2f %5d\n', scr, a.pm, a.gm, a.Ms, a.ok, b.pm, b.gm, b.Ms, b.ok);
    end
    fprintf('\nController gain at 1 Hz %.0f, at 50 Hz %.1f, at 5 kHz %.2f (PI: %.0f, %.1f, %.2f)\n', ...
        abs(freqresp(Kchk, 2*pi*[1 50 5000])), abs(freqresp(P0.ctrl.KpI + P0.ctrl.KiI/s, 2*pi*[1 50 5000])));
end
end

function m = margins_of(L)
S = allmargin(L);
m.gm = min([20*log10(S.GainMargin(S.GainMargin > 1)), Inf]);       % smallest gain increase to instability
m.pm = min([abs(S.PhaseMargin), Inf]);
m.Ms = norm(feedback(1, L), inf);
m.ok = S.Stable;
end

function r = nea_loadflow(m, opt)
%NEA_LOADFLOW  Backward/forward sweep load flow for a radial feeder model.
%
%   r = nea_loadflow(m) solves the model returned by NEA_FEEDER_DATA. Bus
%   loads are shared in proportion to installed distribution transformer
%   kVA and scaled until the feeder-head current equals m.peakAmps.
%
%   r = nea_loadflow(m, opt) with optional fields
%       opt.calibrate  true (default) - scale loads to m.peakAmps
%       opt.loadScale  multiplier applied to the calibrated/explicit loads
%       opt.Sload      explicit complex bus loads in MVA (skips calibration)
%       opt.capMVAr    [bus MVAr] shunt capacitor banks
%       opt.vexp       voltage exponent of the loads, 0 = constant power
%                      (default), 2 = constant impedance

if nargin < 2, opt = struct; end
if ~isfield(opt, 'calibrate'), opt.calibrate = true; end
if ~isfield(opt, 'loadScale'), opt.loadScale = 1; end
if ~isfield(opt, 'capMVAr'),   opt.capMVAr = zeros(0, 2); end
if ~isfield(opt, 'vexp'),      opt.vexp = 0; end

nb = numel(m.busKV);
Sb = m.Sbase;

% Branch table in per unit: lines first, then transformers ---------------
nl = size(m.line, 1);
nt = size(m.xfmr, 1);
br.from = [m.line(:, 1); m.xfmr(:, 1)];
br.to   = [m.line(:, 2); m.xfmr(:, 2)];
br.z    = zeros(nl + nt, 1);
br.tap  = ones(nl + nt, 1);
br.amp  = inf(nl + nt, 1);
br.name = cell(nl + nt, 1);
br.ohm  = zeros(nl + nt, 1);        % series impedance in ohm, to-side base
tempK = 1 + 0.00403 * (m.condTempC - 20);
for k = 1:nl
    c  = m.cond(m.line(k, 4));
    np = m.line(k, 5);
    zOhm = (c.r20 * tempK + 1i * c.x) * m.line(k, 3) / np;
    zb = m.busKV(m.line(k, 1))^2 / Sb;
    br.z(k)    = zOhm / zb;
    br.ohm(k)  = zOhm;
    br.amp(k)  = c.amp * np;
    br.name{k} = sprintf('%s x%d, %.3f km', c.name, np, m.line(k, 3));
end
for k = 1:nt
    zpu = m.xfmr(k, 4) / 100 * Sb / m.xfmr(k, 3);
    xr  = m.xfmr(k, 5);
    j = nl + k;
    br.tap(j)  = m.xfmr(k, 6);
    % impedance referred to the tapped 11 kV winding
    br.z(j)    = zpu * (1 + 1i * xr) / sqrt(1 + xr^2) * br.tap(j)^2;
    br.amp(j)  = m.xfmr(k, 3) * 1e3 / (sqrt(3) * m.busKV(m.xfmr(k, 2)));
    br.ohm(j)  = br.z(j) * m.busKV(m.xfmr(k, 2))^2 / Sb;
    br.name{j} = sprintf('%g/%g kV transformer, %.1f MVA', m.busKV(m.xfmr(k, 1)), ...
                         m.busKV(m.xfmr(k, 2)), m.xfmr(k, 3));
end

% Order branches so every parent is processed before its children --------
order = zeros(0, 1);
seen = false(nb, 1);
seen(1) = true;
left = (1:nl + nt)';
while ~isempty(left)
    hit = seen(br.from(left));
    if ~any(hit)
        error('nea_loadflow:notRadial', 'Network is not a radial tree rooted at bus 1.');
    end
    seen(br.to(left(hit))) = true;
    order = [order; left(hit)]; %#ok<AGROW>
    left = left(~hit);
end

% Loads -------------------------------------------------------------------
phi = acos(m.pf);
shape = m.dtKVA(:) / sum(m.dtKVA);
Sfixed = zeros(nb, 1);
for k = 1:size(m.fixedLoad, 1)
    b = m.fixedLoad(k, 1);
    mva = sqrt(3) * m.busKV(b) * m.fixedLoad(k, 2) * m.fixedLoad(k, 3) / 1e3;
    Sfixed(b) = Sfixed(b) + mva * exp(1i * phi);
end
Qcap = zeros(nb, 1);
for k = 1:size(opt.capMVAr, 1)
    Qcap(opt.capMVAr(k, 1)) = Qcap(opt.capMVAr(k, 1)) + opt.capMVAr(k, 2);
end

if isfield(opt, 'Sload')
    Sfeeder = opt.Sload(:);
    Sfixed = zeros(nb, 1);
else
    kvHead = m.busKV(br.to(m.calBranch));
    Sfeeder = shape * sqrt(3) * kvHead * m.peakAmps / 1e3 * exp(1i * phi);
    if opt.calibrate
        for it = 1:20
            [~, Ibr] = sweep(Sfeeder + Sfixed);
            amps = abs(Ibr(m.calBranch)) * Sb * 1e3 / (sqrt(3) * kvHead);
            Sfeeder = Sfeeder * m.peakAmps / amps;
            if abs(amps - m.peakAmps) < 1e-4, break, end
        end
    end
end
Sfeeder = Sfeeder * opt.loadScale;
Sload = Sfeeder + Sfixed;
[V, Ibr, iter, converged] = sweep(Sload);

% Results -----------------------------------------------------------------
kvTo = m.busKV(br.to)';
r.model     = m;
r.converged = converged;
r.iter      = iter;
r.V         = V;
r.Vpu       = abs(V);
r.Vkv       = abs(V) .* m.busKV(:);
r.Sload     = Sload;                 % MVA at nominal voltage
r.Sfeeder   = Sfeeder;
r.branch    = br;
r.Iamp      = abs(Ibr) * Sb * 1e3 ./ (sqrt(3) * kvTo);
r.loading   = 100 * r.Iamp ./ br.amp;
r.lossKW    = real(br.z) .* abs(Ibr).^2 * Sb * 1e3;
r.lossKVAr  = imag(br.z) .* abs(Ibr).^2 * Sb * 1e3;

% Feeder-only summary: everything downstream of the calibration branch
down = false(nb, 1);
down(br.to(m.calBranch)) = true;
inFeeder = false(nl + nt, 1);
inFeeder(m.calBranch) = true;
for j = order'
    if down(br.from(j)), down(br.to(j)) = true; inFeeder(j) = true; end
end
r.inFeeder = inFeeder;
r.feederBus = down;
head = m.calBranch;
Vhead = V(br.from(head)) * br.tap(head);
Sin = Vhead * conj(Ibr(head)) * Sb;              % MVA into the feeder
r.feederPinKW   = real(Sin) * 1e3;
r.feederQinKVAr = imag(Sin) * 1e3;
r.feederLossKW  = sum(r.lossKW(inFeeder));
r.feederLossPct = 100 * r.feederLossKW / r.feederPinKW;
r.feederHeadAmp = r.Iamp(head);
[r.feederVmin, idx] = min(r.Vpu + ~down * 10);
r.feederVminBus = idx;
r.feederVhead   = abs(V(br.from(head)));
r.feederVdropPct = 100 * (r.feederVhead - r.feederVmin);

% Annual energy, using the empirical loss load factor 0.3 LF + 0.7 LF^2
LF  = m.loadFactor;
LLF = 0.3 * LF + 0.7 * LF^2;
r.lossLoadFactor   = LLF;
r.annualEnergyMWh  = r.feederPinKW * LF * 8760 / 1e3;
r.annualLossMWh    = r.feederLossKW * LLF * 8760 / 1e3;
r.annualLossPct    = 100 * r.annualLossMWh / r.annualEnergyMWh;

    function [V, Ibr, iter, converged] = sweep(S0)
        V = m.Vsource * ones(nb, 1);
        for jj = 1:numel(order)              % flat start, through the taps
            j = order(jj);
            V(br.to(j)) = V(br.from(j)) * br.tap(j);
        end
        converged = false;
        Ibr = zeros(nl + nt, 1);
        for iter = 1:200
            Vold = V;
            Sv = S0 .* abs(V).^opt.vexp - 1i * Qcap .* abs(V).^2;
            Ibus = conj(Sv / Sb ./ V);
            Iacc = Ibus;                     % backward sweep
            for jj = numel(order):-1:1
                j = order(jj);
                Ibr(j) = Iacc(br.to(j));     % current on the to side
                Iacc(br.from(j)) = Iacc(br.from(j)) + Ibr(j) * br.tap(j);
            end
            for jj = 1:numel(order)          % forward sweep
                j = order(jj);
                V(br.to(j)) = V(br.from(j)) * br.tap(j) - br.z(j) * Ibr(j);
            end
            if max(abs(V - Vold)) < 1e-9, converged = true; break, end
        end
    end
end

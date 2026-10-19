function out = build_nea_lv_feeder(loadScale)
%BUILD_NEA_LV_FEEDER  Simulink model of the Pidari 400 V feeder (feeder only).
%
%   out = build_nea_lv_feeder(loadScale) builds nea_pidari_lv_feeder.slx
%   from NEA_LV_FEEDER_DATA(loadScale) (default 1, the recorded peak):
%
%     400 V source -- upstream equivalent (Pidari 11 kV network + DT)
%       -- DT LV bus -- distributor A: A1..A5 (A5 = PCC)
%                    -- distributor B: B1..B3
%
%   400 V, 50 Hz, discrete at 2 us (Simscape Electrical, Specialized
%   Power Systems) - the voltage level, frequency and solver of the
%   hybrid PV-wind islanding test bed, so the feeder can later be joined
%   to it at the PCC. Loads are constant impedances sized to draw their
%   powers at the load-flow voltages. Every bus has a three-phase V-I
%   meter whose voltages are logged as V_<bus> (V, phase to ground) and
%   the DT current as I_DT (A).
%
%   The model is then simulated for 0.2 s and each bus's RMS voltage is
%   compared with a backward/forward sweep load flow.
%   Requires Simulink and Simscape Electrical.

if nargin < 1, loadScale = 1; end
here = fileparts(mfilename('fullpath'));
m = nea_lv_feeder_data(loadScale);
r = sweep(m);
sys = 'nea_pidari_lv_feeder';
buildModel(sys, m, r);
save_system(sys, fullfile(here, [sys '.slx']));

simOut = sim(sys, 'StopTime', '0.2');
nb = numel(m.busName);
vSim = zeros(nb, 1);
for b = 1:nb
    v = simOut.get(['V_' busTag(b)]);
    x = double(v.Data(v.Time >= 0.1, :));
    vSim(b) = sqrt(mean(x(:).^2)) * sqrt(3) / m.Vnom;
end
i = simOut.get('I_DT'); x = double(i.Data(i.Time >= 0.1, :));
iSim = sqrt(mean(x(:).^2));

fprintf('\n%s\n', m.title);
fprintf('Loading %.0f %% of recorded peak: DT load %.1f kW + %.1f kvar, source %.4f pu behind %.4f%+.4fj ohm\n', ...
        100 * m.loadScale, real(m.Sdt) / 1e3, imag(m.Sdt) / 1e3, m.Vsource, real(m.Zsrc), imag(m.Zsrc));
fprintf('  %-12s %12s %12s %10s\n', 'Bus', 'Sweep (pu)', 'Simulink(pu)', 'Diff');
for b = 1:nb
    fprintf('  %-12s %12.4f %12.4f %10.5f\n', m.busName{b}, r.Vpu(b), vSim(b), vSim(b) - r.Vpu(b));
end
fprintf('  DT current  %10.1f A %10.1f A\n', r.Ihead, iSim);
fprintf('  Largest voltage difference: %.5f pu\n', max(abs(vSim - r.Vpu)));
fprintf('  Short-circuit level at the PCC: %.0f kVA, X/R %.2f\n', r.SscPcc / 1e3, r.xrPcc);
close_system(sys, 0);
out = struct('model', m, 'Vsweep', r.Vpu, 'Vsimulink', vSim, 'Isweep', r.Ihead, 'Isimulink', iSim);
end

% -------------------------------------------------------------------------
function r = sweep(m)
% Backward/forward sweep with constant-power loads; bus 1 is the DT LV bus
% behind the source impedance m.Zsrc.
nb = numel(m.busName); nl = size(m.line, 1);
tempK = 1 + 0.00403 * (m.condTempC - 20);
z = zeros(nl, 1);
for k = 1:nl
    c = m.cond(m.line(k, 4));
    z(k) = (c.r20 * tempK + 1i * c.x) * m.line(k, 3);
end
Vs = m.Vsource * m.Vnom / sqrt(3);                  % phase V
S = m.Sload / 3;                                    % per phase VA
V = Vs * ones(nb, 1);
for it = 1:200
    I = conj(S ./ V);                               % load currents
    Ib = zeros(nl, 1); Iacc = I;
    for k = nl:-1:1                                 % lines are listed parent first
        Ib(k) = Iacc(m.line(k, 2));
        Iacc(m.line(k, 1)) = Iacc(m.line(k, 1)) + Ib(k);
    end
    Vold = V;
    V(1) = Vs - m.Zsrc * Iacc(1);
    for k = 1:nl
        V(m.line(k, 2)) = V(m.line(k, 1)) - z(k) * Ib(k);
    end
    if max(abs(V - Vold)) < 1e-9, break, end
end
r.V = V; r.Vpu = abs(V) * sqrt(3) / m.Vnom; r.z = z;
r.Ihead = abs(Iacc(1));
% constant impedances that draw S at these voltages: power at 400 V
r.Snom = m.Sload ./ r.Vpu.^2;
% short-circuit level at the PCC (source + path)
zp = m.Zsrc; b = m.pccBus;
while b ~= 1
    k = find(m.line(:, 2) == b, 1); zp = zp + z(k); b = m.line(k, 1);
end
r.SscPcc = m.Vnom^2 / abs(zp); r.xrPcc = imag(zp) / real(zp);
end

function buildModel(sys, m, r)
if bdIsLoaded(sys), close_system(sys, 0); end
new_system(sys);
for L = {'spspowerguiLib', 'spsThreePhaseSourceLib', 'spsThreePhaseSeriesRLCBranchLib', ...
         'spsThreePhaseParallelRLCLoadLib', 'spsThreePhaseVIMeasurementLib'}
    load_system(L{1});
end
set_param(sys, 'SolverType', 'Fixed-step', 'Solver', 'FixedStepDiscrete', 'FixedStep', '2e-6', 'StopTime', '0.2');
add_block('spspowerguiLib/powergui', [sys '/powergui'], 'Position', [30 20 130 60], ...
          'SimulationMode', 'Discrete', 'SampleTime', '2e-6');
w = 2 * pi * m.freq;
nb = numel(m.busName);

% source and upstream equivalent
h = add_block('spsThreePhaseSourceLib/Three-Phase Source', [sys '/400 V source'], ...
              'Position', [40 200 100 270], 'Voltage', sprintf('%.10g', m.Vsource * m.Vnom), ...
              'Frequency', num2str(m.freq), 'PhaseAngle', '0', 'InternalConnection', 'Yg', ...
              'NonIdealSource', 'off');
zu = add_block('spsThreePhaseSeriesRLCBranchLib/Three-Phase Series RLC Branch', ...
               [sys '/' blockName(m.sourceName)], 'Position', [170 200 240 270], 'BranchType', 'RL', ...
               'Resistance', sprintf('%.10g', real(m.Zsrc)), 'Inductance', sprintf('%.10g', imag(m.Zsrc) / w));
connect(sys, port(h, 'RConn'), port(zu, 'LConn'));

% bus 1: the DT LV terminals, behind a meter that also gives the DT current
[col, row] = treeLayout(m.line(:, 1:2), nb);
xy = [330 + 300 * col(:), 200 + 220 * row(:)];
node = zeros(nb, 3);
node(1, :) = addMeter(sys, m, 1, xy(1, :), port(zu, 'RConn'), true);
for k = 1:size(m.line, 1)
    a = m.line(k, 1); b = m.line(k, 2); c = m.cond(m.line(k, 4));
    zl = r.z(k);
    h = add_block('spsThreePhaseSeriesRLCBranchLib/Three-Phase Series RLC Branch', ...
                  sprintf('%s/%s - %s (%s, %g m)', sys, blockName(m.busName{a}), blockName(m.busName{b}), ...
                          c.name, 1e3 * m.line(k, 3)), ...
                  'Position', [xy(b, 1) - 160, xy(b, 2), xy(b, 1) - 90, xy(b, 2) + 70], 'BranchType', 'RL', ...
                  'Resistance', sprintf('%.10g', real(zl)), 'Inductance', sprintf('%.10g', imag(zl) / w));
    connect(sys, node(a, :), port(h, 'LConn'));
    node(b, :) = addMeter(sys, m, b, xy(b, :), port(h, 'RConn'), false);
end

% loads: constant impedance, power at 400 V
for b = 1:nb
    if abs(m.Sload(b)) == 0, continue, end
    S = r.Snom(b);
    h = add_block('spsThreePhaseParallelRLCLoadLib/Three-Phase Parallel RLC Load', ...
                  sprintf('%s/Load %s (%.1f kW)', sys, blockName(m.busName{b}), real(m.Sload(b)) / 1e3), ...
                  'Position', [xy(b, 1) + 60, xy(b, 2) + 100, xy(b, 1) + 110, xy(b, 2) + 145], ...
                  'Configuration', 'Y (grounded)', 'NominalVoltage', num2str(m.Vnom), ...
                  'NominalFrequency', num2str(m.freq), 'LoadType', 'constant Z', ...
                  'ActivePower', sprintf('%.10g', real(S)), 'InductivePower', sprintf('%.10g', imag(S)), ...
                  'CapacitivePower', '0');
    connect(sys, node(b, :), port(h, 'LConn'));
end
set_param(sys, 'Description', sprintf(['%s\nLoading %.0f %% of the FY 2082/83 recorded peak. ' ...
    'PCC (for a prosumer connection) at %s.\nBuilt by matlab_models/build_nea_lv_feeder.m from nea_lv_feeder_data.m.'], ...
    m.title, 100 * m.loadScale, m.busName{m.pccBus}));
end

function ports = addMeter(sys, m, b, xy, from, logCurrent)
% Inline three-phase meter in front of bus b; returns the bus node ports.
h = add_block('spsThreePhaseVIMeasurementLib/Three-Phase V-I Measurement', ...
              sprintf('%s/Meter %s', sys, blockName(m.busName{b})), ...
              'Position', [xy(1) - 40, xy(2), xy(1), xy(2) + 70], ...
              'VoltageMeasurement', 'phase-to-ground', 'CurrentMeasurement', 'yes');
connect(sys, from, port(h, 'LConn'));
nm = get_param(h, 'Name');
names = {['V_' busTag(b)], 'I_DT'};
for k = 1:1 + logCurrent
    t = add_block('simulink/Sinks/To Workspace', sprintf('%s/Log %s', sys, names{k}), ...
                  'VariableName', names{k}, 'SaveFormat', 'Timeseries', 'Decimation', '10', ...
                  'Position', [xy(1) - 60, xy(2) - 70 + 30 * (k - 1), xy(1) + 20, xy(2) - 50 + 30 * (k - 1)]);
    add_line(sys, [nm '/' num2str(k)], [get_param(t, 'Name') '/1'], 'autorouting', 'on');
end
ports = port(h, 'RConn');
end

function t = busTag(b)
t = sprintf('bus%d', b);
end

function h = port(blk, kind)
ph = get_param(blk, 'PortHandles'); h = ph.(kind)(1:3);
end

function connect(sys, from, to)
for i = 1:3, add_line(sys, from(i), to(i), 'autorouting', 'on'); end
end

function name = blockName(name)
name = strrep(name, '/', '//');
end

function [col, row] = treeLayout(edges, nb)
col = zeros(nb, 1); row = zeros(nb, 1);
kids = cell(nb, 1);
for k = 1:size(edges, 1), kids{edges(k, 1)}(end + 1) = edges(k, 2); end
nextRow = 0;
place(1, 0);
    function place(b, depth)
        col(b) = depth;
        if isempty(kids{b})
            row(b) = nextRow; nextRow = nextRow + 1;
        else
            for c = kids{b}, place(c, depth + 1); end
            row(b) = row(kids{b}(1));
        end
    end
end

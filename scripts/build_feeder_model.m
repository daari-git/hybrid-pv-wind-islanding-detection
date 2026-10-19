function build_feeder_model()
% BUILD_FEEDER_MODEL  hybrid_pv_wind_feeder.slx: the test bed on the Pidari 400 V feeder.
%   Starts from hybrid_pv_wind_islanding.slx (BUILD_MODEL; not changed) and
%   replaces its grid equivalent, one impedance behind the programmable
%   source, by the 400 V feeder of NEA_LV_FEEDER_DATA (Real_model/), laid out
%   as in Real_model/build_nea_lv_feeder.m:
%
%     programmable source (11 kV disturbances) -- upstream equivalent (11 kV
%     network and the 100 kVA transformer) -- transformer breaker -- DT LV
%     bus -- distributor A: A1..A5 / distributor B: B1..B3, constant-impedance
%     loads at every pole
%
%   Everything on the unit's side of its breaker (inverter, LCL filter, local
%   and switched loads, sensor noise, detectors) is unchanged. The breaker's
%   grid side reaches every bus through a service connection whose
%   resistance is set by P.feeder.rConn (1 mohm at the PCC, 1 Mohm
%   elsewhere), so the connection bus is a parameter. The second inverter is
%   moved the same way (P.feeder.rDer2: the unit's PCC or any bus) and now
%   follows the voltage at its own terminals. Added: the transformer breaker
%   (P.feeder.tIsland islands the whole feeder), a switched load at B3, and
%   logs of the transformer's voltage and current and the second inverter's
%   terminal voltage. Values come from FEEDER_PARAMS, so loading and
%   connection bus change without a rebuild.
root = fileparts(fileparts(mfilename('fullpath')));
src  = fullfile(root, 'hybrid_pv_wind_islanding.slx');
mdl  = 'hybrid_pv_wind_feeder';
dst  = fullfile(root, [mdl '.slx']);
bdclose('all');
if exist(dst, 'file'), delete(dst); end
copyfile(src, dst);
load_system(dst);
P = feeder_params(params());
assignin(get_param(mdl, 'ModelWorkspace'), 'P', P);
for L = {'spsThreePhaseSeriesRLCBranchLib', 'spsThreePhaseBreakerLib', 'spsThreePhaseParallelRLCLoadLib', ...
         'spsThreePhaseVIMeasurementLib'}
    load_system(L{1});
end
lib = @(L) libblock(L);
ib  = byname(mdl, '^Breaker for Islanding Simulation$');
ibh = get_param(ib, 'PortHandles');
gv  = [mdl '/Grid voltage'];

%% 1. Remove the grid impedance ------------------------------------------
gz = [mdl '/Grid impedance'];
detach(gz); delete_block(gz);
set_param(gv, 'PositiveSequence', '[P.feeder.Vsrc*P.Vll 0 P.fg]');
ps = get_param(gv, 'Position');
x0 = ps(1) + 300; y0 = ps(4) + 250;                   % feeder drawn below and right of the source

%% 2. Upstream equivalent, transformer breaker and meter -----------------
up = [mdl '/Upstream equivalent (11 kV network + 100 kVA DT)'];
add_block(lib('spsThreePhaseSeriesRLCBranchLib'), up, 'BranchType', 'RL', ...
    'Resistance', 'P.feeder.Rsrc', 'Inductance', 'P.feeder.Lsrc', 'Position', [x0 y0 x0+60 y0+70]);
tb = [mdl '/Transformer breaker'];
add_block(lib('spsThreePhaseBreakerLib'), tb, 'InitialState', 'closed', 'SwitchA', 'on', ...
    'SwitchB', 'on', 'SwitchC', 'on', 'External', 'off', 'SwitchTimes', '[P.feeder.tIsland]', ...
    'Position', [x0+120 y0 x0+170 y0+70]);
mt = [mdl '/Meter DT'];
add_block(lib('spsThreePhaseVIMeasurementLib'), mt, 'VoltageMeasurement', 'phase-to-ground', ...
    'CurrentMeasurement', 'yes', 'Position', [x0+230 y0 x0+270 y0+70]);
connect(mdl, port(gv, 'RConn'), port(up, 'LConn'));
connect(mdl, port(up, 'RConn'), port(tb, 'LConn'));
connect(mdl, port(tb, 'RConn'), port(mt, 'LConn'));
logblk(mdl, 'Meter DT/1', 'Vdt', [x0+230 y0-80]);
logblk(mdl, 'Meter DT/2', 'Idt', [x0+230 y0-50]);

%% 3. Lines and loads ----------------------------------------------------
F = P.feeder; nb = numel(F.busName);
node = zeros(nb, 3);
node(1, :) = port(mt, 'RConn');
xy = zeros(nb, 2); xy(1, :) = [x0+330 y0];
for k = 1:size(F.line, 1)
    a = F.line(k, 1); b = F.line(k, 2);
    if b <= 6, xy(b, :) = xy(a, :) + [260 0]; else, xy(b, :) = xy(a, :) + [260 400*(a == 1)]; end
    h = [mdl '/' sprintf('Line %s - %s', clean(F.busName{a}), clean(F.busName{b}))];
    add_block(lib('spsThreePhaseSeriesRLCBranchLib'), h, 'BranchType', 'RL', ...
        'Resistance', sprintf('P.feeder.lineR(%d)', k), 'Inductance', sprintf('P.feeder.lineL(%d)', k), ...
        'Position', [xy(b,1)-170 xy(b,2) xy(b,1)-110 xy(b,2)+70]);
    connect(mdl, node(a, :), port(h, 'LConn'));
    node(b, :) = port(h, 'RConn');
end
for b = 1:nb
    if F.loadP(b) == 0, continue, end
    h = [mdl '/' sprintf('Load %s', clean(F.busName{b}))];
    add_block(lib('spsThreePhaseParallelRLCLoadLib'), h, 'Configuration', 'Y (grounded)', ...
        'NominalVoltage', 'P.Vll', 'NominalFrequency', 'P.fg', ...
        'ActivePower', sprintf('P.feeder.loadP(%d)', b), 'InductivePower', sprintf('P.feeder.loadQL(%d)', b), ...
        'CapacitivePower', '0', 'Position', [xy(b,1)-90 xy(b,2)+110 xy(b,1)-40 xy(b,2)+160]);
    connect(mdl, node(b, :), port(h, 'LConn'));
end
% switched load at the end of distributor B
sb = [mdl '/Feeder switched load breaker (B3)']; sl = [mdl '/Feeder switched load (B3)'];
add_block(lib('spsThreePhaseBreakerLib'), sb, 'InitialState', 'open', 'SwitchA', 'on', 'SwitchB', 'on', ...
    'SwitchC', 'on', 'External', 'off', 'SwitchTimes', '[P.feeder.swT]', ...
    'Position', [xy(nb,1)+40 xy(nb,2) xy(nb,1)+90 xy(nb,2)+70]);
add_block(lib('spsThreePhaseParallelRLCLoadLib'), sl, 'Configuration', 'Y (grounded)', ...
    'NominalVoltage', 'P.Vll', 'NominalFrequency', 'P.fg', 'ActivePower', 'P.feeder.swP', ...
    'InductivePower', 'P.feeder.swQ', 'CapacitivePower', '0', ...
    'Position', [xy(nb,1)+140 xy(nb,2) xy(nb,1)+190 xy(nb,2)+70]);
connect(mdl, node(nb, :), port(sb, 'LConn'));
connect(mdl, port(sb, 'RConn'), port(sl, 'LConn'));

%% 4. The unit's service connection to every bus ------------------------
for b = 1:nb
    h = [mdl '/' sprintf('Service to %s', clean(F.busName{b}))];
    add_block(lib('spsThreePhaseSeriesRLCBranchLib'), h, 'BranchType', 'R', ...
        'Resistance', sprintf('P.feeder.rConn(%d)', b), ...
        'Position', [xy(b,1)-60 xy(b,2)-200 xy(b,1) xy(b,2)-130]);
    connect(mdl, ibh.RConn(1:3), port(h, 'LConn'));
    connect(mdl, port(h, 'RConn'), node(b, :));
end

%% 5. Second inverter: placed by P.feeder.rDer2, following its own voltage
cs = arrayfun(@(j) sprintf('%s/Second inverter %c', mdl, 'a' + j - 1), 1:3, 'UniformOutput', false);
for j = 1:3                                            % detach from the PCC
    ph = get_param(cs{j}, 'PortHandles');
    l = get_param(ph.RConn(1), 'Line'); if l ~= -1, delete_line(l); end
end
term = zeros(1, 3);
for j = 1:3, ph = get_param(cs{j}, 'PortHandles'); term(j) = ph.RConn(1); end
pc = get_param(cs{1}, 'Position');
vm = [mdl '/Second inverter terminal voltage'];         % in series with the sources' terminals
add_block(lib('spsThreePhaseVIMeasurementLib'), vm, 'VoltageMeasurement', 'phase-to-ground', ...
    'CurrentMeasurement', 'no', 'Position', [pc(1) pc(2)-320 pc(1)+40 pc(2)-250]);
connect(mdl, term, port(vm, 'LConn'));
targets = [{ibh.LConn(1:3)}, arrayfun(@(b) node(b, :), 1:nb, 'UniformOutput', false)];
names = [{'PCC'}, cellfun(@clean, F.busName, 'UniformOutput', false)];
for i = 1:numel(targets)
    h = [mdl '/' sprintf('Second inverter to %s', names{i})];
    add_block(lib('spsThreePhaseSeriesRLCBranchLib'), h, 'BranchType', 'R', ...
        'Resistance', sprintf('P.feeder.rDer2(%d)', i), ...
        'Position', [pc(1)+90*(i-1) pc(2)-200 pc(1)+90*(i-1)+50 pc(2)-140]);
    connect(mdl, port(vm, 'RConn'), port(h, 'LConn'));
    connect(mdl, port(h, 'RConn'), targets{i});
end
add_block('simulink/Signal Routing/Goto', [mdl '/Goto Vder2'], 'GotoTag', 'Vder2', 'TagVisibility', 'global', ...
    'Position', [pc(1) pc(2)-370 pc(1)+60 pc(2)-350]);
add_line(mdl, get_ph(vm, 'Outport', 1), get_ph([mdl '/Goto Vder2'], 'Inport', 1), 'autorouting', 'on');
set_param([mdl '/Second inverter control/From Vabc'], 'GotoTag', 'Vder2');
% The test bed's reference, i = (P*v - Q*v90)/|v|^2 on the raw voltage, acts
% at high frequency as a negative resistance (about -16 ohm at 10 kW). Beside
% the test bed's local load and filter capacitor that was harmless; at a
% lightly loaded feeder bus behind line inductance it oscillated at 17-20 kHz.
% A real inverter follows the fundamental, so the reference now uses the
% terminal voltage through a second-order generalised integrator (SOGI) tuned
% to the measured frequency: unity gain and no phase shift at the fundamental,
% falling off at 20 dB per decade above it.
% sample the frequency too, so the block (and its integrator) runs at P.der2.Ts
dc = [mdl '/Second inverter control'];
lh = get_param([dc '/From freq'], 'LineHandles'); delete_line(lh.Outport(1));
add_block('simulink/Discrete/Zero-Order Hold', [dc '/Sample freq'], 'SampleTime', 'P.der2.Ts', 'Position', [110 75 150 105]);
add_line(dc, 'From freq/1', 'Sample freq/1');
add_line(dc, 'Sample freq/1', 'Current reference/2', 'autorouting', 'on');
set_param([mdl '/Second inverter control/Settings'], 'Value', ...
    '[P.der2.P P.der2.Q P.der2.Kq P.der2.Qlim P.fg 1.5*(0.5*P.Vll*sqrt(2/3))^2 P.der2.Ts]');
ch = find(sfroot, '-isa', 'Stateflow.EMChart', 'Path', [mdl '/Second inverter control/Current reference']);
ch.Script = sprintf([ ...
    'function i = DER2(v, f, en, armed, prm)\n' ...
    '%% Constant-power current references from the fundamental of the terminal voltage.\n' ...
    'persistent x1 x2\n' ...
    'if isempty(x1), x1 = zeros(3, 1); x2 = zeros(3, 1); end\n' ...
    'w = 2*pi*min(max(f, 40), 60); Ts = prm(7); k = sqrt(2);\n' ...
    'x1n = x1 + Ts*w*(k*(v(:) - x1) - x2);   %% SOGI: x1 in phase with v, x2 lagging 90 degrees\n' ...
    'x2 = x2 + Ts*w*x1;\n' ...
    'x1 = x1n;\n' ...
    'Pd = prm(1);\n' ...
    'Q = prm(2) + armed*min(max(prm(3)*(f - prm(5)), -prm(4)), prm(4));\n' ...
    'v90 = [x1(2) - x1(3); x1(3) - x1(1); x1(1) - x1(2)]/sqrt(3);\n' ...
    's = max(x1(1)^2 + x1(2)^2 + x1(3)^2, prm(6));\n' ...
    'i = en*(Pd*x1 - Q*v90)/s;\n']);
logblk(mdl, [get_param(vm, 'Name') '/1'], 'Vder2', [pc(1)+150 pc(2)-370]);

%% 6. Tidy up ------------------------------------------------------------
ln = find_system(mdl, 'FindAll', 'on', 'SearchDepth', 1, 'Type', 'line', 'Connected', 'off');
for k = 1:numel(ln)
    if ishandle(ln(k)) && isempty(get_param(ln(k), 'LineChildren')), delete_line(ln(k)); end
end
set_param(mdl, 'Description', sprintf(['Hybrid PV-wind unit on the Pidari 400 V feeder (%s).\n' ...
    'Built by scripts/build_feeder_model.m from hybrid_pv_wind_islanding.slx and Real_model/nea_lv_feeder_data.m.'], ...
    'NEA, Janakpur DC'));
save_system(mdl);
if exist([dst '.r2018a'], 'file'), delete([dst '.r2018a']); end
close_system(mdl, 0);
fprintf('Built %s\n', dst);
end

% ---- helpers ---------------------------------------------------------------
function detach(blk)
% Delete every wire on a block's physical ports.
ph = get_param(blk, 'PortHandles');
for h = [ph.LConn ph.RConn]
    l = get_param(h, 'Line');
    if l ~= -1, delete_line(l); end
end
end

function logblk(mdl, srcPort, name, xy)
add_block('simulink/Sinks/To Workspace', [mdl '/Log ' name], 'VariableName', ['log_' name], ...
    'SaveFormat', 'Timeseries', 'Decimation', 'P.logDecim', 'Position', [xy(1)+80 xy(2) xy(1)+180 xy(2)+20]);
add_line(mdl, srcPort, ['Log ' name '/1'], 'autorouting', 'on');
end

function s = clean(s)
s = strtrim(regexprep(strrep(s, '/', '-'), '\s*\(PCC\)', ''));
end

function h = port(blk, kind)
ph = get_param(blk, 'PortHandles'); h = ph.(kind)(1:3);
end

function connect(sys, from, to)
for i = 1:3, add_line(sys, from(i), to(i), 'autorouting', 'on'); end
end

function b = byname(sys, pat)
b = find_system(sys, 'SearchDepth', 1, 'Regexp', 'on', 'Name', pat);
b = b(~strcmp(b, sys));
assert(numel(b) == 1, 'Expected one block matching %s in %s, found %d', pat, sys, numel(b));
b = b{1};
end

function b = libblock(L)
load_system(L);
c = find_system(L, 'SearchDepth', 1, 'Type', 'Block');
b = c{1};
end

function h = get_ph(block, kind, idx)
ph = get_param(block, 'PortHandles'); h = ph.(kind)(idx);
end

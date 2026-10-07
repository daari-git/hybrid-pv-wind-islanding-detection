function build_model(scr)
% BUILD_MODEL  Create hybrid_pv_wind_islanding.slx from the original R2018a model.
%   The original in MATLAB_R2018a/ is never modified. Every change made to it
%   is listed here, so the corrected model can be rebuilt and reviewed.
if nargin < 1, scr = 10; end
root = fileparts(fileparts(mfilename('fullpath')));
src  = fullfile(root, 'MATLAB_R2018a', 'pv_and_wind_completed.slx');
mdl  = 'hybrid_pv_wind_islanding';
dst  = fullfile(root, [mdl '.slx']);

bdclose('all');
if exist(dst, 'file'), delete(dst); end
copyfile(src, dst);
load_system(dst);
P = params(scr);
assignin(get_param(mdl, 'ModelWorkspace'), 'P', P);

%% 1. Housekeeping -------------------------------------------------------
delete(find_system(mdl, 'FindAll', 'on', 'SearchDepth', 1, 'Type', 'annotation'));
delete_block(byname(mdl, '^Wind_constant_speed'));       % unconnected leftover
apf = byname(mdl, '^Active Power Filter$');              % out of scope for the islanding study
aph = get_param(apf, 'PortHandles');
for h = aph.RConn                                        % detach its three wires first, so no stubs remain
    l = get_param(h, 'Line');
    if l ~= -1, delete_line(l); end
end
delete_block(apf);
delete_block([mdl '/Wind_Subsystem/powergui']);          % one powergui per model
% make sure the grid-side inductors still reach the PCC measurement
vi2h = get_param([mdl '/Three-Phase V-I Measurement2'], 'PortHandles');
l2 = {'Series RLC Branch3', 'Series RLC Branch4', 'Series RLC Branch5'};
for k = 1:3
    lh = get_param([mdl '/' l2{k}], 'PortHandles');
    pc = get_param([mdl '/' l2{k}], 'PortConnectivity');
    if isempty(pc(2).DstBlock) && isempty(pc(2).SrcBlock)
        add_line(mdl, lh.RConn(1), vi2h.RConn(k), 'autorouting', 'on');
    end
end
set_param([mdl '/powergui'], 'SampleTime', 'P.Ts');
set_param(mdl, 'SolverType', 'Fixed-step', 'Solver', 'FixedStepDiscrete', ...
    'FixedStep', 'P.Ts', 'StopTime', '1.0', 'AlgebraicLoopMsg', 'none', ...
    'UnconnectedInputMsg', 'none', 'UnconnectedOutputMsg', 'none', ...
    'UnconnectedLineMsg', 'none');

%% 2. PV array, irradiance and MPPT -------------------------------------
pv = [mdl '/PV Array'];
set_param(pv, 'Nser', 'P.pv.Nser', 'Npar', 'P.pv.Npar', 'BAL', 'on');   % BAL: break the internal algebraic loop
delete_block([mdl '/MATLAB Function']);                  % 24 h day squeezed into 2.4 s
delete_block([mdl '/Clock']);
prune(mdl);
pos = get_param(pv, 'Position');
add_block('simulink/Sources/Step', [mdl '/Irradiance'], 'Time', 'P.pv.tStep', ...
    'Before', 'P.pv.G0', 'After', 'P.pv.G1', 'SampleTime', '0', ...
    'Position', [pos(1)-140 pos(2) pos(1)-100 pos(2)+30]);
add_block('simulink/Sources/Constant', [mdl '/Cell temperature'], 'Value', 'P.pv.T', ...
    'Position', [pos(1)-140 pos(2)+60 pos(1)-100 pos(2)+90]);
add_line(mdl, 'Irradiance/1', 'PV Array/1', 'autorouting', 'on');
add_line(mdl, 'Cell temperature/1', 'PV Array/2', 'autorouting', 'on');

bc = byname(mdl, '^DC-DC Boost Converter with MPPT$');
% Perturb-and-observe acting directly on the duty cycle. The old version
% produced a 0-50 V voltage reference for a 290 V array and could not track.
ch = find(sfroot, '-isa', 'Stateflow.EMChart', 'Path', [bc '/MPPT']);
ch.Script = sprintf([ ...
    'function D = MPPT(V,I)\n' ...
    '%% Perturb and observe on the boost duty cycle.\n' ...
    '%% A higher duty lowers the PV voltage, since Vpv = Vdc*(1-D).\n' ...
    'Dmin = %g; Dmax = %g; D0 = %g; dD = %g;\n' ...
    'persistent Vold Pold Dold;\n' ...
    'if isempty(Vold)\n    Vold = V; Pold = V*I; Dold = D0;\nend\n' ...
    'P = V*I; dV = V - Vold; dP = P - Pold;\n' ...
    'D = Dold;\n' ...
    'if dP ~= 0\n' ...
    '    if (dP > 0) == (dV > 0)\n        D = Dold - dD;   %% raise the voltage\n' ...
    '    else\n        D = Dold + dD;   %% lower the voltage\n    end\n' ...
    'end\n' ...
    'D = min(max(D, Dmin), Dmax);\n' ...
    'Dold = D; Vold = V; Pold = P;\n'], P.pv.Dmin, P.pv.Dmax, P.pv.D0, P.pv.dD);
delete_block(find_system(bc, 'SearchDepth', 1, 'BlockType', 'Sum'));
delete_block(find_system(bc, 'SearchDepth', 1, 'Regexp', 'on', 'Name', '^PID'));
prune(bc);
relop = find_system(bc, 'SearchDepth', 1, 'BlockType', 'RelationalOperator');
add_line(bc, get_ph([bc '/MPPT'], 'Outport', 1), get_ph(relop{1}, 'Inport', 1), 'autorouting', 'on');
ud = find_system(bc, 'SearchDepth', 1, 'BlockType', 'UnitDelay');
for k = 1:numel(ud), set_param(ud{k}, 'SampleTime', 'P.pv.Tmppt'); end
set_param([bc '/Series RLC Branch2'], 'InitialVoltage', 'P.Vdc');   % DC-link capacitor
block_on_trip(bc, relop{1});          % stop the PV boost once the protection trips

%% 3. LCL filter and grid -----------------------------------------------
for n = {'Series RLC Branch', 'Series RLC Branch1', 'Series RLC Branch2'}
    set_param([mdl '/' n{1}], 'Resistance', 'P.lcl.R1', 'Inductance', 'P.lcl.L1');
end
for n = {'Series RLC Branch3', 'Series RLC Branch4', 'Series RLC Branch5'}
    set_param([mdl '/' n{1}], 'Resistance', 'P.lcl.R2', 'Inductance', 'P.lcl.L2');
end
for n = {'Series RLC Branch6', 'Series RLC Branch7', 'Series RLC Branch8'}
    set_param([mdl '/' n{1}], 'Resistance', 'P.lcl.Rd', 'Capacitance', 'P.lcl.Cf');
end
% The original preset a 10 A initial current on the grid-side inductors. That
% current is not an independent state, so every run raised an
% "Initial state conflict" dialog. No inductor needs a preset current.
il = find_system(mdl, 'LookUnderMasks', 'none', 'SetiL0', 'on');
for k = 1:numel(il), set_param(il{k}, 'SetiL0', 'off'); end
set_param([mdl '/Three-Phase Source'], 'Voltage', 'P.Vll', 'Frequency', 'P.fg', ...
    'SpecifyImpedance', 'off', 'Resistance', 'P.grid.R', 'Inductance', 'P.grid.L');

%% 4. Inverter control ---------------------------------------------------
ic = byname(mdl, '^Inverter Control Logic$');
pid = @(n) [ic '/' n];
todiscrete(find_system(mdl, 'LookUnderMasks', 'none', 'Regexp', 'on', 'ReferenceBlock', 'PID Controller'));
set_param(pid('PID Controller'),  'P', 'P.pll.Kp',  'I', 'P.pll.Ki', ...
    'InitialConditionForIntegrator', 'P.wg');                        % PLL
set_param(pid('PID Controller1'), 'P', 'P.ctrl.KpV', 'I', 'P.ctrl.KiV', ...
    'UpperSaturationLimit', 'P.ctrl.Ilim', 'LowerSaturationLimit', '-P.ctrl.Ilim', ...
    'AntiWindupMode', 'clamping');                                   % DC-link voltage
set_param(pid('PID Controller2'), 'P', 'P.ctrl.KpI', 'I', 'P.ctrl.KiI', 'AntiWindupMode', 'clamping');
set_param(pid('PID Controller3'), 'P', 'P.ctrl.KpI', 'I', 'P.ctrl.KiI');
set_param(pid('Gain'),  'Gain', 'P.wg*P.lcl.L1');
set_param(pid('Gain2'), 'Gain', 'P.wg*P.lcl.L1');
set_param(pid('Constant3'), 'Value', 'P.Vdc');
replace_block(ic, 'SearchDepth', 1, 'Name', 'Integrator', ...
    'simulink/Discrete/Discrete-Time Integrator', 'noprompt');
set_param(pid('Integrator'), 'SampleTime', '-1');

% Current control is sampled at the switching frequency, in step with the PWM
% carrier, and its output is applied one sample later, as in a real digital
% controller. Each axis has a PI and an H-infinity controller in parallel;
% P.ctrl.useHinf selects which one drives the inverter.
set_param(pid('PID Controller2'), 'SampleTime', 'P.Tc');
set_param(pid('PID Controller3'), 'SampleTime', 'P.Tc');
add_hinf(ic, 'PID Controller2', 'd');
add_hinf(ic, 'PID Controller3', 'q');

% Frequency measured from the PLL. The old signal was the PLL angle times pi/2.
p0 = get_param(pid('PID Controller'), 'Position');
add_block('simulink/Math Operations/Gain', pid('rad_s to Hz'), 'Gain', '1/(2*pi)', ...
    'Position', [p0(1) p0(2)-90 p0(1)+40 p0(2)-60]);
add_block('peGeneralControl/Low-Pass Filter (Discrete or Continuous)', pid('Frequency filter'), ...
    'K', '1', 'T', 'P.pll.Tf', 'Ts', '-1', 'Position', [p0(1)+80 p0(2)-90 p0(1)+140 p0(2)-60]);
add_block('simulink/Signal Routing/Goto', pid('Goto freq'), 'GotoTag', 'freq', ...
    'TagVisibility', 'global', 'Position', [p0(1)+180 p0(2)-85 p0(1)+240 p0(2)-65]);
add_line(ic, 'PID Controller/1', 'rad_s to Hz/1', 'autorouting', 'on');
add_line(ic, 'rad_s to Hz/1', 'Frequency filter/1');
% a one-cycle mean removes the 100 Hz and 300 Hz ripple the PLL passes through
add_block('powerlib_meascontrol/Measurements/Mean', pid('Cycle mean'), 'Freq', 'P.fg', 'Ts', 'P.Ts', ...
    'Position', [p0(1)+160 p0(2)-130 p0(1)+220 p0(2)-100]);
try, set_param(pid('Cycle mean'), 'Vinit', 'P.fg'); catch, end
add_line(ic, 'Frequency filter/1', 'Cycle mean/1', 'autorouting', 'on');
add_line(ic, 'Cycle mean/1', 'Goto freq/1', 'autorouting', 'on');

%% 5. Passive protection (baseline detector) -----------------------------
pr = byname(mdl, '^Passive Anti-Islanding Protection$');
wtFrom = find_system(pr, 'SearchDepth', 1, 'BlockType', 'From', 'GotoTag', 'wt');
gt     = find_system(pr, 'SearchDepth', 1, 'BlockType', 'Goto', 'GotoTag', 'freq');
delete_block(wtFrom); delete_block([pr '/Gain']); delete_block(gt);
delete_block([pr '/Derivative']);
ff  = [pr '/S-R Flip-Flop'];
out = find_system(pr, 'SearchDepth', 1, 'BlockType', 'Outport');
tm  = find_system(pr, 'SearchDepth', 1, 'BlockType', 'Terminator');
% the terminator on the flip-flop's inverted output goes; the others stay
pc = get_param(ff, 'PortConnectivity');
qbar = pc(strcmp({pc.Type}, '2') & ~cellfun(@isempty, {pc.DstBlock}));
if ~isempty(qbar), delete_block(qbar(1).DstBlock); end
lh = get_param(ff, 'LineHandles');
delete_line(lh.Inport(1)); delete_line(lh.Outport(1));
prune(pr);

set_param([pr '/Constant6'], 'Value', 'P.prot.uv');
set_param([pr '/Constant7'], 'Value', 'P.prot.ov');
set_param([pr '/Constant8'], 'Value', 'P.prot.uf');
set_param([pr '/Constant9'], 'Value', 'P.prot.of');
set_param([pr '/Constant'],  'Value', 'P.prot.rocof');
set_param([pr '/Gain3'], 'Gain', 'sqrt(3)/P.Vll');
set_param([pr '/RMS'], 'Freq', 'P.fg', 'Ts', 'P.Ts');

% rate of change of frequency, sampled at 1 kHz
f39 = find_system(pr, 'SearchDepth', 1, 'BlockType', 'From', 'GotoTag', 'freq');
src = '';
for k = 1:numel(f39)
    if all(get_param(f39{k}, 'LineHandles').Outport == -1), src = f39{k}; end
end
pa = get_param([pr '/Abs'], 'Position'); yc = round((pa(2)+pa(4))/2);
set_param(src, 'Position', [pa(1)-260 yc-10 pa(1)-215 yc+10]);       % lay the chain out left of Abs
add_block('simulink/Discrete/Zero-Order Hold', [pr '/ROCOF sampler'], 'SampleTime', 'P.prot.Trocof', ...
    'Position', [pa(1)-190 yc-12 pa(1)-160 yc+12]);
add_block('simulink/Discrete/Discrete Derivative', [pr '/ROCOF'], ...
    'Position', [pa(1)-130 yc-15 pa(1)-60 yc+15]);
add_line(pr, get_ph(src, 'Outport', 1), get_ph([pr '/ROCOF sampler'], 'Inport', 1));
add_line(pr, 'ROCOF sampler/1', 'ROCOF/1');
add_line(pr, 'ROCOF/1', 'Abs/1', 'autorouting', 'on');

% start-up blanking, then latch; the breaker stays closed until a trip
pf = get_param(ff, 'Position');
add_block('simulink/Sources/Step', [pr '/Blanking'], 'Time', 'P.prot.tBlank', 'Before', '0', ...
    'After', '1', 'SampleTime', 'P.Ts', 'Position', [pf(1)-150 pf(2)+60 pf(1)-120 pf(2)+90]);
add_block('simulink/Logic and Bit Operations/Logical Operator', [pr '/Armed'], 'Operator', 'AND', ...
    'Position', [pf(1)-80 pf(2) pf(1)-50 pf(2)+40]);
add_line(pr, 'Logical Operator/1', 'Armed/1', 'autorouting', 'on');
add_line(pr, 'Blanking/1', 'Armed/2', 'autorouting', 'on');
add_line(pr, 'Armed/1', 'S-R Flip-Flop/1', 'autorouting', 'on');
add_line(pr, get_ph(ff, 'Outport', 2), get_ph(out{1}, 'Inport', 1), 'autorouting', 'on');
add_block('simulink/Signal Routing/Goto', [pr '/Goto trip'], 'GotoTag', 'trip', ...
    'TagVisibility', 'global', 'Position', [pf(3)+40 pf(2)-40 pf(3)+100 pf(2)-20]);
add_line(pr, 'S-R Flip-Flop/1', 'Goto trip/1', 'autorouting', 'on');

%% 6. Wind turbine, generator and MPPT -----------------------------------
ws = byname(mdl, '^Wind_Subsystem$');
tb = [ws '/10 KW wind turbine system'];
pm = [ws '/Permanent Magnet Synchronous Machine'];
set_param(pm, 'Inductance', 'P.wind.Ls', 'dqInductances', '[P.wind.Ls P.wind.Ls]', ...
    'Mechanical', '[P.wind.J 0.008 P.wind.pp 0]', 'PolePairs', 'P.wind.pp', ...
    'InitialConditions', '[P.wind.wm0 0 0 0]');
replace_block(ws, 'SearchDepth', 1, 'Name', 'Wind Speed', 'simulink/Sources/Step', 'noprompt');
set_param([ws '/Wind Speed'], 'Time', 'P.wind.tStep', 'Before', 'P.wind.v0', 'After', 'P.wind.v1', ...
    'SampleTime', '0');
delete_block([ws '/Rotor Speed']);          % turbine used a fixed speed, not the generator's
delete_block([ws '/Constant']);             % fixed boost duty of 0.435
lh = get_param(pm, 'LineHandles'); delete_line(lh.Inport(1));
prune(ws);
bs = [ws '/Bus Selector'];
add_line(ws, get_ph(bs, 'Outport', 1), get_ph(tb, 'Inport', 4), 'autorouting', 'on');
pp = get_param(pm, 'Position');
% the machine block treats positive torque as a motor load; a turbine drives it
add_block('simulink/Math Operations/Gain', [ws '/Generator sign'], 'Gain', '-1', ...
    'Position', [pp(1)-80 pp(2) pp(1)-50 pp(2)+30]);
add_line(ws, get_ph(tb, 'Outport', 2), get_ph([ws '/Generator sign'], 'Inport', 1), 'autorouting', 'on');
add_line(ws, get_ph([ws '/Generator sign'], 'Outport', 1), get_ph(pm, 'Inport', 1), 'autorouting', 'on');

% optimal-torque MPPT: P* = Kopt*w^3, boost inductor current I* = P*/Vrect
ro = find_system(ws, 'SearchDepth', 1, 'BlockType', 'RelationalOperator');
pr0 = get_param(ro{1}, 'Position'); x = pr0(1) - 620; y = pr0(2) + 120;
blk = @(n) [ws '/' n];
add_block('simulink/Math Operations/Product', blk('w^3'), 'Inputs', '3', 'Position', [x y x+40 y+40]);
add_block('simulink/Math Operations/Gain', blk('Kopt'), 'Gain', 'P.wind.Kopt', 'Position', [x+70 y+5 x+120 y+35]);
add_block('simulink/Signal Routing/From', blk('From Vrect'), 'GotoTag', 'V_wind', 'Position', [x-60 y+80 x y+100]);
add_block('simulink/Discontinuities/Saturation', blk('Vmin'), 'UpperLimit', 'inf', 'LowerLimit', '50', ...
    'Position', [x+30 y+75 x+60 y+105]);
add_block('simulink/Math Operations/Divide', blk('Iref'), 'Position', [x+160 y+10 x+190 y+100]);
add_block('simulink/Discontinuities/Saturation', blk('Ilimit'), 'UpperLimit', 'P.wind.Imax', 'LowerLimit', '0', ...
    'Position', [x+220 y+40 x+250 y+70]);
add_block('simulink/Signal Routing/From', blk('From IL'), 'GotoTag', 'I_wind', 'Position', [x+220 y+110 x+280 y+130]);
add_block('simulink/Math Operations/Sum', blk('Ierr'), 'Inputs', '|+-', 'Position', [x+300 y+45 x+320 y+65]);
add_block('simulink/Discrete/Discrete PID Controller', blk('Current PI'), 'Controller', 'PI', ...
    'P', 'P.wind.KpI', 'I', 'P.wind.KiI', 'SampleTime', '-1', 'LimitOutput', 'on', ...
    'UpperSaturationLimit', '0.92', 'LowerSaturationLimit', '0', 'AntiWindupMode', 'clamping', ...
    'InitialConditionForIntegrator', 'P.wind.D0', 'Position', [x+350 y+35 x+410 y+75]);
add_block('simulink/Signal Routing/Goto', blk('Goto wm'), 'GotoTag', 'wm_wind', 'TagVisibility', 'global', ...
    'Position', [x y-50 x+60 y-30]);
for k = 1:3
    add_line(ws, get_ph(bs, 'Outport', 1), get_ph(blk('w^3'), 'Inport', k), 'autorouting', 'on');
end
add_line(ws, get_ph(bs, 'Outport', 1), get_ph(blk('Goto wm'), 'Inport', 1), 'autorouting', 'on');
add_line(ws, 'w^3/1', 'Kopt/1');
add_line(ws, 'Kopt/1', 'Iref/1');
add_line(ws, 'From Vrect/1', 'Vmin/1');
add_line(ws, 'Vmin/1', 'Iref/2');
add_line(ws, 'Iref/1', 'Ilimit/1');
add_line(ws, 'Ilimit/1', 'Ierr/1');
add_line(ws, 'From IL/1', 'Ierr/2', 'autorouting', 'on');
add_line(ws, 'Ierr/1', 'Current PI/1');
add_line(ws, get_ph(blk('Current PI'), 'Outport', 1), get_ph(ro{1}, 'Inport', 1), 'autorouting', 'on');
block_on_trip(ws, ro{1});             % stop the wind boost once the protection trips

%% 7. Local load and islanding event -------------------------------------
vi2 = [mdl '/Three-Phase V-I Measurement2'];
ib  = byname(mdl, '^Breaker for Islanding Simulation$');
set_param(ib, 'External', 'off', 'InitialState', 'closed', 'SwitchTimes', '[P.tIsland]');
pv2 = get_param(vi2, 'Position');
add_block('powerlib/Elements/Three-Phase Parallel RLC Load', [mdl '/Local load'], ...
    'Configuration', 'Y (grounded)', 'NominalVoltage', 'P.Vll', 'NominalFrequency', 'P.fg', ...
    'ActivePower', 'P.load.P', 'InductivePower', 'P.load.QL', 'CapacitivePower', 'P.load.QC', ...
    'Position', [pv2(3)+15 pv2(2)-190 pv2(3)+75 pv2(2)-110]);
flip = struct('up', 'down', 'down', 'up', 'left', 'right', 'right', 'left');
set_param([mdl '/Local load'], 'Orientation', flip.(get_param([mdl '/Local load'], 'Orientation')));
bph = get_param(ib, 'PortHandles'); lph = get_param([mdl '/Local load'], 'PortHandles');
for k = 1:3
    add_line(mdl, lph.LConn(k), bph.LConn(k), 'autorouting', 'on');   % inverter side of the breaker
end

%% 8. Logging -------------------------------------------------------------
lg = [mdl '/Data logging'];
sp = get_param([mdl '/Three-Phase Source'], 'Position');
add_block('built-in/Subsystem', lg, 'Position', [sp(1) sp(2)-150 sp(1)+110 sp(2)-90]);
tags = {'Vabc','Igrid','Iabc','VDC','ID','IQ','freq','Vpcc_rms','VPV','IPV','trip','wm_wind'};
for k = 1:numel(tags)
    y = 45*k;
    add_block('simulink/Signal Routing/From', sprintf('%s/From %s', lg, tags{k}), ...
        'GotoTag', tags{k}, 'Position', [40 y 110 y+20]);
    add_block('simulink/Sinks/To Workspace', sprintf('%s/Log %s', lg, tags{k}), ...
        'VariableName', ['log_' tags{k}], 'SaveFormat', 'Timeseries', 'Decimation', 'P.logDecim', ...
        'Position', [170 y 290 y+20]);
    add_line(lg, sprintf('From %s/1', tags{k}), sprintf('Log %s/1', tags{k}));
end

% Scope2 showed Id on a two-input scope with the second input left empty;
% give it Iq so the scope shows both current components.
s2 = [mdl '/Scope2'];
lh = get_param(s2, 'LineHandles');
if numel(lh.Inport) == 2 && lh.Inport(2) == -1
    ps2 = get_param(get_param(lh.Inport(1), 'SrcBlockHandle'), 'Position');
    add_block('simulink/Signal Routing/From', [mdl '/From IQ'], 'GotoTag', 'IQ', ...
        'Position', ps2 + [0 45 0 45]);
    sph = get_param(s2, 'PortHandles');
    add_line(mdl, get_ph([mdl '/From IQ'], 'Outport', 1), sph.Inport(2), 'autorouting', 'on');
end

%% 9. Tidy up --------------------------------------------------------------
tidy(mdl); tidy(bc); tidy(ic); tidy(pr); tidy(ws);

save_system(mdl);
if exist([dst '.r2018a'], 'file'), delete([dst '.r2018a']); end   % automatic backup of the copy
fprintf('Built %s (SCR = %g)\n', dst, scr);
end

% ---- helpers ---------------------------------------------------------------
function b = byname(sys, pat)
b = find_system(sys, 'SearchDepth', 1, 'Regexp', 'on', 'Name', pat);
b = b(~strcmp(b, sys));
assert(numel(b) == 1, 'Expected one block matching %s in %s, found %d', pat, sys, numel(b));
b = b{1};
end

function block_on_trip(sys, relop)
% Gate a converter's switching pulse with NOT(trip), so the source stops
% feeding the DC link after the protection has opened the breaker.
lh  = get_param(relop, 'LineHandles'); ln = lh.Outport(1);
dst = get_param(ln, 'DstPortHandle'); delete_line(ln);
p = get_param(relop, 'Position');
add_block('simulink/Signal Routing/From', [sys '/From trip'], 'GotoTag', 'trip', ...
    'Position', [p(1) p(4)+40 p(1)+50 p(4)+60]);
add_block('simulink/Logic and Bit Operations/Logical Operator', [sys '/Not tripped'], 'Operator', 'NOT', ...
    'Position', [p(1)+70 p(4)+35 p(1)+100 p(4)+65]);
add_block('simulink/Logic and Bit Operations/Logical Operator', [sys '/Pulse enable'], 'Operator', 'AND', ...
    'Position', [p(3)+30 p(2) p(3)+60 p(4)+10]);
add_line(sys, 'From trip/1', 'Not tripped/1');
add_line(sys, get_ph(relop, 'Outport', 1), get_ph([sys '/Pulse enable'], 'Inport', 1), 'autorouting', 'on');
add_line(sys, 'Not tripped/1', 'Pulse enable/2', 'autorouting', 'on');
for k = 1:numel(dst)
    if dst(k) ~= -1
        add_line(sys, get_ph([sys '/Pulse enable'], 'Outport', 1), dst(k), 'autorouting', 'on');
    end
end
end

function tidy(sys)
% Remove wires left open by deleted blocks, then any scope, display or
% From block that no longer has a connection.
again = true;
while again
    again = false;
    ln = find_system(sys, 'FindAll', 'on', 'SearchDepth', 1, 'Type', 'line', 'Connected', 'off');
    for k = 1:numel(ln)
        if ishandle(ln(k)) && isempty(get_param(ln(k), 'LineChildren'))
            delete_line(ln(k)); again = true;
        end
    end
    bl = [find_system(sys, 'SearchDepth', 1, 'BlockType', 'Scope'); ...
          find_system(sys, 'SearchDepth', 1, 'BlockType', 'Display'); ...
          find_system(sys, 'SearchDepth', 1, 'BlockType', 'From')];
    for k = 1:numel(bl)
        lh = get_param(bl{k}, 'LineHandles');
        h = [lh.Inport(:); lh.Outport(:)];
        if all(h == -1), delete_block(bl{k}); again = true; end
    end
end
end

function add_hinf(ic, pidName, ax)
% Put an H-infinity controller beside one PI current controller, with a
% selector and a one-sample computation delay on the chosen output.
pidb = [ic '/' pidName];
lh  = get_param(pidb, 'LineHandles');
src = get_param(lh.Inport(1), 'SrcPortHandle');
dst = get_param(lh.Outport(1), 'DstPortHandle');
delete_line(lh.Outport(1));
p = get_param(pidb, 'Position'); y = p(2) - 70;
n = @(s) sprintf('%s/%s %s', ic, s, ax);
add_block('simulink/Discrete/Discrete State-Space', n('Hinf'), 'A', 'P.hinf.A', 'B', 'P.hinf.B', ...
    'C', 'P.hinf.C', 'D', 'P.hinf.D', 'SampleTime', 'P.Tc', 'Position', [p(1) y p(3) y+40]);
add_block('simulink/Discontinuities/Saturation', n('Hinf limit'), 'UpperLimit', '400', 'LowerLimit', '-400', ...
    'Position', [p(3)+20 y+5 p(3)+50 y+35]);
add_block('simulink/Sources/Constant', n('Use Hinf'), 'Value', 'P.ctrl.useHinf', ...
    'Position', [p(3)+20 y+55 p(3)+50 y+75]);
add_block('simulink/Signal Routing/Switch', n('Controller select'), 'Criteria', 'u2 >= Threshold', ...
    'Threshold', '0.5', 'Position', [p(3)+80 y+40 p(3)+110 y+100]);
add_block('simulink/Discrete/Unit Delay', n('Computation delay'), 'SampleTime', 'P.Tc', ...
    'Position', [p(3)+130 y+55 p(3)+160 y+85]);
add_line(ic, src, get_ph(n('Hinf'), 'Inport', 1), 'autorouting', 'on');
add_line(ic, get_ph(n('Hinf'), 'Outport', 1), get_ph(n('Hinf limit'), 'Inport', 1));
add_line(ic, get_ph(n('Hinf limit'), 'Outport', 1), get_ph(n('Controller select'), 'Inport', 1), 'autorouting', 'on');
add_line(ic, get_ph(n('Use Hinf'), 'Outport', 1), get_ph(n('Controller select'), 'Inport', 2), 'autorouting', 'on');
add_line(ic, get_ph(pidb, 'Outport', 1), get_ph(n('Controller select'), 'Inport', 3), 'autorouting', 'on');
add_line(ic, get_ph(n('Controller select'), 'Outport', 1), get_ph(n('Computation delay'), 'Inport', 1));
for k = 1:numel(dst)
    if dst(k) ~= -1
        add_line(ic, get_ph(n('Computation delay'), 'Outport', 1), dst(k), 'autorouting', 'on');
    end
end
end

function h = get_ph(block, kind, idx)
ph = get_param(block, 'PortHandles'); h = ph.(kind)(idx);
end

function prune(sys)
% Remove signal lines left dangling after a block was deleted.
% Electrical (physical connection) lines are never touched.
changed = true;
while changed
    changed = false;
    ln = find_system(sys, 'FindAll', 'on', 'SearchDepth', 1, 'Type', 'line');
    for k = 1:numel(ln)
        if ~ishandle(ln(k)), continue; end
        s = get_param(ln(k), 'SrcPortHandle'); d = get_param(ln(k), 'DstPortHandle');
        ends = [s; d(:)]; ends = ends(ends ~= -1);
        if isempty(ends) || ~isempty(get_param(ln(k), 'LineChildren')), continue; end
        if any(strcmp(get_param(ends, 'PortType'), 'connection')), continue; end
        if isequal(s, -1) || all(d == -1)
            delete_line(ln(k)); changed = true;
        end
    end
end
end

function todiscrete(blocks)
% Run every PID controller as a discrete block so a fixed-step solver can be used.
for k = 1:numel(blocks)
    set_param(blocks{k}, 'TimeDomain', 'Discrete-time', 'SampleTime', '-1');
end
end

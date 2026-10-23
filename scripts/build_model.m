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
% a start-up limit on irradiance lets weak-grid runs start at low PV power
add_block('simulink/Sources/Step', [mdl '/Irradiance start limit'], 'Time', 'P.pv.tStart', ...
    'Before', 'P.pv.Gstart', 'After', '1e4', 'SampleTime', '0', ...
    'Position', [pos(1)-140 pos(2)-60 pos(1)-100 pos(2)-30]);
add_block('simulink/Math Operations/MinMax', [mdl '/Irradiance limit'], 'Function', 'min', 'Inputs', '2', ...
    'Position', [pos(1)-70 pos(2)-20 pos(1)-40 pos(2)+20]);
add_line(mdl, 'Irradiance/1', 'Irradiance limit/2', 'autorouting', 'on');
add_line(mdl, 'Irradiance start limit/1', 'Irradiance limit/1', 'autorouting', 'on');
add_line(mdl, 'Irradiance limit/1', 'PV Array/1', 'autorouting', 'on');
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
% controller. Each axis has four controllers in parallel (PI, PID, H-infinity,
% fuzzy PI); P.ctrl.mode selects which one drives the inverter.
set_param(pid('PID Controller2'), 'SampleTime', 'P.Tc');
set_param(pid('PID Controller3'), 'SampleTime', 'P.Tc');
add_current_controller(ic, 'PID Controller2', 'd');
add_current_controller(ic, 'PID Controller3', 'q');

% Active frequency drift: the q-axis current reference was a constant 0.
q0 = [ic '/Constant5'];
lh = get_param(q0, 'LineHandles'); dstq = get_param(lh.Outport(1), 'DstPortHandle');
pq = get_param(q0, 'Position'); delete_line(lh.Outport(1)); delete_block(q0);
aq = [ic '/Active frequency drift'];
add_block('built-in/Subsystem', aq, 'Position', [pq(1)-60 pq(2)-15 pq(3)+20 pq(4)+15], 'BackgroundColor', 'cyan');
m = @(s) [aq '/' s];
add_block('simulink/Signal Routing/From', m('From freq'), 'GotoTag', 'freq', 'Position', [20 40 80 60]);
add_block('simulink/Sources/Constant', m('fg'), 'Value', 'P.fg', 'Position', [20 80 60 100]);
add_block('simulink/Math Operations/Sum', m('Frequency error'), 'Inputs', '+-', 'Position', [110 45 130 85]);
add_block('simulink/Math Operations/Gain', m('K'), 'Gain', 'P.afd.K', 'Position', [160 50 200 80]);
add_block('simulink/Sources/Constant', m('bias'), 'Value', 'P.afd.bias', 'Position', [160 110 210 130]);
add_block('simulink/Math Operations/Sum', m('Add bias'), 'Inputs', '++', 'Position', [240 55 260 95]);
add_block('simulink/Discontinuities/Saturation', m('Limit'), 'UpperLimit', 'P.afd.lim', 'LowerLimit', '-P.afd.lim', ...
    'Position', [290 60 320 90]);
add_block('simulink/Sources/Step', m('Armed'), 'Time', 'P.prot.tBlank', 'Before', '0', 'After', 'P.afd.on', ...
    'SampleTime', 'P.Tc', 'Position', [290 120 320 150]);
add_block('simulink/Math Operations/Product', m('Enable'), 'Position', [360 65 390 125]);
% the ML detector's confirmation nudge (section 7e, step 9) adds to the same reference
add_block('simulink/Signal Routing/From', m('From ml_nudge'), 'GotoTag', 'ml_nudge', 'Position', [360 150 420 170]);
add_block('simulink/Math Operations/Sum', m('Add nudge'), 'Inputs', '++', 'Position', [430 85 450 125]);
add_block('simulink/Sinks/Out1', m('Iq ref'), 'Position', [490 98 520 112]);
add_line(aq, 'From freq/1', 'Frequency error/1');  add_line(aq, 'fg/1', 'Frequency error/2', 'autorouting', 'on');
add_line(aq, 'Frequency error/1', 'K/1');  add_line(aq, 'K/1', 'Add bias/1');
add_line(aq, 'bias/1', 'Add bias/2', 'autorouting', 'on');  add_line(aq, 'Add bias/1', 'Limit/1');
add_line(aq, 'Limit/1', 'Enable/1', 'autorouting', 'on');  add_line(aq, 'Armed/1', 'Enable/2', 'autorouting', 'on');
add_line(aq, 'Enable/1', 'Add nudge/1');  add_line(aq, 'From ml_nudge/1', 'Add nudge/2', 'autorouting', 'on');
add_line(aq, 'Add nudge/1', 'Iq ref/1');
for k = 1:numel(dstq)
    if dstq(k) ~= -1, add_line(ic, get_ph(aq, 'Outport', 1), dstq(k), 'autorouting', 'on'); end
end

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
add_block('simulink/Sources/Step', [pr '/Blanking'], 'Time', 'P.prot.tArm', 'Before', '0', ...
    'After', '1', 'SampleTime', 'P.Ts', 'Position', [pf(1)-150 pf(2)+60 pf(1)-120 pf(2)+90]);
add_block('simulink/Logic and Bit Operations/Logical Operator', [pr '/Armed'], 'Operator', 'AND', ...
    'Position', [pf(1)-80 pf(2) pf(1)-50 pf(2)+40]);
add_line(pr, 'Logical Operator/1', 'Armed/1', 'autorouting', 'on');
add_line(pr, 'Blanking/1', 'Armed/2', 'autorouting', 'on');
% the machine-learning detector (section 7e) trips through the same latch
add_block('simulink/Signal Routing/From', [pr '/From ml_trip'], 'GotoTag', 'ml_trip', ...
    'Position', [pf(1)-150 pf(2)+110 pf(1)-90 pf(2)+130]);
add_block('simulink/Logic and Bit Operations/Logical Operator', [pr '/Relay or ML'], 'Operator', 'OR', ...
    'Position', [pf(1)-35 pf(2)+5 pf(1)-10 pf(2)+45]);
add_line(pr, 'Armed/1', 'Relay or ML/1', 'autorouting', 'on');
add_line(pr, 'From ml_trip/1', 'Relay or ML/2', 'autorouting', 'on');
add_line(pr, 'Relay or ML/1', 'S-R Flip-Flop/1', 'autorouting', 'on');
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

%% 7b. Programmable grid and switched equipment for disturbance tests -------
% The fixed grid source becomes a programmable voltage source (sags, swells,
% frequency ramps, phase jumps) behind the same impedance. A switched load
% and a switched capacitor bank sit at the PCC for load-switching events.
for L = {'spsThreePhaseProgrammableVoltageSourceLib', 'spsThreePhaseSeriesRLCBranchLib', 'spsGroundLib', ...
         'spsThreePhaseBreakerLib', 'spsThreePhaseParallelRLCLoadLib'}
    load_system(L{1});
end
gs = [mdl '/Three-Phase Source'];
ps = get_param(gs, 'Position');
gph = get_param(gs, 'PortHandles');
for k = 1:3
    l = get_param(gph.RConn(k), 'Line'); if l ~= -1, delete_line(l); end
end
delete_block(gs);
ibh = get_param(ib, 'PortHandles');
gv = [mdl '/Grid voltage']; gz = [mdl '/Grid impedance']; gn = [mdl '/Grid neutral'];
add_block(libblock('spsThreePhaseProgrammableVoltageSourceLib'), gv, 'Position', ps);
set_param(gv, 'PositiveSequence', '[P.Vll 0 P.fg]', 'VariationEntity', 'None', ...
    'Amplitudes', 'P.event.amp', 'TimeValues', 'P.event.time', 'VariationStep', 'P.event.step', ...
    'VariationRate', 'P.event.rate', 'VariationTiming', 'P.event.timing', ...
    'HarmonicA', 'P.grid.harmA', 'HarmonicB', 'P.grid.harmB', 'Timing', '[0 1e6]');   % background harmonics, switched on by run_model
add_block(libblock('spsThreePhaseSeriesRLCBranchLib'), gz, 'BranchType', 'RL', ...
    'Resistance', 'P.grid.R', 'Inductance', 'P.grid.L', 'Position', ps + [-140 0 -140 0]);
add_block(libblock('spsGroundLib'), gn, 'Position', [ps(3)+30 ps(4)+20 ps(3)+60 ps(4)+50]);
gvh = get_param(gv, 'PortHandles'); gzh = get_param(gz, 'PortHandles'); gnh = get_param(gn, 'PortHandles');
for k = 1:3
    add_line(mdl, ibh.RConn(k), gzh.LConn(k), 'autorouting', 'on');
    add_line(mdl, gzh.RConn(k), gvh.RConn(k), 'autorouting', 'on');
end
add_line(mdl, gvh.LConn(1), gnh.LConn(1), 'autorouting', 'on');

% switched load and switched capacitor bank at the PCC (inverter side of the grid breaker)
pl = get_param([mdl '/Local load'], 'Position');
sw = {'Switched load', 'P.event.loadP', '0', 'P.event.loadT'; ...
      'Switched capacitor', '1', 'P.event.capQ', 'P.event.capT'};
for k = 1:2
    br = [mdl '/' sw{k,1} ' breaker']; ld = [mdl '/' sw{k,1}];
    x = pl(1) + 140*k;
    add_block(libblock('spsThreePhaseBreakerLib'), br, 'InitialState', 'open', 'SwitchA', 'on', ...
        'SwitchB', 'on', 'SwitchC', 'on', 'External', 'off', 'SwitchTimes', ['[' sw{k,4} ']'], ...
        'Position', [x pl(2)-120 x+50 pl(2)-60]);
    add_block(libblock('spsThreePhaseParallelRLCLoadLib'), ld, 'Configuration', 'Y (grounded)', ...
        'NominalVoltage', 'P.Vll', 'NominalFrequency', 'P.fg', 'ActivePower', sw{k,2}, ...
        'InductivePower', '0', 'CapacitivePower', sw{k,3}, 'Position', [x pl(2)-220 x+50 pl(2)-150]);
    bh = get_param(br, 'PortHandles'); lh2 = get_param(ld, 'PortHandles');
    for j = 1:3
        add_line(mdl, bh.LConn(j), ibh.LConn(j), 'autorouting', 'on');
        add_line(mdl, bh.RConn(j), lh2.LConn(j), 'autorouting', 'on');
    end
end

%% 7c. Second inverter at the PCC (multi-inverter islanding cases) -------
% An averaged constant-power source: three controlled current sources whose
% references follow the PCC voltage, i = (P*v - Q*v90)/sum(v.^2). Its reactive
% power can drift with the measured frequency (P.der2.Kq). Off unless P.der2.on.
dc = [mdl '/Second inverter control'];
add_block('built-in/Subsystem', dc, 'Position', [pl(1)+420 pl(2)-320 pl(1)+540 pl(2)-260], 'BackgroundColor', 'cyan');
m = @(s) [dc '/' s];
add_block('simulink/Signal Routing/From', m('From Vabc'), 'GotoTag', 'Vabc', 'Position', [20 30 80 50]);
add_block('simulink/Discrete/Zero-Order Hold', m('Sample'), 'SampleTime', 'P.der2.Ts', 'Position', [110 25 150 55]);
add_block('simulink/Signal Routing/From', m('From freq'), 'GotoTag', 'freq', 'Position', [20 80 80 100]);
add_block('simulink/Sources/Step', m('Enable'), 'Time', 'P.der2.tOn', 'Before', '0', 'After', 'P.der2.on', ...
    'SampleTime', 'P.der2.Ts', 'Position', [110 120 150 150]);
add_block('simulink/Sources/Step', m('Armed'), 'Time', 'P.prot.tBlank', 'Before', '0', 'After', '1', ...
    'SampleTime', 'P.der2.Ts', 'Position', [110 170 150 200]);
add_block('simulink/Sources/Constant', m('Settings'), 'Value', ...
    '[P.der2.P P.der2.Q P.der2.Kq P.der2.Qlim P.fg 1.5*(0.5*P.Vll*sqrt(2/3))^2]', 'Position', [60 220 150 250]);
add_block('simulink/User-Defined Functions/MATLAB Function', m('Current reference'), 'Position', [210 40 330 240]);
ch = find(sfroot, '-isa', 'Stateflow.EMChart', 'Path', m('Current reference'));
ch.Script = sprintf([ ...
    'function i = DER2(v, f, en, armed, prm)\n' ...
    '%% Constant-power current references from the PCC voltage.\n' ...
    'Pd = prm(1);\n' ...
    'Q = prm(2) + armed*min(max(prm(3)*(f - prm(5)), -prm(4)), prm(4));\n' ...
    'v90 = [v(2) - v(3); v(3) - v(1); v(1) - v(2)]/sqrt(3);   %% lags v by 90 degrees\n' ...
    's = max(v(1)^2 + v(2)^2 + v(3)^2, prm(6));\n' ...
    'i = en*(Pd*v(:) - Q*v90)/s;\n']);
add_block('simulink/Discrete/Unit Delay', m('Delay'), 'SampleTime', 'P.der2.Ts', 'Position', [370 125 400 155]);
add_block('simulink/Sinks/Out1', m('Iabc ref'), 'Position', [440 133 470 147]);
add_line(dc, 'From Vabc/1', 'Sample/1');  add_line(dc, 'Sample/1', 'Current reference/1', 'autorouting', 'on');
add_line(dc, 'From freq/1', 'Current reference/2', 'autorouting', 'on');
add_line(dc, 'Enable/1', 'Current reference/3', 'autorouting', 'on');
add_line(dc, 'Armed/1', 'Current reference/4', 'autorouting', 'on');
add_line(dc, 'Settings/1', 'Current reference/5', 'autorouting', 'on');
add_line(dc, 'Current reference/1', 'Delay/1');  add_line(dc, 'Delay/1', 'Iabc ref/1');
dm = [mdl '/Second inverter phases'];
add_block('simulink/Signal Routing/Demux', dm, 'Outputs', '3', 'ShowName', 'off', 'Position', [pl(1)+600 pl(2)-320 pl(1)+605 pl(2)-260]);
add_line(mdl, get_ph(dc, 'Outport', 1), get_ph(dm, 'Inport', 1));
for j = 1:3
    cs = sprintf('%s/Second inverter %c', mdl, 'a' + j - 1);
    x = pl(1) + 600 + 130*j;
    add_block('powerlib/Electrical Sources/Controlled Current Source', cs, 'Initialize', 'off', ...
        'Position', [x pl(2)-310 x+30 pl(2)-250]);
    gd = sprintf('%s/Second inverter ground %c', mdl, 'a' + j - 1);
    add_block(libblock('spsGroundLib'), gd, 'Position', [x pl(2)-230 x+30 pl(2)-200]);
    ch3 = get_param(cs, 'PortHandles'); gh = get_param(gd, 'PortHandles');
    add_line(mdl, get_ph(dm, 'Outport', j), ch3.Inport(1), 'autorouting', 'on');
    add_line(mdl, ch3.RConn(1), ibh.LConn(j), 'autorouting', 'on');   % current flows out of this terminal into the PCC
    add_line(mdl, ch3.LConn(1), gh.LConn(1), 'autorouting', 'on');
end

%% 7d. Sensor noise ---------------------------------------------------------
% Every measurement the controls and detectors use passes through a sensor
% model: white noise sampled at the control rate, with the standard deviations
% of P.noise (off unless P.noise.on). The measurement blocks now publish the
% true signals under *_true tags; the noisy ones keep the old tags, so every
% user of Vabc, Igrid, Iabc and VDC sees the sensor's output.
sp = get_param([mdl '/Grid voltage'], 'Position');
set_param(vi2, 'LabelV', 'Vabc_true', 'LabelI', 'Igrid_true');
set_param([mdl '/Three-Phase V-I Measurement1'], 'LabelI', 'Iabc_true');
gdc = find_system(mdl, 'SearchDepth', 1, 'BlockType', 'Goto', 'GotoTag', 'VDC');
set_param(gdc{1}, 'GotoTag', 'VDC_true');
sn = [mdl '/Sensor noise'];
add_block('built-in/Subsystem', sn, 'Position', [sp(1)+150 sp(2)-150 sp(1)+260 sp(2)-90], 'BackgroundColor', 'cyan');
ch = {'Vabc', 'P.noise.v*P.Vpk', '[1 2 3]'; 'Igrid', 'P.noise.i*P.Ipk', '[4 5 6]'; ...
      'Iabc', 'P.noise.i*P.Ipk', '[7 8 9]'; 'VDC', 'P.noise.vdc*P.Vdc', '10'};
for k = 1:size(ch, 1)
    y = 70*k; m = @(s) sprintf('%s/%s %s', sn, s, ch{k,1});
    add_block('simulink/Signal Routing/From', m('From true'), 'GotoTag', [ch{k,1} '_true'], 'Position', [30 y 110 y+20]);
    add_block('simulink/Sources/Random Number', m('Noise'), 'Mean', '0', ...
        'Variance', sprintf('(P.noise.on*%s)^2', ch{k,2}), 'Seed', ['10*P.noise.seed + ' ch{k,3}], ...
        'SampleTime', 'P.Tc', 'Position', [30 y+28 110 y+52]);
    add_block('simulink/Math Operations/Sum', m('Sensor'), 'Inputs', '++', 'Position', [150 y+5 170 y+45]);
    add_block('simulink/Signal Routing/Goto', m('Goto'), 'GotoTag', ch{k,1}, 'TagVisibility', 'global', ...
        'Position', [210 y+15 270 y+35]);
    add_line(sn, sprintf('From true %s/1', ch{k,1}), sprintf('Sensor %s/1', ch{k,1}), 'autorouting', 'on');
    add_line(sn, sprintf('Noise %s/1', ch{k,1}), sprintf('Sensor %s/2', ch{k,1}), 'autorouting', 'on');
    add_line(sn, sprintf('Sensor %s/1', ch{k,1}), sprintf('Goto %s/1', ch{k,1}));
end

%% 7e. Machine-learning islanding detector ---------------------------------
% The Phase 6 detector running in the loop. Every control period it buffers
% the PCC voltage and inverter current waveforms (10 kHz) and, every 1 ms,
% frequency, RMS voltage, DC-link voltage and the d/q currents. Every
% P.ml.step it computes the 22 features of ML_FEATURES over the last window
% against the baseline before it and runs the network; P.ml.debounce windows
% in a row above P.ml.threshold latch a trip, which opens the inverter's
% breaker through the protection's latch (section 5). Buffer and layer sizes
% are fixed when the model is built, from ml/islanding_classifier.mat. With
% P.ml.confirm.on (step 9) the alarm first nudges the q-axis current
% (ml_nudge, added in the drift block of section 4) and trips only if the
% PCC voltage angle answers as an island's does (ml_resp, ml_raw).
md = [mdl '/Machine-learning islanding detector'];
add_block('built-in/Subsystem', md, 'Position', [sp(1)+300 sp(2)-150 sp(1)+430 sp(2)-90], 'BackgroundColor', 'cyan');
m = @(s) [md '/' s];
src = {'Vabc', 'Igrid', 'freq', 'Vpcc_rms', 'VDC', 'ID', 'IQ'};
for k = 1:numel(src)
    y = 40*k;
    add_block('simulink/Signal Routing/From', m(['From ' src{k}]), 'GotoTag', src{k}, 'Position', [20 y 90 y+20]);
end
add_block('simulink/Signal Routing/Mux', m('Slow signals'), 'Inputs', '5', 'Position', [130 115 135 305]);
for k = 3:7, add_line(md, sprintf('From %s/1', src{k}), sprintf('Slow signals/%d', k - 2), 'autorouting', 'on'); end
smp = {'Sample v', 'From Vabc/1'; 'Sample i', 'From Igrid/1'; 'Sample slow', 'Slow signals/1'};
for k = 1:3
    y = 40 + 90*(k - 1);
    add_block('simulink/Discrete/Zero-Order Hold', m(smp{k,1}), 'SampleTime', 'P.Tc', 'Position', [180 y 210 y+30]);
    add_line(md, smp{k,2}, [smp{k,1} '/1'], 'autorouting', 'on');
end
add_block('simulink/Sources/Step', m('Armed'), 'Time', 'P.ml.tArm', 'Before', '0', 'After', '1', ...
    'SampleTime', 'P.Tc', 'Position', [180 300 210 330]);
add_block('simulink/Sources/Constant', m('Network'), 'Value', 'P.ml.theta', 'Position', [150 360 210 380]);
add_block('simulink/Sources/Constant', m('Settings'), 'Value', ...
    '[P.ml.threshold P.ml.debounce P.Vpk P.Ipk P.Sn P.ml.trip]', 'Position', [130 410 210 430]);
% step 9: the ML-triggered confirmation (P.ml.confirm); off, an alarm trips as before
add_block('simulink/Sources/Constant', m('Confirmation'), 'Value', ['[P.ml.confirm.on P.ml.confirm.amp ' ...
    'round(P.ml.confirm.T/P.Tc) P.ml.confirm.thr P.ml.confirm.sign round(P.ml.confirm.hold/P.Tc) P.ml.confirm.mode]'], ...
    'Position', [130 460 210 480]);
add_block('simulink/User-Defined Functions/MATLAB Function', m('Detector'), 'Position', [270 40 400 480]);
L = P.ml.layers; fw = 1/P.Tc; fs = 1e3;
ch = find(sfroot, '-isa', 'Stateflow.EMChart', 'Path', m('Detector'));
ch.Script = sprintf([ ...
    'function [trip, score, nudge, resp, raw] = ML(v, i, s, armed, th, cfg, cc)\n' ...
    '%% Sliding-window islanding detector: features (ML_FEATURES) and a neural network.\n' ...
    '%% s = [frequency; RMS voltage; DC-link voltage; Id; Iq]; cfg = [threshold debounce Vpk Ipk Sn trip].\n' ...
    '%% cc = [on amp samples thr sign hold mode] (P.ml.confirm): with on > 0 an alarm starts a\n' ...
    '%% q-current nudge of amp for the given samples and trips only if the PCC voltage angle\n' ...
    '%% then moves by more than thr (resp: drift of the two cycles before removed; raw: not).\n' ...
    'NB = %d; NW = %d; MB = %d; MW = %d; DEC = %d; EVERY = %d; NF = %d; H1 = %d; H2 = %d; NC = %d;\n' ...
    'persistent bv bi bs k run sc tr conf hld P0 r rs rw\n' ...
    'if isempty(k)\n' ...
    '    bv = zeros(NB + NW + 1, 3); bi = zeros(NB + NW + 1, 3); bs = zeros(MB + MW + 1, 5);\n' ...
    '    k = 0; run = 0; sc = 0; tr = 0; conf = 0; hld = 0; P0 = complex(0, 0); r = 0; rs = 0; rw = 0;\n' ...
    'end\n' ...
    'bv = [bv(2:end,:); v(:).''];  bi = [bi(2:end,:); i(:).''];\n' ...
    'if mod(k, DEC) == 0, bs = [bs(2:end,:); s(:).'']; end\n' ...
    'if armed > 0 && mod(k, EVERY) == 0 && k >= NB + NW\n' ...
    '    x = ml_features(bv, bi, bs(:,1), bs(:,3), bs(:,4), bs(:,5), MW, NW, cfg(3), cfg(4), cfg(5), %g, %g);\n' ...
    '    z = (x(:) - th(1:NF))./th(NF+1:2*NF); o = 2*NF;\n' ...
    '    W1 = reshape(th(o+1:o+H1*NF), H1, NF); o = o + H1*NF; b1 = th(o+1:o+H1); o = o + H1;\n' ...
    '    W2 = reshape(th(o+1:o+H2*H1), H2, H1); o = o + H2*H1; b2 = th(o+1:o+H2); o = o + H2;\n' ...
    '    W3 = reshape(th(o+1:o+2*H2), 2, H2); o = o + 2*H2; b3 = th(o+1:o+2);\n' ...
    '    a = W3*max(W2*max(W1*z + b1, 0) + b2, 0) + b3;\n' ...
    '    sc = 1/(1 + exp(a(1) - a(2)));\n' ...
    '    if sc > cfg(1) && conf == 0 && hld == 0, run = run + 1; else, run = 0; end\n' ...
    '    if run >= cfg(2) && cfg(6) > 0 && tr == 0\n' ...
    '        run = 0;\n' ...
    '        if cc(1) > 0\n' ...
    '            conf = 1; P0 = cycle_phasor(bv, k, 0, NC, cfg(3));\n' ...
    '            r = angle(P0*conj(cycle_phasor(bv, k, NC, NC, cfg(3))));\n' ...
    '        else\n' ...
    '            tr = 1;\n' ...
    '        end\n' ...
    '    end\n' ...
    'end\n' ...
    'if conf > cc(3)\n' ...
    '    P1 = cycle_phasor(bv, k, 0, NC, cfg(3));\n' ...
    '    rw = angle(P1*conj(P0)); rs = angle(P1*conj(P0)*exp(-1i*r*cc(3)/NC));\n' ...
    '    d = rs; if cc(7) > 1, d = rw; end\n' ...
    '    if cc(5) ~= 0, d = cc(5)*d; else, d = abs(d); end\n' ...
    '    if d > cc(4), tr = 1; else, hld = cc(6); end\n' ...
    '    conf = 0;\n' ...
    'elseif conf > 0\n' ...
    '    conf = conf + 1;\n' ...
    'elseif hld > 0\n' ...
    '    hld = hld - 1;\n' ...
    'end\n' ...
    'k = k + 1;\n' ...
    'trip = tr; score = sc; nudge = cc(2)*(conf > 0); resp = rs; raw = rw;\n' ...
    '\n' ...
    'function P = cycle_phasor(bv, k, lag, NC, Vpk)\n' ...
    '%% Positive-sequence voltage phasor (pu) of the cycle ending LAG samples ago, at 50 Hz.\n' ...
    'j = (size(bv, 1) - lag - NC + (1:NC)).'';      %% rows; the newest row is sample k\n' ...
    'm = (k - lag - NC + (1:NC)).'';\n' ...
    'a = exp(1i*2*pi/3);\n' ...
    'x = (bv(j,1) + a*bv(j,2) + a*a*bv(j,3))*(2/(3*Vpk));\n' ...
    'P = mean(x.*exp(-1i*2*pi*m/NC));\n'], ...
    round(P.ml.Wb*fw), round(P.ml.W*fw), round(P.ml.Wb*fs), round(P.ml.W*fs), round(fw/fs), ...
    round(P.ml.step*fw), L(1), L(2), L(3), round(fw/P.fg), fs, fw);
for k = 1:3, add_line(md, [smp{k,1} '/1'], sprintf('Detector/%d', k), 'autorouting', 'on'); end
add_line(md, 'Armed/1', 'Detector/4', 'autorouting', 'on');
add_line(md, 'Network/1', 'Detector/5', 'autorouting', 'on');
add_line(md, 'Settings/1', 'Detector/6', 'autorouting', 'on');
add_line(md, 'Confirmation/1', 'Detector/7', 'autorouting', 'on');
outs = {'ml_trip', 'ml_score', 'ml_nudge', 'ml_resp', 'ml_raw'};
for k = 1:numel(outs)
    add_block('simulink/Signal Routing/Goto', m(['Goto ' outs{k}]), 'GotoTag', outs{k}, 'TagVisibility', 'global', ...
        'Position', [450 40+90*k 510 60+90*k]);
    add_line(md, sprintf('Detector/%d', k), ['Goto ' outs{k} '/1'], 'autorouting', 'on');
end

%% 8. Logging -------------------------------------------------------------
lg = [mdl '/Data logging'];
add_block('built-in/Subsystem', lg, 'Position', [sp(1) sp(2)-150 sp(1)+110 sp(2)-90]);
tags = {'Vabc','Igrid','Iabc','VDC','ID','IQ','freq','Vpcc_rms','VPV','IPV','trip','wm_wind','ml_score','ml_trip','Igrid_true', ...
        'ml_nudge','ml_resp','ml_raw'};
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

function add_current_controller(ic, pidName, ax)
% Replace one PI current controller with a block, "Current controller d" or
% "Current controller q", holding four controllers fed by the same error:
% 1 PI (the original), 2 PID, 3 H-infinity, 4 fuzzy PI. A selector driven by
% P.ctrl.mode picks one, and a one-sample computation delay follows it.
pidb = [ic '/' pidName];
lh  = get_param(pidb, 'LineHandles');
src = get_param(lh.Inport(1), 'SrcPortHandle');
dst = get_param(lh.Outport(1), 'DstPortHandle');
p0  = get_param(pidb, 'Position');
sub = sprintf('%s/Current controller %s', ic, ax);
n   = @(s) sprintf('%s/%s', sub, s);
add_block('built-in/Subsystem', sub);
add_block('simulink/Sources/In1', n('error'), 'Position', [30 228 60 242]);
% 1: PI, same settings as the original block
add_block(pidb, n('PI'), 'Position', [200 40 270 80]);
% 2: PID with a filtered derivative
add_block('simulink/Discrete/Discrete PID Controller', n('PID'), 'Controller', 'PID', ...
    'P', 'P.pid.Kp', 'I', 'P.pid.Ki', 'D', 'P.pid.Kd', 'N', 'P.pid.N', 'SampleTime', 'P.Tc', ...
    'IntegratorMethod', 'Forward Euler', 'FilterMethod', 'Backward Euler', ...
    'LimitOutput', 'on', 'UpperSaturationLimit', '400', 'LowerSaturationLimit', '-400', ...
    'AntiWindupMode', 'clamping', 'Position', [200 120 270 160]);
% 3: H-infinity
add_block('simulink/Discrete/Discrete State-Space', n('H-infinity'), 'A', 'P.hinf.A', 'B', 'P.hinf.B', ...
    'C', 'P.hinf.C', 'D', 'P.hinf.D', 'SampleTime', 'P.Tc', 'BackgroundColor', 'orange', ...
    'Position', [200 200 270 240]);
add_block('simulink/Discontinuities/Saturation', n('H-infinity limit'), 'UpperLimit', '400', ...
    'LowerLimit', '-400', 'Position', [300 205 330 235]);
% 4: fuzzy PI in incremental form, u(k) = u(k-1) + Ku*FLC(e/Ke, de/Kde)
add_block('simulink/Discrete/Unit Delay', n('Previous error'), 'SampleTime', 'P.Tc', 'Position', [100 330 130 360]);
add_block('simulink/Math Operations/Sum', n('Error change'), 'Inputs', '+-', 'Position', [160 325 180 365]);
add_block('simulink/Math Operations/Gain', n('Scale e'), 'Gain', '1/P.flc.Ke', 'Position', [200 285 240 315]);
add_block('simulink/Math Operations/Gain', n('Scale de'), 'Gain', '1/P.flc.Kde', 'Position', [200 330 240 360]);
add_block('simulink/Discontinuities/Saturation', n('Limit e'), 'UpperLimit', '1', 'LowerLimit', '-1', 'Position', [260 285 290 315]);
add_block('simulink/Discontinuities/Saturation', n('Limit de'), 'UpperLimit', '1', 'LowerLimit', '-1', 'Position', [260 330 290 360]);
add_block('simulink/Signal Routing/Mux', n('Mux'), 'Inputs', '2', 'Position', [310 290 315 355]);
load_system('fuzblock');                                  % library block name contains a line break
fl = find_system('fuzblock', 'SearchDepth', 1, 'Regexp', 'on', 'Name', '^Fuzzy Logic\s+Controller$');
add_block(fl{1}, n('Fuzzy logic'), 'BackgroundColor', 'cyan', ...
    'Position', [340 300 420 345]);
set_param(n('Fuzzy logic'), 'FIS', 'P.flc.fis', 'SimulateUsing', 'Code generation');   % interpreted mode is far too slow at 10 kHz
add_block('simulink/Math Operations/Gain', n('Ku'), 'Gain', 'P.flc.Ku', 'Position', [440 307 480 337]);
add_block('simulink/Discrete/Discrete-Time Integrator', n('Accumulate'), ...
    'IntegratorMethod', 'Integration: Backward Euler', 'gainval', '1/P.Tc', 'SampleTime', 'P.Tc', ...
    'LimitOutput', 'on', 'UpperSaturationLimit', '400', 'LowerSaturationLimit', '-400', ...
    'Position', [500 305 540 340]);
% selector and computation delay
add_block('simulink/Sources/Constant', n('Controller mode'), 'Value', 'P.ctrl.mode', ...
    'Position', [530 100 610 130]);
add_block('simulink/Signal Routing/Multiport Switch', n('Controller select'), 'Inputs', '4', ...
    'DataPortOrder', 'One-based contiguous', 'Position', [650 80 690 280]);
add_block('simulink/Discrete/Unit Delay', n('Computation delay'), 'SampleTime', 'P.Tc', ...
    'Position', [740 165 775 195]);
add_block('simulink/Sinks/Out1', n('u'), 'Position', [830 173 860 187]);
L = @(a, b) add_line(sub, a, b, 'autorouting', 'on');
L('error/1', 'PI/1');  L('error/1', 'PID/1');  L('error/1', 'H-infinity/1');
L('error/1', 'Previous error/1');  L('error/1', 'Error change/1');  L('error/1', 'Scale e/1');
L('Previous error/1', 'Error change/2');  L('Error change/1', 'Scale de/1');
L('Scale e/1', 'Limit e/1');  L('Scale de/1', 'Limit de/1');
L('Limit e/1', 'Mux/1');  L('Limit de/1', 'Mux/2');  L('Mux/1', 'Fuzzy logic/1');
L('Fuzzy logic/1', 'Ku/1');  L('Ku/1', 'Accumulate/1');
L('H-infinity/1', 'H-infinity limit/1');
L('Controller mode/1', 'Controller select/1');
L('PI/1', 'Controller select/2');  L('PID/1', 'Controller select/3');
L('H-infinity limit/1', 'Controller select/4');  L('Accumulate/1', 'Controller select/5');
L('Controller select/1', 'Computation delay/1');  L('Computation delay/1', 'u/1');
% swap it in for the original PI
delete_line(lh.Inport(1)); delete_line(lh.Outport(1));
delete_block(pidb);
set_param(sub, 'Position', [p0(1) p0(2)-10 p0(3)+25 p0(4)+10], 'BackgroundColor', 'orange');
add_line(ic, src, get_ph(sub, 'Inport', 1), 'autorouting', 'on');
for k = 1:numel(dst)
    if dst(k) ~= -1
        add_line(ic, get_ph(sub, 'Outport', 1), dst(k), 'autorouting', 'on');
    end
end
end

function b = libblock(L)
% The single block in a Specialized Power Systems block library.
load_system(L);
c = find_system(L, 'SearchDepth', 1, 'Type', 'Block');
b = c{1};
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

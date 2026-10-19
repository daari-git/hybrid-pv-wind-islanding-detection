function m = nea_lv_feeder_data(loadScale)
%NEA_LV_FEEDER_DATA  400 V feeder of a distribution transformer on Pidari 11 kV.
%
%   m = nea_lv_feeder_data(loadScale) returns the low-voltage (400 V,
%   50 Hz) feeder supplied by a 100 kVA 11/0.433 kV distribution
%   transformer (DT) at Khajuri Chanha, at the far end of the Pidari 11 kV
%   feeder (Mujeliya 33/11 kV substation, Janakpur DC). loadScale is the
%   loading as a fraction of the FY 2082/83 recorded peak (default 1).
%
%   The 400 V network is modelled on its own: bus 1 is an ideal 400 V
%   source behind the impedance of everything upstream of the DT's LV
%   terminals - the Dhalkebar/Mujeliya source, the Mujeliya 33/11 kV
%   transformer, the Pidari 11 kV sections to Khajuri Chanha and the DT -
%   computed from NEA_FEEDER_DATA('rural') and NEA_LOADFLOW. Its voltage
%   is the 11 kV load-flow voltage at Khajuri Chanha times the DT's
%   no-load ratio.
%
%   Tags as in NEA_FEEDER_DATA: [YB]/[TD] from the NEA year books, [ASSUMED]
%   engineering assumptions. The year books give no LV data, so the DT
%   rating and the whole LV layout below are [ASSUMED] (typical NEA
%   practice: IS 1180 DTs with 433 V no-load secondary, aerial bundled
%   cable distributors, about 50 m pole spans).
%
%   m.pccBus is the node at the end of distributor A where a prosumer
%   (e.g. a PV-wind unit) would connect.

if nargin < 1, loadScale = 1; end
m.Sbase = 0.1;      % MVA
m.freq  = 50;       % Hz
m.Vnom  = 400;      % V line-to-line
m.loadScale = loadScale;

% DT [ASSUMED]: 100 kVA, 11/0.433 kV Dyn11, 4.5 %, X/R 2.5, tap 0
m.dt = struct('bus11', 18, 'kVA', 100, 'Zpct', 4.5, 'xr', 2.5, 'Vlv', 433, 'tap', 0);

% Upstream of the DT LV terminals, from the 11 kV model -----------------
up = nea_feeder_data('rural');
r0 = nea_loadflow(up);
r  = nea_loadflow(up, struct('loadScale', loadScale));
br = r.branch;
path = false(size(br.from));                     % branches from bus 1 to the DT bus
b = m.dt.bus11;
while b ~= 1
    j = find(br.to == b, 1); path(j) = true; b = br.from(j);
end
zb11 = 11^2 / up.Sbase;
zUp11 = sum(br.ohm(path & br.to ~= 2)) + ...                 % 11 kV sections, ohm
        br.ohm(br.to == 2) + up.src.Zohm * (11 / 33)^2 * br.tap(br.to == 2)^2;   % transformer + source
n = (m.dt.Vlv / 1e3) / 11 / (1 + m.dt.tap);                  % DT ratio, V_LV per V_HV
zDT = m.dt.Zpct / 100 * (m.dt.Vlv / 1e3)^2 / (m.dt.kVA / 1e3) * (1 + 1i * m.dt.xr) / sqrt(1 + m.dt.xr^2);
m.Zsrc = zUp11 * n^2 + zDT;                                  % ohm at 400 V
m.Zsrc11 = zUp11 * n^2;  m.Zdt = zDT;
m.Vsource = r.Vpu(m.dt.bus11) * (m.dt.Vlv / 400) / (1 + m.dt.tap);   % pu of 400 V
m.sourceName = sprintf('Pidari 11 kV at %s + %g kVA DT (equivalent)', up.busName{m.dt.bus11}, m.dt.kVA);
m.title = sprintf('Pidari LV feeder: %g kVA DT at %s, 400 V', m.dt.kVA, up.busName{m.dt.bus11});

% LV conductors [ASSUMED - typical IS 14255 ABC data]: R at 20 degC and
% X at 50 Hz in ohm/km, rating in A
m.cond = struct('name', {'ABC 3x95+70 mm2 Al', 'ABC 3x50+35 mm2 Al'}, ...
                'r20', {0.320, 0.641}, 'x', {0.080, 0.085}, 'amp', {195, 130});
ABC95 = 1; ABC50 = 2;
m.condTempC = 60;   % [ASSUMED]

% Topology [ASSUMED]: two distributors, poles every 100 m shown as nodes
m.busName = {'DT LV bus', ...
             'A1', 'A2', 'A3', 'A4', 'A5 (PCC)', ...
             'B1', 'B2', 'B3'};
m.line = [ ...      % [from to lengthKm conductor]
    1 2 0.10 ABC95
    2 3 0.10 ABC95
    3 4 0.10 ABC95
    4 5 0.10 ABC50
    5 6 0.10 ABC50
    1 7 0.10 ABC50
    7 8 0.10 ABC50
    8 9 0.10 ABC50];
m.pccBus = 6;

% Customer load: this DT's share of the Khajuri Chanha 11 kV load
% (shared by DT kVA, as NEA_LOADFLOW shares it), spread equally over the
% eight nodes, at the Pidari power factor
Sdt = r0.Sfeeder(m.dt.bus11) * 1e6 * m.dt.kVA / up.dtKVA(m.dt.bus11) * loadScale;   % VA
m.pf = up.pf;
m.Sload = [0; repmat(Sdt / 8, 8, 1)];        % VA at each bus
m.Sdt = Sdt;
end

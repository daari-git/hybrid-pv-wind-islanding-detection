function m = nea_feeder_data(name)
%NEA_FEEDER_DATA  Network data for two Nepal distribution feeder models.
%
%   m = nea_feeder_data('urban')  K3 66/11 kV substation and Putalisadak
%                                 11 kV feeder, Ratnapark DC, Kathmandu
%                                 (underground / covered conductor)
%   m = nea_feeder_data('rural')  Mujeliya 33/11 kV substation and Pidari
%                                 11 kV feeder, Janakpur DC, Madhesh
%                                 (overhead ACSR)
%
%   Values tagged [YB] are taken from the NEA DCSD Year Book FY 2082/083
%   (2025/026), Annexes "Substation Status", "33 kV Feeder Status" and
%   "11 kV Feeder Status". Values tagged [TD] are from the NEA
%   Transmission Directorate year book FY 2082/083 (grid substation
%   capacities and single-line descriptions). Values tagged [ASSUMED] are
%   engineering assumptions (the year books give feeder totals, not
%   section-by-section topology or fault levels) and should be replaced
%   with survey / GIS / protection-study data when available.
%
%   m.src describes the network behind bus 1 (the load flow holds bus 1
%   at m.Vsource; the dynamic models put m.src.Zohm behind it).

m.Sbase = 10;       % MVA
m.freq  = 50;       % Hz

% Conductor library ---------------------------------------------------
% R at 20 degC and X at 50 Hz in ohm/km, thermal rating in A.
% Standard ACSR / XLPE catalogue values [ASSUMED - typical data sheets].
C = struct('name', {}, 'r20', {}, 'x', {}, 'amp', {});
C(end+1) = struct('name', 'ACSR Weasel 30mm2',     'r20', 0.9116, 'x', 0.390, 'amp', 140);
C(end+1) = struct('name', 'ACSR Rabbit 50mm2',     'r20', 0.5426, 'x', 0.375, 'amp', 190);
C(end+1) = struct('name', 'ACSR Dog 100mm2',       'r20', 0.2733, 'x', 0.355, 'amp', 300);
C(end+1) = struct('name', 'Covered AAAC 100mm2',   'r20', 0.3390, 'x', 0.300, 'amp', 290);
C(end+1) = struct('name', 'XLPE 3C 150mm2 Al',     'r20', 0.2060, 'x', 0.105, 'amp', 270);
C(end+1) = struct('name', 'XLPE 3C 300mm2 Al',     'r20', 0.1000, 'x', 0.094, 'amp', 400);
m.cond = C;
WEASEL = 1; RABBIT = 2; DOG = 3; COVERED = 4; XLPE150 = 5; XLPE300 = 6;

switch lower(name)
    case 'urban'
        m.title = 'Model A - Urban underground feeder: K3 66/11 kV substation + Putalisadak 11 kV, Ratnapark DC, Kathmandu';
        m.tag   = 'urban';

        % [YB] Ratnapark DC 11 kV feeder "Putalisadak": 9 km, 248 A peak,
        %      conductor "XLPE + COVERED + 0.1 ACSR".
        % [TD] K3 substation, Singhadurbar: 66/11 kV GIS, 2 x 22.5 MVA,
        %      peak load 44.30 MVA; "feeds power to Bhrikutimandap,
        %      Putalisadak, Anamnagar, Singhadurbar, Kalikasthan and K2
        %      switching station"; supplied by 66 kV underground cables
        %      from Teku and Suichatar.
        m.peakAmps      = 248;     % [YB]
        m.feederLengthKm = 9.0;    % [YB]
        m.provinceLossPct = 7.30;  % [YB] Bagmati Provincial Office, all DCs
        m.pf            = 0.92;    % [ASSUMED] urban domestic/commercial mix
        m.loadFactor    = 0.55;    % [ASSUMED]
        m.condTempC     = 65;      % [ASSUMED] cable operating temperature
        m.Vsource       = 1.00;    % pu at K3 66 kV bus [ASSUMED]
        m.substationPeakMVA = 44.30;   % [TD] K3

        % Buses 3-14 are real localities in the Putalisadak area; which
        % transformer sits where on the feeder is [ASSUMED].
        m.sourceName = 'K3 66kV (cables from Teku and Suichatar)';
        m.feederName = 'Putalisadak';
        m.busName = {'K3 66kV', 'K3 11kV', 'Pradarshani Marg', 'Bagbazar Chowk', ...
                     'Padma Kanya Campus', 'Putalisadak Chowk', 'Shankar Dev Campus', ...
                     'Ram Shah Path', 'Padmodaya Mod', 'Old Bagbazar', ...
                     'Share Market', 'Nepal Law Campus', 'Singha Durbar West Gate', ...
                     'Adwait Marg'};
        m.busKV   = [66 11*ones(1, 13)];

        % [from to lengthKm conductor nParallel] - section lengths
        % [ASSUMED] but constrained to the year book total: 5.2 km XLPE,
        % 3.7 km covered conductor, 0.1 km ACSR = 9.0 km.
        m.line = [ ...
             2  3  1.2  XLPE300  1
             3  4  0.9  XLPE300  1
             4  5  0.8  XLPE300  1
             5  6  0.7  XLPE300  1
             6  7  0.9  COVERED  1
             7  8  0.8  COVERED  1
             8  9  0.6  COVERED  1
             4 10  0.7  XLPE150  1
             6 11  0.8  COVERED  1
             7 12  0.6  COVERED  1
             9 13  0.1  DOG      1
             5 14  0.9  XLPE150  1];

        % [from to MVA Zpct X/R tap] - K3: 2 x 22.5 MVA [TD] in parallel,
        % 10 % each on own rating, OLTC boosting the 11 kV side by 5 %
        % [ASSUMED].
        m.xfmr = [1 2 45 10.0 20 1.05];

        % Installed 11/0.4 kV distribution transformer kVA per bus
        % [ASSUMED]. Peak load is shared in proportion to these ratings
        % and scaled so the feeder head current equals the 248 A [YB].
        m.dtKVA = [0 0 630 1000 630 1000 630 500 400 630 500 300 200 630];

        % The other K3 11 kV feeders that the Ratnapark DC table lists and
        % [TD] says K3 feeds [YB names and peak A], each as its own load on
        % the K3 11 kV bus, plus the balance that brings the substation to
        % its 44.30 MVA recorded peak [TD]: [bus  peakAmps  coincidence].
        % Coincidence 0.90 [ASSUMED].
        m.fixedName = {'Bhrikutimandap', 'Anamnagar', 'Singhadurbar-2', 'Singhadurbar-1', ...
                       'Kalikasthan', 'K-2(1) incomer', 'K-2(2) incomer', 'Other K3 load (balance)'};
        amps = [200 198 135 5 205 296 290];
        cf = 0.90;
        balance = m.substationPeakMVA * 1e3 / (sqrt(3) * 11) - m.peakAmps - cf * sum(amps);
        m.fixedLoad = [2 * ones(8, 1), [amps(:); balance], [cf * ones(7, 1); 1]];
        m.calBranch = 1;           % line 2-3 is the Putalisadak feeder head

        % Network behind the K3 66 kV bus: the Kathmandu 66 kV cable ring
        % at 1000 MVA, X/R 8 [ASSUMED - no fault level is published].
        m.src = struct('desc', {{'Kathmandu 66 kV network at K3, 1000 MVA, X/R 8 [ASSUMED]'}}, ...
                       'Zohm', zsc(66, 1000, 8));

    case 'rural'
        m.title = 'Model B - Rural Terai overhead feeder: Mujeliya 33/11 kV substation + Pidari 11 kV, Janakpur DC';
        m.tag   = 'rural';

        % [YB] Mujeliya 33/11 kV substation, Janakpur DC:
        %      16.6 + 16.6 + 24 = 57.2 MVA.
        % [YB] 11 kV feeder "PIDARI": 69.851 km, 293 A peak,
        %      ACSR DOG/RABBIT/WEASEL.
        % [YB] Other Janakpur DC 11 kV feeders (peak A): City-1 288,
        %      City-2 252, City-3 334, City-4 293, Dedicated 174,
        %      Industrial 152, Mahendranagar 175, Ring 198, Janaki 231.
        % [YB] Incoming 33 kV feeder "Mujeliya": 45 km, 885 A peak, HTLS
        %      DOG double circuit. Its current is a cross-check on the
        %      substation loading; its impedance is part of m.src below.
        % [TD] Dhalkebar 132/33 kV: 2 x 63 MVA.
        m.peakAmps        = 293;      % [YB] Pidari 11 kV
        m.feederLengthKm  = 69.851;   % [YB] Pidari 11 kV
        m.peakAmps33      = 885;      % [YB] cross-check only
        m.provinceLossPct = 15.02;    % [YB] Madhesh Provincial Office
        m.pf              = 0.85;     % [ASSUMED] domestic + irrigation pumps
        m.loadFactor      = 0.45;     % [ASSUMED]
        m.condTempC       = 60;       % [ASSUMED] Terai summer peak
        m.Vsource         = 1.00;     % pu at Mujeliya 33 kV bus [ASSUMED]

        % Buses 3-19 are real localities of Dhanusha district around
        % Janakpur; which of them the Pidari feeder actually serves, and
        % in what order, is [ASSUMED].
        m.sourceName = 'Mujeliya 33kV incomer (from Dhalkebar)';
        m.feederName = 'Pidari';
        m.busName = {'Mujeliya 33kV', 'Mujeliya 11kV', ...
                     'Pidari Chowk', 'Kuwa', 'Kapileshwar', 'Basahiya', 'Bindhi', ...
                     'Kurtha', 'Basbitti', 'Devpura Rupaitha', 'Mithileshwar Nikas', ...
                     'Lakhauri', 'Giddha', ...
                     'Mansingpatti', 'Debadiha', 'Tarapatti Sirsiya', 'Thadi Jhijha', ...
                     'Khajuri Chanha', 'Ekarahi'};
        m.busKV   = [33 11*ones(1, 18)];

        % Section lengths [ASSUMED], constrained to the year book total of
        % 69.851 km: 15 km Dog trunk, 34 km Rabbit branches,
        % 20.851 km Weasel spurs.
        m.line = [ ...
             2  3   2.5   DOG     1
             3  4   3.0   DOG     1
             4  5   3.0   DOG     1
             5  6   3.5   DOG     1
             6  7   3.0   DOG     1
             3  8   5.0   RABBIT  1
             4  9   6.0   RABBIT  1
             5 10   6.0   RABBIT  1
             6 11   5.5   RABBIT  1
             7 12   6.0   RABBIT  1
             7 13   5.5   RABBIT  1
             8 14   3.5   WEASEL  1
             9 15   4.0   WEASEL  1
            10 16   3.851 WEASEL  1
            11 17   3.0   WEASEL  1
            12 18   3.5   WEASEL  1
            13 19   3.0   WEASEL  1];

        % [from to MVA Zpct X/R tap] - 3 units in parallel, 8 % each on
        % own rating, OLTC boosting the 11 kV side by 5 % [ASSUMED].
        m.xfmr = [1 2 57.2 8.0 15 1.05];

        % Installed DT kVA per bus [ASSUMED]: load density falls with
        % distance from Janakpur town.
        m.dtKVA = [0 0, 1000 800 630 500 400, 630 630 500 500 400 400, ...
                   250 250 250 250 200 200];

        % The other nine Janakpur DC 11 kV feeders [YB names and peak A],
        % each as its own load on the Mujeliya 11 kV bus:
        % [bus  peakAmps  coincidenceFactor]. Coincidence [ASSUMED].
        m.fixedName = {'City-1', 'City-2', 'City-3', 'City-4', 'Dedicated', ...
                       'Industrial', 'Mahendranagar', 'Ring', 'Janaki'};
        amps = [288 252 334 293 174 152 175 198 231];
        m.fixedLoad = [2 * ones(9, 1), amps(:), 0.90 * ones(9, 1)];
        m.calBranch = 1;           % line 2-3 is the Pidari feeder head

        % Network behind the Mujeliya 33 kV bus, referred to 33 kV:
        % Dhalkebar 132 kV grid, Dhalkebar 132/33 kV 2 x 63 MVA [TD], and
        % the Mujeliya 33 kV line, HTLS Dog double circuit [YB]. The year
        % book's 45 km is the 33 kV feeder total; the Dhalkebar-Janakpur
        % route is taken as 25 km [ASSUMED].
        zLine = (C(DOG).r20 * (1 + 0.00403 * 55) + 1i * 0.38) * 25 / 2;
        m.src = struct('desc', {{'Dhalkebar 132 kV grid, 2000 MVA, X/R 10 [ASSUMED]', ...
                                 'Dhalkebar 132/33 kV 2 x 63 MVA [TD], 12.5 % each, X/R 30 [ASSUMED]', ...
                                 '33 kV HTLS Dog double circuit [YB], 25 km route at 75 degC [ASSUMED]'}}, ...
                       'Zohm', zsc(33, 2000, 10) + zsc(33, 126 / 0.125, 30) + zLine);

    otherwise
        error('nea_feeder_data:unknownModel', ...
              'Unknown model "%s". Use ''urban'' or ''rural''.', name);
end
m.src.MVAsc = m.busKV(1)^2 / abs(m.src.Zohm);
end

function z = zsc(kV, MVA, xr)
% Short-circuit impedance in ohm at kV for a fault level MVA with ratio X/R.
z = kV^2 / MVA * (1 + 1i * xr) / sqrt(1 + xr^2);
end

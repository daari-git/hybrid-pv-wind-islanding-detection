function C = operating_conditions()
% OPERATING_CONDITIONS  The sixteen operating conditions of the Phase 5 dataset.
%   Four grid strengths (SCR 20, 10, 5, 3) times four generation mixes:
%     full   1000 W/m2, 12 m/s   18.6 kW at the PCC
%     pv     1000 W/m2,  6 m/s   PV-dominated, 10.6 kW
%     wind    300 W/m2, 12 m/s   wind-dominated, 11.2 kW
%     low     500 W/m2,  8 m/s   6.8 kW
%   Each element has fields id, scr, mix, G, v and tEvent, the earliest event
%   time: 0.45 s, or 0.8 s at SCR 3, where the PV starts at 200 W/m2 and is
%   released at 0.3 s (a full-power start does not synchronise on a weak grid).
mixes = {'full', 1000, 12; 'pv', 1000, 6; 'wind', 300, 12; 'low', 500, 8};
C = struct('id', {}, 'scr', {}, 'mix', {}, 'G', {}, 'v', {}, 'tEvent', {});
for scr = [20 10 5 3]
    for k = 1:size(mixes, 1)
        C(end+1) = struct('id', sprintf('scr%g_%s', scr, mixes{k,1}), 'scr', scr, 'mix', mixes{k,1}, ...
            'G', mixes{k,2}, 'v', mixes{k,3}, 'tEvent', 0.45 + 0.35*(scr < 5)); %#ok<AGROW>
    end
end
end

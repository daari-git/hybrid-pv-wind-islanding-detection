function C = test_conditions()
% TEST_CONDITIONS  Phase 7: operating conditions the detector was never trained on.
%   Grid strengths and generation mixes between those of the dataset
%   (OPERATING_CONDITIONS):
%     scr15_t1   SCR 15, 800 W/m2, 10 m/s
%     scr7_t2    SCR 7,  600 W/m2, 11 m/s, with background grid distortion:
%                2% fifth (negative sequence) and 1.5% seventh harmonic
%     scr4_t3    SCR 4,  900 W/m2,  7 m/s (weak-grid start, as at SCR 3)
%   Fields as OPERATING_CONDITIONS, plus HARM (background harmonics on).
%   Events come at 0.6 s, or 1.0 s on the weak grid, so the detector, armed
%   0.25 s earlier, first watches steady operation.
C = struct('id', {'scr15_t1', 'scr7_t2', 'scr4_t3'}, 'scr', {15, 7, 4}, 'mix', {'t1', 't2', 't3'}, ...
    'G', {800, 600, 900}, 'v', {10, 11, 7}, 'tEvent', {0.6, 0.6, 1.0}, 'harm', {false, true, false});
end

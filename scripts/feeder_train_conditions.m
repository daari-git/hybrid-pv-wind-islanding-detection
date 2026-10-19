function C = feeder_train_conditions()
% FEEDER_TRAIN_CONDITIONS  Feeder conditions for training the detector (FEEDER_DATASET).
%   Four conditions that share no pole, loading and generation mix with the
%   test conditions of FEEDER_CONDITIONS, so those stay unseen; A3, a test
%   pole, is never used. The mixes are those of the Phase 5 dataset
%   (OPERATING_CONDITIONS):
%     ft1_a5_low    unit at A5, feeder at 20 % of its peak, 500 W/m2, 8 m/s
%     ft2_a4_pv     A4, 40 %, 1000 W/m2, 6 m/s
%     ft3_a2_full   A2, 30 %, 1000 W/m2, 12 m/s
%     ft4_a1_wind   A1, 70 %, 300 W/m2, 12 m/s
%   DER2P = NaN: FEEDER_OPERATING_POINTS sizes the other generation at B3 to
%   bring the feeder's generation to 1.3 times its consumption.
C = struct('id', {'ft1_a5_low', 'ft2_a4_pv', 'ft3_a2_full', 'ft4_a1_wind'}, 'load', {0.2, 0.4, 0.3, 0.7}, ...
    'pcc', {6, 5, 3, 2}, 'G', {500, 1000, 1000, 300}, 'v', {8, 6, 12, 12}, 'tEvent', {0.45, 0.45, 0.45, 0.45}, ...
    'harm', {false, false, false, false}, 'der2P', {NaN, NaN, NaN, NaN}, 'scr', {10, 10, 10, 10}, ...
    'mix', {'low', 'pv', 'full', 'wind'});
end

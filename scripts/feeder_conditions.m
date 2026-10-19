function C = feeder_conditions()
% FEEDER_CONDITIONS  Operating conditions on the Pidari 400 V feeder (FEEDER_PARAMS).
%   Three loadings inside the unit's operating window (FEEDER_SCREENING) and
%   the generation mixes of TEST_CONDITIONS, which the detector never saw:
%     f30_t1    unit at A5, feeder at 30 % of its recorded peak, 800 W/m2, 10 m/s
%     f50_t2    unit at A5, 50 %, 600 W/m2, 11 m/s, with background distortion
%               (2 % fifth, negative sequence, and 1.5 % seventh harmonic)
%     f60a3_t3  unit at A3, the best planned location, 60 %, 900 W/m2, 7 m/s
%   LOAD is the loading, PCC the unit's bus. At these mixes the unit makes
%   10-13 kW, less than the feeder draws, so an island of the whole feeder
%   can only be balanced with other generation on it: DER2P, the other
%   rooftop units lumped as the second inverter at B3, brings the feeder's
%   generation to about 1.25 times its consumption.
C = struct('id', {'f30_t1', 'f50_t2', 'f60a3_t3'}, 'load', {0.3, 0.5, 0.6}, 'pcc', {6, 6, 4}, ...
    'G', {800, 600, 900}, 'v', {10, 11, 7}, 'tEvent', {0.6, 0.6, 0.6}, 'harm', {false, true, false}, ...
    'der2P', {10e3, 22e3, 28e3}, 'scr', {10, 10, 10}, 'mix', {'t1', 't2', 't3'});
end

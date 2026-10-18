function [x, names] = window_features(D, ts, W, Wb, P)
% WINDOW_FEATURES  Features of one measurement window, relative to the window before it.
%   [X, NAMES] = WINDOW_FEATURES(D, TS, W, WB, P) uses the dataset case D
%   (see MAKE_DATASET). The window runs from TS to TS + W seconds after the
%   start of D's record; the baseline is the WB seconds before TS. Every
%   feature is a change from the baseline, so the operating point itself is
%   not a feature. All inputs are quantities an inverter measures at its own
%   terminals: PCC voltage, its own current, its PLL frequency, DC-link
%   voltage and its d/q currents. The voltage magnitude is computed from the
%   waveforms (Phase 7); the dataset's RMS voltage is not used. P supplies
%   the ratings (P.Sn, P.Ipk, P.Vpk).
%   The computation itself is ML_FEATURES, which the Simulink model runs too.
%
%   Fundamental components come from a least-squares fit of the voltage and
%   current space vectors to a positive- and a negative-sequence phasor at
%   the baseline frequency; what the fit leaves over is the distortion.
%   Zh_ratio compares the distortion impedance (residual voltage over
%   residual current) with the baseline's: when the grid is lost the PCC
%   impedance the inverter's ripple current sees rises from the grid's to
%   the load's, while ordinary events leave it nearly unchanged. df_max_n
%   and dV_max_n are scaled by the baseline's own fluctuation, so a noisier
%   weak grid does not look like an event.
names = {'dV_mean', 'dV_max', 'df_end', 'df_max', 'rocof_fit', 'rocof_peak', ...
         'phase_jump', 'dV_pos', 'dV_neg', 'dI_pos', 'dI_neg', 'dP', 'dQ', 'P_slope', ...
         'dTHD_v', 'dTHD_i', 'dVdc_max', 'dId_max', 'dIq_max', 'Zh_ratio', 'df_max_n', 'dV_max_n'};
fs = D.fs; fw = D.fsWave;
r  = (round((ts - Wb)*fs):round((ts + W)*fs)) + 1;    % 1 kHz signals: baseline and window
rw = (round((ts - Wb)*fw):round((ts + W)*fw)) + 1;    % 10 kHz waveforms
g = @(s) double(s(r));
x = ml_features(double(D.Vabc(rw,:)), double(D.Igrid(rw,:)), g(D.freq), g(D.VDC), ...
    g(D.ID), g(D.IQ), round(W*fs), round(W*fw), P.Vpk, P.Ipk, P.Sn, fs, fw);
end

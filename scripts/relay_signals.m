function [t, V, f, rocof] = relay_signals(S)
% RELAY_SIGNALS  The signals a relay sees, resampled at 1 ms from a logged run:
%   PCC voltage (pu RMS), frequency (Hz) and |rate of change of frequency|
%   (Hz/s, 1 ms derivative and 10 Hz low-pass, as in the model's protection).
%   Times before the start-up blanking (S.P.prot.tBlank) are left out.
Ts = 1e-3;
t  = (S.P.prot.tBlank:Ts:S.Vpcc_rms.Time(end))';
V  = interp1(S.Vpcc_rms.Time, double(S.Vpcc_rms.Data(:,1)), t);
f  = interp1(S.freq.Time, double(S.freq.Data(:,1)), t);
a  = exp(-Ts*2*pi*10);
rocof = abs(filter(1 - a, [1 -a], [0; diff(f)/Ts]));
end

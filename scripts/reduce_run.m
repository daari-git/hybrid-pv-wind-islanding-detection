function R = reduce_run(S, t1, t2)
% REDUCE_RUN  Keep a run's 1 ms signals for detector replay.
%   R = REDUCE_RUN(S, T1, T2) resamples PCC voltage, frequency, DC-link
%   voltage and the d/q currents at 1 ms, and stores grid-connected power
%   quality measured over [T1, T2] in R.pre.
t = (0:1e-3:S.Vpcc_rms.Time(end))';
R.P = S.P;
for n = {'Vpcc_rms', 'freq', 'VDC', 'ID', 'IQ'}
    x = S.(n{1});
    R.(n{1}) = timeseries(interp1(x.Time, double(x.Data(:,1)), t), t);
end
M = signal_metrics(S, t1, t2);
R.pre = struct('P', M.P, 'Q', M.Q, 'thd', M.thd, 'thdV', M.thdV);
end

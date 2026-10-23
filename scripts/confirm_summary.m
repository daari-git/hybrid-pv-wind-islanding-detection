function s = confirm_summary(R)
% CONFIRM_SUMMARY  The confirmations of one closed-loop run (step 9).
%   S = CONFIRM_SUMMARY(R), with R a run saved by CLOSED_LOOP_TEST or
%   FEEDER_CLOSED_LOOP, gives S.n, the number of q-current nudges; S.t, when
%   the first began (s after the event); and S.resp and S.raw, the PCC
%   voltage angle responses (rad) it measured, with and without the drift of
%   the two cycles before it removed. S.t, S.resp and S.raw are NaN without a
%   nudge (and for runs saved before step 9).
s = struct('n', 0, 't', NaN, 'resp', NaN, 'raw', NaN);
if ~isfield(R, 'ml_nudge'), return, end
x = R.ml_nudge.Data(:) ~= 0; t = R.ml_nudge.Time(:);
on = find(diff([0; x]) > 0); off = find(diff([x; 0]) < 0);
s.n = numel(on);
if s.n == 0, return, end
s.t = t(on(1)) - R.tEvent;
k = min(off(1) + 2, numel(t));                         % the response is set as the nudge ends
s.resp = R.ml_resp.Data(k); s.raw = R.ml_raw.Data(k);
end

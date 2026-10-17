function D = detect_islanding(S, relay, tIsland)
% DETECT_ISLANDING  Apply a set of voltage/frequency relay settings to a run.
%   D = DETECT_ISLANDING(S, RELAY, TISLAND) replays the logged PCC voltage
%   (pu, RMS) and measured frequency of run S through the relay settings
%   RELAY (for example P.relay.fast or P.relay.ieee) and returns:
%     D.trip    true if any element tripped after TISLAND
%     D.t       detection time after TISLAND (s), Inf if none
%     D.element which element tripped first ('uv1', 'of2', 'rocof', ...)
%     D.falseTrip  time of a trip before TISLAND (s), NaN if none
%   Each element trips once its condition has held for its clearing time.
%   Signals are resampled at 1 ms; ROCOF uses the same 1 ms derivative and
%   10 Hz low-pass as the model's protection. Only times after the start-up
%   blanking (S.P.prot.tBlank) count.
[t, V, f, rocof] = relay_signals(S);

el = {};
add = @(name, cond, tclr) struct('name', name, 'cond', cond, 'tclr', tclr);
for k = 1:size(relay.uv, 1), el{end+1} = add(sprintf('uv%d', k), V < relay.uv(k,1), relay.uv(k,2)); end %#ok<AGROW>
for k = 1:size(relay.ov, 1), el{end+1} = add(sprintf('ov%d', k), V > relay.ov(k,1), relay.ov(k,2)); end %#ok<AGROW>
for k = 1:size(relay.uf, 1), el{end+1} = add(sprintf('uf%d', k), f < relay.uf(k,1), relay.uf(k,2)); end %#ok<AGROW>
for k = 1:size(relay.of, 1), el{end+1} = add(sprintf('of%d', k), f > relay.of(k,1), relay.of(k,2)); end %#ok<AGROW>
if isfinite(relay.rocof(1)), el{end+1} = add('rocof', rocof > relay.rocof(1), relay.rocof(2)); end

D = struct('trip', false, 't', Inf, 'element', '', 'falseTrip', NaN);
for k = 1:numel(el)
    tt = first_sustained(t, el{k}.cond, el{k}.tclr);
    if isempty(tt), continue; end
    if tt < tIsland
        D.falseTrip = min([D.falseTrip, tt], [], 'omitnan');
    elseif tt - tIsland < D.t
        D.t = tt - tIsland; D.element = el{k}.name; D.trip = true;
    end
end
end

function tt = first_sustained(t, c, tclr)
% First time at which condition c has been true continuously for tclr seconds.
tt = [];
if ~any(c), return; end
d  = diff([false; c(:); false]);
on = find(d == 1); off = find(d == -1) - 1;
for k = 1:numel(on)
    if t(off(k)) - t(on(k)) >= tclr - 1e-9
        tt = t(on(k)) + tclr; return
    end
end
end

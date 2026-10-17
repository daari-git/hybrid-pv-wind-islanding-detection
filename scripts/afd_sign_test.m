% AFD_SIGN_TEST  Matched-load island with no drift and with drift of each sign.
P0 = params(10);
cases = {'no AFD', 0, 1; 'AFD +K', 1, 1; 'AFD -K', 1, -1};
for c = 1:3
    P = island_case(P0, 0, 0, 0.4);
    P.afd.on = cases{c,2};
    P.afd.K = cases{c,3}*abs(P.afd.K); P.afd.bias = cases{c,3}*abs(P.afd.bias);
    S = run_model(2.45, P, '');
    a = detect_islanding(S, P.relay.fast, P.tIsland);
    b = detect_islanding(S, P.relay.ieee, P.tIsland);
    ts = [0.39 0.5 0.75 1.0 1.5 2.0 2.4];
    fprintf('%-7s f: %s | V: %s\n', cases{c,1}, sprintf('%6.2f', interp1(S.freq.Time, S.freq.Data, ts)), ...
        sprintf('%5.2f', interp1(S.Vpcc_rms.Time, S.Vpcc_rms.Data, ts)));
    fprintf('        fast relay: %s %.3f s | IEEE relay: %s %.3f s\n', a.element, a.t, b.element, b.t);
end

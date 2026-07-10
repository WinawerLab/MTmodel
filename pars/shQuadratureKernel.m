% q = shQuadratureKernel(k)
%
% Return a 90-degree phase-shifted ("quadrature") version of a temporal kernel k,
% via the analytic-signal (Hilbert) FFT method. Used to give ON and OFF RGC
% channels a constant-phase temporal difference, which produces broadband
% direction selectivity when combined with an ON/OFF spatial offset (Chariker/
% Shapley Mechanism #2; see explore/prototypeOnOffDelayDS.m and
% docs/RGC_V1_unification_plan.md §2.7).
%
% NOTE: the exact Hilbert quadrature is acausal. Biology approximates a constant
% phase offset with a shaped *causal* kernel; this utility is a first-pass stand-
% in. The output is rescaled to match the peak magnitude of k.

function q = shQuadratureKernel(k)

    k = k(:);
    L = numel(k);
    N = 2 ^ nextpow2(4 * L);

    Kf = fft(k, N);
    h = zeros(N, 1);
    h(1) = 1;
    h(N / 2 + 1) = 1;
    h(2:N / 2) = 2;

    analytic = ifft(Kf .* h);
    q = imag(analytic(1:L));

    if max(abs(q)) > 0
        q = q ./ max(abs(q)) .* max(abs(k));
    end

end

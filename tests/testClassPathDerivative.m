% testClassPathDerivative  Verify the unified class-based V1 forward
% (shRgcClassesDerivative + shModelV1LinearFromClasses) reproduces the existing
% derivative path and legacy V1 to machine precision at nScales = 1.
%
% This is the guardrail for the pars.rgc.classes refactor
% (docs/RGC_V1_unification_plan.md): the derivative preset must stay exact.

rng(1);
pars = shPars();

parsCls = pars;
parsCls.rgc.classes = shRgcClassesDerivative(parsCls);
parsCls.rgc.combine = 'steer';

parsLeg = pars; parsLeg.rgc.enabled = 0;

dims = shGetDims(pars, 'mtPattern', [1 1 20]);
stims = { mkDots(dims, 0, 1.0, 0.12, 1.0), ...
          mkSin(dims, pi/4, 0.08, 0.10, 1.0) };

for i = 1:numel(stims)
    s = stims{i};

    popCls = shModelV1LinearFromClasses(s, parsCls);
    popDer = shModelV1Linear(s, pars);        % existing derivative dispatch
    popLeg = shModelV1Linear(s, parsLeg);     % legacy

    shAssert(all(isfinite(popCls(:))), 'class path: V1 output must be finite');
    shAssert(isequal(size(popCls), size(popDer)), 'class path: output size mismatch vs derivative path');

    eDer = max(abs(popCls(:) - popDer(:)));
    eLeg = max(abs(popCls(:) - popLeg(:)));
    shAssert(eDer < 1e-10, sprintf('class path vs derivative path too far: %.3e (stim %d)', eDer, i));
    shAssert(eLeg < 1e-10, sprintf('class path vs legacy too far: %.3e (stim %d)', eLeg, i));

    % 4th output (resdirs / additional neurons) must also match legacy exactly,
    % since shModel uses it for the v1lin stage with additional neurons.
    resdirs = [0.3 0.4; 1.2 0.25; 2.5 0.3];
    [~, ~, ~, resCls] = shModelV1Linear(s, pars, resdirs);      % now the class path
    [~, ~, ~, resLeg] = shModelV1Linear(s, parsLeg, resdirs);
    shAssert(max(abs(resCls(:) - resLeg(:))) < 1e-10, ...
        sprintf('class-path resdirs output must match legacy (stim %d)', i));
end

% 'steer' must reject a non-diagonal (non-10-column) class basis.
threw = false;
try
    badPars = parsCls;
    badPars.rgc.classes(1).readoutOrders = [0 1 2 3];   % now > 10 columns
    shModelV1LinearFromClasses(stims{1}, badPars);
catch
    threw = true;
end
shAssert(threw, 'steer combine must error on a non-diagonal class basis');

% verifyClassPathDerivative  Check the unified class-based forward reproduces the
% existing derivative path (and legacy) exactly, at nScales = 1.
%
% Increment 1 of the pars.rgc.classes refactor (docs/RGC_V1_unification_plan.md):
% shRgcClassesDerivative + shModelV1LinearFromClasses(...,'steer') should equal
% shModelV1LinearFromRgcDerivative to machine precision, and match legacy V1.

thisFile = mfilename('fullpath');
repoRoot = fileparts(fileparts(thisFile));
addpath(genpath(repoRoot));
rng(3);

pars = shPars;                                  % derivative mode, nScales=1
parsCls = pars;
parsCls.rgc.classes = shRgcClassesDerivative(parsCls);
parsCls.rgc.combine = 'steer';

parsLeg = pars; parsLeg.rgc.enabled = 0;        % legacy oracle

% test on several stimulus sizes / contents
dims = shGetDims(pars, 'mtPattern', [1 1 18]);
stims = { randn(dims), ...
          mkSin(dims, pi/4, 0.08, 0.10, 1), ...
          mkDots(dims, pi/3, 0.9, 0.12, 1) };

fprintf('%-22s | %-12s | %-12s\n','stimulus','vs derivPath','vs legacy');
for i = 1:numel(stims)
    s = stims{i};
    popCls = shModelV1LinearFromClasses(s, parsCls);
    popDer = shModelV1Linear(s, pars);          % existing derivative dispatch
    popLeg = shModelV1Linear(s, parsLeg);       % legacy
    eDer = max(abs(popCls(:) - popDer(:)));
    eLeg = max(abs(popCls(:) - popLeg(:)));
    fprintf('%-22s | %.3e   | %.3e\n', sprintf('stim %d %s',i,mat2str(dims)), eDer, eLeg);
end

fprintf(['\nExpectation: vs derivPath ~1e-16 (identical computation); ' ...
         'vs legacy ~1e-13 (derivative reconstruction).\n']);

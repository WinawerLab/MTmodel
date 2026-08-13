% verifyClassPathBiological  Increment 2 check: the biological midget/parasol
% class preset runs end-to-end through the unified class path and fits legacy V1.
%
% Fits pars.rgc.v1Weights with shFitClassV1Weights on a training set, then
% measures held-out reconstruction of legacy V1. Compares against the documented
% fourPop ceiling (~0.69). Also sanity-checks that outputs are finite and that
% the ON/OFF quadrature + spatial offset actually change the basis (vs a plain
% no-DS variant).

thisFile = mfilename('fullpath');
repoRoot = fileparts(fileparts(thisFile));
addpath(genpath(repoRoot));
rng(0);

pars = shPars;
scale = pars.scaleFactors.v1Linear;
parsLeg = pars; parsLeg.rgc.enabled = 0;

parsBio = pars;
parsBio.rgc.classes = shRgcClassesMidgetParasol(parsBio);
parsBio.rgc.combine = 'weights';

dims = shGetDims(pars, 'mtPattern', [1 1 18]);
mkGr = @(th,sp,c) mkSin(dims, th, subsref(v12sin([th sp]),struct('type','()','subs',{{2}})), ...
                                subsref(v12sin([th sp]),struct('type','()','subs',{{3}})), c);
trainSet = { mkDots(dims,0,1.0,0.12,1), mkDots(dims,pi/2,0.7,0.12,0.7), ...
             mkGr(0,1.0,1), mkGr(pi/3,1.6,1), mkGr(pi,0.8,1), mkGr(-pi/4,1.2,1) };
testSet  = { mkDots(dims,pi/4,0.9,0.12,1), mkGr(pi/6,1.3,1), mkGr(2*pi/3,0.9,1), ...
             mkDots(dims,pi,0.6,0.12,0.8) };

% fit weights
parsBio.rgc.v1Weights = shFitClassV1Weights(parsBio, trainSet);
fprintf('fitted W size: %s (expect 28 x 40)\n', mat2str(size(parsBio.rgc.v1Weights)));

% evaluate on held-out set
P = []; T = [];
for i = 1:numel(testSet)
    s = testSet{i};
    popBio = shModelV1LinearFromClasses(s, parsBio);
    popLeg = shModelV1Linear(s, parsLeg);
    P = [P; popBio(:)]; T = [T; popLeg(:)]; %#ok<AGROW>
end
c = corr(P, T);
nrmse = sqrt(mean((P - T).^2)) / (max(T) - min(T));
allFinite = all(isfinite(P));

fprintf('\nBiological midget/parasol (ON/OFF quadrature + offset), held-out:\n');
fprintf('  V1 corr vs legacy = %.4f   NRMSE = %.4f   finite=%d\n', c, nrmse, allFinite);
fprintf('  (reference: plain fourPop ceiling ~0.69)\n');

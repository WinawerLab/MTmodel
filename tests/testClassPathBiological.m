% testClassPathBiological  Guardrail for the biological midget/parasol preset on
% the unified class path (increment 2): the DoG + rectification + ON/OFF
% quadrature/offset machinery must run end-to-end, fit legacy V1 to a sensible
% level, and stay finite. See docs/RGC_V1_unification_plan.md.

rng(0);
pars = shPars;
parsLeg = pars; parsLeg.rgc.enabled = 0;

parsBio = pars;
parsBio.rgc.classes = shRgcClassesMidgetParasol(parsBio);
parsBio.rgc.combine = 'weights';

dims = shGetDims(pars, 'mtPattern', [1 1 18]);
% varied grating + dot training set (directions/SF/TF) so the 40-feature fit
% generalizes; too few/narrow stimuli make held-out correlation unstable.
p1 = v12sin([0 1.0]); p2 = v12sin([pi/3 1.6]); p3 = v12sin([pi 0.8]); p4 = v12sin([-pi/4 1.2]);
trainSet = { mkDots(dims,0,1.0,0.12,1), mkDots(dims,pi/2,0.7,0.12,0.7), ...
             mkSin(dims,0,p1(2),p1(3),1), mkSin(dims,pi/3,p2(2),p2(3),1), ...
             mkSin(dims,pi,p3(2),p3(3),1), mkSin(dims,-pi/4,p4(2),p4(3),1) };
pt1 = v12sin([pi/6 1.3]); pt2 = v12sin([2*pi/3 0.9]);
testSet  = { mkDots(dims,pi/4,0.9,0.12,1), mkSin(dims,pi/6,pt1(2),pt1(3),1), ...
             mkSin(dims,2*pi/3,pt2(2),pt2(3),1), mkDots(dims,pi,0.6,0.12,0.8) };

% combine='weights' must error before weights are fit
threw = false;
try
    shModelV1LinearFromClasses(trainSet{1}, parsBio);
catch
    threw = true;
end
shAssert(threw, 'biological class path must error when combine=weights but no v1Weights set');

% fit and evaluate
parsBio.rgc.v1Weights = shFitClassV1Weights(parsBio, trainSet);
shAssert(isequal(size(parsBio.rgc.v1Weights), [28 40]), 'fitted class weights must be 28x40');

P = []; T = [];
for i = 1:numel(testSet)
    s = testSet{i};
    popBio = shModelV1LinearFromClasses(s, parsBio);
    popLeg = shModelV1Linear(s, parsLeg);
    shAssert(all(isfinite(popBio(:))), 'biological class V1 output must be finite');
    P = [P; popBio(:)]; T = [T; popLeg(:)]; %#ok<AGROW>
end

c = corr(P, T);
shAssert(c > 0.6, sprintf('biological class path legacy-V1 correlation too low: %.3f', c));

% runAllTests  Run all MTmodel regression tests.
%
% Usage:
%   matlab -batch "run('tests/runAllTests.m')"
%
% Exits with 0 if all tests pass, 1 if any fail.

repoRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(genpath(repoRoot));
rng(1);

tests = {
    'testParsLoading',
    'testStimGeneration',
    'testV1Pipeline',
    'testMtPipeline',
    'testRgcPath',
    'testRgcVsLegacyCorr',
    'testRgcDerivativeVsLegacy',
    'testClassPathDerivative',
    'testClassPathBiological',
    'testV1Rf',
    'testGetNeuron',
    'testEdgeCases',
};

nPassed  = 0;
nFailed  = 0;
failures = {};

for i = 1:length(tests)
    name = tests{i};
    try
        run(name);
        fprintf('[PASS] %s\n', name);
        nPassed = nPassed + 1;
    catch ME
        fprintf('[FAIL] %s: %s\n', name, ME.message);
        nFailed  = nFailed + 1;
        failures{end+1} = name;
    end
end

fprintf('\n%d passed, %d failed\n', nPassed, nFailed);

if nFailed > 0
    fprintf('Failed tests:\n');
    for i = 1:length(failures)
        fprintf('  %s\n', failures{i});
    end
    exit(1);
end

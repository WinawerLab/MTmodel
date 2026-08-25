% testParsLoading  Verify shPars() returns a valid, complete parameter struct.

pars = shPars();

shAssert(isstruct(pars), 'shPars must return a struct');

% Required top-level fields
shAssert(isfield(pars, 'v1SpatialFilters'),           'v1SpatialFilters missing');
shAssert(isfield(pars, 'v1TemporalFilters'),           'v1TemporalFilters missing');
shAssert(isfield(pars, 'v1PopulationDirections'),      'v1PopulationDirections missing');
shAssert(isfield(pars, 'mtPopulationVelocities'),      'mtPopulationVelocities missing');
shAssert(isfield(pars, 'v1C50'),                       'v1C50 missing');
shAssert(isfield(pars, 'mtC50'),                       'mtC50 missing');
shAssert(isfield(pars, 'rgc'),                         'rgc missing');
shAssert(isfield(pars, 'scaleFactors'),                'scaleFactors missing');

% Scale factors must be finite and positive
shAssert(isfinite(pars.scaleFactors.v1Linear)  && pars.scaleFactors.v1Linear  > 0, 'v1Linear scale factor must be positive finite');
shAssert(isfinite(pars.scaleFactors.mtLinear)  && pars.scaleFactors.mtLinear  > 0, 'mtLinear scale factor must be positive finite');
shAssert(isfinite(pars.scaleFactors.mtPattern) && pars.scaleFactors.mtPattern > 0, 'mtPattern scale factor must be positive finite');

% RGC on by default, using the exact-reconstruction 'derivative' mode
shAssert(pars.rgc.enabled == 1, 'RGC must be enabled by default');
shAssert(strcmpi(pars.rgc.mode, 'derivative'), 'RGC mode must default to ''derivative''');
shAssert(isequal(pars.rgc.derivative.channelGain, ones(1, 4)), 'RGC derivative.channelGain must default to ones(1,4)');
shAssert(isempty(pars.rgc.v1Weights), 'RGC v1Weights must be unset by default (unused in ''derivative'' mode)');

% Population arrays have the right shape
shAssert(size(pars.v1PopulationDirections, 2) == 2, 'v1PopulationDirections must have 2 columns');
shAssert(size(pars.mtPopulationVelocities, 2) == 2, 'mtPopulationVelocities must have 2 columns');
shAssert(size(pars.v1PopulationDirections, 1) > 0,  'v1PopulationDirections must be non-empty');
shAssert(size(pars.mtPopulationVelocities, 1) > 0,  'mtPopulationVelocities must be non-empty');

% Filters are non-empty matrices
shAssert(~isempty(pars.v1SpatialFilters),  'v1SpatialFilters must be non-empty');
shAssert(~isempty(pars.v1TemporalFilters), 'v1TemporalFilters must be non-empty');

% Sanity-check key scalar params
shAssert(pars.v1C50 > 0 && pars.v1C50 < 1,  'v1C50 must be in (0,1)');
shAssert(pars.mtBaseline > 0,                'mtBaseline must be positive');
shAssert(pars.nScales == 1,                  'default nScales should be 1');

% ---------------------------------------------------------------------------
% THE TWO-PRESET CONTRACT. There are exactly two ways to run this model, and
% shPars must return each one fully assembled -- no hand-assembly by callers.
% If you are changing these assertions, re-read the shPars header first.

% shPars() and shPars('derivative') are the same thing.
shAssert(isequal(shPars(), shPars('derivative')), ...
    'shPars() must be identical to shPars(''derivative'')');

% The default preset is single-stream.
shAssert(~isfield(pars.rgc, 'mtMix') || isempty(pars.rgc.mtMix), ...
    'derivative preset must not set mtMix');
shAssert(numel(pars.rgc.classes) == 4, 'derivative preset must have 4 classes');

% The lagged preset arrives complete: custom dispatch, 16 classes, fitted
% stream-B weights, AND stream A switched on.
parsL = shPars('lagged');
shAssert(strcmpi(parsL.rgc.mode, 'custom'), ...
    'lagged preset must set rgc.mode = ''custom'' (else shModelV1Linear rebuilds the classes)');
shAssert(strcmpi(parsL.rgc.classesMode, 'custom'), 'lagged preset must set rgc.classesMode = ''custom''');
shAssert(strcmpi(parsL.rgc.combine, 'weights'),    'lagged preset must set rgc.combine = ''weights''');
shAssert(numel(parsL.rgc.classes) == 16, 'lagged preset must have 16 classes (ON/OFF x midget/parasol x lags 0-3)');

nFeat = numel(parsL.rgc.classes) * 10;
shAssert(isequal(size(parsL.rgc.v1Weights), [28 nFeat]), ...
    sprintf('lagged stream-B weights must be 28x%d', nFeat));

% Two streams by default, reading out of ONE basis: both matrices are 28xnFeat.
shAssert(isfield(parsL.rgc, 'mtMix') && ~isempty(parsL.rgc.mtMix), ...
    'lagged preset must switch on the two-stream MT (mtMix) by default');
shAssert(isequal(size(parsL.rgc.mtMix.weightsA), [28 nFeat]), ...
    sprintf('lagged stream-A weights must be 28x%d -- the basis is NOT doubled', nFeat));
shAssert(parsL.rgc.mtMix.alpha == 0.10, 'lagged preset must default to alpha = 0.10');
shAssert(parsL.rgc.mtMix.delay == 0,    'lagged preset must default to delay = 0');

% Stream A really is parasol-masked: its midget columns must be exactly zero.
isMidget   = contains({parsL.rgc.classes.name}, 'midget');
colClass   = repelem(1:numel(parsL.rgc.classes), 10);
midgetCols = ismember(colClass, find(isMidget));
shAssert(all(all(parsL.rgc.mtMix.weightsA(:, midgetCols) == 0)), ...
    'stream A must be parasol-masked (midget columns exactly zero)');
shAssert(any(any(parsL.rgc.v1Weights(:, midgetCols) ~= 0)), ...
    'stream B must carry midget drive (it is the mixed M+P read-out)');

% There is no third preset.
threw = false;
try, shPars('somethingElse'); catch, threw = true; end
shAssert(threw, 'shPars must reject any preset other than ''derivative''/''lagged''');

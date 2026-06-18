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

% RGC off by default
shAssert(pars.rgc.enabled == 0, 'RGC must be disabled by default');

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

% testRgcPath  Verify RGC preprocessing layer runs correctly.

rng(1);
pars = shPars();

% Use a small stimulus for the RGC-only tests (DoG filters are compact)
smallSz = [15 15 15];
stim = 0.5 * ones(smallSz);
stim(7, 7, 7) = 1.0;

% --- RGC disabled: shModelRgc passes through the raw stimulus ---
parsOff = pars; parsOff.rgc.enabled = 0;
out0 = shModelRgc(stim, parsOff);
shAssert(isnumeric(out0),                   'RGC off: output must be numeric');
shAssert(isequal(size(out0), smallSz),      'RGC off: output size must match input');
shAssertNear(out0, stim, 1e-12,             'RGC off: output must equal input');

% --- RGC enabled: four-population struct ---
parsOn = pars; parsOn.rgc.enabled = 1;
outRgc = shModelRgc(stim, parsOn);
shAssert(isstruct(outRgc),                  'RGC on: output must be a struct');
shAssert(isfield(outRgc, 'mode'),           'RGC on: mode field missing');
shAssert(isfield(outRgc, 'channels'),       'RGC on: channels field missing');
shAssert(isfield(outRgc, 'combined'),       'RGC on: combined field missing');

% Four base channels must be present
shAssert(isfield(outRgc.channels, 'onFast'),  'RGC on: onFast channel missing');
shAssert(isfield(outRgc.channels, 'offFast'), 'RGC on: offFast channel missing');
shAssert(isfield(outRgc.channels, 'onSlow'),  'RGC on: onSlow channel missing');
shAssert(isfield(outRgc.channels, 'offSlow'), 'RGC on: offSlow channel missing');

% Channels must have the right size and be finite
chNames = {'onFast', 'offFast', 'onSlow', 'offSlow'};
for i = 1:length(chNames)
    ch = outRgc.channels.(chNames{i});
    shAssert(isequal(size(ch), smallSz), sprintf('RGC on: %s has wrong size', chNames{i}));
    shAssert(all(isfinite(ch(:))),       sprintf('RGC on: %s has non-finite values', chNames{i}));
end
shAssert(all(isfinite(outRgc.combined(:))), 'RGC on: combined must be finite');

% --- Lagged channels appear when lag > 0 ---
parsLag = parsOn;
parsLag.rgc.temporal.fastLag = 2;
parsLag.rgc.temporal.slowLag = 2;
outLag = shModelRgc(stim, parsLag);
shAssert(isfield(outLag.channels, 'onFastLag'),  'lagged RGC: onFastLag missing');
shAssert(isfield(outLag.channels, 'offFastLag'), 'lagged RGC: offFastLag missing');
shAssert(isfield(outLag.channels, 'onSlowLag'),  'lagged RGC: onSlowLag missing');
shAssert(isfield(outLag.channels, 'offSlowLag'), 'lagged RGC: offSlowLag missing');

% --- Full V1 run with RGC enabled completes without error ---
dims = shGetDims(pars, 'v1Complex', [1 1 1]);
stimFull = mkDots(dims, 0, 1.0, 0.12, 1.0);
[popRgc, indRgc] = shModel(stimFull, parsOn, 'v1Complex');
shAssert(~isempty(popRgc),           'V1 run with RGC: pop must be non-empty');
shAssert(all(isfinite(popRgc(:))),   'V1 run with RGC: pop must be finite');

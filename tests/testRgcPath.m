% testRgcPath  Verify RGC preprocessing layer runs correctly (both modes).

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

% --- RGC enabled, default mode ('derivative'): 4-channel struct ---
parsOn = pars; parsOn.rgc.enabled = 1;
outRgc = shModelRgc(stim, parsOn);
shAssert(isstruct(outRgc),                  'RGC on (derivative): output must be a struct');
shAssert(isfield(outRgc, 'mode'),           'RGC on (derivative): mode field missing');
shAssert(strcmpi(outRgc.mode, 'derivative'), 'RGC on: default mode must be ''derivative''');
shAssert(isfield(outRgc, 'channels'),       'RGC on (derivative): channels field missing');

derivChNames = {'order0', 'order1', 'order2', 'order3'};
for i = 1:length(derivChNames)
    ch = outRgc.channels.(derivChNames{i});
    shAssert(isequal(size(ch), smallSz), sprintf('RGC on (derivative): %s has wrong size', derivChNames{i}));
    shAssert(all(isfinite(ch(:))),       sprintf('RGC on (derivative): %s has non-finite values', derivChNames{i}));
end

% --- channelGain lesioning hook: zeroing a channel changes it, leaves others alone ---
parsLesion = parsOn;
parsLesion.rgc.derivative.channelGain = [0 1 1 1];
outLesion = shModelRgc(stim, parsLesion);
shAssert(all(outLesion.channels.order0(:) == 0), 'channelGain lesion: order0 must be silenced');
shAssertNear(outLesion.channels.order1, outRgc.channels.order1, 1e-12, ...
    'channelGain lesion: unlesioned channels must be unaffected');

% --- Full V1 run with RGC enabled (default derivative mode) completes without error ---
dims = shGetDims(pars, 'v1Complex', [1 1 1]);
stimFull = mkDots(dims, 0, 1.0, 0.12, 1.0);
[popRgc, indRgc] = shModel(stimFull, parsOn, 'v1Complex');
shAssert(~isempty(popRgc),           'V1 run with RGC: pop must be non-empty');
shAssert(all(isfinite(popRgc(:))),   'V1 run with RGC: pop must be finite');

% --- RGC enabled, 'fourPop' mode: biological four-population struct ---
parsFourPop = pars; parsFourPop.rgc.enabled = 1; parsFourPop.rgc.mode = 'fourPop';
parsFourPop.rgc.v1Weights = [];
outFourPop = shModelRgc(stim, parsFourPop);
shAssert(isstruct(outFourPop),                  'RGC on (fourPop): output must be a struct');
shAssert(strcmpi(outFourPop.mode, 'fourPop'),   'RGC on (fourPop): mode field wrong');
shAssert(isfield(outFourPop, 'channels'),       'RGC on (fourPop): channels field missing');
shAssert(isfield(outFourPop, 'combined'),       'RGC on (fourPop): combined field missing');

% Four base channels must be present
fourPopChNames = {'onFast', 'offFast', 'onSlow', 'offSlow'};
for i = 1:length(fourPopChNames)
    ch = outFourPop.channels.(fourPopChNames{i});
    shAssert(isequal(size(ch), smallSz), sprintf('RGC on (fourPop): %s has wrong size', fourPopChNames{i}));
    shAssert(all(isfinite(ch(:))),       sprintf('RGC on (fourPop): %s has non-finite values', fourPopChNames{i}));
end
shAssert(all(isfinite(outFourPop.combined(:))), 'RGC on (fourPop): combined must be finite');

% --- Lagged channels appear when lag > 0 ---
parsLag = parsFourPop;
parsLag.rgc.temporal.fastLag = 2;
parsLag.rgc.temporal.slowLag = 2;
outLag = shModelRgc(stim, parsLag);
shAssert(isfield(outLag.channels, 'onFastLag'),  'lagged RGC: onFastLag missing');
shAssert(isfield(outLag.channels, 'offFastLag'), 'lagged RGC: offFastLag missing');
shAssert(isfield(outLag.channels, 'onSlowLag'),  'lagged RGC: onSlowLag missing');
shAssert(isfield(outLag.channels, 'offSlowLag'), 'lagged RGC: offSlowLag missing');

% --- Full V1 run with RGC enabled (fourPop mode) completes without error ---
parsFourPopFit = parsFourPop;
parsFourPopFit.rgc.v1Weights = shFitRgcV1Weights(parsFourPopFit, {stimFull});
[popFourPop, indFourPop] = shModel(stimFull, parsFourPopFit, 'v1Complex');
shAssert(~isempty(popFourPop),           'V1 run with RGC (fourPop): pop must be non-empty');
shAssert(all(isfinite(popFourPop(:))),   'V1 run with RGC (fourPop): pop must be finite');

% testRgcPath  Verify the RGC preprocessing layer runs correctly.
%
% Covers the 'derivative' front-end, which is the only one shModelRgc
% inspects; class-based presets are covered by testClassPathBiological.

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

function pars = lesionApply(parsBase, lesionName, varargin)
% lesionApply  Apply a named lesion to a pars struct (fixed weights, no refit).
%
%   pars = lesionApply(parsBase, 'amplitude_uniform');
%   pars = lesionApply(parsBase, 'amplitude_delay_uniform');  % gain AND delay, independent
%   pars = lesionApply(parsBase, 'hf_lowpass');   % exponential (τ = 2 default)
%   pars = lesionApply(parsBase, 'hf_highcut');   % passband-unity Butterworth
%   pars = lesionApply(parsBase, 'delay_random', 'fieldSize', 128);
%   pars = lesionApply(parsBase, 'amplitude_uniform_map', 'stimSize', [Y X]);
%
% Lesion names match lesionCatalog entries and docs/MODEL_AND_LESIONS.md §4.7.
% Parameters come from lesionPars() unless overridden:
%   pars = lesionApply(parsBase, 'amplitude_uniform', 'uniformGain', 0.3);
%
% See also: lesionPars, lesionCatalog, lesionCropToStim.

cfg = lesionPars();
[cfg, extra] = localSplitCfgOverrides(cfg, varargin);
localRequireClasses(parsBase);

switch lower(strrep(lesionName, '-', '_'))
    case {'healthy', 'none', ''}
        pars = parsBase;

    case 'amplitude_uniform'
        pars = localClassGainAll(parsBase, cfg.uniformGain);

    case 'delay_uniform'
        pars = localClassDelayAll(parsBase, cfg.uniformDelayFrames);

    case {'amplitude_delay_uniform', 'uniform_amp_delay'}
        % Independent uniform axes, not `coupled` (which ties maps).
        pars = localClassGainAll(parsBase, cfg.uniformGain);
        pars = localClassDelayAll(pars, cfg.uniformDelayFrames);
        pars.rgc.mode = 'custom';
        pars.rgc.classesMode = 'custom';

    case 'amplitude_parasol'
        pars = localClassGainName(parsBase, 'parasol', cfg.cellTypeGain);

    case 'amplitude_midget'
        pars = localClassGainName(parsBase, 'midget', cfg.cellTypeGain);

    case {'delay_on_only', 'delay_ononly'}
        pars = localClassDelayRectify(parsBase, 'on', cfg.onDelayFrames);

    case {'hf_lowpass', 'high_frequency_failure'}
        pars = localHfLowpass(parsBase, cfg);

    case {'hf_highcut', 'hf_passband'}
        pars = localHfHighcut(parsBase, cfg);

    case 'amplitude_uniform_map'
        stimSz = localGetStimSize(extra);
        pars = parsBase;
        pars.rgc.impairmentEnabled = 1;
        pars.rgc.impairmentAmplitudeMap = cfg.uniformGain * ones(stimSz(1), stimSz(2));

    case 'amplitude_random'
        fieldSize = localGetFieldSize(extra, cfg);
        pars = localAmplitudeRandom(parsBase, cfg, fieldSize);

    case 'delay_random'
        fieldSize = localGetFieldSize(extra, cfg);
        pars = localDelayRandom(parsBase, cfg, fieldSize);

    case 'amplitude_patchy'
        fieldSize = localGetFieldSize(extra, cfg);
        pars = localAmplitudePatchy(parsBase, cfg, fieldSize);

    case 'delay_patchy'
        fieldSize = localGetFieldSize(extra, cfg);
        pars = localDelayPatchy(parsBase, cfg, fieldSize);

    case 'coupled'
        fieldSize = localGetFieldSize(extra, cfg);
        pars = localCoupled(parsBase, cfg, fieldSize);

    otherwise
        error('lesionApply:unknownLesion', ...
            'Unknown lesion ''%s''. See help lesionCatalog.', lesionName);
end
end

function [cfg, extra] = localSplitCfgOverrides(cfg, args)
extra = {};
if isempty(args), return; end
if mod(numel(args), 2) ~= 0
    error('lesionApply:badArgs', 'Optional args must be name/value pairs.');
end
known = fieldnames(cfg);
for i = 1:2:numel(args)
    key = args{i};
    if ismember(key, known)
        cfg.(key) = args{i + 1};
    else
        extra(end+1:end+2) = {key, args{i + 1}}; %#ok<AGROW>
    end
end
end

function localRequireClasses(pars)
if ~isfield(pars, 'rgc') || ~isfield(pars.rgc, 'classes') || isempty(pars.rgc.classes)
    error('lesionApply:noClasses', ...
        'pars.rgc.classes must be set (use shPars or motionLetterModelPars first).');
end
end

function fieldSize = localGetFieldSize(extra, cfg)
fieldSize = cfg.defaultFieldSize;
for i = 1:2:numel(extra)
    if strcmp(extra{i}, 'fieldSize')
        fieldSize = extra{i + 1};
    end
end
if numel(fieldSize) ~= 1 || fieldSize < 1
    error('lesionApply:badFieldSize', 'fieldSize must be a positive scalar.');
end
end

function stimSz = localGetStimSize(extra)
stimSz = [];
for i = 1:2:numel(extra)
    if strcmp(extra{i}, 'stimSize')
        stimSz = extra{i + 1};
    end
end
if isempty(stimSz) || numel(stimSz) < 2
    error('lesionApply:needStimSize', ...
        'Lesion ''amplitude_uniform_map'' requires ''stimSize'', [Y X].');
end
stimSz = stimSz(1:2);
end

function pars = localClassGainAll(parsBase, gain)
pars = parsBase;
for i = 1:numel(pars.rgc.classes)
    pars.rgc.classes(i).gain = gain;
end
end

function pars = localClassGainName(parsBase, token, gain)
pars = parsBase;
for i = 1:numel(pars.rgc.classes)
    if contains(pars.rgc.classes(i).name, token, 'IgnoreCase', true)
        pars.rgc.classes(i).gain = gain;
    end
end
end

function pars = localClassDelayAll(parsBase, delayFrames)
pars = parsBase;
for i = 1:numel(pars.rgc.classes)
    k = pars.rgc.classes(i).temporalKernel;
    pars.rgc.classes(i).temporalKernel = [zeros(delayFrames, 1); k(:)];
end
end

function pars = localHfLowpass(parsBase, cfg)
% Causal exponential low-pass on every class kernel. Not a gain and not a
% whole-frame shift. hfRenorm = true keeps L1(k) so the lesion is shape only.
if ~isscalar(cfg.hfTauFrames) || ~(cfg.hfTauFrames > 0) || ~isfinite(cfg.hfTauFrames)
    error('lesionApply:hfTau', 'hfTauFrames must be a positive scalar.');
end
tau = cfg.hfTauFrames;
L = max(8, 2 * ceil(6 * tau) + 1);
t = (0:L-1)';
h = exp(-t / tau);
h = h / sum(h);

pars = parsBase;
for i = 1:numel(pars.rgc.classes)
    k0 = pars.rgc.classes(i).temporalKernel(:);
    k1 = conv(k0, h);
    if cfg.hfRenorm
        s0 = sum(abs(k0));
        s1 = sum(abs(k1));
        if s1 > 0
            k1 = k1 * (s0 / s1);
        end
    end
    pars.rgc.classes(i).temporalKernel = k1;
end
pars.rgc.mode = 'custom';
pars.rgc.classesMode = 'custom';
end

function pars = localHfHighcut(parsBase, cfg)
% Frequency-domain low-pass on every class kernel: H(0) = 1, no L1 renorm.
% Not the causal exponential (`hf_lowpass`). Butterworth |H(f)|^2 prototype,
% real even H so the kernel stays real. Cuts above hfCutCycPerFrame.
fc = cfg.hfCutCycPerFrame;
ord = cfg.hfCutOrder;
if ~isscalar(fc) || ~(fc > 0) || ~(fc < 0.5) || ~isfinite(fc)
    error('lesionApply:hfCut', 'hfCutCycPerFrame must be in (0, 0.5) cyc/frame.');
end
if ~isscalar(ord) || ~(ord >= 1) || ~isfinite(ord)
    error('lesionApply:hfCutOrder', 'hfCutOrder must be a positive scalar.');
end

pars = parsBase;
for i = 1:numel(pars.rgc.classes)
    k0 = pars.rgc.classes(i).temporalKernel(:);
    n = numel(k0);
    nfft = 2^nextpow2(max(256, 8 * n));
    K = fft(k0, nfft);
    f = (0:nfft-1)' / nfft;
    fNy = min(f, 1 - f);
    H = 1 ./ (1 + (fNy / fc).^(2 * ord));
    H(1) = 1;
    kPad = real(ifft(K .* H));
    pars.rgc.classes(i).temporalKernel = kPad(1:n);
end
pars.rgc.mode = 'custom';
pars.rgc.classesMode = 'custom';
end

function pars = localClassDelayRectify(parsBase, token, delayFrames)
pars = parsBase;
for i = 1:numel(pars.rgc.classes)
    if contains(pars.rgc.classes(i).rectify, token, 'IgnoreCase', true)
        k = pars.rgc.classes(i).temporalKernel;
        pars.rgc.classes(i).temporalKernel = [zeros(delayFrames, 1); k(:)];
    end
end
end

function pars = localAmplitudeRandom(parsBase, cfg, fieldSize)
pars = parsBase;
rng(cfg.stochasticAmpSeed);
pars.rgc.impairmentEnabled = 1;
lo = cfg.stochasticAmpRange(1);
hi = cfg.stochasticAmpRange(2);
pars.rgc.impairmentAmplitudeFieldFull = lo + (hi - lo) * rand(fieldSize, fieldSize);
end

function pars = localDelayRandom(parsBase, cfg, fieldSize)
pars = parsBase;
rng(cfg.stochasticDelaySeed);
pars.rgc.impairmentEnabled = 1;
d = cfg.stochasticDelayFrames;
pars.rgc.impairmentDelayFieldFull = randi(d, fieldSize, fieldSize);
end

function pars = localAmplitudePatchy(parsBase, cfg, fieldSize)
pars = parsBase;
rng(cfg.patchySeed);
rawMap = rand(fieldSize, fieldSize);
smoothMap = imgaussfilt(rawMap, cfg.patchySigma);
smoothMap = (smoothMap - min(smoothMap(:))) / max(eps, max(smoothMap(:)) - min(smoothMap(:)));
lo = cfg.patchyAmpRange(1);
hi = cfg.patchyAmpRange(2);
pars.rgc.impairmentEnabled = 1;
pars.rgc.impairmentAmplitudeFieldFull = lo + (hi - lo) * smoothMap;
end

function pars = localDelayPatchy(parsBase, cfg, fieldSize)
pars = parsBase;
rng(cfg.patchySeed + 1);
rawMap = rand(fieldSize, fieldSize);
smoothMap = imgaussfilt(rawMap, cfg.patchySigma);
delayField = zeros(fieldSize, fieldSize);
for i = 1:numel(cfg.patchyDelayThresholds)
    delayField(smoothMap > cfg.patchyDelayThresholds(i)) = i;
end
pars.rgc.impairmentEnabled = 1;
pars.rgc.impairmentDelayFieldFull = delayField;
end

function pars = localCoupled(parsBase, cfg, fieldSize)
pars = parsBase;
rng(cfg.coupledSeed);
rawMap = rand(fieldSize, fieldSize);
smoothMap = imgaussfilt(rawMap, cfg.patchySigma);
smoothMap = (smoothMap - min(smoothMap(:))) / max(eps, max(smoothMap(:)) - min(smoothMap(:)));
lo = cfg.coupledAmpRange(1);
hi = cfg.coupledAmpRange(2);
amplitudeField = lo + (hi - lo) * smoothMap;
delayField = zeros(fieldSize, fieldSize);
delayField(amplitudeField < 0.4) = 3;
delayField(amplitudeField >= 0.4 & amplitudeField < 0.5) = 2;
delayField(amplitudeField >= 0.5 & amplitudeField < 0.6) = 1;
pars.rgc.impairmentEnabled = 1;
pars.rgc.impairmentAmplitudeFieldFull = amplitudeField;
pars.rgc.impairmentDelayFieldFull = delayField;
end

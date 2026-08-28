function pars = lesionApply(parsBase, lesionName, varargin)
% lesionApply  Apply a named lesion to a pars struct (fixed weights, no refit).
%
%   pars = lesionApply(parsBase, 'amplitude_uniform');
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

    case 'amplitude_parasol'
        pars = localClassGainName(parsBase, 'parasol', cfg.cellTypeGain);

    case 'amplitude_midget'
        pars = localClassGainName(parsBase, 'midget', cfg.cellTypeGain);

    case {'delay_on_only', 'delay_ononly'}
        pars = localClassDelayRectify(parsBase, 'on', cfg.onDelayFrames);

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

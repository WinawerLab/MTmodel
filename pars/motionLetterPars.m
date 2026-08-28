function [cfg, pars, stimSz, stimArgs] = motionLetterPars(varargin)
% motionLetterPars  Single source of truth for motion-letter experiments.
%
% Edit the DEFAULTS block below to change dot size, speed, letter size, model
% preset, etc. Explore and classifier scripts call this function instead of
% duplicating mkMotionLetter arguments.
%
% Usage:
%   [cfg, pars, stimSz, stimArgs] = motionLetterPars();
%   [stim, info] = mkMotionLetter(stimSz, cfg.letter, stimArgs{:});
%
% One-off overrides (do not edit defaults for a single run):
%   [...] = motionLetterPars('letter', 'V', 'speedDegS', 1, 'dotSize', 3);
%
% Outputs
%   cfg      struct of all settings (after overrides)
%   pars     motionLetterModelPars(cfg) — ready for shModel
%   stimSz   [Y X T] input size from shGetDims (includes RF padding)
%   stimArgs cell array of name/value pairs for mkMotionLetter
%
% Model-only (same stimulus, two RGC presets):
%   pars = motionLetterModelPars('derivative');
%
% See also: mkMotionLetter, motionLetterModelPars, shModelUnits, shPars.

%% ======================== DEFAULTS (edit here) =============================
cfg = struct( ...
    'letter',              'C', ...
    'speedDegS',           5, ...          % 1 px/frame (MT slow unit); clinical band 0.19–3
    'seed',                1, ...
    'outSz',               [128 128 120], ... % desired model *output* [Y X T]
    'modelStage',          'mtPattern', ...  % shGetDims stage
    'rgcPreset',           'lagged', ...     % 'derivative' | 'lagged'
    'mtMix',               true, ...         % two-stream MT (lagged only)
    'dotSize',             3, ...            % nominal dot diameter (px at model scale)
    'dotContrast',         1.0, ...
    'dotShape',            'square', ...     % 'square' | 'disk'
    'fCovered',            0.3, ...
    'drawBackgroundDots',  true, ...
    'fontName',            'Sloan', ...
    'letterSizeFraction',  0.62, ...         % letter height = fraction of min(stim field)
    'letterSizePx',        [] ...            % [] = use letterSizeFraction
);
%% ==========================================================================

cfg = localApplyOverrides(cfg, varargin);

pars = motionLetterModelPars(cfg.rgcPreset, cfg.mtMix);
stimSz = shGetDims(pars, cfg.modelStage, cfg.outSz);
letterPx = localLetterPx(cfg, stimSz);
stimArgs = localStimArgs(cfg, letterPx);

cfg.stimSz = stimSz;
cfg.letterPx = letterPx;
cfg.units = shModelUnits();

end

function cfg = localApplyOverrides(cfg, args)
if isempty(args), return; end
if mod(numel(args), 2) ~= 0
    error('motionLetterPars:badArgs', ...
        'Overrides must be name/value pairs, e.g. motionLetterPars(''letter'', ''V'').');
end
for i = 1:2:numel(args)
    key = args{i};
    if ~isfield(cfg, key)
        error('motionLetterPars:unknownField', ...
            'Unknown override ''%s''. Valid fields: %s.', key, strjoin(fieldnames(cfg), ', '));
    end
    cfg.(key) = args{i + 1};
end
end

function letterPx = localLetterPx(cfg, stimSz)
if ~isempty(cfg.letterSizePx)
    letterPx = round(cfg.letterSizePx);
else
    letterPx = round(cfg.letterSizeFraction * min(stimSz(1:2)));
end
end

function args = localStimArgs(cfg, letterPx)
u = shModelUnits();
args = { ...
    'referenceDisplaySize', [], ...
    'ppd', u.pixelsPerDegree, ...
    'frameRate', u.framesPerSecond, ...
    'dotSpeedDegS', cfg.speedDegS, ...
    'letterSizePx', letterPx, ...
    'dotSize', cfg.dotSize, ...
    'dotContrast', cfg.dotContrast, ...
    'drawBackgroundDots', cfg.drawBackgroundDots, ...
    'fCovered', cfg.fCovered, ...
    'dotShape', cfg.dotShape, ...
    'fontName', cfg.fontName, ...
    'seed', cfg.seed ...
};
end

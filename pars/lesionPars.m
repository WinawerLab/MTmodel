function cfg = lesionPars(varargin)
% lesionPars  Single source of truth for optic-neuritis lesion parameters.
%
% Edit the DEFAULTS block below. Apply lesions with:
%   pars = lesionApply(parsBase, 'amplitude_uniform');
%   pars = lesionApply(parsBase, 'delay_random', 'fieldSize', 128);
%
% Build a condition list for a script:
%   lesions = lesionCatalog('motionLetterPhase2', 'fieldSize', fieldSize);
%
% Crop a full-field stochastic map to the stimulus:
%   pars = lesionCropToStim(pars, stimY, stimX);
%
% See also: lesionApply, lesionCatalog, lesionCropToStim, lesionCropForCall,
%           docs/MODEL_AND_LESIONS.md §4.7.

%% ======================== DEFAULTS (edit here) =============================
cfg = struct( ...
    ... % --- Phase 2 class-level (uniform) ---
    'uniformGain',           0.5, ...   % remaining gain, all classes
    'uniformDelayFrames',    2, ...     % prepend to every temporal kernel
    ... % --- Phase 2 cell-type selective ---
    'cellTypeGain',          0.3, ...   % remaining gain on affected classes (70% cut)
    'onDelayFrames',         1, ...     % ON half-wave classes only
    ... % --- Phase 2b stochastic (spatial maps) ---
    'stochasticAmpSeed',     42, ...
    'stochasticAmpRange',    [0.3 0.7], ...
    'stochasticDelaySeed',   43, ...
    'stochasticDelayFrames', [0 3], ...  % integer range, inclusive
    'patchySeed',            44, ...
    'patchySigma',           3.0, ...   % px, Gaussian smoothing for correlated maps
    'patchyAmpRange',        [0.3 0.7], ...
    'patchyDelayThresholds', [0.25 0.5 0.75], ... % quantiles -> delays 1,2,3
    'coupledSeed',           46, ...
    'coupledAmpRange',       [0.3 0.7], ...
    ... % --- Fig 9-14 stochastic script default field (max panel size) ---
    'defaultFieldSize',      51 ...
);
%% ==========================================================================

cfg = localApplyOverrides(cfg, varargin);
end

function cfg = localApplyOverrides(cfg, args)
if isempty(args), return; end
if mod(numel(args), 2) ~= 0
    error('lesionPars:badArgs', 'Overrides must be name/value pairs.');
end
for i = 1:2:numel(args)
    key = args{i};
    if ~isfield(cfg, key)
        error('lesionPars:unknownField', ...
            'Unknown override ''%s''. Valid: %s.', key, strjoin(fieldnames(cfg), ', '));
    end
    cfg.(key) = args{i + 1};
end
end

function lesions = lesionCatalog(setName, varargin)
% lesionCatalog  Named lesion lists for explore scripts.
%
%   lesions = lesionCatalog('motionLetterPhase2', 'fieldSize', 128);
%   lesions = lesionCatalog('phase2Uniform');
%   lesions = lesionCatalog('phase2Biological');
%   lesions = lesionCatalog('phase2b', 'fieldSize', 51);
%   lesions = lesionCatalog('compareAmplitude');
%
% Each element has: name, shortLabel, description, applyFn.
% applyFn(parsBase) returns lesioned pars (call lesionCropToStim before shModel
% when using spatial maps on motion-letter stimuli).

cfg = lesionPars(varargin{:});
extra = varargin;
fieldSize = cfg.defaultFieldSize;
for i = 1:2:numel(extra)
    if strcmp(extra{i}, 'fieldSize')
        fieldSize = extra{i + 1};
    end
end

switch lower(strrep(setName, '-', '_'))
    case {'motionletterphase2', 'motion_letter_phase2', 'phase2_motionletter'}
        lesions = localMotionLetterPhase2(cfg, fieldSize);

    case {'phase2uniform', 'phase2_uniform', 'universal'}
        lesions = localPhase2Uniform(cfg);

    case {'phase2biological', 'phase2_biological', 'biological'}
        lesions = localPhase2Biological(cfg);

    case {'phase2full', 'phase2_full'}
        lesions = [localPhase2Uniform(cfg), localPhase2Biological(cfg)];

    case {'phase2b', 'stochastic', 'phase2_stochastic'}
        lesions = localPhase2b(cfg, fieldSize);

    case {'compareamplitude', 'compare_amplitude'}
        lesions = localCompareAmplitude(cfg);

    otherwise
        error('lesionCatalog:unknownSet', ...
            'Unknown set ''%s''. Valid: motionLetterPhase2, phase2Uniform, phase2Biological, phase2b, compareAmplitude.', ...
            setName);
end

for i = 1:numel(lesions)
    lesions(i).applyFn = localMakeApplyFn(lesions(i).lesionId, cfg, fieldSize);
    lesions(i) = rmfield(lesions(i), 'lesionId');
end
end

function fn = localMakeApplyFn(lesionId, cfg, fieldSize)
if isempty(lesionId)
    fn = @(p) p;
    return;
end
cfgArgs = localCfgToNameValue(cfg);
spatialLesions = {'delay_random', 'amplitude_random', 'amplitude_patchy', ...
    'delay_patchy', 'coupled'};
if any(strcmp(lesionId, spatialLesions))
    fn = @(p) lesionApply(p, lesionId, cfgArgs{:}, 'fieldSize', fieldSize);
else
    fn = @(p) lesionApply(p, lesionId, cfgArgs{:});
end
end

function args = localCfgToNameValue(cfg)
f = fieldnames(cfg);
args = cell(1, 2 * numel(f));
for i = 1:numel(f)
    args{2*i - 1} = f{i};
    args{2*i} = cfg.(f{i});
end
end

function lesions = localMotionLetterPhase2(cfg, fieldSize)
lesions = [
    struct('name', 'healthy', 'shortLabel', 'Healthy', ...
        'description', 'Healthy baseline (no lesion)', 'lesionId', '')
    struct('name', 'amplitude_uniform', 'shortLabel', 'Amp uniform', ...
        'description', sprintf('All classes, gain %.2f (%.0f%% amplitude reduction)', ...
        cfg.uniformGain, 100*(1-cfg.uniformGain)), 'lesionId', 'amplitude_uniform')
    struct('name', 'delay_uniform', 'shortLabel', 'Delay uniform', ...
        'description', sprintf('All classes, +%d frame conduction delay', ...
        cfg.uniformDelayFrames), 'lesionId', 'delay_uniform')
    struct('name', 'amplitude_parasol', 'shortLabel', 'Amp parasol', ...
        'description', sprintf('Parasol only, gain %.1f (%.0f%% reduction; midgets spared)', ...
        cfg.cellTypeGain, 100*(1-cfg.cellTypeGain)), 'lesionId', 'amplitude_parasol')
    struct('name', 'amplitude_midget', 'shortLabel', 'Amp midget', ...
        'description', sprintf('Midget only, gain %.1f (%.0f%% reduction; parasols spared)', ...
        cfg.cellTypeGain, 100*(1-cfg.cellTypeGain)), 'lesionId', 'amplitude_midget')
    struct('name', 'delay_ON_only', 'shortLabel', 'Delay ON', ...
        'description', sprintf('ON pathway only, +%d frame delay (OFF spared)', ...
        cfg.onDelayFrames), 'lesionId', 'delay_ON_only')
    struct('name', 'delay_random', 'shortLabel', 'Delay random', ...
        'description', sprintf('Stochastic spatial delay {%d–%d} frames (Phase 2b)', ...
        cfg.stochasticDelayFrames(1), cfg.stochasticDelayFrames(2)), ...
        'lesionId', 'delay_random')
];
end

function lesions = localPhase2Uniform(cfg)
lesions = [
    struct('name', 'amplitude_uniform', 'shortLabel', 'Amp uniform', ...
        'description', sprintf('Uniform gain %.2f remaining', cfg.uniformGain), ...
        'lesionId', 'amplitude_uniform')
    struct('name', 'delay_uniform', 'shortLabel', 'Delay uniform', ...
        'description', sprintf('Uniform %d-frame delay', cfg.uniformDelayFrames), ...
        'lesionId', 'delay_uniform')
];
end

function lesions = localPhase2Biological(cfg)
lesions = [
    struct('name', 'amplitude_parasol', 'shortLabel', 'Amp parasol', ...
        'description', sprintf('Parasol-only gain %.1f remaining', cfg.cellTypeGain), ...
        'lesionId', 'amplitude_parasol')
    struct('name', 'delay_ON_only', 'shortLabel', 'Delay ON', ...
        'description', sprintf('ON-only %d-frame delay', cfg.onDelayFrames), ...
        'lesionId', 'delay_ON_only')
];
end

function lesions = localPhase2b(cfg, fieldSize)
lesions = [
    struct('name', 'amplitude_random', 'shortLabel', 'Amp random', ...
        'description', sprintf('Random amplitude [%.1f, %.1f]', ...
        cfg.stochasticAmpRange(1), cfg.stochasticAmpRange(2)), ...
        'lesionId', 'amplitude_random')
    struct('name', 'delay_random', 'shortLabel', 'Delay random', ...
        'description', sprintf('Random delay {%d–%d} frames', ...
        cfg.stochasticDelayFrames(1), cfg.stochasticDelayFrames(2)), ...
        'lesionId', 'delay_random')
    struct('name', 'amplitude_patchy', 'shortLabel', 'Amp patchy', ...
        'description', 'Patchy correlated amplitude', 'lesionId', 'amplitude_patchy')
    struct('name', 'delay_patchy', 'shortLabel', 'Delay patchy', ...
        'description', 'Patchy correlated delay', 'lesionId', 'delay_patchy')
    struct('name', 'coupled', 'shortLabel', 'Coupled', ...
        'description', 'Coupled amplitude + delay (correlated)', 'lesionId', 'coupled')
];
if fieldSize <= 0
    error('lesionCatalog:needFieldSize', 'Set ''fieldSize'' for phase2b catalog.');
end
end

function lesions = localCompareAmplitude(cfg)
lesions = [
    struct('name', 'parasol_gain0p3', 'shortLabel', 'Parasol', ...
        'description', sprintf('Parasol-only, gain %.1f (midgets spared)', cfg.cellTypeGain), ...
        'lesionId', 'amplitude_parasol')
    struct('name', 'uniform_gain0p5', 'shortLabel', 'Uniform', ...
        'description', sprintf('All classes, gain %.1f', cfg.uniformGain), ...
        'lesionId', 'amplitude_uniform')
];
end

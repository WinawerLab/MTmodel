% pars = shPars(preset)     get the parameters structure for the SH model.
%
% THERE ARE EXACTLY TWO WAYS TO RUN THIS MODEL. Both are complete: each call
% returns a pars struct ready to hand straight to shModel, with no further
% assembly.
%
%   pars = shPars;              % or shPars('derivative')
%       The Simoncelli-Heeger basis. Reproduces the legacy (RGC-disabled)
%       model to machine precision. No fitted weights involved.
%
%   pars = shPars('lagged');
%       The biological front-end: ON/OFF x midget/parasol x lags 0-3
%       (16 classes -> 160 features). MT runs on BOTH streams by default --
%       see "Two streams" below.
%
% Anything else is a variation on one of these two, not a third way to run the
% model. Do not hand-assemble a front-end; call shPars with a preset and then
% modify the result.
%
% TWO STREAMS ('lagged' only). MT pools a mixture of two read-outs of the SAME
% 160-feature basis (Nassi & Callaway 2006, 2007):
%
%   popMT = (1 - alpha)*streamA + alpha*streamB
%
%   stream A  parasol-masked weights; the dominant, fast magnocellular drive.
%   stream B  the mixed M+P weights, relayed via V2; the slow minority drive.
%
% Both are 28 x 160 matrices reading out the SAME 160-feature basis, so the
% feature dimension is not doubled -- but the basis is recomputed once per
% stream, so 'lagged' costs about twice a single-stream run. This is on by
% default because MT is magnocellular by construction; stream B alone is
% midget-dominated, which is backwards. To run single-stream (e.g. to reproduce
% pre-2026-08-14 results), clear pars.rgc.mtMix.
%
% LESIONS AND CUSTOM SETTINGS start from a preset and edit it -- see
% pars.rgc.impairmentAmplitudeMap / impairmentDelayMap, pars.rgc.classes(i).gain,
% and pars.rgc.mtMix.alpha. Read docs/MODEL_AND_LESIONS.md first.
%
% Choosing certain parameters outside of certain ranges will lead to
% crashes:
%
% pars.v1C50 should be below around .6, though depending on other
% parameters it may be safe to push it higher.
%
% pars.mtC50 should be equal to pars.v1C50. It is possible in some cases to
% move it away from pars.v1C50, but this usually leads to unusual model
% behavior.
%
% pars.mtBaseline must be between .001 and 1. Values close to 1 lead to
% very strange model behavior.
%
% SEE ALSO: shRgcClassesDerivative, shRgcClassesMidgetParasolLagged,
%           shModelV1ComplexForMt (the two-stream mixture), shModelUnits,
%           shParsScaleFactors, shParsV1PopulationDirections

function pars = shPars(preset)

    % Which RGC front-end to build:
    %   'derivative' (default) - the SH basis; reproduces legacy exactly.
    %   'lagged'               - ON/OFF x midget/parasol x lags 0-3, with the
    %                            two-stream magnocellular MT already switched on.
    if nargin < 1 || isempty(preset)
        preset = 'derivative';
    end

    % load some of the paramters that are big matrices that are no fun to type
    % into this file when you change them.
    directoryContainingThisFile = which('shPars');
    w = find(directoryContainingThisFile == '/');
    directoryContainingThisFile = directoryContainingThisFile(1:w(end));
    load([directoryContainingThisFile, 'defaultParameters.mat']);

    %%%%% NOW WE GET STARTED: V1
    pars.nScales = 1;
    pars.rgc.enabled = 1;                           % If 1, pass the stimulus through an RGC layer before V1.
    pars.rgc.mode = 'derivative';                   % Set by the preset switch at the END of this file; do not set
                                                     % it by hand. 'derivative' = the SH basis (no fitting needed);
                                                     % 'custom' = classes supplied in pars.rgc.classes.
    pars.rgc.derivative.channelGain = ones(1, 4);   % Per-channel gain for 'derivative' mode [order0 order1 order2 order3].
                                                     % A simple lesioning hook: set an entry to 0 to silence that
                                                     % temporal-derivative-order channel everywhere.
    % The RGC spatial RFs and temporal kernels live in the CLASSES
    % (pars.rgc.classes), not here -- shRgcClassesMidgetParasolLagged carries its
    % own DoG sigmas and difference-of-gamma kernels. Edit a class to change the
    % front-end; see shRgcClass.
    pars.rgc.v1Weights = [];                        % Fitted class-to-V1 weights (28 x nFeatures). Set by the
                                                     % 'lagged' preset; unused by 'derivative', which steers analytically.
    pars.rgc.impairmentEnabled = 0;                 % If 1, apply amplitude/timing impairments.
    pars.rgc.impairmentAmplitudeMap = [];           % Optional YxX multiplicative map for RGC amplitude deficits.
    pars.rgc.impairmentDelayMap = [];               % Optional YxX integer delay map (frames) for timing deficits.
    pars.v1SpatialFilters = v1SpatialFilters;       % Linear filters used to compute V1 responses. Stored in defaultParameters.mat
    pars.v1TemporalFilters = v1TemporalFilters;     % Linear filters used to compute V1 responses. Stored in defaultParameters.mat
    pars.v1PopulationDirections = v1PopulationDirections;       % Parameters for neurons in the V1 population. Stored in defaultParameters.mat
    pars.v1Baseline = 0;                            % Additive constant in V1. Always 0. Included out of fidelity to the original paper.
    pars.v1ComplexFilter = mkGaussianFilter(1.6);   % Blurring filter used to make complex cell responses phase invariant.
    pars.v1NormalizationType = 'tuned';             % Choices: 'tuned', 'untuned', and 'off';
    % 'untuned' and 'off' are diagnostic settings and shouldn't be used unless you know what you're about.
    pars.v1NormalizationSpatialFilter = mkGaussianFilter(-1);   % Blurring filter to make the normalization pool larger than the CRF.
    pars.v1NormalizationTemporalFilter = mkGaussianFilter(-1);  % Blurring filter to make the normalization signal pool over time.
    pars.v1C50 = .1;                                % Contrast at which V1 neurons have half maximal response to a drifting grating.

    %%%%% AND ON TO MT
    pars.mtPopulationVelocities = mtPopulationVelocities;   % Preferred velocities of neurons in the MT population; stored in defaultParameters.mat
    pars.mtSpatialPoolingBeforeThreshold = 1;           % Is spatial pooling performed before or after the half wave rectification of MT responses?
    pars.mtSpatialPoolingFilter = mkGaussianFilter(3);  % MT spatial pooling filter
    pars.mtNormalizationType = 'tuned';             % choices are 'tuned' and 'self'. 'self' is currently a diagnostic setting for those who know what they're about.
    pars.mtNormalizationSpatialFilter = mkGaussianFilter(-1);   % Filter for spatial pooling of the MT normalization signal.
    pars.mtNormalizationTemporalFilter = mkGaussianFilter(-1);  % Filter for temporal pooling of the MT normalization signal.
    pars.mtC50 = pars.v1C50;                        % Contrast at which MT neurons have half maximum response to full field drifting gratings.
    % Model is unstable if v1C50 ~= mtC50.
    pars.mtBaseline = .1;                           % Baseline response of MT neurons.
    pars.mtExponent = 2;                            % Exponent to which MT neuron responses are raised.

    %%%% COMPUTE SCALE FACTORS
    % Scale factors are derived from the legacy (no-RGC) path so any
    % subsequent weight fit has the correct normalization reference.
    pars.rgc.enabled = 0;
    pars = shParsScaleFactors(pars);
    pars.rgc.enabled = 1;

    % Build the requested front-end. Everything the preset needs -- classes,
    % read-out rule, fitted weights, and (for 'lagged') the two-stream MT --
    % is set here, so callers never have to assemble it by hand.
    switch lower(preset)
        case 'derivative'
            pars.rgc.mode        = 'derivative';
            pars.rgc.classes     = shRgcClassesDerivative(pars);
            pars.rgc.combine     = 'steer';
            pars.rgc.classesMode = 'derivative';

        case 'lagged'
            pars.rgc.mode        = 'custom';
            pars.rgc.classes     = shRgcClassesMidgetParasolLagged(pars, [0 1 2 3]);
            pars.rgc.combine     = 'weights';
            pars.rgc.classesMode = 'custom';
            % Stream B: the mixed M+P read-out, relayed via V2.
            pars.rgc.v1Weights   = localLoadWeights(directoryContainingThisFile, ...
                'shRgcClassesMidgetParasolLagged_v1Weights_lag0123.mat', 'v1Weights');
            % Stream A: the parasol-masked read-out, the dominant magno drive.
            % On by default -- MT is magnocellular by construction. Clear
            % pars.rgc.mtMix to get the single-stream (midget-dominated) model.
            pars.rgc.mtMix = struct( ...
                'weightsA', localLoadWeights(directoryContainingThisFile, ...
                    'shRgcClassesMidgetParasolLagged_v1WeightsMagnoA_lag0123.mat', ...
                    'v1WeightsMagnoA'), ...
                'alpha', 0.10, 'delay', 0);

        otherwise
            error('shPars:preset', ...
                  'preset must be ''derivative'' or ''lagged'', got ''%s''.', preset);
    end

end

function W = localLoadWeights(parsDir, fileName, fieldName)
    f = fullfile(parsDir, fileName);
    if ~exist(f, 'file')
        % Each cache has its own fitting script. Stream B (the mixed M+P
        % read-out) is fitted by explore/validateSHFigs9to14.m; stream A (the
        % parasol-masked read-out) by explore/fitMagnoMtPopulation.m.
        if strcmpi(fieldName, 'v1WeightsMagnoA')
            refitWith = 'explore/fitMagnoMtPopulation.m';
        else
            refitWith = 'explore/validateSHFigs9to14.m';
        end
        error('shPars:missingWeights', ...
              'Cached weights not found: %s\nRefit with %s.', f, refitWith);
    end
    c = load(f);
    if ~isfield(c, fieldName)
        error('shPars:badWeights', '%s has no field ''%s''.', f, fieldName);
    end
    W = c.(fieldName);
end

% pars = shPars         get default parameters structure for the SH model.
%
% Feel free to create a new function using this as a template.
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
% SEE ALSO: shParsScaleFactors, shParsV1PopulationDirections

function pars = shPars

    % load some of the paramters that are big matrices that are no fun to type
    % into this file when you change them.
    directoryContainingThisFile = which('shPars');
    w = find(directoryContainingThisFile == '/');
    directoryContainingThisFile = directoryContainingThisFile(1:w(end));
    load([directoryContainingThisFile, 'defaultParameters.mat']);

    %%%%% NOW WE GET STARTED: V1
    pars.nScales = 1;
    pars.rgc.enabled = 0;                           % If 1, pass the stimulus through an RGC layer before V1.
    pars.rgc.populationMode = 'legacy';             % 'legacy' (single channel) or 'fourPop' (ON/OFF x fast/slow).
    pars.rgc.centerSigma = 0.8;                     % Center sigma (pixels) for legacy spatial filtering.
    pars.rgc.surroundSigma = 2.0;                   % Surround sigma (pixels) for legacy spatial filtering.
    pars.rgc.surroundWeight = 0;                    % 0 preserves legacy behavior; increase to enable center-surround antagonism.
    pars.rgc.temporalSigma = 0;                     % Temporal sigma (frames) for legacy mode. 0 means no temporal smoothing.
    pars.rgc.gain = 1;                              % Global gain applied after RGC filtering.
    pars.rgc.spatial.centerSigma = 0.8;             % fourPop: center sigma for ON/OFF center-surround filters.
    pars.rgc.spatial.surroundSigma = 2.0;           % fourPop: surround sigma (pixels).
    pars.rgc.spatial.surroundWeight = 0.25;         % fourPop: surround antagonism strength.
    pars.rgc.temporal.fastSigma = 0.6;              % fourPop: temporal smoothing for fast populations (frames).
    pars.rgc.temporal.slowSigma = 2.0;              % fourPop: temporal smoothing for slow populations (frames).
    pars.rgc.onOffSignSplit = 'local';              % fourPop: 'local' (contrast split) or 'bipolar' (rectify DoG output).
    pars.rgc.onOffSymmetry = 1.0;                   % fourPop: relative scaling of OFF vs ON rectification.
    pars.rgc.v1Weights = [];                        % fourPop: optional Nx40 fitted V1 weights (4 RGC x 10 basis).
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
    pars = shParsScaleFactors(pars);

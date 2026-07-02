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
    pars.rgc.enabled = 1;                           % If 1, pass the stimulus through an RGC layer before V1.
    pars.rgc.mode = 'derivative';                   % 'derivative' (default): 4 causal temporal-derivative-order
                                                     % channels that exactly reconstruct legacy V1/MT (no fitting
                                                     % needed). 'fourPop': biological ON/OFF x fast/slow channels.
    pars.rgc.derivative.channelGain = ones(1, 4);   % Per-channel gain for 'derivative' mode [order0 order1 order2 order3].
                                                     % A simple lesioning hook: set an entry to 0 to silence that
                                                     % temporal-derivative-order channel everywhere.
    pars.rgc.gain = 1;                              % Global gain applied after RGC filtering.
    pars.rgc.spatial.centerSigma = 0.8;             % RGC center sigma for ON/OFF center-surround filters.
    pars.rgc.spatial.surroundSigma = 2.0;           % RGC surround sigma (pixels).
    pars.rgc.spatial.surroundWeight = 0.25;         % RGC surround antagonism strength.
    pars.rgc.spatial.fastRfScale = 1.0;             % RF size scale for fast channels relative to slow (e.g. 1.5 = 50% larger).
    pars.rgc.spatial.onRfScale = 1.0;               % RF size scale for ON channels relative to OFF (e.g. 1.1 = 10% larger).
    pars.rgc.temporal.mode = 'causal';              % RGC temporal mode: 'causal' biphasic kernels or explicit 'gaussian'.
    pars.rgc.temporal.fastSigma = 0.6;              % RGC fallback width for fast temporal kernel (frames).
    pars.rgc.temporal.slowSigma = 2.0;              % RGC fallback width for slow temporal kernel (frames).
    pars.rgc.temporal.fastTau1 = 0.6;               % RGC causal fast kernel first lobe time constant (frames).
    pars.rgc.temporal.fastTau2 = 1.2;               % RGC causal fast kernel second lobe time constant (frames).
    pars.rgc.temporal.fastWeight = 0.45;            % RGC causal fast kernel second lobe weight.
    pars.rgc.temporal.slowTau1 = 2.0;               % RGC causal slow kernel first lobe time constant (frames).
    pars.rgc.temporal.slowTau2 = 4.0;               % RGC causal slow kernel second lobe time constant (frames).
    pars.rgc.temporal.slowWeight = 0.15;            % RGC causal slow kernel second lobe weight.
    pars.rgc.temporal.fastLag = 0;                 % Delay (frames) for lagged fast channels; 0 disables them.
    pars.rgc.temporal.slowLag = 0;                 % Delay (frames) for lagged slow channels; 0 disables them.
    pars.rgc.temporal.power = 2;                    % RGC gamma-kernel exponent.
    pars.rgc.onOffSignSplit = 'contrast';           % RGC 'contrast' (frame mean-subtracted), 'local', or 'bipolar'.
    pars.rgc.onOffSymmetry = 1.0;                   % RGC relative scaling of OFF vs ON rectification.
    pars.rgc.v1Weights = [];                        % Fitted V1 weights, 'fourPop' mode only (Nx40, or Nx80 with lagged channels). Unused in 'derivative' mode.
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

    %%%% COMPUTE SCALE FACTORS AND (FOR 'fourPop') FIT RGC WEIGHTS
    % Scale factors are derived from the legacy (no-RGC) path so any
    % subsequent weight fit has the correct normalization reference.
    pars.rgc.enabled = 0;
    pars = shParsScaleFactors(pars);
    pars.rgc.enabled = 1;

    % The 'derivative' mode needs no fitted weights -- it reconstructs the
    % legacy basis exactly (see shModelV1LinearFromRgcDerivative). Only the
    % biological 'fourPop' mode needs a numerically fitted channel-to-V1
    % weight matrix.
    if strcmpi(pars.rgc.mode, 'fourPop')
        pars.rgc.v1Weights = shFitRgcV1Weights(pars, localDefaultStimSet(pars));
    end

end

function stimSet = localDefaultStimSet(pars)
    dims = shGetDims(pars, 'mtPattern', [1 1 18]);
    g1 = v12sin([0, 1.0]);
    g2 = v12sin([pi/3, 1.6]);
    stimSet = { ...
        mkDots(dims, 0,    1.0, 0.12, 1), ...
        mkDots(dims, pi/2, 0.7, 0.12, 0.7), ...
        mkSin(dims, 0,    g1(2), g1(3), 1), ...
        mkSin(dims, pi/3, g2(2), g2(3), 1) ...
    };
end

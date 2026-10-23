%% Stochastic lesion application functions - add to validateSHFigs9to14_lesions.m

function pars = lesionAmplitudeStochastic(parsBase)
% Stochastic amplitude deficit: each location drawn from Uniform(0.3, 0.7)
% Uncorrelated spatial pattern (pixel-level independence)
pars = parsBase;

% Get spatial dimensions from parameters
dims = shGetDims(pars, 'v1Complex', [1 1 1]);
Y = dims(1); X = dims(2);

% Generate random amplitude map
rng(42); % deterministic for reproducibility
amplitudeMap = 0.3 + 0.4 * rand(Y, X); % Uniform(0.3, 0.7)

% Apply via impairment mechanism
pars.rgc.impairmentEnabled = 1;
pars.rgc.impairmentAmplitudeMap = amplitudeMap;
end

function pars = lesionDelayStochastic(parsBase)
% Stochastic delay: each location drawn from {0, 1, 2, 3} frames
% Uncorrelated spatial pattern
pars = parsBase;

dims = shGetDims(pars, 'v1Complex', [1 1 1]);
Y = dims(1); X = dims(2);

% Generate random delay map
rng(43); % deterministic, different seed from amplitude
delayMap = randi([0 3], Y, X); % Uniform integer {0, 1, 2, 3}

pars.rgc.impairmentEnabled = 1;
pars.rgc.impairmentDelayMap = delayMap;
end

function pars = lesionAmplitudePatchyCorrelated(parsBase)
% Spatially correlated (patchy) amplitude deficit
% Smooth random field creates realistic clustered damage
pars = parsBase;

dims = shGetDims(pars, 'v1Complex', [1 1 1]);
Y = dims(1); X = dims(2);

% Generate random field
rng(44);
rawMap = rand(Y, X);

% Smooth with Gaussian to create spatial correlation
sigma = 3.0; % controls patch size (larger = bigger patches)
smoothMap = imgaussfilt(rawMap, sigma);

% Scale to amplitude range [0.3, 0.7]
smoothMap = (smoothMap - min(smoothMap(:))) / (max(smoothMap(:)) - min(smoothMap(:))); % normalize to [0,1]
amplitudeMap = 0.3 + 0.4 * smoothMap;

pars.rgc.impairmentEnabled = 1;
pars.rgc.impairmentAmplitudeMap = amplitudeMap;
end

function pars = lesionDelayPatchyCorrelated(parsBase)
% Spatially correlated (patchy) delay deficit
% Creates clustered regions of similar delays
pars = parsBase;

dims = shGetDims(pars, 'v1Complex', [1 1 1]);
Y = dims(1); X = dims(2);

% Generate smooth random field
rng(45);
rawMap = rand(Y, X);
sigma = 3.0;
smoothMap = imgaussfilt(rawMap, sigma);

% Threshold into delay levels {0, 1, 2, 3}
thresholds = [0.25 0.5 0.75];
delayMap = zeros(Y, X);
for i = 1:length(thresholds)
    delayMap(smoothMap > thresholds(i)) = i;
end

pars.rgc.impairmentEnabled = 1;
pars.rgc.impairmentDelayMap = delayMap;
end

function pars = lesionCoupledAmplitudeDelay(parsBase)
% Coupled amplitude and delay: worse amplitude → longer delay
% Tests whether correlated deficits are more disruptive
pars = parsBase;

dims = shGetDims(pars, 'v1Complex', [1 1 1]);
Y = dims(1); X = dims(2);

% Generate correlated random field
rng(46);
rawMap = rand(Y, X);
sigma = 3.0;
smoothMap = imgaussfilt(rawMap, sigma);
smoothMap = (smoothMap - min(smoothMap(:))) / (max(smoothMap(:)) - min(smoothMap(:)));

% Amplitude inversely related to smoothMap (lower = worse amplitude)
amplitudeMap = 0.3 + 0.4 * smoothMap; % range [0.3, 0.7]

% Delay directly related to damage (lower amplitude → higher delay)
% Map [0.3, 0.7] amplitude to {3, 2, 1, 0} delay
delayMap = zeros(Y, X);
delayMap(amplitudeMap < 0.4) = 3; % worst amplitude (0.3-0.4) → 3 frame delay
delayMap(amplitudeMap >= 0.4 & amplitudeMap < 0.5) = 2;
delayMap(amplitudeMap >= 0.5 & amplitudeMap < 0.6) = 1;
% amplitudeMap >= 0.6 → delay = 0

pars.rgc.impairmentEnabled = 1;
pars.rgc.impairmentAmplitudeMap = amplitudeMap;
pars.rgc.impairmentDelayMap = delayMap;
end

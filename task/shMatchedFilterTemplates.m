function filters = shMatchedFilterTemplates(pars, templates, options)
% shMatchedFilterTemplates  Expected MT opponent map for each letter, for use as matched filters.
%
%   filters = shMatchedFilterTemplates(pars, templates) runs NumPerLetter
%   trials of each letter through the model, WITHOUT internal noise, at one
%   speed and coherence (by default 5 deg/s and coherence 1: easy
%   conditions, where the map shows the letter clearly). It flips the maps of
%   leftward trials so every map has the sign of a rightward letter, averages
%   the maps of each letter, and makes each average zero-mean with unit norm.
%   shMatchedFilterScores then correlates a trial's map with these.
%
%   One set of filters is used for every speed and coherence (JW,
%   2026-09-11). Because the score is a correlation, the map's overall
%   strength does not matter, but its SHAPE may change with speed and
%   coherence. Whether filters made in other conditions do better is an open
%   check (docs/FORM_FROM_MOTION.md).
%
%   The trials use their own seeds (Seed + 1, Seed + 2, ...), far from the
%   test trials' default seeds, so the filters are not built from the same dot
%   samples they are later tested on.
%
%   filters = shMatchedFilterTemplates(..., Name=Value)
%
%   Inputs:
%     pars          model parameters. pars.noise is set to zero here.
%     templates     from shLetterTemplates
%     SpeedPxPerFrame  [1], i.e. 5 deg/s
%     Coherence        [1]
%     NumPerLetter     trials per letter [8]
%     Seed             base seed [1000000]
%     TrialOptions     struct of further name-value options for
%                      shRunLetterTrials (for example DotSizePx), so the
%                      filters are built with the same stimulus as the test
%                      trials. Default: none, i.e. its defaults.
%
%   Output fields:
%     maps          [Y X nLetters], zero-mean, unit norm
%     letters, speedPxPerFrame, coherence, numPerLetter, seed
%
%   See also shMatchedFilterScores, shRunLetterTrials, shLetterTemplates

    arguments
        pars (1,1) struct
        templates (1,1) struct
        options.SpeedPxPerFrame (1,1) double {mustBePositive} = 1
        options.Coherence (1,1) double {mustBeBetween(options.Coherence, 0, 1)} = 1
        options.NumPerLetter (1,1) double {mustBeInteger, mustBePositive} = 8
        options.Seed (1,1) double {mustBeInteger, mustBeNonnegative} = 1000000
        options.TrialOptions (1,1) struct = struct()
    end

    if isfield(pars, "noise")
        pars.noise.rgcSd = 0;
        pars.noise.v1Sd = 0;
        pars.noise.mtSd = 0;
    end

    nLetters = numel(templates.letters);
    trialArgs = namedargs2cell(options.TrialOptions);
    trialRun = shRunLetterTrials(pars, nLetters*options.NumPerLetter, trialArgs{:}, ...
        SpeedPxPerFrame=options.SpeedPxPerFrame, Coherence=options.Coherence, ...
        Templates=templates, Seed=options.Seed, KeepMaps=true);

    directionSign = reshape(cosd(trialRun.motionAngleDeg), 1, 1, []);
    alignedMaps = trialRun.maps.*directionSign;
    maps = zeros([templates.outSz(1:2) nLetters]);
    for k = 1:nLetters
        meanMap = mean(alignedMaps(:, :, trialRun.trueIndex == k), 3);
        centred = meanMap - mean(meanMap(:));
        maps(:, :, k) = centred/norm(centred(:));
    end

    filters = struct( ...
        "maps", maps, ...
        "letters", templates.letters, ...
        "speedPxPerFrame", options.SpeedPxPerFrame, ...
        "coherence", options.Coherence, ...
        "numPerLetter", options.NumPerLetter, ...
        "seed", options.Seed);
end

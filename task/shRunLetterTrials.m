function results = shRunLetterTrials(pars, nTrials, options)
% shRunLetterTrials  Simulate the motion-defined letter task through the model to MT.
%
%   results = shRunLetterTrials(pars, nTrials) runs nTrials trials of the
%   motion-defined letter task at one speed and one coherence. On each trial
%   one Sloan letter is drawn as a motion-defined form (mkMotionLetter, or
%   mkBoothLetterMovie for booth templates): the letter's dots drift one way
%   and the background's dots the other. The direction is chosen at random on
%   each trial (rightward or leftward letter), as in the booth. The movie runs
%   through shModel to MT, the MT response is reduced to a
%   rightward-minus-leftward map (shOpponentMap), and the map is scored
%   against every letter.
%
%   Read-outs reported:
%
%     known letter    The true letter's template score (shTemplateScores:
%                     inside minus outside), multiplied by the sign of the
%                     trial's direction so that it is positive when the letter
%                     is seen. Its mean over trials divided by its SD over
%                     trials is a d'. shMafcProportionCorrect turns that into
%                     the proportion correct of an ideal 10-AFC observer whose
%                     other nine scores are independent and centred on zero,
%                     which is optimistic.
%     classifier      The letter whose template score is largest in ABSOLUTE
%                     size, so the decision does not depend on knowing the
%                     direction. Chance is 1/10. The same decision with the
%                     direction known is also kept.
%     matched filter  Only if MatchedFilters is given. The correlation of the
%                     map with each letter's expected map
%                     (shMatchedFilterScores); the letter with the largest
%                     correlation in absolute size is chosen. A d' is also
%                     computed from the true letter's sign-corrected
%                     correlation.
%
%   Every trial's full score vectors are kept, so other decision rules can be
%   applied later without re-running the model.
%
%   Trial n calls rng(Seed + n) before it draws anything. Every condition
%   therefore sees the same letters, directions, dot samples and noise draws,
%   trial for trial, which makes comparisons between conditions paired.
%
%   results = shRunLetterTrials(..., Name=Value)
%
%   Name-value options (defaults in brackets):
%     SpeedPxPerFrame          dot speed [1]; 1 px/frame = 5 deg/s (shModelUnits).
%                              On the booth display a model pixel per model
%                              frame is 10 booth pixels per 20 ms.
%     Coherence                fraction of signal dots [1]
%     DotLifetimeFrames        [5], i.e. 100 ms at 50 frames/s, as in the booth
%     OutSz                    MT output [Y X T] [64 64 50]: 6.4 x 6.4 deg, 1 s
%     Letters                  ["CDHKNORSVZ"]
%     LetterSizePx             font size [28]: a 29-px (2.9 deg) Sloan letter
%     FCovered                 dot coverage [0.5], as in the booth
%     DotSizePx                dot diameter in model pixels [0.4]. The booth dot
%                              is 4 px at 100.6 px/deg = 0.040 deg = 0.40 px.
%     DotRendering             ["area"] draws each dot as its area, shared among
%                              the pixels around it; "pixel" stamps whole pixels
%     RandomizeDirection       [true]; false keeps the letter moving rightward
%     BackgroundVelocityScale  [-1]; +1 moves the background WITH the letter,
%                              the control that removes relative motion
%     Seed                     base seed [1]
%     Templates                from shLetterTemplates. If given, its outSz,
%                              letters and letterSizePx are used and OutSz,
%                              Letters and LetterSizePx are ignored. If it was
%                              built with BoothDisplay, every trial is drawn as
%                              on the booth display (mkBoothLetterMovie), and
%                              DotLifetimeFrames, FCovered, DotSizePx and
%                              DotRendering are ignored.
%     BoothDisplay             from boothDisplay [none]. Used only when
%                              Templates is not given: booth templates are then
%                              built, so the trials are drawn as on the booth.
%     MatchedFilters           from shMatchedFilterTemplates [none]
%     Weighting                shOpponentMap weighting ["cosine"]
%     KeepMaps                 keep every trial's opponent map [false]
%
%   Output fields:
%     options, letters, stimInfo (first trial), seconds
%     trueIndex [nTrials 1], motionAngleDeg [nTrials 1]
%     scores [nTrials nLetters]                      template scores
%     choice, correct, proportionCorrect, proportionCorrectSe   (sign-free classifier)
%     choiceKnownDirection, proportionCorrectKnownDirection
%     scoreTrue, scoreTrueMean, scoreTrueSd, dprime, proportionCorrectFromDprime
%     matchedScores [nTrials nLetters], choiceMatched, proportionCorrectMatched,
%     proportionCorrectMatchedSe, dprimeMatched      (empty or NaN without filters)
%     maps [Y X nTrials] if KeepMaps, else []
%
%   See also shLetterTemplates, shOpponentMap, shTemplateScores,
%            shMatchedFilterTemplates, shMatchedFilterScores,
%            shMafcProportionCorrect, mkMotionLetter, mkBoothLetterMovie

    arguments
        pars (1,1) struct
        nTrials (1,1) double {mustBeInteger, mustBePositive}
        options.SpeedPxPerFrame (1,1) double {mustBeNonnegative} = 1
        options.Coherence (1,1) double {mustBeBetween(options.Coherence, 0, 1)} = 1
        options.DotLifetimeFrames (1,1) double {mustBePositive} = 5
        options.OutSz (1,3) double {mustBeInteger, mustBePositive} = [64 64 50]
        options.Letters (1,1) string = "CDHKNORSVZ"
        options.LetterSizePx (1,1) double {mustBePositive} = 28
        options.FCovered (1,1) double {mustBePositive} = 0.5
        options.DotSizePx (1,1) double {mustBePositive} = 0.4
        options.DotRendering (1,1) string {mustBeMember(options.DotRendering, ["area", "pixel"])} = "area"
        options.RandomizeDirection (1,1) logical = true
        options.BackgroundVelocityScale (1,1) double = -1
        options.Seed (1,1) double {mustBeInteger, mustBeNonnegative} = 1
        options.Templates struct = struct.empty
        options.BoothDisplay struct = struct.empty
        options.MatchedFilters struct = struct.empty
        options.Weighting (1,1) string = "cosine"
        options.KeepMaps (1,1) logical = false
    end

    templates = options.Templates;
    if isempty(templates)
        if isempty(options.BoothDisplay)
            templates = shLetterTemplates(pars, options.OutSz, Letters=options.Letters, ...
                LetterSizePx=options.LetterSizePx);
        else
            margin = shGetDims(pars, "mtPattern", [1 1 1]) - 1;
            templates = shLetterTemplates(pars, options.BoothDisplay.modelSize - margin, ...
                Letters=options.Letters, BoothDisplay=options.BoothDisplay);
        end
    end
    booth = struct.empty;
    if isfield(templates, "boothDisplay")
        booth = templates.boothDisplay;
    end
    isBooth = ~isempty(booth);
    useMatched = ~isempty(options.MatchedFilters);
    if useMatched && ~strcmp(options.MatchedFilters.letters, templates.letters)
        error("shRunLetterTrials:letters", ...
            "The matched filters are for letters %s but the templates are for %s. " + ...
            "Build both with the same letters.", options.MatchedFilters.letters, templates.letters);
    end
    units = shModelUnits();
    nLetters = numel(templates.letters);
    leftwardDeg = 180;

    % A fixed RGC-noise seed would give every trial the same retina.
    if isfield(pars, "noise")
        pars.noise.seed = [];
    end

    trueIndex = mod((0:nTrials-1)', nLetters) + 1;    % each letter equally often
    motionAngleDeg = zeros(nTrials, 1);
    scores = zeros(nTrials, nLetters);
    matchedScores = zeros(nTrials, nLetters*useMatched);
    if options.KeepMaps
        maps = zeros([templates.outSz(1:2) nTrials]);
    else
        maps = [];
    end

    timer = tic;
    for n = 1:nTrials
        rng(options.Seed + n);
        if options.RandomizeDirection && rand() < 0.5
            motionAngleDeg(n) = leftwardDeg;
        end
        k = trueIndex(n);
        if isBooth
            [stim, info] = mkBoothLetterMovie(templates.boothMasks(:, :, k), booth, ...
                SpeedPxPerSec=options.SpeedPxPerFrame*booth.pixelsPerModelPixel*booth.modelFrameRate, ...
                Coherence=options.Coherence, MotionAngleDeg=motionAngleDeg(n), ...
                BackgroundVelocityScale=options.BackgroundVelocityScale);
        else
            [stim, info] = mkMotionLetter(templates.stimSz, templates.letters(k), ...
                referenceDisplaySize=[], ppd=units.pixelsPerDegree, ...
                frameRate=units.framesPerSecond, dotSpeedPxPerFrame=options.SpeedPxPerFrame, ...
                letterSizePx=templates.letterSizePx, letterMask=templates.stimMasks(:, :, k), ...
                dotSize=options.DotSizePx, dotRendering=char(options.DotRendering), ...
                fCovered=options.FCovered, coherence=options.Coherence, ...
                dotLifetimeFrames=options.DotLifetimeFrames, ...
                backgroundVelocityScale=options.BackgroundVelocityScale, ...
                motionAngleDeg=motionAngleDeg(n));
        end
        [pop, ind] = shModel(stim, pars, "mtPattern");
        map = shOpponentMap(pop, ind, pars, Weighting=options.Weighting);
        scores(n, :) = shTemplateScores(map, templates.masks);
        if useMatched
            matchedScores(n, :) = shMatchedFilterScores(map, options.MatchedFilters.maps);
        end
        if options.KeepMaps
            maps(:, :, n) = map;
        end
        if n == 1
            stimInfo = info;
            if ~isBooth
                stimInfo = rmfield(info, ["letterContrastFrame", "binaryMask"]);
            end
        end
    end
    seconds = toc(timer);

    % Rightward letter -> +1, leftward -> -1 (cosd is exact at 0 and 180).
    directionSign = cosd(motionAngleDeg);
    trueEntry = sub2ind([nTrials nLetters], (1:nTrials)', trueIndex);
    scoreTrue = scores(trueEntry).*directionSign;

    [~, choice] = max(abs(scores), [], 2);
    correct = choice == trueIndex;
    proportionCorrect = mean(correct);
    [~, choiceKnownDirection] = max(scores.*directionSign, [], 2);
    dprime = mean(scoreTrue)/std(scoreTrue);

    if useMatched
        [~, choiceMatched] = max(abs(matchedScores), [], 2);
        proportionCorrectMatched = mean(choiceMatched == trueIndex);
        matchedTrue = matchedScores(trueEntry).*directionSign;
        dprimeMatched = mean(matchedTrue)/std(matchedTrue);
    else
        choiceMatched = [];
        proportionCorrectMatched = NaN;
        dprimeMatched = NaN;
    end

    results = struct( ...
        "options", rmfield(options, ["Templates", "MatchedFilters"]), ...
        "letters", templates.letters, ...
        "stimInfo", stimInfo, ...
        "seconds", seconds, ...
        "trueIndex", trueIndex, ...
        "motionAngleDeg", motionAngleDeg, ...
        "scores", scores, ...
        "choice", choice, ...
        "correct", correct, ...
        "proportionCorrect", proportionCorrect, ...
        "proportionCorrectSe", sqrt(proportionCorrect*(1-proportionCorrect)/nTrials), ...
        "choiceKnownDirection", choiceKnownDirection, ...
        "proportionCorrectKnownDirection", mean(choiceKnownDirection == trueIndex), ...
        "scoreTrue", scoreTrue, ...
        "scoreTrueMean", mean(scoreTrue), ...
        "scoreTrueSd", std(scoreTrue), ...
        "dprime", dprime, ...
        "proportionCorrectFromDprime", shMafcProportionCorrect(dprime, nLetters), ...
        "matchedScores", matchedScores, ...
        "choiceMatched", choiceMatched, ...
        "proportionCorrectMatched", proportionCorrectMatched, ...
        "proportionCorrectMatchedSe", sqrt(proportionCorrectMatched*(1-proportionCorrectMatched)/nTrials), ...
        "dprimeMatched", dprimeMatched, ...
        "maps", maps);
end

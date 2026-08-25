function m = motionLetterMetrics(popMt, indMt, popV1, indV1, pars, stimInfo)
% motionLetterMetrics  Opponent maps and letter-vs-background d' for motion letters.
%
% Uses the same speed-matched opponent-pair selection as showMotionLetterModel
% and the d' definition from runMotionLetterDemo:
%   d' = (mean_inside - mean_outside) / sqrt(0.5 * (var_inside + var_outside))
%
% Inputs
%   popMt, indMt   shModel outputs at mtPattern
%   popV1, indV1   shModel outputs at v1Complex, or [] to skip V1
%   pars           model parameters (for population tunings)
%   stimInfo       struct from mkMotionLetter (needs binaryMask)
%
% Output struct fields
%   mtOpp, v1Opp     time-averaged right-minus-left opponent maps
%   mask             letter mask center-cropped to the map (not resized)
%   dMt, dV1         letter-vs-background d'
%   mtPair, v1Pair   2×2 [dir rad, speed px/frame] for chosen units
%   mtNote, v1Note   human-readable pair descriptions
%   iMtRight, iMtLeft, iV1Right, iV1Left  population indices

speedPx = stimInfo.dotSpeedPxPerFrame;
mtVels = pars.mtPopulationVelocities;
skipV1 = nargin < 4 || isempty(popV1);

[iMtRight, iMtLeft, m.mtNote] = localOpponentPair(mtVels, speedPx);
m.iMtRight = iMtRight;
m.iMtLeft = iMtLeft;

mtRightMap = squeeze(shGetSubPop(popMt, indMt, iMtRight));
mtLeftMap  = squeeze(shGetSubPop(popMt, indMt, iMtLeft));
m.mtOpp = mean(mtRightMap - mtLeftMap, 3);
m.mask = motionLetterMaskOnMap(stimInfo.binaryMask, size(m.mtOpp, 1), size(m.mtOpp, 2));
m.dMt = localDprime(m.mtOpp, m.mask);
m.mtPair = mtVels([iMtRight, iMtLeft], :);

if skipV1
    m.v1Opp = [];
    m.dV1 = NaN;
    m.v1Pair = [];
    m.v1Note = '';
    m.iV1Right = [];
    m.iV1Left = [];
    return;
end

v1Dirs = pars.v1PopulationDirections;
[iV1Right, iV1Left, m.v1Note] = localOpponentPair(v1Dirs, speedPx);
m.iV1Right = iV1Right;
m.iV1Left = iV1Left;
v1RightMap = squeeze(shGetSubPop(popV1, indV1, iV1Right));
v1LeftMap  = squeeze(shGetSubPop(popV1, indV1, iV1Left));
m.v1Opp = mean(v1RightMap - v1LeftMap, 3);
m.dV1 = localDprime(m.v1Opp, m.mask);
m.v1Pair = v1Dirs([iV1Right, iV1Left], :);
end

function d = localDprime(map, mask)
a = map(mask);
b = map(~mask);
d = (mean(a) - mean(b)) / sqrt(0.5 * (var(a) + var(b)));
end

function [iPos, iNeg, note] = localOpponentPair(tuning, speedPx, targetDir)
if nargin < 3 || isempty(targetDir), targetDir = 0; end

speeds = tuning(:, 2);
moving = find(speeds > 0);
if isempty(moving)
    error('motionLetterMetrics:noMovingUnits', ...
        'Population contains no units with non-zero preferred speed.');
end

unitVecs = localTuningToUnitVec(tuning(moving, :));
cosPos = unitVecs * localTuningToUnitVec([targetDir, speedPx])';
[~, a] = max(cosPos);
iPos = moving(a);

cosNeg = unitVecs * localTuningToUnitVec([targetDir + pi, tuning(iPos, 2)])';
[~, b] = max(cosNeg);
iNeg = moving(b);

note = sprintf(['stimulus %.4f px/frame; pref %.1f deg @ %.3f px/frame ' ...
    'vs %.1f deg @ %.3f px/frame'], speedPx, ...
    rad2deg(tuning(iPos, 1)), tuning(iPos, 2), ...
    rad2deg(tuning(iNeg, 1)), tuning(iNeg, 2));

if abs(tuning(iPos, 2) - speedPx) > 0.5 * speedPx
    warning('motionLetterMetrics:speedMismatch', ...
        ['Nearest tuned speed (%.3f px/frame) is far from the stimulus speed ' ...
         '(%.4f px/frame). Population speeds: %s.'], ...
        tuning(iPos, 2), speedPx, mat2str(unique(round(speeds(moving), 3))', 3));
end
end

function v = localTuningToUnitVec(tuning)
el = atan3(tuning(:, 2), ones(size(tuning, 1), 1));
v = sphere2rec([tuning(:, 1), el]);
v = v ./ sqrt(sum(v.^2, 2));
end

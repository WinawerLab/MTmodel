function scores = shTemplateScores(map, masks)
% shTemplateScores  Score an MT opponent map against a set of letter templates.
%
%   scores = shTemplateScores(map, masks) returns, for each template k, the
%   mean of the map INSIDE the letter minus the mean OUTSIDE it:
%
%       scores(k) = mean(map(masks(:, :, k))) - mean(map(~masks(:, :, k)))
%
%   The score is positive when the letter's dots drift right and the
%   background's drift left, and negative the other way round. Taking means,
%   not sums, makes letters of different area comparable.
%
%   Inputs:
%     map     [Y X] map from shOpponentMap
%     masks   [Y X nLetters] logical templates from shLetterTemplates (.masks)
%
%   Output:
%     scores  [1 nLetters]
%
%   See also shOpponentMap, shLetterTemplates, shRunLetterTrials

    arguments
        map (:,:) double
        masks (:,:,:) logical
    end

    if ~isequal(size(map), [size(masks, 1) size(masks, 2)])
        error("shTemplateScores:size", ...
            "The map is %s but the templates are %s. Build the templates for the same MT output size.", ...
            mat2str(size(map)), mat2str([size(masks, 1) size(masks, 2)]));
    end

    nLetters = size(masks, 3);
    inside = reshape(double(masks), [], nLetters);
    outside = 1 - inside;
    values = map(:).';
    scores = (values*inside)./sum(inside, 1) - (values*outside)./sum(outside, 1);
end

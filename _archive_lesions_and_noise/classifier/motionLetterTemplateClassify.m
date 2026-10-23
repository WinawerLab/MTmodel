function out = motionLetterTemplateClassify(mtOpp, templates, letters)
% motionLetterTemplateClassify  Guess letter identity by correlating with masks.
%
% Each trial's time-averaged MT opponent map is Pearson-correlated with each
% letter's binary Sloan mask (center-cropped to the map). Predicted letter =
% argmax. Pearson is invariant to gain and offset, so a uniform amplitude drop
% does not by itself change the guess — only a change in spatial shape does.
%
% Inputs
%   mtOpp      [Y x X] or [Y x X x nTrials]
%   templates  [Y x X x nLetters] logical or double (1 = letter, 0 = ground)
%   letters    char row, length nLetters, e.g. 'CHON'
%
% Output struct
%   pred     nTrials x 1 char
%   scores   nTrials x nLetters Pearson r
%   letters  char row of template labels

letters = char(letters);
if isvector(letters)
    letters = letters(:)';
end

if ndims(mtOpp) < 3
    mtOpp = reshape(mtOpp, size(mtOpp, 1), size(mtOpp, 2), 1);
end

[y, x, nTrials] = size(mtOpp);
[ty, tx, nLetters] = size(templates);
if y ~= ty || x ~= tx
    error('motionLetterTemplateClassify:sizeMismatch', ...
        'Map is %dx%d but templates are %dx%d.', y, x, ty, tx);
end
if numel(letters) ~= nLetters
    error('motionLetterTemplateClassify:letterCount', ...
        'letters has %d entries but templates has %d pages.', ...
        numel(letters), nLetters);
end

scores = nan(nTrials, nLetters);
pred = repmat(' ', nTrials, 1);
for iT = 1:nTrials
    a = double(mtOpp(:, :, iT));
    a = a(:);
    for iL = 1:nLetters
        b = double(templates(:, :, iL));
        b = b(:);
        if std(a) == 0 || std(b) == 0
            scores(iT, iL) = NaN;
            continue;
        end
        r = corrcoef(a, b);
        scores(iT, iL) = r(1, 2);
    end
    row = scores(iT, :);
    row(isnan(row)) = -Inf;
    [~, idx] = max(row);
    pred(iT) = letters(idx);
end

out.pred = pred;
out.scores = scores;
out.letters = letters;
end

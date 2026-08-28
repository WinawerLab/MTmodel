function d = shSite2LastND(nume, deno)
% shSite2LastND  Get/set last Site-2 N and D scalars (instrumentation).
%
%   shSite2LastND(nume, deno)   record means after V1 numerator noise
%   d = shSite2LastND()         struct with Nmean, Dmean, or [] if none
%   shSite2LastND('clear')      drop the record
%
% Used by motionLetterTrials so each trial can store N/D alongside d'.

if nargin == 0
    d = getappdata(0, 'MTmodel_site2ND');
    return
end
if nargin == 1 && ischar(nume) && strcmp(nume, 'clear')
    if isappdata(0, 'MTmodel_site2ND')
        rmappdata(0, 'MTmodel_site2ND');
    end
    d = [];
    return
end
d = struct('Nmean', mean(nume(:)), 'Dmean', mean(deno(:)), ...
    'Nstd', std(nume(:)), 'Dstd', std(deno(:)));
setappdata(0, 'MTmodel_site2ND', d);
end

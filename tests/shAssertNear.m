function shAssertNear(a, b, tol, msg)
    if nargin < 3, tol = 1e-10; end
    if nargin < 4, msg = 'values not equal within tolerance'; end
    d = max(abs(a(:) - b(:)));
    shAssert(d < tol, sprintf('%s (max diff = %.3g)', msg, d));
end

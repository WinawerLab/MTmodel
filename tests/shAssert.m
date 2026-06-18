function shAssert(condition, msg)
    if ~condition
        error('shAssert:failed', '%s', msg);
    end
end

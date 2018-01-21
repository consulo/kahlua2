local meta = {}
function meta.__add(a, b)
    local c = {}
    for i = 1, math.max(#a, #b) do
        c[i] = (a[i] or 0) + (b[i] or 0)
    end
    return c
end

function meta.__sub(a, b)
    local c = {}
    for i = 1, math.max(#a, #b) do
        c[i] = (a[i] or 0) - (b[i] or 0)
    end
    return c
end

local a = setmetatable({}, meta)
local b = setmetatable({}, meta)
a[1] = 15
a[2] = 30
a[3] = 20

b[1] = 9
b[2] = 51

local c = a + b
testAssert(type(c) == "table")
testAssert(c[1] == 24)
testAssert(c[2] == 81)
testAssert(c[3] == 20)

local c = a - b
testAssert(type(c) == "table")
testAssert(c[1] == 6)
testAssert(c[2] == -21)
testAssert(c[3] == 20)

function endswith(s1, s2)
    return s1:sub(-#s2, -1) == s2
end

do
    local meta = {}
    meta.__index = meta
    meta.__newindex = meta

    local t = setmetatable(meta, meta)
    local ok, errmsg = pcall(function()
        return t.hello
    end)
    testAssert(not ok, "expected recursive metatable error")
    testAssert(endswith(errmsg, "loop in gettable"), "wrong error message: " .. errmsg)

    local ok, errmsg = pcall(function()
        t.hello = "world"
    end)
    testAssert(not ok, "expected recursive metatable error")
    testAssert(endswith(errmsg, "loop in settable"), "wrong error message: " .. errmsg)
end

do
    local t1, t2 = {}, {}
    local ok, errmsg = pcall(function()
        return t1 + t2
    end)
    testAssert(not ok)
    --assert(endswith(errmsg, "no meta function was found for __add"))

    local ok, errmsg = pcall(function()
        local x = (-t1)
    end)
    testAssert(not ok)

    local ok, errmsg = pcall(function()
        return t1 <= t2
    end)
    testAssert(not ok)

    local ok, errmsg = pcall(function()
        return t1 == t2
    end)
    testAssert(ok)
end

do
    local meta = { __lt = function(a, b)
        return true
    end }
    local t1 = setmetatable({}, meta)
    local t2 = setmetatable({}, meta)
    testAssert(t1 < t2)
    testAssert(t2 < t1)
    testAssert(not (t1 <= t2))
    testAssert(not (t2 <= t1))
end

do
    local meta1 = { __lt = function(a, b)
        return true
    end }
    local meta2 = { __lt = function(a, b)
        return false
    end }
    local t1 = setmetatable({}, meta1)
    local t2 = setmetatable({}, meta2)
    local ok, errmsg = pcall(function()
        assert(t1 < t2)
    end)
    testAssert(not ok)
end

do
    local meta = { __unm = function(a)
        return { -a[1] }
    end }
    local t1 = setmetatable({ 12 }, meta)
    local t2
    local ok, errmsg = pcall(function()
        t2 = -t1
    end)
    testAssert(ok)
    testAssert(t2[1] == -12)
end

do
    local meta = { __eq = function(a, b)
        return rawequal(a, b)
    end }
    local t1 = setmetatable({}, meta)
    local t2 = setmetatable({}, meta)
    testAssert(t1 == t1)
    testAssert(not (t1 == t2))
    testAssert(not (t1 ~= t1))
    testAssert(t1 ~= t2)
end

do
    local function compare_true(a, b)
        return true
    end
    local function other_compare_true(a, b)
        return true
    end
    local meta1 = { __lt = compare_true, __eq = compare_true }
    local meta2 = { __lt = compare_true, __eq = compare_true }
    local meta3 = { __lt = other_compare_true, __eq = other_compare_true }
    local t1 = setmetatable({}, meta1)
    local t2 = setmetatable({}, meta2)
    local t3 = setmetatable({}, meta3)
    local ok, result = pcall(function()
        return (t1 == t2)
    end)
    testAssert(ok) -- No error raised
    testAssert(result) -- Expected result
    local ok, result = pcall(function()
        return (t1 < t2)
    end)
    testAssert(ok) -- No error raised
    testAssert(result) -- Expected result
    local ok, errmsg = pcall(function()
        return (t1 < t3)
    end)
    testAssert(not ok) -- _lt should raise an error if the metamethods differ
    assert(endswith(errmsg, "not defined for operand"))
    local ok, result = pcall(function()
        return (t1 == t3)
    end)
    testAssert(ok) -- __eq must not rise any errors if the metamethods differ
    testAssert(not result) -- __eq should return false instead
end

do
    local lt = function(a, b)
        return a.val < b.val
    end
    local le = function(a, b)
        return a.val <= b.val
    end
    local eq = function(a, b)
        return a.val == b.val
    end
    local meta1 = { __lt = lt, __le = le, __eq = eq }
    local t1 = setmetatable({ val = 1 }, meta1)
    local meta2 = { __lt = lt, __le = le, __eq = eq }
    local t2 = setmetatable({ val = 2 }, meta1)
    -- comparing t1 with t1
    local ok, res = pcall(function()
        return (t1 < t1)
    end)
    testAssert(ok)
    testAssert(res == false)
    local ok, res = pcall(function()
        return (t1 <= t1)
    end)
    testAssert(ok)
    testAssert(res == true)
    local ok, res = pcall(function()
        return (t1 == t1)
    end)
    testAssert(ok)
    testAssert(res == true)
    -- comparing t1 with t2
    local ok, res = pcall(function()
        return (t1 < t2)
    end)
    testAssert(ok)
    testAssert(res == true)
    local ok, res = pcall(function()
        return (t1 <= t2)
    end)
    testAssert(ok)
    testAssert(res == true)
    local ok, res = pcall(function()
        return (t1 == t2)
    end)
    testAssert(ok)
    testAssert(res == false)
    -- comparing t2 with t1
    local ok, res = pcall(function()
        return (t2 < t1)
    end)
    testAssert(ok)
    testAssert(res == false)
    local ok, res = pcall(function()
        return (t2 <= t1)
    end)
    testAssert(ok)
    testAssert(res == false)
    local ok, res = pcall(function()
        return (t2 == t1)
    end)
    testAssert(ok)
    testAssert(res == false)
end

do
    testAssert("a" ~= nil)
end

do
    local meta1 = { __eq = function(a, b)
        return true
    end }
    local meta2 = { __eq = function(a, b)
        return false
    end }
    local t1 = setmetatable({}, meta1)
    local t2 = nil
    testAssert(t1 ~= t2)
    testAssert(t2 ~= t1)
    t2 = {}
    testAssert(t1 ~= t2)
    testAssert(t2 ~= t1)
    t2 = setmetatable(t2, meta2)
    testAssert(t1 ~= t2)
    testAssert(t2 ~= t1)
end

do
    local table = {}
    local meta1 = {}
    local meta2 = {}
    setmetatable(table, meta1)
    meta1.__metatable = 'FORBIDEN'
    testAssert(getmetatable(table) == 'FORBIDEN')
    local ok, errormsg = pcall(function()
        setmetatable(table, meta2)
    end)
    testAssert(not ok)
    assert(endswith(errormsg, "cannot change a protected metatable"), errormsg)
end


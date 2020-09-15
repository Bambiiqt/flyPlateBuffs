local _, fPB = ...

local L = setmetatable({}, {__index = function(L,key)
	return key
end})

fPB.L = L

function exports.logn(n, x)
	return math.log(x) / math.log(n)
end

function exports.reverse(t)
	local nt = {} -- new table
	local size = #t + 1
	for k,v in ipairs(t) do
		nt[size - k] = v
	end
	return nt
end

function exports.tobits(num)
	local t={}
	while num>0 do
		rest=num%2
		t[#t+1]=rest
		num=(num-rest)/2
	end
	return reverse(t)
end

function exports.table_slice(values,i1,i2)
	local res = {}
	local n = #values
	-- default values for range
	i1 = i1 or 1
	i2 = i2 or n
	if i2 < 0 then
		i2 = n + i2 + 1
	elseif i2 > n then
		i2 = n
	end
	if i1 < 1 or i1 > n then
		return {}
	end
	local k = 1
	for i = i1,i2 do
		res[k] = values[i]
		k = k + 1
	end
	return res
end

function exports.split(str, sSeparator, nMax, bRegexp)
	assert(sSeparator ~= '')
	assert(nMax == nil or nMax >= 1)

	local aRecord = {}

	if #str > 0 then
		local bPlain = not bRegexp
		nMax = nMax or -1

		local nField, nStart = 1, 1
		local nFirst,nLast = str:find(sSeparator, nStart, bPlain)
		while nFirst and nMax ~= 0 do
			-- if nStart == nil then
				-- print('aRecord: ' .. textutils.serialize(aRecord))
				-- print('nMax: ' .. nMax)
				-- print('nFirst: ' .. nFirst)
				-- -- nStart = nFirst
				-- print('nStart: ' .. nStart)
			-- end
			if nFirst - nStart >= 1 or (nStart > 1 and nFirst < #str) then
				aRecord[nField] = str:sub(nStart, nFirst-1)
				nField = nField+1
			end
			nStart = nLast+1
			nFirst,nLast = str:find(sSeparator, nStart, bPlain)
			nMax = nMax-1
		end
		aRecord[nField] = str:sub(nStart)
	end

	return aRecord
end

function exports.pcallResume(...)
	return coroutine.resume(...)
end

function exports.erroredResume(...)
	local rtn = {exports.pcallResume(...)}

	if rtn[1] then
		return unpack(exports.table_slice(rtn, 2))
	else
		error(rtn[2])
	end
end
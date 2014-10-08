local logging = require('apis/logging')
local utils   = require('apis/utils')

local matParts = 4
local matSize = 32

function exports.validateMAT(mat, silent)
	local warn

	if silent then
		warn = function(msg)
			logging.warn(msg)
		end
	else
		warn = function(msg)
			error(msg)
		end
	end

	if type(mat) ~= 'table' then warn('MAT address must be in table form, got: ' .. type(mat)) return false end
	if type(mat.parts) ~= 'table' then warn('MAT address must have parts, got: ' .. type(mat.parts)) return false end
	if #mat.parts ~= matParts then warn('MAT address must have 4 parts, got: ' .. #mat.parts) return false end

	-- Check all the parts of the MAT address
	for i = 1, matParts do
		if mat.parts[i] > 255 then
			warn('MAT address parts cannot be greater than 255, #' .. tostring(i) .. ': ' .. tostring(mat.parts[i]))
			return false
		elseif mat.parts[i] < 0 then
			warn('MAT address parts cannot be less than 0, #' .. tostring(i) .. ': ' .. tostring(mat.parts[i]))
			return false
		end
	end

	if type(mat.netBits) == 'number' and mat.netBits > matSize then warn('Netmasks cannot be longer than ' .. tostring(matSize) .. ', got: ' .. tostring(mat.netBits)) end
	if type(mat.netBits) == 'number' and mat.netBits < 0 then warn('Netmasks cannot be negative, got: ' .. tostring(mat.netBits)) end
end

function exports.parse(mat)
	local m, subnetStart

	local mata = {
		matchBits = matSize
	}

	-- Match the subnet
	m = {mat:find('/(%d+)$')}

	if m[1] and #m == 3 then
		mata.matchBits = tonumber(m[3])
		mat = mat:sub(1, m[1] - 1)
	end

	local matArr = utils.split(mat, ':')
	local expanderFound = false
	local outofRow = false
	local expander
	local remove = 0

	-- Expand the expander
	local newMatArr = {}

	for i, v in pairs(matArr) do
		if v == '' then
			for _ = 1, (matParts - #matArr + 1) do
				table.insert(newMatArr, 0)
			end
		else
			table.insert(newMatArr, tonumber(v))
		end
	end

	mata.parts = newMatArr

	local ok, err = pcall(exports.validateMAT, mata)

	if not ok then
		error('Error parsing mat address: ' .. mat .. ': ' .. err, 2)
	end

	return mata
end

function exports.toString(mata)
	local expander = false
	local expanderLoc
	local expanderNum
	local outofRow = false
	local foundZero = false

	validateMAT(mata)

	-- Find where to put an expander
	for i, v in ipairs(mata.parts) do
		if v == 0 then
			if expander and not outofRow then
				expanderNum = expanderNum + 1
			elseif not expander and foundZero then
				expander = true
				expanderNum = 2
				outofRow = false
				foundZero = false
			elseif not expander and not foundZero then
				foundZero = true
				expanderLoc = i
			end
		else
			outofRow = true
		end
	end

	local res

	if expander then
		-- Get the parts before the expander
		res = table.concat(utils.table_slice(mata.parts, 1, expanderLoc - 1), ':') ..
		       '::' ..
		       -- Get the parts after the expander
		       table.concat(utils.table_slice(mata.parts, expanderLoc + expanderNum), ':')
	else
		res = table.concat(mata.parts, ':')
	end

	-- Add the net bits to the end
	if type(mata.matchBits) == 'number' and mata.matchBits ~= matSize then
		res = res .. '/' .. tostring(mata.matchBits)
	end

	return res
end

-- MAT Address Syntax
-- 4 sections each 1 byte long
-- :: expands to as many 0s as necesary
-- /<num> specify how many bits to include in the subnet mask
-- Examples:
-- :: blank mat
-- 127::/8 localhost subnet (gos into the local buffer)
-- 10::/8 private network subnet (these are the mats that computers on private networks should get)
-- 10::1 private network router
-- 224::/8 multicast subnet
-- 240:255::/8 dev subnet ->
--   240:255:224:0/24 multicast dev subnet

function exports.createAddrMask(bits)
	if bits > matSize then error('Netmasks cannot be larger than ' .. tostring(matSize) .. ' got: ' .. tostring(bits)) end

	return bit.blshift(2^bits - 1, matSize - bits)
end

function exports.createMatcher(mat)
	exports.validateMAT(mat)

	if type(mat.matchBits) ~= 'number' then error('Match bits are required for creating a matcher, got: ' .. type(mat.matchBits)) end

	local addr = { mask = exports.createAddrMask(mat.matchBits), parts = mat.parts, matchBits = mat.matchBits }

	addr.matchNum = bit.band(addr.mask, exports.toNum(mat))

	return addr
end

function exports.match(input, matcher)
	exports.validateMAT(input)
	exports.validateMAT(matcher)
	
	if (type(matcher.matchNum) ~= 'number' or type(matcher.mask ~= 'number')) and type(matcher.matchBits) == 'number' then
		matcher = exports.createMatcher(matcher)
	end
	if type(matcher.matchBits) == 'number' then
		return bit.band(exports.toNum(input), matcher.mask) == matcher.matchNum
	end

	return toNum(input) == toNum(matcher)
end

function exports.toNum(mat)
	exports.validateMAT(mat)
	return bit.blshift(mat.parts[1], 24) + bit.blshift(mat.parts[2], 16) + bit.blshift(mat.parts[3], 8) + mat.parts[4]
end

undefined = exports.createMatcher(exports.parse('::'))

function exports.wrap(mat)
	if type(mat) == 'string' then
		return exports.parse(mat)
	elseif type(mat) == 'table' and type(mat.parts) == 'table' and #mat.parts == matParts then
		return mat
	end
end
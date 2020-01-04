local util = {}

function util.removeMany(tbl, start, run)
	local len = #tbl
	for i = start, len - run do
		tbl[i] = tbl[i + run]
	end
	for i = 0, run - 1 do
		tbl[len - i] = nil
	end
end

function util.concat(...)
	local res = { n = 0; }

	for _, tbl in ipairs({...}) do
		for i = 1, tbl.n or #tbl do
			res.n = res.n + 1
			res[res.n] = tbl[i]
		end
	end
	
	return res
end

return util

local coroy = {}

local old = {}
for k, v in pairs(coroutine) do
	old[k] = v
end

setmetatable(coroy, { __call = function()
	local function yield(...)
		return old.yield(coroutine.running(), yield, table.pack(...))
	end
	
	return yield
end })

local data_yields = setmetatable({}, {
	__mode = 'k';
	__index = function(data_yields, co)
		if type(co) ~= 'thread' then
			error('bad coroutine')
		end
		local yield = coroy()
		data_yields[co] = yield
		return yield
	end;
})

function coroy.resume(co, yields, args)
	local data = data_yields[co]

	while true do
		local res = table.pack(old.resume(co, table.unpack(args, 1, args.n or #args)))

		local ok = res[1]
		res = table.pack(table.unpack(res, 2, res.n))

		if not ok then
			return 'error', res
		end

		if coroutine.status(co) == 'dead' then
			return nil, res
		end

		local cor, _, res = table.unpack(res, 1, res.n)

		if _ == data then
			return nil, res
		else
			local found = false
			for i, yield in ipairs(yields) do
				if yield == _ then
					found = true
					break
				end
			end

			if found then
				return _, res
			else
				args = table.pack(old.yield(cor, _, res))
			end
		end
	end
end

function coroutine.resume(co, ...)
	local _, res = coroy.resume(co, {}, table.pack(...))
	if _ == 'error' then
		return false, table.unpack(res, 1, res.n)
	elseif _ == nil then
		return true, table.unpack(res, 1, res.n)
	end
end

function coroutine.yield(...)
	return data_yields[coroutine.running()](...)
end

return coroy


-- do
-- 	local promise_y = coroy()
--
-- 	local co = coroutine.create(function()
-- 		local log_y = coroy()
--
-- 		local co = coroutine.create(function()
-- 			local co = coroutine.create(function()
-- 				local a, b = 0, 1
-- 				while true do
-- 					log_y(promise_y(string.format('a: %d b: %d', a, b)))
-- 					coroutine.yield(a)
--
-- 					local tmp = a + b
-- 					a = b
-- 					b = tmp
-- 				end
-- 			end)
--
-- 			while coroutine.status(co) ~= 'dead' do
-- 				local res = table.pack(coroutine.resume(co))
--
-- 				if res[1] then
-- 					if coroutine.status(co) == 'dead' then
-- 						return table.unpack(res, 2, res.n)
-- 					else
-- 						print('fib', res[2])
-- 					end
-- 				else
-- 					error(res[2])
-- 				end
-- 			end
-- 		end)
--
-- 		while coroutine.status(co) ~= 'dead' do
-- 			local _, res = coroy.resume(co, {log_y}, {})
--
-- 			if _ == log_y then
-- 				print('log', table.unpack(res, 1, res.n))
-- 			elseif _ == 'error' then
-- 				error(res[1])
-- 			elseif coroutine.status(co) == 'dead' then
-- 				return table.unpack(res, 1, res.n)
-- 			else
-- 				print('bad', 'log')
-- 			end
-- 		end
-- 	end)
--
-- 	local args = {}
-- 	while coroutine.status(co) ~= 'dead' do
-- 		local _, res = coroy.resume(co, {promise_y}, args)
--
-- 		if _ == promise_y then
-- 			os.execute('sleep 1')
-- 			args = res
-- 		elseif _ == 'error' then
-- 			error(res[1])
-- 		elseif coroutine.status(co) == 'dead' then
-- 			return table.unpack(res, 1, res.n)
-- 		else
-- 			print('bad', 'promise')
-- 		end
-- 	end
-- end

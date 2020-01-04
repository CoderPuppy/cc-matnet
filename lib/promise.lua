local coroy = require './coroy'
local util = require './util'

local Promise = {}

setmetatable(Promise, { __call = function(_, fn)
	local prom = {}

	local handlers = {}

	setmetatable(prom, { __call = function(_, cb)
		if prom.resolved then
			cb(table.unpack(prom.v, 1, prom.v.n))
		else
			handlers[#handlers + 1] = cb
		end
	end })

	local function resolve(...)
		if prom.resolved then
			error('already resolved')
		end

		prom.resolved = true
		prom.v = table.pack(...)

		for _, handler in ipairs(handlers) do
			handler(...)
		end
		handlers = {}
	end

	if fn then
		fn(resolve)
	end

	return setmetatable({}, {
		__index = prom;
		__newindex = function()
			error('readonly table')
		end;
		__call = function(_, ...)
			return prom(...)
		end;
		__metatable = 'readonly';
		__pairs = function(_)
			return pairs(prom)
		end;
	}), resolve
end })

function Promise.ret(...)
	local prom, resolve = Promise()
	resolve(...)
	return prom
end

function Promise.raw_flat_map(prom, ...)
	local fn, args

	local function run(prom)
		return Promise(function(resolve)
			prom(function(...)
				local args_ = util.concat(args, table.pack(...))
				xpcall(function()
					fn(table.unpack(args_, 1, args_.n))(resolve)
				end, function(msg)
					local level = 5
					local stack = {}
					while true do
						local _, msg = pcall(error, '@', level)
						if msg == '@' then break end
						stack[#stack + 1] = msg
						level = level + 1
					end
					resolve(false, msg, stack)
				end)
			end)
		end)
	end

	if type(prom) == 'function' then
		args = table.pack(...)
		fn = prom
		return run
	else
		args = table.pack(...)
		fn = args[1]
		args = table.pack(table.unpack(args, 2, args.n))
		return run(prom)
	end
end

function Promise.raw_map(prom, ...)
	local fn, args

	local function run(prom)
		return Promise.raw_flat_map(prom, function(...)
			local args_ = util.concat(args, table.pack(...))
			return Promise.ret(fn(table.unpack(args_, 1, args_.n)))
		end)
	end

	if type(prom) == 'function' then
		args = table.pack(...)
		fn = prom
		return run
	else
		args = table.pack(...)
		fn = args[1]
		args = table.pack(table.unpack(args, 2, args.n))
		return run(prom)
	end
end

function Promise.flat_map(prom, ...)
	local fn, args

	local function run(prom)
		return Promise.raw_flat_map(prom, function(ok, ...)
			if ok then
				local args_ = util.concat(args, table.pack(...))
				return fn(table.unpack(args_, 1, args_.n))
			else
				return Promise.ret(ok, ...)
			end
		end)
	end

	if type(prom) == 'function' then
		args = table.pack(...)
		fn = prom
		return run
	else
		args = table.pack(...)
		fn = args[1]
		args = table.pack(table.unpack(args, 2, args.n))
		return run(prom)
	end
end

function Promise.map(prom, ...)
	local fn, args

	local function run(prom)
		return Promise.flat_map(prom, function(...)
			local args_ = util.concat(args, table.pack(...))
			return fn(table.unpack(args_, 1, args_.n))
		end)
	end

	if type(prom) == 'function' then
		args = table.pack(...)
		fn = prom
		return run
	else
		args = table.pack(...)
		fn = args[1]
		args = table.pack(table.unpack(args, 2, args.n))
		return run(prom)
	end
end

do
	Promise.wait = coroy()

	local waiting = setmetatable({}, {
		__index = function(waiting, prom)
			local r = {}
			waiting[prom] = r
			return r
		end;
	})

	local ticking = false
	local queue = {}

	local function tick()
		if ticking then
			return
		end
		ticking = true

		local i = 1
		while i <= #queue do
			local prom = queue[i]
			
			if not rawget(waiting, prom) then
				error('bad')
			end

			local procs = waiting[prom]
			waiting[prom] = nil

			for proc in pairs(procs) do
				proc.resume()
			end

			i = i + 1
		end

		util.removeMany(queue, 1, i - 1)

		ticking = false
	end

	function Promise.proc(co)
		if type(co) == 'function' then co = coroutine.create(co) end

		local proc = {}

		proc.prom, proc.resolve = Promise()

		proc.co = co
		proc.wait = Promise.ret()
		
		function proc.resume()
			local _, res = coroy.resume(co, {Promise.wait}, {proc.wait.v})

			if _ == Promise.wait then
				local prom = res[1]
				proc.wait = prom
				local was = rawget(waiting, prom)
				waiting[prom][proc] = true
				if not was then
					prom(function()
						queue[#queue + 1] = prom
						tick()
					end)
				end
			elseif _ == 'error' then
				proc.resolve(false, table.unpack(res, 1, res.n))
			elseif coroutine.status(proc.co) == 'dead' then
				proc.resolve(true, table.unpack(res, 1, res.n))
			else
				print('bad', 'promise')
			end
		end

		proc.resume()

		return proc.prom
	end
end

return Promise

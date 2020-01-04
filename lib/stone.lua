local uv = require 'luv'
local nn = require 'nn'

local Channel = require './channel'

return function(addr)
	local id = tostring({})

	local inp_chan = Channel()

	local ipc = nn.socket(nn.AF_SP, nn.NN_PAIR)
	ipc:bind('inproc://' .. id)

	local async = uv.new_async(function()
		print('reading')
		while true do
			local msg = ipc:recv(nil, nn.NN_DONTWAIT)
			if msg then
				inp_chan.put(msg)
			else
				break
			end
		end
	end)

	local thread = uv.new_thread(function(addr, id, async)
		xpcall(function()
			local nn = require 'nn'
			local uv = require 'luv'

			local sock = nn.socket(nn.AF_SP, nn.NN_BUS)
			sock:bind(addr)

			local ipc = nn.socket(nn.AF_SP, nn.NN_PAIR)
			ipc:connect('inproc://' .. id)

			local poll = nn.poll()
			local sock_poll = poll:add(sock, true, true)
			local ipc_poll = poll:add(ipc, true, true)
			
			local out_queue = {}
			local in_queue = {}

			local function flush(queue, sock)
				local sent = 0
				for _, msg in ipairs(queue) do
					if sock:send(msg, nn.NN_DONTWAIT) then
						sent = sent + 1
					else
						break
					end
				end
				local len = #queue
				for i = 1, len - sent do
					queue[i] = queue[i + sent]
				end
				for i = 0, sent - 1 do
					queue[len - i] = nil
				end
			end

			while true do
				if poll:poll() > 0 then
					if poll:inp(sock_poll) then
						while true do
							local msg = sock:recv(nil, nn.NN_DONTWAIT)
							if msg then
								in_queue[#in_queue + 1] = msg
							else
								break
							end
						end
						flush(in_queue, ipc)
						uv.async_send(async)
					end

					if poll:out(ipc_poll) then
						flush(in_queue, ipc)
						uv.async_send(async)
					end

					if poll:inp(ipc_poll) then
						while true do
							local msg = ipc:recv(nil, nn.NN_DONTWAIT)
							if msg then
								out_queue[#in_queue + 1] = msg
							else
								break
							end
						end
						flush(out_queue, sock)
					end

					if poll:out(sock_poll) then
						flush(out_queue, sock)
					end
				end
			end
		end, function(msg)
			print 'nanomsg listen thread err'
			print('err: ' .. msg)
			local level = 5
			local stack = {}
			while true do
				local _, msg = pcall(error, '@', level)
				if msg == '@' then break end
				print(msg)
				level = level + 1
			end
		end)
	end, addr, id, async)

	local sock = {}

	function sock.put(msg)
		ipc:send(msg)
	end

	function sock.get()
		return inp_chan.get()
	end

	return sock
end

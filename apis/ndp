function createDaemon(opts)
	if type(opts) ~= 'table' then error('You must specify an interface and a routes table') end

	if type(opts.inter) ~= 'table' then error('You must pass a valid interface, got: ' .. type(opts.inter)) end
	if type(opts.routes) ~= 'table' then error('You must pass a valid routes table, got: ' .. type(opts.routes)) end

	local server = {}

	function server.run()
		return net.startDaemon('ndpd')
	end

	function server.daemon()
		while true do
			local _, packet = coroutine.yield()

			repeat
				if _ == 'lcp' then
					if packet.command == 'daemon:stop' then
						return
					end
				elseif _ == 'network' then
					if packet.type == 'ndp' then
						local data = textutils.unserialize(packet.data)

						if data.command == nil then break end

						if data.command == 'neighbor:lookup' and mat.match(mat, data.mat) then
							
						end
					end
				end
			until true
		end
	end

	net.addDaemon('ndpd', server.daemon)

	return server
end

function createClient(opts)
	if type(opts) ~= 'table' then error('You must specify an interface and a routes table') end

	if type(opts.inter) ~= 'table' then error('You must pass a valid interface, got: ' .. type(opts.inter)) end
	if type(opts.routes) ~= 'table' then error('You must pass a valid routes table, got: ' .. type(opts.routes)) end
	
	local client = {}

	function client.run()
		return true
	end

	return client
end
function createServer(opts)
	if type(opts) ~= 'table' then error('You must specify a network') end

	if type(opts.net) ~= 'table' then error('You must pass a valid network, got: ' .. type(opts.net)) end

	local net = opts.net

	local server = {}

	function server.run()
		net.startDaemon('dnsd')
	end

	net.addDaemon('dnsd', function(net)
		while true do
			local _, packet = coroutine.yield()

			if _ == 'lcp' then
				if packet.command == 'daemon:stop' then
					return
				end
			elseif _ == 'network' and packet.type == 'dns' then

			end
		end
	end)

	return server
end
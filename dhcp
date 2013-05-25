function createServer(net)
	local server = {}

	function server.run()
		return false
	end

	function server.daemon(mat)
		while true do
			local _, packet = coroutine.yield()

			if _ == 'lcp' then
				if packet.command == 'daemon:stop' then
					return
				end
			elseif _ == 'network' then
				if packet.type == 'dhcp' then
					
				end
			end
		end
	end

	return server
end

function createClient(net)
	local client = {}

	function client.run()
		return true
	end

	function client.discover()
		net.send({
			to = '-1.-1.-1.-1'
		})
	end

	return client
end
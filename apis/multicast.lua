local mat = require('apis/mat')

function initInter(net, routes, inters, addr)
	if addr == nil then addr = '224::/8' end
	addr = mat.wrap(addr)
	-- Dunno if this will catch any arrays
	if type(#inters) ~= 'number' or #inters <= 0 then
		inters = { inters }
	end

	for i = 1, #inters do
		routes.add(addr, { inter = inters[i], id = -1 })
	end
end

function listen(net, addr)
	addr = mat.wrap(addr)
	net.listen(addr)
	-- TODO: Make this tell routers that this network needs packets for this multicast address
end
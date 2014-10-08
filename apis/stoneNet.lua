id = os.getComputerID()

local logging = require('apis/logging')
local devices = require('../peak/devices')
local utils   = require('apis/utils')

local interID = 0

function exports.createInterface(opts)
	if type(opts) ~= 'table' then error('You must specify device, channel and matables') end

	if not devices.isDevice(opts.device) then error('You must pass a valid device, got: ' .. type(opts.device), 2) end
	if opts.device.type ~= 'modem'       then error('Device must be a modem, got: ' .. opts.device.type, 2) end

	if type(opts.channel) ~= 'number' then error('Channel must be a number, got: ' .. type(opts.channel), 2) end
	if opts.channel <= 0              then error('Channel must be greater than 0, got: ' .. tostring(opts.channel), 2) end
	if opts.channel >= 65535          then error('Channel must be less than 65535, got: ' .. tostring(opts.channel), 2) end
	if type(opts.matables) ~= 'table' then error('You must pass a valid matable instance, got: ' .. type(opts.matables), 2) end

	local device = opts.device
	local modem = device.api
	local channel = opts.channel

	local inter = { id = id, type = 'eth' }
	local daemons = {}
	local runningDaemons = {}

	inter.name = inter.type .. tostring(interID)
	interID = interID + 1

	function inter.addDaemon(name, fn)
		if type(fn) ~= 'function' then
			return false
		end

		daemons[name] = fn

		return true
	end

	local running = false

	function inter.run()
		if running then return true end

		modem.open(channel)

		running = modem.isOpen(channel)

		return running
	end

	function inter.stop()
		for name in pairs(daemons) do
			if type(runningDaemons[name]) == 'thread' and not inter.stopDaemon(name) then return false end
		end

		modem.close(channel)

		if modem.isOpen(channel) then return false end

		return true
	end

	function inter.startDaemon(name)
		local fn = daemons[name]

		-- Not really necessary
		-- if type(fn) ~= 'function' then return false end

		logging.debug('Starting Daemon: ' .. name)

		local daemon = coroutine.create(fn)
		runningDaemons[name] = daemon
		utils.erroredResume(daemon, inter)

		return true
	end

	function inter.stopDaemon(name)
		local daemon = runningDaemons[name]

		-- Handle daemons that aren't started
		if type(daemon) ~= 'thread' then return true end

		logging.debug(inter.name .. ': Stopping Daemon: ' .. name)

		utils.erroredResume(daemon, 'lcp', {
			command = 'daemon:stop'
		})

		if coroutine.status(daemon) == 'dead' then
			runningDaemons[name] = nil
		else
			logging.warn(name .. ' didn\'t stop when told to')

			return false
		end

		return true
	end

	function inter.handleEvent(ev)
		if ev[1] ~= 'modem_message' or ev[2] ~= device.id or ev[3] ~= channel then
			return false
		end

		local frame = exports.parseEvent(ev)

		if frame.to ~= id and frame.to ~= -1 and not inter.promisc then
			return false
		end

		for name, daemon in pairs(runningDaemons) do
			utils.erroredResume(daemon, 'link', frame)
		end

		return true
	end

	function inter.send(frame)
		modem.transmit(channel, channel, exports.genMsg(frame))
	end

	return inter
end

function exports.genMsg(frame)
	return textutils.serialize(frame)
end

function exports.parseEvent(ev)
	local frame = {}
	local data = textutils.unserialize(ev[5]) -- This should change

	frame.to = data.to
	frame.from = data.from
	frame.data = data.data
	frame.type = data.type
	frame.channel = ev[2]
	frame.event = ev

	return frame
end
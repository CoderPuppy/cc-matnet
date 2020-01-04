local require = require 'nsrq' ()

local uv = require 'luv'
local Promise = require '../lib/promise'

local stone = require '../lib/stone' ('ipc:///tmp/matnet-a.sock')
local gold = require '../lib/gold' ()
gold.add(stone)

uv.run()

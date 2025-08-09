local addonName, addon = ...
addon.DataHub = addon.DataHub or {}
local DataHub = addon.DataHub

local eventFrame = CreateFrame("Frame")
local driver = CreateFrame("Frame")

DataHub.streams = {}
DataHub.eventMap = {}
DataHub.polling = {}

local tinsert = table.insert
local tremove = table.remove
local ipairs = ipairs
local pairs = pairs

local function acquireRow(stream)
	local row = tremove(stream.pool)
	if row then
		wipe(row)
	else
		row = {}
	end
	return row
end

local function releaseRows(stream)
	for i = #stream.snapshot, 1, -1 do
		local row = stream.snapshot[i]
		stream.snapshot[i] = nil
		stream.pool[#stream.pool + 1] = row
	end
end

local function runUpdate(stream)
	releaseRows(stream)
	if stream.update then stream.update(stream) end
	for cb in pairs(stream.subscribers) do
		pcall(cb, stream.snapshot, stream.name)
	end
end

eventFrame:SetScript("OnEvent", function(_, event, ...)
	local streams = DataHub.eventMap[event]
	if streams then
		for stream in pairs(streams) do
			DataHub:RequestUpdate(stream.name)
		end
	end
end)

function DataHub:UpdateDriver()
	if next(self.polling) then
		driver:SetScript("OnUpdate", function(_, elapsed)
			for _, stream in pairs(DataHub.polling) do
				stream.elapsed = stream.elapsed + elapsed
				if stream.elapsed >= stream.interval then
					stream.elapsed = 0
					DataHub:RequestUpdate(stream.name)
				end
			end
		end)
	else
		driver:SetScript("OnUpdate", nil)
	end
end

function DataHub:RegisterStream(name, opts)
	if self.streams[name] then return self.streams[name] end
	local stream = {
		name = name,
		snapshot = {},
		pool = {},
		subscribers = {},
		events = {},
		update = opts and opts.update,
		throttle = opts and opts.throttle or 0.1,
		interval = opts and opts.interval,
		elapsed = 0,
	}
	self.streams[name] = stream

	if opts and opts.events then
		for _, event in ipairs(opts.events) do
			self:RegisterEvent(stream, event)
		end
	end

	if stream.interval and stream.interval > 0 then
		self.polling[name] = stream
		self:UpdateDriver()
	end

	self:RequestUpdate(name)
	return stream
end

function DataHub:UnregisterStream(name)
	local stream = self.streams[name]
	if not stream then return end

	for event in pairs(stream.events) do
		self:UnregisterEvent(stream, event)
	end

	self.polling[name] = nil
	self:UpdateDriver()

	releaseRows(stream)
	self.streams[name] = nil
end

function DataHub:RegisterEvent(stream, event)
	stream.events[event] = true
	self.eventMap[event] = self.eventMap[event] or {}
	self.eventMap[event][stream] = true
	eventFrame:RegisterEvent(event)
end

function DataHub:UnregisterEvent(stream, event)
	stream.events[event] = nil
	local map = self.eventMap[event]
	if map then
		map[stream] = nil
		if not next(map) then
			self.eventMap[event] = nil
			eventFrame:UnregisterEvent(event)
		end
	end
end

function DataHub:RequestUpdate(name)
	local stream = type(name) == "table" and name or self.streams[name]
	if not stream or stream.pending then return end
	stream.pending = true
	C_Timer.After(stream.throttle, function()
		stream.pending = nil
		runUpdate(stream)
	end)
end

function DataHub:AcquireRow(name)
	local stream = type(name) == "table" and name or self.streams[name]
	if not stream then return {} end
	return acquireRow(stream)
end

function DataHub:GetSnapshot(name)
	local stream = self.streams[name]
	return stream and stream.snapshot
end

function DataHub:Subscribe(name, callback)
	local stream = self.streams[name]
	if stream and callback then stream.subscribers[callback] = true end
end

function DataHub:Unsubscribe(name, callback)
	local stream = self.streams[name]
	if stream and callback then stream.subscribers[callback] = nil end
end

function DataHub:ExportCSV(name)
	local snapshot = self:GetSnapshot(name)
	if not snapshot or not snapshot[1] then return "" end

	local headers = {}
	for k in pairs(snapshot[1]) do
		headers[#headers + 1] = k
	end
	local lines = {}
	lines[1] = table.concat(headers, ",")
	for _, row in ipairs(snapshot) do
		local values = {}
		for i, key in ipairs(headers) do
			local v = row[key]
			if type(v) == "string" then
				v = v:gsub('"', '""')
				values[i] = '"' .. v .. '"'
			else
				values[i] = tostring(v or "")
			end
		end
		lines[#lines + 1] = table.concat(values, ",")
	end
	return table.concat(lines, "\n")
end

return DataHub

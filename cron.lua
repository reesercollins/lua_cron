CronFields = {
	SECOND = 1,
	MINUTE = 2,
	HOUR = 3,
	DAY_OF_MONTH = 4,
	MONTH = 5,
	DAY_OF_WEEK = 6,
	YEAR = 7
}

CronConstants = {
	MAX_SECONDS = 60,
	MAX_MINUTES = 60,
	MAX_HOURS = 24,
	MAX_DAYS_OF_WEEK = 8, -- This is because sunday can be either 0 or 7
	MAX_DAYS_OF_MONTH = 31,
	MAX_MONTHS = 13, -- This is because months are 1-indexed
	MAX_DAYS_IN_YEAR = 365,

	DAYS = { "SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN" },
	MONTHS = { "JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC" }

}

CronExp = {}

function CronExp.pushToFields(fields, field)
	if (not fields) or field == -1 then return end
	if table.HasValue(fields, field) then return end
	for i=0,7 do
		if fields[i] == -1 then
			fields[i] = field
			return
		end
	end
end

function CronExp.addToField(field, date, value)
	if field == -1 then return -1 end
	if field == CronFields.SECOND then
		date.sec = date.sec + value
	elseif field == CronFields.MINUTE then
		date.min = date.min + value
	elseif field == CronFields.HOUR then
		date.hour = date.hour + value
	elseif field == CronFields.DAY_OF_MONTH then
		date.day = date.day + value
	elseif field == CronFields.MONTH then
		date.month = date.month + value
	elseif field == CronFields.DAY_OF_WEEK then
		date.wday = date.wday + value
	elseif field == CronFields.YEARS then
		date.year = date.year + value
	end
end

function CronExp.resetMin(field, date)
	if field == -1 then return -1 end
	if field == CronFields.SECOND then
		date.sec = 0
	elseif field == CronFields.MINUTE then
		date.min = 0
	elseif field == CronFields.HOUR then
		date.hour = 0
	elseif field == CronFields.DAY_OF_MONTH then
		date.day = 1
	elseif field == CronFields.MONTH then
		date.month = 0
	elseif field == CronFields.DAY_OF_WEEK then
		date.wday = 1
	elseif field == CronFields.DAY_OF_WEEK then
		date.year = 0
	end
end

function CronExp.resetAllMin(date, lowerOrders)
	for k,v in ipairs(lowerOrders) do
		if not v == -1 then
			CronExp.resetMin(v, date)
		end
	end
end

function CronExp.setField(field, date, value)
	if field == CronFields.SECOND then
		date.sec = value
	elseif field == CronFields.MINUTE then
		date.min = value
	elseif field == CronFields.HOUR then
		date.hour = value
	elseif field == CronFields.DAY_OF_MONTH then
		date.day = value
	elseif field == CronFields.MONTH then
		date.month = value
	elseif field == CronFields.DAY_OF_WEEK then
		date.wday = value
	elseif field == CronFields.DAY_OF_WEEK then
		date.year = value
	end
end

function CronExp.getRange(value, min, max)

	local range = {}

	if #value == 1 and value == "*" then
		range[1] = min
		range[2] = max - 1
	elseif select(1, string.find(value, '-')) == nil then
		range[1] = tonumber(value)
		range[2] = tonumber(value)
	else
		local parts = string.Split(value, "-")
		if not parts == 2 then
			error("Ranges require two values: " .. value)
		end
		range[1] = tonumber(parts[1])
		range[2] = tonumber(parts[2])
	end

	if range[1] >= max or range[2] >= max or range[1] < min or range[2] < min then
		error("Range is outside limits: " .. value .. " (min=" .. min .. ",max=" .. max - 1 .. ")")
	end

	if range[1] > range[2] then
		error("Start of range is larger than end of range: " .. value)
	end

	return range

end

function CronExp.getNumberBits(value, min, max)

	local values = string.Split(value, ",")
	local res = {}
	for i=min,max-1 do
		res[i] = false
	end

	for _,v in ipairs(values) do

		if select(1, string.find(v, "/")) == nil then
			local range = CronExp.getRange(v, min, max)
			for i=range[1],range[2] do
				res[i] = true
			end
		else
			local split = string.Split(v, "/")
			local range = CronExp.getRange(split[1], min, max)
			if select(1, string.find(split[1], "-")) == nil then
				range[2] = max - 1
			end
			if tonumber(split[2]) == 0 then
				error("Increment cannot be zero: " .. v)
			end
			for i=range[1],range[2],tonumber(split[2]) do
				res[i] = true
			end
		end

	end

	return res

end

function CronExp.replaceOrdinals(input, replacement)
	local res = input
	for i=1,#replacement do
		res = string.Replace(res, replacement[i], i)
	end
	return res
end

function CronExp.getMonth(value)
	local res = CronExp.getNumberBits(CronExp.replaceOrdinals(value, CronConstants.MONTHS), 1, CronConstants.MAX_MONTHS)
	-- Shift everything back to 0-indexed so it's consistent
	for i=1,CronConstants.MAX_MONTHS do
		if res[i] then
			res[i - 1] = true
			res[i] = nil
		end
	end
	return res
end

function CronExp.getDaysOfWeek(value)
	local res = CronExp.getNumberBits(CronExp.replaceOrdinals(value, CronConstants.DAYS), 0, CronConstants.MAX_DAYS_OF_WEEK)
	-- Make sunday 0
	if res[7] == true then
		res[0] = true
		res[7] = nil
	end
	return res
end

function CronExp.fromString(exp)
	local res = {}
	local parts = string.Split(exp, " ")
	res.seconds = CronExp.getNumberBits(parts[1], 0, CronConstants.MAX_SECONDS)
	res.minutes = CronExp.getNumberBits(parts[2], 0, CronConstants.MAX_MINUTES)
	res.hours = CronExp.getNumberBits(parts[3], 0, CronConstants.MAX_HOURS)
	if #parts[4] == 1 and parts[4][1] == "?" then
		parts[4] = "*" .. string.sub(parts[4], 2)
	end
	res.daysMonth = CronExp.getNumberBits(parts[4], 0, CronConstants.MAX_DAYS_OF_MONTH)
	res.month = CronExp.getMonth(parts[5])
	if #parts[6] == 1 and parts[6][1] == "?" then
		parts[6] = "*" .. string.sub(parts[6], 2)
	end
	res.daysWeek = CronExp.getDaysOfWeek(parts[6])
	return res
end

function CronExp.findNextBit(bits, from, to)
	for i=from,to-1 do
		if bits[i] == true then return i end
	end
	return -1
end

function CronExp.findNext(bits, value, max, date, field, nextField, lowerOrders)
	local nextValue = CronExp.findNextBit(bits, value, max)
	local notFound = (nextValue == -1)
	if notFound then
		CronExp.addToField(nextField, date, 1)
		local res = CronExp.resetMin(field, date)
		if res == -1 then
			return -1
		end
		nextValue = CronExp.findNextBit(bits, 0, value)
		notFound = (nextValue == -1)
	end
	if notFound or value != nextValue then
		CronExp.setField(field, date, nextValue)
		CronExp.resetAllMin(date, lowerOrders)
	end
	return nextValue
end

function CronExp.findNextDay(date, daysMonth, daysWeek, resets)
	local count = 0
	local dayOfMonth = date.day - 1
	local dayOfWeek = date.wday - 1
	while (daysMonth[dayOfMonth] == false or daysWeek[dayOfWeek] == false) and count < 10 do
		count = count + 1
		local res = CronExp.addToField(CronFields.DAY_OF_MONTH, date, 1)
		if res == -1 then return -1 end
		dayOfMonth = date.day - 1
		dayOfWeek = date.wday - 1
		CronExp.resetAllMin(date, resets)
	end
	return dayOfMonth
end

function CronExp.doNext(exp, date)
	local second, updateSecond, minute, updateMinute, hour, updateHour, dayOfWeek, dayOfMonth, updateDayOfMonth, month, updateMonth = 0
	local res = 0
	local resets = {}
	local emptyList = {}

	for i=0,7 do
		resets[i] = -1
		emptyList[i] = -1
	end

	second = date.sec
	updateSecond = CronExp.findNext(exp.seconds, second, CronConstants.MAX_SECONDS, date, CronFields.SECOND, CronFields.MINUTE, emptyList)
	if updateSecond == -1 then goto returnResult end
	if second == updateSecond then
		CronExp.pushToFields(resets, CronFields.SECOND)
	end

	minute = date.min
	updateMinute = CronExp.findNext(exp.minutes, minute, CronConstants.MAX_MINUTES, date, CronFields.MINUTE, CronFields.HOUR, resets)
	if updateMinute == -1 then goto returnResult end
	if minute == updateMinute then
		CronExp.pushToFields(resets, CronFields.MINUTE)
	else
		res = CronExp.doNext(exp, date)
	end

	hour = date.hour
	updateHour = CronExp.findNext(exp.hours, hour, CronConstants.MAX_HOURS, date, CronFields.HOUR, CronFields.DAY_OF_WEEK, resets)
	if updateHour == -1 then goto returnResult end
	if hour == updateHour then
		CronExp.pushToFields(resets, CronFields.HOUR)
	else
		res = CronExp.doNext(exp, date)
	end

	-- Subtract 1 because they are 1-indexed
	dayOfWeek = date.wday - 1
	dayOfMonth = date.day - 1
	updateDayOfMonth = CronExp.findNextDay(date, exp.daysMonth, exp.daysWeek, resets)
	if updateDayOfMonth == -1 then goto returnResult end
	if dayOfMonth == updateDayOfMonth then
		CronExp.pushToFields(resets, CronFields.DAY_OF_MONTH)
	else
		res = CronExp.doNext(exp, date)
	end

	month = date.month
	updateMonth = CronExp.findNext(exp.month, month, CronConstants.MAX_MONTHS, date, CronFields.MONTH, CronFields.YEAR, resets)
	if updateMonth == -1 then goto returnResult end
	if not month == updateMonth then
		res = CronExp.doNext(exp, date)
	end

	::returnResult::
	return date
end

function CronExp.getNext(exp, date)
	local calculated = CronExp.doNext(exp, date)
	-- Prevent it from giving the current time back
	if date == calculated then
		CronExp.addToField(CronFields.SECOND, date, 1)
		calculated = CronExp.doNext(exp, date)
	end
	return calculated
end

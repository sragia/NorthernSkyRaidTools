if ElvUF and ElvUF.Tags then
	ElvUF.Tags.Events['NSNickName'] = 'UNIT_NAME_UPDATE'
	ElvUF.Tags.Events['NSNickName:Short'] = 'UNIT_NAME_UPDATE'
	ElvUF.Tags.Events['NSNickName:Medium'] = 'UNIT_NAME_UPDATE'
	ElvUF.Tags.Methods['NSNickName'] = function(unit)
		local name = UnitName(unit)
		return name and NSAPI and NSAPI:GetName(name) or name
	end

	ElvUF.Tags.Methods['NSNickName:veryshort'] = function(unit)
		local name = UnitName(unit)
		name = name and NSAPI and NSAPI:GetName(name) or name
		return string.sub(name, 1, 5)
	end

	ElvUF.Tags.Methods['NSNickName:short'] = function(unit)
		local name = UnitName(unit)
		name = name and NSAPI and NSAPI:GetName(name) or name
		return string.sub(name, 1, 8)
	end

	ElvUF.Tags.Methods['NSNickName:medium'] = function(unit)
		local name = UnitName(unit)
		name = name and NSAPI and NSAPI:GetName(name) or name
		return string.sub(name, 1, 10)
	end
end
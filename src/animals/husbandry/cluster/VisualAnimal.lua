VisualAnimal = {}


local VisualAnimal_mt = Class(VisualAnimal)


function VisualAnimal.new(animal, husbandryId, animalId)

	local self = setmetatable({}, VisualAnimal_mt)

	self.animal = animal
	self.husbandryId = husbandryId
	self.animalId = animalId

	self.nodes = {
		["root"] = getAnimalRootNode(husbandryId, animalId)
	}
	self.texts = {
		["earTagLeft"] = {},
		["earTagRight"] = {}
	}

	self.leftTextColour, self.rightTextColour = { 0, 0, 0 }, { 0, 0, 0 }

	return self

end


function VisualAnimal:delete()

	for _, nodeType in pairs(self.texts) do

		for _, nodes in pairs(nodeType) do

			for _, node in pairs(nodes) do delete3DLinkedText(node) end

		end

	end

end


function VisualAnimal:load()

	local nodes = self.nodes
	local visualData = g_currentMission.animalSystem:getVisualByAge(self.animal.subTypeIndex, self.animal.age)

	if visualData.monitor ~= nil then nodes.monitor = I3DUtil.indexToObject(nodes.root, visualData.monitor) end
	if visualData.noseRing ~= nil then nodes.noseRing = I3DUtil.indexToObject(nodes.root, visualData.noseRing) end
	if visualData.bumId ~= nil then nodes.bumId = I3DUtil.indexToObject(nodes.root, visualData.bumId) end
	if visualData.marker ~= nil then nodes.marker = I3DUtil.indexToObject(nodes.root, visualData.marker) end
	if visualData.earTagLeft ~= nil then nodes.earTagLeft = I3DUtil.indexToObject(nodes.root, visualData.earTagLeft) end
	if visualData.earTagRight ~= nil then nodes.earTagRight = I3DUtil.indexToObject(nodes.root, visualData.earTagRight) end

	self:setMonitor()
	self:setNoseRing()
	self:setBumId()
	self:setMarker()
	self:setLeftEarTag()
	self:setRightEarTag()

end


function VisualAnimal:setMonitor()

	if self.nodes.monitor == nil then return end

    setVisibility(self.nodes.monitor, self.animal.monitor.active or self.animal.monitor.removed)

end


function VisualAnimal:setNoseRing()

	if self.nodes.noseRing == nil then return end

    setVisibility(self.nodes.noseRing, self.animal.gender == "male")

end


function VisualAnimal:setBumId()

	if self.nodes.bumId == nil then return end

	for _, nodeGroup in pairs(self.texts.bumId or {}) do
		for _, node in pairs(nodeGroup) do delete3DLinkedText(node) end
	end

	local uniqueId = self.animal.uniqueId or ""
	if string.len(uniqueId) < 6 then
		local paddedUniqueId = string.rep("0", 6 - string.len(uniqueId)) .. uniqueId
		print(string.format("[RL][setBumId] uniqueId '%s' padded to '%s'", tostring(uniqueId), paddedUniqueId))
		uniqueId = paddedUniqueId
	else
		print(string.format("[RL][setBumId] uniqueId '%s' length=%d", tostring(uniqueId), string.len(uniqueId)))
	end

	local digits = {
		string.sub(uniqueId, 3, 3),
		string.sub(uniqueId, 4, 4),
		string.sub(uniqueId, 5, 5),
		string.sub(uniqueId, 6, 6)
	}

	local nodeNames = { "bumId1", "bumId2", "bumId3", "bumId4" }
	local childNodes = {}
	local hasAllChildren = true

	print("[RL][setBumId] Resolving bumId child nodes for animal uniqueId=" .. tostring(uniqueId))

	for i, name in ipairs(nodeNames) do
		local child = getChild(self.nodes.bumId, name)
		if child ~= nil and child ~= 0 then
			childNodes[i] = child
			local x, y, z = getWorldTranslation(child)
			local rx, ry, rz = getWorldRotation(child)
			print(string.format("[RL][setBumId] Found child '%s' (index=%d) nodeId=%s worldPos=(%.3f, %.3f, %.3f) worldRot=(%.3f, %.3f, %.3f)", name, i, tostring(child), x or -999, y or -999, z or -999, rx or -999, ry or -999, rz or -999))
		else
			childNodes[i] = nil
			hasAllChildren = false
			print(string.format("[RL][setBumId] Missing child '%s' (index=%d)", name, i))
			break
		end
	end

	self.texts.bumId = { ["digits"] = {} }

	if hasAllChildren then
		print("[RL][setBumId] All child nodes present; mapping digits")
		for i = 1, #digits do
			local digitNode = childNodes[i]
			local digitText = digits[i] ~= nil and digits[i] ~= "" and digits[i] or "-"
			local lx, ly, lz = localToLocal(digitNode, getParent(digitNode) or digitNode, 0, 0, 0)
			print(string.format("[RL][setBumId] Digit index=%d nodeId=%s text='%s' localPos=(%.3f, %.3f, %.3f)", i, tostring(digitNode), tostring(digitText), lx or -999, ly or -999, lz or -999))
			self.texts.bumId.digits[i] = create3DLinkedText(digitNode, 0, 0, 0, 0, 0, 0, 0.05, digitText)
		end
	else
		print("[RL][setBumId] Child nodes missing, falling back to stacked text")
		self.texts.bumId.uniqueId = {
			["top"] = create3DLinkedText(self.nodes.bumId, 0, -0.006, 0, 0, 0, 0, 0.05, string.sub(uniqueId, 3, 4)),
			["bottom"] = create3DLinkedText(self.nodes.bumId, 0, -0.012, 0, 0, 0, 0, 0.05, string.sub(uniqueId, 5, 6))
		}
		print(string.format("[RL][setBumId] fallback top='%s' bottom='%s'", string.sub(uniqueId, 3, 4), string.sub(uniqueId, 5, 6)))
	end

end


function VisualAnimal:setMarker()

	if self.nodes.marker == nil then return end

	local markerColour = AnimalSystem.BREED_TO_MARKER_COLOUR[self.animal.breed]
    local isMarked = self.animal:getMarked()

    setVisibility(self.nodes.marker, isMarked)
    if isMarked then setShaderParameter(self.nodes.marker, "colorScale", markerColour[1], markerColour[2], markerColour[3], nil, false) end

end



function VisualAnimal:setEarTagColours(leftTag, leftText, rightTag, rightText)

	if self.nodes.earTagLeft ~= nil then

		if leftTag ~= nil then setShaderParameter(self.nodes.earTagLeft, "colorScale", leftTag[1], leftTag[2], leftTag[3], nil, false) end

		if leftText ~= nil then

			self.leftTextColour = leftText
		
			for _, nodes in pairs(self.texts.earTagLeft) do
				for _, node in pairs(nodes) do change3DLinkedTextColour(node, leftText[1], leftText[2], leftText[3], 1) end
			end

		end

	end

	if self.nodes.earTagRight ~= nil then

		if rightTag ~= nil then setShaderParameter(self.nodes.earTagRight, "colorScale", rightTag[1], rightTag[2], rightTag[3], nil, false) end

		if rightText ~= nil then

			self.rightTextColour = rightText
		
			for _, nodes in pairs(self.texts.earTagRight) do
				for _, node in pairs(nodes) do change3DLinkedTextColour(node, rightText[1], rightText[2], rightText[3], 1) end
			end

		end

	end

end


function VisualAnimal:setLeftEarTag()

	if self.nodes.earTagLeft == nil then return end

	for _, nodes in pairs(self.texts.earTagLeft) do
		for _, node in pairs(nodes) do delete3DLinkedText(node) end
	end

    local uniqueId = self.animal.uniqueId
    local farmId = self.animal.farmId
    local birthday = self.animal:getBirthday()
	local countryCode = birthday ~= nil and birthday.country ~= nil and (RealisticLivestock.AREA_CODES[birthday.country] or RealisticLivestock.getMapCountryCode()).code
	local node = self.nodes.earTagLeft
	local colour = self.leftTextColour

	local front = getChild(node, "front")
	local back = getChild(node, "back")
	
	setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_MIDDLE)
	setTextAlignment(RenderText.ALIGN_CENTER)
	setTextColor(colour[1], colour[2], colour[3], 1)
	setTextFont(RealisticLivestock.FONTS.dejavu_sans)

	self.texts.earTagLeft = {
		["uniqueId"] = {
			["back"] = create3DLinkedText(back, 0, -0.006, -0.015, 0, 0, 0, 0.035, uniqueId),
			["front"] = create3DLinkedText(front, 0, -0.006, -0.015, 0, 0, 0, 0.035, uniqueId)
		},
		["farmId"] = {
			["back"] = create3DLinkedText(back, 0, -0.041, -0.02, 0, 0, 0, 0.05, farmId),
			["front"] = create3DLinkedText(front, 0, -0.041, -0.02, 0, 0, 0, 0.05, farmId)
		},
		["country"] = {
			["back"] = create3DLinkedText(back, 0, 0.021, -0.015, 0, 0, 0, 0.03, countryCode),
			["front"] = create3DLinkedText(front, 0, 0.021, -0.015, 0, 0, 0, 0.03, countryCode)
		}
	}

	
	setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_BASELINE)
	setTextAlignment(RenderText.ALIGN_LEFT)
	setTextColor(1, 1, 1, 1)
	setTextFont()

end


function VisualAnimal:setRightEarTag()

	if self.nodes.earTagRight == nil then return end

	for _, nodes in pairs(self.texts.earTagRight) do
		for _, node in pairs(nodes) do delete3DLinkedText(node) end
	end
	
	local node = self.nodes.earTagRight
	local colour = self.rightTextColour
	local name = self.animal:getName()
    local birthday = self.animal:getBirthday()
	local day, month, year = birthday.day, birthday.month, birthday.year + RealisticLivestock.START_YEAR.PARTIAL
	local birthdayText = string.format("%s%s/%s%s/%s%s", day < 10 and 0 or "", day, month < 10 and 0 or "", month, year < 10 and 0 or "", year)

	local front = getChild(node, "front")
	local back = getChild(node, "back")

	set3DTextAutoScale(true)
	set3DTextRemoveSpaces(true)
	set3DTextWrapWidth(0.14)
	setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_MIDDLE)
	setTextAlignment(RenderText.ALIGN_CENTER)
	setTextColor(colour[1], colour[2], colour[3], 1)
	set3DTextWordsPerLine(1)
	setTextLineHeightScale(0.75)
	setTextFont(RealisticLivestock.FONTS.toms_handwritten)


	self.texts.earTagRight = {
		["name"] = {
			["back"] = create3DLinkedText(back, 0, -0.01, -0.015, 0, 0, 0, 0.035, name),
			["front"] = create3DLinkedText(front, 0, -0.01, -0.015, 0, 0, 0, 0.035, name)
		}
	}

	set3DTextWrapWidth(0)
	setTextFont(RealisticLivestock.FONTS.dejavu_sans)
	
	self.texts.earTagRight.birthday = {
		["back"] = create3DLinkedText(back, 0, 0.018, -0.015, 0, 0, 0, 0.02, birthdayText),
		["front"] = create3DLinkedText(front, 0, 0.018, -0.015, 0, 0, 0, 0.02, birthdayText)
	}

	
	setTextLineHeightScale(1.1)
	set3DTextWordsPerLine(0)
	set3DTextAutoScale(false)
	set3DTextRemoveSpaces(false)
	setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_BASELINE)
	setTextAlignment(RenderText.ALIGN_LEFT)
	setTextColor(1, 1, 1, 1)
	setTextFont()

end

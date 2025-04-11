-- Auto-install Basalt 2 if missing
if not fs.exists("basalt.lua") then
    print("Basalt not found — installing Basalt 2...")

    local installer = http.get("https://raw.githubusercontent.com/Pyroxenium/Basalt2/main/install.lua")
    if installer then
        local code = installer.readAll()
        installer.close()

        local func, err = load(code, "basalt-installer", "t", _ENV)
        if func then
            func()
            print("Basalt 2 installed successfully.")
        else
            error("Failed to load Basalt installer: " .. err)
        end
    else
        error("Failed to fetch Basalt installer. Check your internet connection.")
    end
end

local basalt = require("basalt")

-- Peripheral setup
local reader = peripheral.wrap("vaultreader_1")
local input = peripheral.wrap("sophisticatedstorage:barrel_0")
local recycler = peripheral.wrap("sophisticatedstorage:barrel_1")
local output = peripheral.wrap("sophisticatedstorage:barrel_2")

-- Config
local DEFAULT_FILE, WEIGHTS_FILE = "default.json", "weights.json"
local DEFAULT_AFFIX_WEIGHT, unavailableWeight, requiredWeight = 1, 10, 55
local slot, initializedStates = 1, {}
local rarityCounts = { SCRAPPY = 0, COMMON = 0, RARE = 0, EPIC = 0, OMEGA = 0, SPECIAL = 0 }
local rarities = { "SCRAPPY", "COMMON", "RARE", "EPIC", "OMEGA", "SPECIAL" }

-- JSON helpers
local function loadJSON(filename)
    if not fs.exists(filename) then return nil end
    local f = fs.open(filename, "r")
    local contents = f.readAll()
    f.close()
    return textutils.unserializeJSON(contents)
end

local function saveJSON(filename, data)
    local f = fs.open(filename, "w")
    f.write(textutils.serializeJSON(data))
    f.close()
end
-- Debug log writer
local function writeDebugLog(message)
    local logFile = fs.open("debug_log.txt", "a")
    logFile.writeLine(message)
    logFile.close()
end
-- Default config loading
local function loadDefault()
    local default = loadJSON(DEFAULT_FILE)
    if type(default) ~= "table" then
        print("default.json was invalid — regenerating.")
        default = {
            Implicit = {}, Prefix = {}, Suffix = {},
            Rarity = {
                SCRAPPY = -10, COMMON = 5,
                RARE = 20, EPIC = 60, OMEGA = 10000
            }
        }
        saveJSON(DEFAULT_FILE, default)
    end
    return default
end

-- Safety Check
local function safeNumber(val, fallback)
    local n = tonumber(val)
    return n or fallback or 0
end

-- Load weights or fall back to default
local Weights = (function()
    local default = loadDefault()
    local weights = loadJSON(WEIGHTS_FILE)
    if type(weights) ~= "table" then
        print("weights.json not found or invalid — generating from default.")
        saveJSON(WEIGHTS_FILE, default)
        weights = default
    end

    for _, section in ipairs({ "Implicit", "Prefix", "Suffix", "Rarity" }) do
        weights[section] = weights[section] or default[section] or {}
    end
    requiredWeight = safeNumber(weights.requiredWeight, requiredWeight)
    return weights
end)()

-- Helpers for affix parsing and scoring
local function getMultiplier(val, min, max)
    if min == max then return 1.5 end
    return (val - min) / (max - min) + 0.5
end

local function getAffixWeight(affix, affixType)
    -- Legendary shortcut
    local successType, affixTypeResult = pcall(reader.getType, affix)
    if successType and affixTypeResult == "legendary" then
        return 1000, false
    end

    -- Safe calls
    local successName, name = pcall(reader.getName, affix)
    local successMin, min = pcall(reader.getMinimumRoll, affix)
    local successMax, max = pcall(reader.getMaximumRoll, affix)
    local successVal, val = pcall(reader.getModifierValue, affix)

    if not (successName and successMin and successMax and successVal)
       or type(val) ~= "number"
       or type(min) ~= "number"
       or type(max) ~= "number"
    then
        writeDebugLog("Special affix detected or failed read: " ..
            tostring(name) .. " | val=" .. tostring(val) ..
            ", min=" .. tostring(min) .. ", max=" .. tostring(max))
        return 0, true
    end

    local baseWeight = Weights[affixType][name] or unavailableWeight
    return baseWeight * getMultiplier(val, min, max), false
end




local function parseAffixes(count, getter, affixtype)
    local total, hasSpecial = 0, false
    for i = 0, count() - 1 do
        local affix = getter(i)
        local weight, special = getAffixWeight(affix, affixtype)
        total = total + weight
        if special then hasSpecial = true end
    end
    return total, hasSpecial
end


local function parseRarity()
    return Weights.Rarity[reader.getRarity()] or 0
end

local function getWeight()
    local rarityWeight = parseRarity()
    local iWeight, iSpecial = parseAffixes(reader.getImplicitCount, reader.getImplicit, "Implicit")
    local pWeight, pSpecial = parseAffixes(reader.getPrefixCount, reader.getPrefix, "Prefix")
    local sWeight, sSpecial = parseAffixes(reader.getSuffixCount, reader.getSuffix, "Suffix")
    
    local totalSpecial = iSpecial or pSpecial or sSpecial
    return rarityWeight + iWeight + pWeight + sWeight, totalSpecial
end


local function shouldKeep()
    local weight, isSpecial = getWeight()
    if isSpecial then return true, weight, "SPECIAL" end
    return weight > requiredWeight, weight, reader.getRarity()
end

-- Check and add missing affixes
local function addMissingAffix(type, name, pending)
    pending[type] = pending[type] or {}
    if not Weights[type][name] and not pending[type][name] then
        Weights[type][name] = DEFAULT_AFFIX_WEIGHT
        pending[type][name] = true
    end
end

local function checkForNewAffixes()
    local pending = {}

    for i = 0, reader.getImplicitCount() - 1 do
        local name = reader.getName(reader.getImplicit(i))
        if name and name ~= "null" and name ~= "empty" then
            addMissingAffix("Implicit", name, pending)
        end
    end

    for i = 0, reader.getPrefixCount() - 1 do
        local name = reader.getName(reader.getPrefix(i))
        if name and name ~= "null" and name ~= "empty" then
            addMissingAffix("Prefix", name, pending)
        end
    end

    for i = 0, reader.getSuffixCount() - 1 do
        local name = reader.getName(reader.getSuffix(i))
        if name and name ~= "null" and name ~= "empty" then
            addMissingAffix("Suffix", name, pending)
        end
    end

    if next(pending) then
        local default = loadDefault()
        local updated = false
        for type, affixes in pairs(pending) do
            default[type] = default[type] or {}
            for name in pairs(affixes) do
                if not default[type][name] then
                    default[type][name] = DEFAULT_AFFIX_WEIGHT
                    updated = true
                end
            end
        end

        if updated then saveJSON(DEFAULT_FILE, default) end
        saveJSON(WEIGHTS_FILE, Weights)
    end
end

local function moveItem(from, to, fromSlot, toSlot)
    return from.pushItems(peripheral.getName(to), fromSlot or 1, 1, toSlot or 1)
end

-- UI setup
local mon = peripheral.wrap("monitor_0")
local main = basalt.getMainFrame()
local monitorFrame = basalt.createFrame():setTerm(mon):setBackground(colors.lightBlue)
local monitorWidth, monitorHeight = mon.getSize()

-- === Stats and Rarity Panels ===
local function centerText(label, text, y)
    local width = mon.getSize()
    local x = math.floor((width / 2) - (#text / 2))
    return label:setText(text):setPosition(x, y):setForeground(colors.black)
end

local topScore, lowScore, totalScanned = 0, math.huge, 0

-- Left side (stats)
local leftPanel = monitorFrame:addFrame()
    :setPosition(2, 2)
    :setSize(18, monitorHeight - 2)
    :setBackground(colors.white)

-- Right side (rarity)
local rightPanel = monitorFrame:addFrame()
    :setPosition(40, 2)
    :setSize(10, monitorHeight - 2)
    :setBackground(colors.cyan)

-- Labels on monitor
centerText(monitorFrame:addLabel(), "== Vault Gear Evaluator ==", 1)
local statusLabel = monitorFrame:addLabel():setText("Status: Waiting"):setPosition(23, 3):setForeground(colors.black)
local rarityLabel = monitorFrame:addLabel():setText("Rarity: --"):setPosition(23, 5):setForeground(colors.black)
local scoreLabel  = monitorFrame:addLabel():setText("Score : --"):setPosition(23, 7):setForeground(colors.black)
local minKeepLabel = monitorFrame:addLabel():setText("Min Keep: " .. tostring(requiredWeight)):setPosition(23, 9):setForeground(colors.black)

-- Stat counters
local topScoreLabel = leftPanel:addLabel():setText("Top Score : --"):setPosition(1, 2):setForeground(colors.black)
local lowScoreLabel = leftPanel:addLabel():setText("Lowest    : --"):setPosition(1, 4):setForeground(colors.black)
local totalLabel    = leftPanel:addLabel():setText("Total Eval: 0 "):setPosition(1, 6):setForeground(colors.black)

-- Rarity Background Colors
local rarityColors = {
    SCRAPPY = colors.gray,
    COMMON = colors.lime,
    RARE = colors.blue,
    EPIC = colors.purple,
    OMEGA = colors.orange,
    UNKNOWN = colors.magenta
}

-- Rarity counters
local rarityLabels = {}
for i, rarity in ipairs(rarities) do
    local y = i * 2

    -- Wrap label inside a colored frame
    local labelFrame = rightPanel:addFrame()
        :setPosition(1, y)
        :setSize(12, 1)
        :setBackground(rarityColors[rarity] or colors.black)

    rarityLabels[rarity] = labelFrame:addLabel()
        :setText(rarity .. ": 0")
        :setForeground(colors.white)
        :setPosition(1, 1)
end


function updateRarityCounter(rarity)
    rarity = rarity or "SPECIAL"
    rarityCounts[rarity] = (rarityCounts[rarity] or 0) + 1
    rarityLabels[rarity]:setText(rarity .. ": " .. rarityCounts[rarity])
end

function updateScoreStats(score)
    if score > topScore then topScore = score end
    if score < lowScore then lowScore = score end
    totalScanned = totalScanned + 1

    topScoreLabel:setText("Top Score : " .. math.floor(topScore))
    lowScoreLabel:setText("Lowest    : " .. math.floor(lowScore))
    totalLabel:setText("Total Eval: " .. totalScanned)
end

local function updateUI(status, weight, rarity)
    statusLabel:setText("Status: " .. status)
    rarityLabel:setText("Rarity: " .. rarity)
    scoreLabel:setText("Score : " .. string.format("%.1f", tonumber(weight) or 0))
    minKeepLabel:setText("Min Keep: " .. tostring(requiredWeight))
end

local function displayStatus(status, weight, rarity)
    updateUI(status, weight, rarity)
end

-- === Tabbed Affix Editor ===
local buttonFrame = main:addFrame():setPosition(1, 1):setSize(60, 1)

local editorFrameImplicit = main:addFrame({x = 2, y = 3, width = 50, height = 14, background = colors.gray})
local editorFramePrefix   = main:addFrame({x = 2, y = 3, width = 50, height = 14, background = colors.gray}):setVisible(false)
local editorFrameSuffix   = main:addFrame({x = 2, y = 3, width = 50, height = 14, background = colors.gray}):setVisible(false)
local editorFrameRarity   = main:addFrame({x = 2, y = 3, width = 50, height = 14, background = colors.gray}):setVisible(false)

local function getChildrenHeight(container)
    local height = 0
    for _, child in ipairs(container.get("children")) do
        if child.get("visible") then
            local newHeight = child.get("y") + child.get("height")
            if newHeight > height then height = newHeight end
        end
    end
    return height
end

local function makeScrollable(frame)
    frame:onScroll(function(self, delta)
        local offset = math.max(0, math.min(self.get("offsetY") + delta, getChildrenHeight(self) - self.get("height")))
        self:setOffsetY(offset)
    end)
end

for _, frame in pairs({editorFrameImplicit, editorFramePrefix, editorFrameSuffix}) do
    makeScrollable(frame)
end

local currentType = "Implicit"
local editorFrames = {
    Implicit = editorFrameImplicit,
    Prefix = editorFramePrefix,
    Suffix = editorFrameSuffix,
    Rarity = editorFrameRarity
}

local affixInputs = {
    Implicit = {},
    Prefix = {},
    Suffix = {},
    Rarity = {}
}

local function populateEditor(affixType, frame)
    frame:clear()
    affixInputs[affixType] = {}
    local y = 2
    for affix, weight in pairs(Weights[affixType]) do
        local stateKey = affix .. "_" .. affixType
        if not initializedStates[stateKey] then
            main:initializeState(stateKey, tostring(weight), true)
            initializedStates[stateKey] = true
        end
        frame:addLabel():setText(affix):setPosition(2, y)
        local input = frame:addInput():setPosition(35, y):setSize(6, 1):bind("text", stateKey)
        input:setText(tostring(weight))
        affixInputs[affixType][affix] = input
        y = y + 1
    end
end

for _, affixType in ipairs({ "Implicit", "Prefix", "Suffix", "Rarity" }) do
    populateEditor(affixType, editorFrames[affixType])
end

-- Required weight global input box
local rwStateKey = "requiredWeight_Global"
if not initializedStates[rwStateKey] then
    main:initializeState(rwStateKey, tostring(requiredWeight), true)
    initializedStates[rwStateKey] = true
end

local rwInput = main:addInput()
    :setPosition(38, 18)
    :setSize(6, 1)
    :bind("text", rwStateKey)
    :setText(tostring(requiredWeight))

-- Label for global min score
main:addLabel()
    :setText("Keep Minimum:")
    :setPosition(25, 18)
    :setForeground(colors.black)

-- Store for accessing in update handler
local requiredWeightInputs = {
    Global = { input = rwInput, stateKey = rwStateKey }
}

-- Tab buttons
local startX, spacing = 2, 11
local tabButtons = {}

local function setActiveTab(tabName)
    currentType = tabName
    for type, frame in pairs(editorFrames) do
        frame:setVisible(type == tabName)
    end
    for type, btn in pairs(tabButtons) do
        local isActive = (type == tabName)
        btn:setBackground(isActive and colors.white or colors.gray)
        btn:setForeground(isActive and colors.black or colors.red)
    end
end

tabButtons["Implicit"] = buttonFrame:addButton()
    :setPosition(startX, 1)
    :setSize(10, 1)
    :setText("Implicits")
    :onClick(function() setActiveTab("Implicit") end)

tabButtons["Prefix"] = buttonFrame:addButton()
    :setPosition(startX + spacing, 1)
    :setSize(10, 1)
    :setText("Prefixes")
    :onClick(function() setActiveTab("Prefix") end)

tabButtons["Suffix"] = buttonFrame:addButton()
    :setPosition(startX + spacing * 2 + 1, 1)
    :setSize(10, 1)
    :setText("Suffixes")
    :onClick(function() setActiveTab("Suffix") end)

tabButtons["Rarity"] = buttonFrame:addButton()
    :setPosition(startX + spacing * 3 + 3, 1)
    :setSize(10, 1)
    :setText("Rarities")
    :onClick(function() setActiveTab("Rarity") end)

-- Highlight default tab
setActiveTab("Implicit")

local updateButton = main:addButton()
    :setText("Update")
    :setSize(10, 1)
    :setPosition(8, 18)

-- Update button handler
updateButton:onClick(function()
    -- Update affix weights
    for affix, input in pairs(affixInputs[currentType]) do
        local stateKey = affix .. "_" .. currentType
        local state = input:getState(stateKey)
        if state then
            local val = tonumber(state)
            if val then
                Weights[currentType][affix] = val
                writeDebugLog("Updated " .. currentType .. " " .. affix .. " to " .. val)
            else
                writeDebugLog("Invalid value for " .. currentType .. " " .. affix .. ": " .. state)
            end
        end
    end

    -- ✅ Update global required weight, with fallback
    local globalRW = requiredWeightInputs["Global"]
    if globalRW then
        local inputVal = globalRW.input:getState(globalRW.stateKey)
        local rw = tonumber(inputVal)
        if rw then
            requiredWeight = rw
            Weights.requiredWeight = rw
            writeDebugLog("Updated requiredWeight to: " .. rw)
        else
            -- fallback: restore current value to field
            writeDebugLog("Invalid requiredWeight input: " .. tostring(inputVal))
            globalRW.input:setText(tostring(requiredWeight))
        end
    end

    updateUI("Waiting", 0, "---")
    saveJSON(WEIGHTS_FILE, Weights)
end)


-- === Main parallel runtime ===
parallel.waitForAny(
    function()
        while true do
            if redstone.getInput("back") then
                local items = input.list()
                local firstSlot = next(items)
                if firstSlot then
                    moveItem(input, reader, firstSlot, 1)
                    checkForNewAffixes()
                    local success, result = pcall(shouldKeep)
                    local score = getWeight()
                    local rarity = reader.getRarity()
                    local success, result, score, rarity = pcall(shouldKeep)
					if success then
						updateScoreStats(score)
						updateRarityCounter(rarity)
						displayStatus(result and "KEEP" or "RECYCLE", score, rarity)
						if result then
							moveItem(reader, output, 1)
						else
							moveItem(reader, recycler, 1)
						end
					else
						displayStatus("ERROR", 0, "SPECIAL")
						moveItem(reader, output, 1)
					end
                end
            else
                updateUI("Toggled Off", "--", "--")
            end
            os.sleep(1)
        end
    end,
    function()
        basalt.run()
    end
)

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:GetInfo()
	return {
		name      = "Scenario window",
		desc      = "Handles Scenarios",
		author    = "Beherith",
		date      = "2021 Feb.",
		license   = "GNU LGPL, v2.1 or later",
		layer     = -10000,
		enabled   = true  --  loaded by default?
	}
end

-- TODO: 
	-- gameside checking
	-- make nice dgun scenario
	-- push



--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Local Variables

local scenarioWindow
local scenarios
local scenariosorter
local currentscenario
local mybonus = 0
local alreadyDownloaded = false
local barversion = nil
local myside = nil
local mydifficulty = {name = "Normal", playerhandicap = 100, enemyhandicap = 100}
local myscores = {time = 0, resources = 0}
local myside = nil

local scoreData = {} -- a table, with keys being scenario uniqueIDs, e.g.:
--[[
{ supcrossingvsbarbs001 = {
	"1.0" = {
		"Easy" = {
			time = 10000,
			resources = 10000,
		}		
	}
	}
}
--]]
local unitdefname_to_humanname = {} -- from en.lua, attached at the end of the file
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Utilities


local function MaybeDownloadMap(mapName)
	Spring.Echo("Scenario:", "Downloading map", mapName)

	WG.DownloadHandler.MaybeDownloadArchive(mapName, "map", -1)
end

local function ShortenGameName(gameName)
	gameName = gameName:gsub("Beyond All Reason","BAR")
	gameName = gameName:gsub("test","")
	if gameName:find("-[^-]*$") then
	  gameName = gameName:sub(1, gameName:find("-[^-]*$") -1 )
	end
	return gameName
end

local function DownloadRequirements()
	local config = WG.Chobby.Configuration
	local gameName = config:GetDefaultGameName()
	barversion = gameName
	if gameName ~= nil and not alreadyDownloaded then
		Spring.Echo("Scenario:", "Downloading game", gameName)
		WG.DownloadHandler.MaybeDownloadArchive(gameName, "game", 1)
		alreadyDownloaded = true
	end
end

local function ShortenEngineName(engineName)
	if engineName:find("-[^-]*$") then
		engineName = engineName:sub(1, engineName:find("-[^-]*$") -1)
	end
	return engineName
end

local function ternary(condition, T, F)
	if condition then return T else return F end
end

  
local function LoadScenarios()
	scenarios = {}
	local files = VFS.DirList("LuaMenu/configs/gameConfig/byar/scenarios/")
	for i = 1, #files do
		if string.find(files[i],".lua") then
			scenarios[#scenarios+1] = VFS.Include(files[i])
		end
	end

	local function SortFunc(a,b)
		return a.index < b.index
	end

	table.sort(scenarios, SortFunc )
end



local function EncodeScenarioOptions(scenario)
	scenario.scenariooptions.version = scenario.version
	scenario.scenariooptions.scenarioid = scenario.scenarioid
	return Spring.Utilities.Base64Encode(Spring.Utilities.json.encode(scenario.scenariooptions))
end

local function GetBestScores(scenarioID,scenarioVersion,difficulty)
	if scoreData[scenarioid] and 
		scoreData[scenarioID][scenarioVersion] and 
		scoreData[scenarioID][scenarioVersion][difficulty] then
			myscores = scoreData[scenarioID][scenarioVersion][difficulty]
			return myscores
	else 
		return  {time = 0, resources = 0}
	end
end

local function SetScore(scenarioID,scenarioVersion,difficulty,time,resources,gamewon)
	
	Spring.Echo("Scenario Window SetScore")
	if scoreData[scenarioID] == nil then
		scoreData[scenarioID] = {}
	end 
	if scoreData[scenarioID][scenarioVersion] == nil then
		scoreData[scenarioID][scenarioVersion] = {}
	end 
	if scoreData[scenarioID][scenarioVersion][difficulty] == nil then
		scoreData[scenarioID][scenarioVersion][difficulty] = {}
	end 
	if gamewon then
		local sd = scoreData[scenarioID][scenarioVersion][difficulty] 
		if sd.time == nil or (time < sd.time) then sd.time = time end 
		if sd.resources == nil or (resources < sd.resources) then sd.resources = resources end 
		scoreData[scenarioID][scenarioVersion][difficulty] = sd
	end
end

--------------------------------------------------------------------------------
-- GUI


local function CreateScenarioPanel(shortname, sPanel)
	local Configuration = WG.Chobby.Configuration
	
	
	sPanel:ClearChildren()
	
	local scen = scenarios[1]
	for i, s in pairs(scenarios) do
		if shortname == s.title then
			scen = s 
		end
	end

	MaybeDownloadMap(scen.mapfilename)

		
	local difficulties = {}
	local defaultdifficultyindex = 1
	for i,diff in pairs(scen.difficulties) do
		difficulties[#difficulties + 1] = diff.name
		if diff.name == scen.defaultdifficulty then 
			defaultdifficultyindex = i
			mydifficulty = diff
		end
	end
	
	myscores = GetBestScores(scen.scenarioID, scen.version, mydifficulty.name)

	myside = scen.defaultside

	
	local titletext = Label:New{
		x = 0,
		y = 0,
		width = "50%",
		height = "5%",
		parent = sPanel,
		font = Configuration:GetFont(3),
		caption = scen.title,
	}
	
	local summarySP = ScrollPanel:New {
		x = 0,
		y = "5%",
		width = "49%",
		height = "14%",
		parent = sPanel,
		horizontalScrollbar = true,
	}

	local summarytext = scen.summary 
	local additionalText = "\nUnit Limits:"
	local numdisabledunits = 0
	if scen.unitlimits then
		for unitid, count in pairs(scen.unitlimits) do 
			additionalText = additionalText .. "\n  - " .. unitdefname_to_humanname[unitid] .. " (" ..unitid .. "): " .. tostring(count)
			numdisabledunits = numdisabledunits + 1
		end
	end
	if numdisabledunits > 0 then
		summarytext = summarytext .. additionalText
	end


	local summarytextbox = TextBox:New {
		x = 0,
		y = 0,
		width = "100%",
		height = "100%",
		valign = 'top',
		fontsize = Configuration:GetFont(2).size,
		text = summarytext,
		parent = summarySP,
		padding = {10,10,10,10},
	}

	local lblvictoryText = Label:New{
		x = 0,
		y = "20%",
		width = "50%",
		height = "5%",
		parent = sPanel,
		font = Configuration:GetFont(2),
		caption = "Victory",
	}
	lblvictoryText.font.color = {0.7, 0.7, 0.7, 1.0}
	
	local victoryText = Label:New{
		x = "16%",
		y = "20%",
		width = "50%",
		height = "5%",
		parent = sPanel,
		font = Configuration:GetFont(2),
		caption = scen.victorycondition,
	}

	local lbllossText = Label:New{
		x = 0,
		y = "24%",
		width = "50%",
		height = "5%",
		parent = sPanel,
		font = Configuration:GetFont(2),
		caption = "Loss" ,
	}
	lbllossText.font.color = {0.7, 0.7, 0.7, 1.0}

	local lossText = Label:New{
		x = "16%",
		y = "24%",
		width = "50%",
		height = "5%",
		parent = sPanel,
		font = Configuration:GetFont(2),
		caption = scen.losscondition,
	}

	local lbldifficultyText = Label:New{
		x = 0,
		y = "28%",
		width = "50%",
		height = "5%",
		parent = sPanel,
		font = Configuration:GetFont(2),
		caption = "Challenge",
	}
	lbldifficultyText.font.color = {0.7, 0.7, 0.7, 1.0}

	
	local difficultyText = Label:New{
		x = "16%",
		y = "28%",
		width = "50%",
		height = "5%",
		parent = sPanel,
		font = Configuration:GetFont(2),
		caption = tostring(scen.difficulty),
	}

	local lblpartimeText = Label:New{
		x = 0,
		y = "32%",
		width = "50%",
		height = "5%",
		parent = sPanel,
		font = Configuration:GetFont(2),
		caption = "Par Time",
	}
	lblpartimeText.font.color = {0.7, 0.7, 0.7, 1.0}


	local partimeText = Label:New{
		x = "16%",
		y = "32%",
		width = "50%",
		height = "5%",
		parent = sPanel,
		font = Configuration:GetFont(2),
		caption = tostring(math.ceil(scen.partime/60)) .. " minutes",
	}

	local lblparresourcesText = Label:New{
		x = 0,
		y = "36%",
		width = "50%",
		height = "5%",
		parent = sPanel,
		font = Configuration:GetFont(2),
		caption = "Par Resources" ,
	}
	lblparresourcesText.font.color = {0.7, 0.7, 0.7, 1.0}


	local parresourcesText = Label:New{
		x = "16%",
		y = "36%",
		width = "50%",
		height = "5%",
		parent = sPanel,
		font = Configuration:GetFont(2),
		caption =  tostring(math.ceil(scen.parresources/1000)) .. "K metal",
	}


	---------------------------------
		
	local mapImage = Image:New {
		y = "0%",
		right = "0%",
		height = "47%",
		width = "47%",
		keepAspect = true,
		file =Configuration:GetMinimapImage(scen.mapfilename),
		parent = sPanel,
		tooltip = scen.mapfilename,
		padding = {0,0,0,0},
	}

	local commstartimg = Image:New { --LuaMenu/images/ranks/player.png
		x = scen.playerstartx,
		y = scen.playerstarty,
		width = "10%",
		height = "10%",
		keepAspect = true,
		file = "LuaMenu/images/ranks/player.png",
		parent = mapImage,
		tooltip = "You Start Here",
	}

	----------------------------------------------

	local flavorimage = Image:New {
		x = "0",
		y = "51%",
		width = "74%",
		height = "23%",
		keepAspect = false,
		crop = true,
		file = "LuaMenu/configs/gameConfig/byar/scenarios/" .. scen.imagepath,
		parent = sPanel,
		--tooltip = scen.mapfilename,
		padding = {10,10,10,10},
	}
	
	local flavortext = Label:New{
		x = "12.5%",
		bottom = "25%",
		width = "73%",
		height = "5%",
		parent = flavorimage,
		font = Configuration:GetFont(2),
		caption = scen.imageflavor,
	}

	----------------------

	local briefingtextSP = ScrollPanel:New {
		x = 0,
		y = "76%",
		width = "74%",
		bottom = 0,
		parent = sPanel,
		horizontalScrollbar = true,
		--padding = {10,10,10,10},
	}

	local briefingtext = TextBox:New {
		x = 0,
		y = 0,
		width = "100%",
		height = "100%",
		valign = 'top',
		fontsize = Configuration:GetFont(2).size,
		text = scen.briefing,
		parent = briefingtextSP,
		
		padding = {10,10,10,10},
	}

	------------------------
	local lblpersonal = Label:New{
		x = "76%",
		y = "67.5%",
		width = "20%",
		height = "5%",
		parent = sPanel,
		font = Configuration:GetFont(3),
		caption = "Personal Records",
	}

	
	local lbldifflevelpersonal = Label:New{
		x = "76%",
		y = "72.5%",
		width = "20%",
		height = "5%",
		parent = sPanel,
		font = Configuration:GetFont(2),
		caption = "Difficulty: "..tostring(mydifficulty.name),
	}

	local lblmytime = Label:New{
		x = "76%",
		y = "77.5%",
		width = "25%",
		height = "5%",
		parent = sPanel,
		font = Configuration:GetFont(2),
		caption = "My Best Time: ",
	}
	lblmytime.font.color = {0.7, 0.7, 0.7, 1.0}
	
	local mytime = Label:New{
		x = "76%",
		y = "80.5%",
		width = "25%",
		height = "5%",
		parent = sPanel,
		font = Configuration:GetFont(2),
		caption = tostring(math.ceil(myscores.time/60)) .. " minutes",
	}

	local lblmyresources = Label:New{
		x = "76%",
		y = "85%",
		width = "25%",
		height = "5%",
		parent = sPanel,
		font = Configuration:GetFont(2),
		caption = "My Resources ",
	}
	lblmyresources.font.color = {0.7, 0.7, 0.7, 1.0}

	local myresources = Label:New{
		x = "76%",
		y = "89%",
		width = "25%",
		height = "5%",
		parent = sPanel,
		font = Configuration:GetFont(2),
		caption = tostring(math.ceil(myscores.resources/1000)) .. "K metal",
	}


	local sidelabel = Label:New{
		x = "0%",
		y = "40%" ,
		width = "100",
		height = "4%",
		parent = sPanel,
		font = Configuration:GetFont(2),
		caption = "Faction",
	}
	sidelabel.font.color = {0.7, 0.7, 0.7, 1.0}

	--[[
	local sidechangebutton  = Button:New {
		x = "25%",
		y = "50%" ,
		width = "100",
		height = "4%",
		caption = myside,
		classname = "option_button",
		font = Configuration:GetFont(2),
		tooltip = "Start the scenario",
		OnClick = {
			function(obj)
					Spring.Echo("Changing side:")
					WG.SideChangeWindow.CreateSideChangeWindow({
						initialSide = myside or 0,
						OnAccepted = function(sideId)
								local sidedata = Configuration:GetSideData()
								Spring.Echo("Chose side:",sideID,sidedata[sideID+1])
								myside = sidedata[sideID+1]
								obj:SetCaption(myside)
							end
					})
			end
		},
		parent = sPanel,
	}]]--

	local sideCombo = ComboBox:New{
		x = "16%",
		y = "40%" ,
		width = "33%",
		height = "4%",
		itemHeight = 22,
		valign = "center",
		align = "left",
		selectByName = true,
		--captionHorAlign = -32,
		text = "HasText",
		font = Configuration:GetFont(2),
		items = {"Armada", "Cortex", "Random"}, --{"Coop", "Team", "1v1", "FFA", "Custom"},
		itemFontSize = Configuration:GetFont(2).size,
		selected = 1,
		OnSelectName = {
			function (obj, selectedName)
					Spring.Echo("Faction selected:",selectedName)
					myside = selectedName
			end
		},
		parent = sPanel,
	}
	

	local difflabel = Label:New{
		x = "0%",
		y = "44%" ,
		width = "100",
		height = "4%",
		parent = sPanel,
		font = Configuration:GetFont(2),
		caption = "Difficulty",
	}
	difflabel.font.color = {0.7, 0.7, 0.7, 1.0}


	local function UpdateDifficulty(newdifficultyname)
		for i, diff in pairs(scen.difficulties) do 
			if diff.name == newdifficultyname then mydifficulty = diff end
		end
		lbldifflevelpersonal:SetCaption("Difficulty level: "..tostring(mydifficulty.name))
	end

	local difficultCombo = ComboBox:New{
		x = "16%",
		y = "44%" ,
		width = "33%",
		height = "4%",
		itemHeight = 22,
		valign = "left",
		align = "left",
		selectByName = true,
		--captionHorAlign = -32,
		text = "HasText",
		font = Configuration:GetFont(2),
		items = difficulties, --{"Coop", "Team", "1v1", "FFA", "Custom"},
		itemFontSize = Configuration:GetFont(2).size,
		selected = defaultdifficultyindex,
		OnSelectName = {
			function (obj, selectedName)
				Spring.Echo("Difficulty selected:",selectedName)
				UpdateDifficulty(selectedName,scenarioPanel)
			end
		},
		parent = sPanel,
	}


	local function createstartscript()
		local basescript = scen.startscript
		local numrestrictions = 0
		local restrictionstring = ''
		for unitid, count in pairs(scen.unitlimits) do 
			restrictionstring = restrictionstring .. "Unit"..tostring(numrestrictions).."="..unitid..";\nLimit"..tostring(numrestrictions).."="..tostring(count)..";\n"
			numrestrictions = numrestrictions + 1
		end
		local myName = WG.Chobby.Configuration:GetPlayerName()
		basescript = basescript:gsub("__NUMRESTRICTIONS__",tostring(numrestrictions))
		basescript = basescript:gsub("__RESTRICTEDUNITS__",restrictionstring)
		basescript = basescript:gsub("__PLAYERNAME__",myName)
		basescript = basescript:gsub("__PLAYERHANDICAP__",tostring(mydifficulty.playerhandicap))
		basescript = basescript:gsub("__ENEMYHANDICAP__",tostring(mydifficulty.enemyhandicap))
		basescript = basescript:gsub("__BARVERSION__",tostring(barversion))
		basescript = basescript:gsub("__MAPNAME__",tostring(scen.mapfilename))
		basescript = basescript:gsub("__PLAYERSIDE__",tostring(myside or scen.defaultside))
		basescript = basescript:gsub("__SCENARIOOPTIONS__",tostring(EncodeScenarioOptions(scen)))
	
	
		return basescript
	end

	local startmissionbutton = Button:New {
		x = "76%",
		y = "51%",
		right = 0,
		height = "10%",
		caption = "Start Scenario",
		classname = "action_button",
		font = Configuration:GetFont(3),
		tooltip = "Start the scenario",
		OnClick = {
			function()
					local scriptTxt = createstartscript()
					Spring.Echo("Mission Ready")
					Spring.Echo(scriptTxt)
					if WG.Analytics and WG.Analytics.SendRepeatEvent then
						WG.Analytics.SendRepeatEvent("game_start:singleplayer:scenario_start_" .. scen.scenarioid)
					end
					Spring.Reload(scriptTxt)
			end
		},
		parent = sPanel,
	}

end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Controls

local function InitializeControls(parentControl)
	local Configuration = WG.Chobby.Configuration

	DownloadRequirements()

	Label:New {
		x = "2%",
		y = 14,
		width = 180,
		--height = 30,
		parent = parentControl,
		font = Configuration:GetFont(3),
		caption = "Scenario",
	}

	local scenarioPanel = Control:New{
		x = "2%",
		y = 55,
		right = "2%",
		bottom = '2%',

		padding = {0,0,0,0},
		parent = parentControl,
	}

	local cbitemlist = {}
	for i, scen in ipairs(scenarios) do 
		cbitemlist[#cbitemlist+1] = scen.title
	end

	local scenarioSelectorCombo = ComboBox:New{
		x = 180,
		right = "2%",
		y = "16",
		height = 35,
		itemHeight = 35,
		selectByName = true,
		
		valign = "top",
		align = "left",
		--captionHorAlign = -32,
		text = "HasText",
		font = Configuration:GetFont(3),
		items = cbitemlist, --{"Coop", "Team", "1v1", "FFA", "Custom"},
		itemFontSize = Configuration:GetFont(3).size,
		selected = 1,
		OnSelectName = {
			function (obj, selectedName)
				Spring.Echo(selectedName)
				CreateScenarioPanel(selectedName,scenarioPanel)
			end
		},
		parent = parentControl,

	}

	CreateScenarioPanel(1,scenarioPanel)
	
	local externalFunctions = {}

	function externalFunctions.Example(none)
	end

	return externalFunctions
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- External Interface

local ScenarioHandler = {}

function ScenarioHandler.GetControl()

	local window = Control:New {
		name = "ScenarioHandler",
		x = "0%",
		y = "0%",
		width = "100%",
		height = "100%",
		OnParent = {
			function(obj)
				if obj:IsEmpty() then
					scenarioWindow = InitializeControls(obj)
				end
			end
		},
	}
	return window
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Widget Interface

local SCENARIO_COMPLETE_STRING = "scenario_complete_"

function widget:RecvLuaMsg(msg)
	if string.find(msg, SCENARIO_COMPLETE_STRING) then
		--local missionName = string.sub(msg, string.len(SCENARIO_COMPLETE_STRING) + 1)
		-- TODO:  Implement parsing of a scenario complete string
		-- It should return a couple of things, as we theoretically know the scenario ids passed through scenariooptions
		-- scenario ID
		-- time to game end in sec
		-- did player win t/f
		-- spent metal + E/60 resources value
		
		WG.Analytics.SendRepeatEvent("game_start:singleplayer:scenario_complete_" .. msg)
		Spring.Echo("scenario_complete_", msg)
	end
end

function widget:GetConfigData()
	Spring.Echo("Scenario Window GetConfigData")
	return {
		scores = scoreData,
	}
end

function widget:SetConfigData(data)
	
	Spring.Echo("Scenario Window SetConfigData")
	scoreData = data.scores or {}
end



local function DelayedInitialize()
	local Configuration = WG.Chobby.Configuration
	SetScore("testscores","1.0","Hard",100,9999) -- seems to work
end


function widget:Initialize()
	CHOBBY_DIR = LUA_DIRNAME .. "widgets/chobby/"
	VFS.Include(LUA_DIRNAME .. "widgets/chobby/headers/exports.lua", nil, VFS.RAW_FIRST)

	LoadScenarios()

	WG.Delay(DelayedInitialize, 1)

	WG.ScenarioHandler = ScenarioHandler

	--test scoring
end


local framenum = 0
function widget:Update() -- just to check if this still runs, and yes
	framenum = framenum + 1
	if math.fmod(framenum,1000)==0 then
		--Spring.Echo("widget:Update()")
	end
end
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
unitdefname_to_humanname  = {
		armaak = "Archangel",
		armaap = "Advanced Aircraft Plant",
		armaas = "Archer",
		armaca = "Advanced Construction Aircraft",
		armack = "Advanced Construction Bot",
		armacsub = "Advanced Construction Sub",
		armacv = "Advanced Construction Vehicle",
		armadvsol = "Advanced Solar Collector",
		armafus = "Advanced Fusion Reactor",
		armageo = "Geothermal Powerplant",
		armah = "Swatter",
		armalab = "Advanced Bot Lab",
		armamb = "Ambusher",
		armamd = "Protector",
		armamex = "Twilight",
		armamph = "Pelican",
		armamsub = "Amphibious Complex",
		armanac = "Anaconda",
		armanni = "Annihilator",
		armap = "Aircraft Plant",
		armapt3 = "Tech 3 Aircraft Plant",
		armarad = "Advanced Radar Tower",
		armart = "Shellshocker",
		armaser = "Eraser",
		armason = "Advanced Sonar Station",
		armasp = "Air Repair Pad",
		armassimilator = "Assimilator",
		armasy = "Advanced Shipyard",
		armatl = "Moray",
		armatlas = "Atlas",
		armavp = "Advanced Vehicle Plant",
		armawac = "Eagle",
		armbanth = "Bantha",
		armbats = "Millennium",
		armbeamer = "Beamer",
		armbeaver = "Beaver",
		armblade = "Blade",
		armbrawl = "Brawler",
		armbrtha = "Big Bertha",
		armbull = "Bulldog",
		armca = "Construction Aircraft",
		armcarry = "Colossus",
		armch = "Construction Hovercraft",
		armcir = "Chainsaw",
		armck = "Construction Bot",
		armckfus = "Cloakable Fusion Reactor",
		armclaw = "Dragon's Claw",
		armcom = "Commander",
		armcomboss = "Epic Commander - Final Boss",
		armconsul = "Consul",
		armcroc = "Triton",
		armcrus = "Conqueror",
		armcs = "Construction Corvette",
		armcsa = "Construction Seaplane",
		armcv = "Construction Vehicle",
		armdecade = "Decade",
		armdecom = "Commander",
		armdf = "Fusion Reactor",
		armdfly = "Dragonfly",
		armdl = "Anemone",
		armdrag = "Dragon's Teeth",
		armemp = "Detonator",
		armepoch = "Epoch",
		armestor = "Energy Storage",
		armeyes = "Dragon's Eye",
		armfark = "Fark",
		armfast = "Zipper",
		armfatf = "Floating Targeting Facility",
		armfav = "Rover",
		armfboy = "Fatboy",
		armfdrag = "Shark's Teeth",
		armfepocht4 = "Flying Epoch",
		armferret = "Ferret",
		armfflak = "Flakker NS",
		armfgate = "Aurora",
		armfhlt = "Stingray",
		armfhp = "Floating Hovercraft Platform",
		armfido = "Fido",
		armfig = "Freedom Fighter",
		armflak = "Flakker",
		armflash = "Flash",
		armflea = "Flea",
		armfmine3 = "Mega NS",
		armfmkr = "Floating Energy Converter",
		armfort = "Fortification Wall",
		armfrad = "Floating Radar/Sonar Tower",
		armfrock = "Scumbag",
		armfrt = "Sentry",
		armfus = "Fusion Reactor",
		armgate = "Keeper",
		armgeo = "Geothermal Powerplant",
		armgmm = "Prude",
		armgplat = "Gun Platform",
		armgremlin = "Gremlin",
		armguard = "Guardian",
		armham = "Hammer",
		armhawk = "Hawk",
		armhlt = "Sentinel",
		armhp = "Hovercraft Platform",
		armjam = "Jammer",
		armjamt = "Sneaky Pete",
		armjanus = "Janus",
		armjeth = "Jethro",
		armjuno = "Arm Juno",
		armkam = "Banshee",
		armlab = "Bot Lab",
		armlance = "Lancet",
		armlatnk = "Panther",
		armliche = "Liche",
		armllt = "LLT",
		armlun = "Lun",
		armlunchbox = "Lunchbox",
		armmakr = "Energy Converter",
		armmanni = "Penetrator",
		armmar = "Marauder",
		armmark = "Marky",
		armmart = "Luger",
		armmav = "Maverick",
		armmeatball = "Meatball",
		armmercury = "Mercury",
		armmerl = "Merl",
		armmex = "Metal Extractor",
		armmh = "Wombat",
		armmine1 = "Micro",
		armmine2 = "Kilo",
		armmine3 = "Mega",
		armmls = "Valiant",
		armmlv = "Podger",
		armmmkr = "Energy Converter",
		armmoho = "Moho Mine",
		armmship = "Ranger",
		armmstor = "Metal Storage",
		armnanotc = "Nano Turret",
		armnanotcplat = "Nano Turret",
		armpb = "Pit Bull",
		armpeep = "Peeper",
		armpincer = "Pincer",
		armplat = "Seaplane Platform",
		armpnix = "Phoenix",
		armpship = "Ellysaw",
		armpt = "Skeeter",
		armptl = "Harpoon",
		armpw = "Peewee",
		armpwt4 = "Epic Peewee",
		armrad = "Radar Tower",
		armrattet4 = "Ratte",
		armraz = "Razorback",
		armrecl = "Grim Reaper",
		armrectr = "Rector",
		armrectrt4 = "Epic Rector",
		armrl = "Defender",
		armrock = "Rocko",
		armroy = "Crusader",
		armsaber = "Sabre",
		armsam = "Samson",
		armsb = "Tsunami",
		armscab = "Scarab",
		armsd = "Tracer",
		armseap = "Albatross",
		armseer = "Seer",
		armsehak = "Seahawk",
		armserp = "Serpent",
		armserpold = "Serpent",
		armsfig = "Tornado",
		armsh = "Skimmer",
		armshltx = "Experimental Gantry",
		armshltxuw = "Experimental Gantry",
		armsilo = "Retaliator",
		armsjam = "Escort",
		armsnipe = "Sharpshooter",
		armsolar = "Solar Collector",
		armsonar = "Sonar Station",
		armspid = "Spider",
		armsptk = "Recluse",
		armsptkt4 = "Epic Recluse",
		armspy = "Infiltrator",
		armstil = "Stiletto",
		armstone = "Commander Tombstone",
		armstump = "Stumpy",
		armsub = "Lurker",
		armsubk = "Piranha",
		armsubkold = "Piranha",
		armsy = "Shipyard",
		armtarg = "Targeting Facility",
		armthovr = "Bear",
		armthund = "Thunder",
		armthundt4 = "Epic Thunder",
		armtide = "Tidal Generator",
		armtl = "Harpoon",
		armtorps = "Torpedo Ship",
		armtship = "Hulk",
		armuwadves = "Hardened Energy Storage",
		armuwadvms = "Hardened Metal Storage",
		armuwes = "Underwater Energy Storage",
		armuwfus = "Underwater Fusion Plant",
		armuwmex = "Offshore Metal Extractor",
		armuwmme = "Underwater Moho Mine",
		armuwmmm = "Floating Energy Converter",
		armuwms = "Underwater Metal Storage",
		armvader = "Invader",
		armvadert4 = "Epic Invader",
		armvang = "Vanguard",
		armveil = "Veil",
		armvp = "Vehicle Plant",
		armvulc = "Vulcan",
		armwar = "Warrior",
		armwin = "Wind Generator",
		armyork = "Phalanx",
		armzeus = "Zeus",
		chicken1 = "Chicken",
		chicken1b = "Chicken",
		chicken1c = "Chicken",
		chicken1d = "Chicken",
		chicken1x = "Chicken",
		chicken1y = "Chicken",
		chicken1z = "Chicken",
		chicken2 = "Chicken",
		chicken2b = "Chicken",
		chicken_dodo1 = "Dodo",
		chicken_dodo2 = "Alpha Dodo",
		chickena1 = "Cockatrice",
		chickena1b = "Cockatrice",
		chickena1c = "Cockatrice",
		chickena2 = "Alpha Cockatrice",
		chickena2b = "Alpha Cockatrice",
		chickenc1 = "Basilisk",
		chickenc2 = "Manticore",
		chickenc3 = "Weevil",
		chickenc3b = "Weevil",
		chickenc3c = "Weevil",
		chickend1 = "Chicken Tube",
		chickenf1 = "Talon",
		chickenf1b = "Talon",
		chickenf2 = "Buzzard",
		chickenh1 = "Weaver",
		chickenh1b = "Weaver",
		chickenh2 = "Progenitor",
		chickenh3 = "Chicken",
		chickenh4 = "Chicken",
		chickenh5 = "Patriarch",
		chickenp1 = "Bombardier",
		chickenr1 = "Lobber",
		chickenr2 = "Enraged Lobber",
		chickenr3 = "Chicken Colonizer",
		chickens1 = "Spiker",
		chickens2 = "Advanced Spiker",
		chickens3 = "Fang",
		chickenw1 = "Claw",
		chickenw1b = "Claw",
		chickenw1c = "Claw",
		chickenw1d = "Claw",
		chickenw2 = "Crow",
		coraak = "Manticore",
		coraap = "Advanced Aircraft Plant",
		coraca = "Advanced Construction Aircraft",
		corack = "Advanced Construction Bot",
		coracsub = "Advanced Construction Sub",
		coracv = "Advanced Construction Vehicle",
		coradvsol = "Advanced Solar Collector",
		corafus = "Advanced Fusion Reactor",
		corageo = "Geothermal Powerplant",
		corah = "Slinger",
		corak = "A.K.",
		coralab = "Advanced Bot Lab",
		coramph = "Gimp",
		coramsub = "Amphibious Complex",
		corap = "Aircraft Plant",
		corape = "Rapier",
		corapt3 = "Tech 3 Aircraft Plant",
		corarad = "Advanced Radar Tower",
		corarch = "Shredder",
		corason = "Advanced Sonar Station",
		corasp = "Air Repair Pad",
		corasy = "Advanced Shipyard",
		coratl = "Lamprey",
		coravp = "Advanced Vehicle Plant",
		corawac = "Vulture",
		corban = "Banisher",
		corbats = "Warlord",
		corbhmth = "Behemoth",
		corblackhy = "Black Hydra",
		corbuzz = "Buzzsaw",
		corbw = "Bladewing",
		corca = "Construction Aircraft",
		corcan = "Can",
		corcarry = "Hive",
		corcat = "Catapult",
		corch = "Construction Hovercraft",
		corck = "Construction Bot",
		corcom = "Commander",
		corcomboss = "Epic Commander - Final Boss",
		corcrash = "Crasher",
		corcrus = "Executioner",
		corcrw = "Krow",
		corcrwt4 = "Epic Krow",
		corcs = "Construction Ship",
		corcsa = "Construction Seaplane",
		corcut = "Cutlass",
		corcv = "Construction Vehicle",
		cordecom = "Commander",
		cordemont4 = "Demon",
		cordl = "Jellyfish",
		cordoom = "Doomsday Machine",
		cordrag = "Dragon's Teeth",
		corenaa = "Cobra - NS",
		corerad = "Eradicator",
		corestor = "Energy Storage",
		coresupp = "Supporter",
		coreter = "Deleter",
		corexp = "Exploiter",
		coreyes = "Dragon's Eye",
		corfast = "Freaker",
		corfatf = "Floating Targeting Facility",
		corfav = "Weasel",
		corfblackhyt4 = "Flying Black Hydra",
		corfdrag = "Shark's Teeth",
		corfgate = "Atoll",
		corfhlt = "Thunderbolt",
		corfhp = "Floating Hovercraft Platform",
		corfink = "Fink",
		corflak = "Cobra",
		corfmd = "Fortitude",
		corfmine3 = "1100 NS",
		corfmkr = "Floating Energy Converter",
		corfort = "Fortification Wall",
		corfrad = "Floating Radar/Sonar Tower",
		corfrock = "Janitor",
		corfrt = "Stinger",
		corfus = "Fusion Reactor",
		corgant = "Experimental Gantry",
		corgantuw = "Experimental Gantry",
		corgarp = "Garpike",
		corgate = "Overseer",
		corgator = "Instigator",
		corgatreap = "Gaat Reaper",
		corgeo = "Geothermal Powerplant",
		corgol = "Goliath",
		corgolt4 = "Epic Goliath",
		corgplat = "Gun Platform",
		corhal = "Halberd",
		corhllt = "HLLT",
		corhlt = "Warden",
		corhp = "Hovercraft Platform",
		corhrk = "Dominator",
		corhunt = "Hunter",
		corhurc = "Hurricane",
		corint = "Intimidator",
		corintr = "Intruder",
		corjamt = "Castro",
		corjugg = "Juggernaut",
		corjuno = "Cortex Juno",
		corkarg = "Karganeth",
		corkarganetht4 = "Epic Karganeth",
		corkorg = "Korgoth",
		corlab = "Bot Lab",
		corlevlr = "Leveler",
		corllt = "LLT",
		cormabm = "Hedgehog",
		cormadsam = "SAM",
		cormakr = "Energy Converter",
		cormando = "Commando",
		cormart = "Pillager",
		cormaw = "Dragon's Maw",
		cormex = "Metal Extractor",
		cormexp = "Moho Exploiter",
		cormh = "Nixer",
		cormine1 = "11",
		cormine2 = "110",
		cormine3 = "1100",
		cormine4 = "112",
		cormist = "Slasher",
		cormls = "Pathfinder",
		cormlv = "Spoiler",
		cormmkr = "Energy Converter",
		cormoho = "Moho Mine",
		cormort = "Morty",
		cormship = "Messenger",
		cormstor = "Metal Storage",
		cormuskrat = "Muskrat",
		cornanotc = "Nano Turret",
		cornanotcplat = "Nano Turret",
		cornecro = "Necro",
		corparrow = "Poison Arrow",
		corplat = "Seaplane Platform",
		corpship = "Era",
		corpt = "Searcher",
		corptl = "Urchin",
		corpun = "Punisher",
		corpyro = "Pyro",
		corrad = "Radar Tower",
		corraid = "Raider",
		correap = "Reaper",
		correcl = "Death Cavalry",
		corrl = "Pulverizer",
		corroach = "Roach",
		corroy = "Enforcer",
		corsb = "Dam Buster",
		corscreamer = "Screamer",
		corsd = "Nemesis",
		corseah = "Seahook",
		corseal = "Croc",
		corseap = "Typhoon",
		corsent = "Copperhead",
		corsfig = "Voodoo",
		corsh = "Scrubber",
		corshad = "Shadow",
		corshark = "Shark",
		corsharkold = "Shark",
		corshiva = "Shiva",
		corshroud = "Shroud",
		corsilo = "Silencer",
		corsjam = "Phantom",
		corsktl = "Skuttle",
		corsnap = "Snapper",
		corsok = "Sokolov",
		corsolar = "Solar Collector",
		corsonar = "Sonar Station",
		corspec = "Spectre",
		corspy = "Parasite",
		corssub = "Leviathan",
		corssubold = "Leviathan",
		corstone = "Commander Tombstone",
		corstorm = "Storm",
		corsub = "Snake",
		corsumo = "Sumo",
		corsy = "Shipyard",
		cortarg = "Targeting Facility",
		cortermite = "Termite",
		corthovr = "Turtle",
		corthud = "Thud",
		cortide = "Tidal Generator",
		cortitan = "Titan",
		cortl = "Urchin",
		cortoast = "Toaster",
		cortrem = "Tremor",
		cortron = "Catalyst",
		cortship = "Envoy",
		coruwadves = "Hardened Energy Storage",
		coruwadvms = "Hardened Metal Storage",
		coruwes = "Underwater Energy Storage",
		coruwfus = "Underwater Fusion Plant",
		coruwmex = "Offshore Metal Extractor",
		coruwmme = "Underwater Moho Mine",
		coruwmmm = "Floating Energy Converter",
		coruwms = "Underwater Metal Storage",
		corvalk = "Valkyrie",
		corvamp = "Vamp",
		corveng = "Avenger",
		corvipe = "Viper",
		corvoyr = "Voyeur",
		corvp = "Vehicle Plant",
		corvrad = "Informer",
		corvroc = "Diplomat",
		corwin = "Wind Generator",
		corwolv = "Wolverine",
		e_chickenq = "Chicken Queen",
		epic_chickenq = "Epic Chicken Queen",
		h_chickenq = "Chicken Queen",
		n_chickenq = "Chicken Queen",
		roost = "Roost",
		ve_chickenq = "Chicken Queen",
		vh_chickenq = "Chicken Queen",
}
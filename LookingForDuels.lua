--------------------------------------------------------------------------------
--                      L O O K I N G   F O R   D U E L S                     --
--------------------------------------------------------------------------------
--				  Copyright 2017-2019 Dylan Fortune (Crieve-Atiesh)           --
--------------------------------------------------------------------------------
local app = select(2, ...);
LookingForDuelsAPI = app;	
local events = {};
app.events = events;
local _ = CreateFrame("FRAME", nil, UIParent);
_:SetScript("OnEvent", function(self, e, ...) (rawget(events, e) or print)(...); end);
_:SetPoint("BOTTOMLEFT", UIParent, "TOPLEFT", 0, 0);
_:RegisterEvent("VARIABLES_LOADED");
_:RegisterEvent("DUEL_REQUESTED");
_:SetSize(1, 1);
_:Show();

-- Coroutine Helper Functions
app.refreshing = {};
local function OnUpdate(self)
	for i=#self.__stack,1,-1 do
		if not self.__stack[i][1](self) then
			table.remove(self.__stack, i);
			if #self.__stack < 1 then
				self:SetScript("OnUpdate", nil);
			end
		end
	end
end
local function Push(self, name, method)
	if not self.__stack then
		self.__stack = {};
		self:SetScript("OnUpdate", OnUpdate);
	elseif #self.__stack < 1 then 
		self:SetScript("OnUpdate", OnUpdate);
	end
	table.insert(self.__stack, { method, name });
end
local function StartCoroutine(name, method)
	if method and not app.refreshing[name] then
		local instance = coroutine.create(method);
		app.refreshing[name] = instance;
		Push(_, name, function()
			-- Check the status of the coroutine
			if instance and coroutine.status(instance) ~= "dead" then
				local ok, err = coroutine.resume(instance);
				if ok then return true;	-- This means more work is required.
				else
					-- Show the error. Returning nothing is the same as canceling the work.
					print(err);
				end
			end
			app.refreshing[name] = nil;
		end);
	end
end
local function StopCoroutine(name)
	if app.refreshing[name] then
		debug.sethook(app.refreshing[name], function()
			error("Coroutine Ended Externally");
		end, "l");
		app.refreshing[name] = nil;
	end
end

-- Class Prototypes
local DefaultSettings = { __index = {
	BattleAudioEnabled = true,
	BattleAudioOptions = {
		"battle1.ogg"
	},
	DefeatAudioEnabled = true,
	DefeatAudioOptions = {
		"defeat1.ogg"
	},
	OutOfBoundsAudioEnabled = true,
	OutOfBoundsAudioOptions = {
		"outofbounds1.ogg"
	},
	SoundEffectsChannel = "SFX",
	VictoryAudioEnabled = true,
	VictoryAudioOptions = {
		"victory1.ogg"
	},
}};
local OpponentClass = { __index = function(t, key)
	if key == "name" then
		local guid = rawget(t, "guid");
		if guid then
			for name,g in pairs(LookingForDuelsData.CachedCharacterGUIDS) do
				if guid == g then
					rawset(t, key, name);
					return name;
				end
			end
		end
	elseif key == "lvl" then
		local name = t.name;
		if name then
			local lvl = UnitLevel(t.name);
			if lvl then
				rawset(t, key, name);
				return lvl;
			end
			return 1;
		end
		return 0;
	elseif key == "class" then
		local name = t.name;
		if name then
			local class = select(3, UnitClass(name));
			if class then
				rawset(t, key, class);
				return class;
			end
		end
	elseif key == "race" then
		local name = t.name;
		if name then
			local race = select(3, UnitRace(name));
			if race then
				rawset(t, key, race);
				return race;
			end
		end
	elseif key == "faction" then
		local name = t.name;
		if name then
			local faction = UnitFactionGroup("target");
			if faction then
				rawset(t, key, faction);
				return faction;
			end
		end
	elseif key == "text" then
		local classInfo = C_CreatureInfo.GetClassInfo(t.class);
		local raceInfo = C_CreatureInfo.GetRaceInfo(t.race);
		return "|c" .. (RAID_CLASS_COLORS[classInfo.classFile].colorStr or "ff1eff00") .. t.name .. " (Level " .. (t.lvl or "??") .. " " .. (raceInfo.raceName or "??").. " " .. (classInfo.className or "??") .. ")|r";
	end
end};


-- Functionality
function Print(...)
	print("LFD: ", ...);
end
function PlayAddonMusic(music)
	if music then
		PlayMusic("Interface\\Addons\\LookingForDuels\\media\\audio\\" .. music);
	end
end
function PlayRandomMusic(audioTable)
	if audioTable then PlayAddonMusic(audioTable[math.random(1, #audioTable)]); end
end
function PlayAddonSound(soundEffect)
	if soundEffect then PlaySoundFile("Interface\\Addons\\LookingForDuels\\media\\audio\\" .. soundEffect, LookingForDuelsData.SoundEffectsChannel); end
end
function PlayRandomSound(audioTable)
	if audioTable then PlayAddonSound(audioTable[math.random(1, #audioTable)]); end
end
function PlayBattleMusic()
	if LookingForDuelsData.BattleAudioEnabled then
		PlayRandomMusic(LookingForDuelsData.BattleAudioOptions);
	end
end
function PlayDefeatSound()
	if LookingForDuelsData.DefeatAudioEnabled then
		PlayRandomSound(LookingForDuelsData.DefeatAudioOptions);
	end
end
function PlayVictorySound()
	if LookingForDuelsData.VictoryAudioEnabled then
		PlayRandomSound(LookingForDuelsData.VictoryAudioOptions);
	end
end
function CleanUpDuel()
	LookingForDuelsData.IsDueling = nil;
	LookingForDuelsData.IsPending = nil;
	LookingForDuelsData.CurrentOpponentName = nil;
	LookingForDuelsData.WinCondition = nil;
	LookingForDuelsData.WinRetreatCondition = nil;
	LookingForDuelsData.LoseCondition = nil;
	LookingForDuelsData.LoseRetreatCondition = nil;
	LookingForDuelsData.OutOfBounds = nil;
	LookingForDuelsData.Victory = nil;
	_:UnregisterEvent("CHAT_MSG_SYSTEM");
	_:UnregisterEvent("DUEL_INBOUNDS");
	_:UnregisterEvent("DUEL_OUTOFBOUNDS");
	_:UnregisterEvent("DUEL_FINISHED");
end
function ProcessDuel()
	-- Acquire the GUID of the Opponent. [Global Persistence]
	local CurrentOpponentName, CurrentOpponent = LookingForDuelsData.CurrentOpponentName, nil;
	local guid = rawget(LookingForDuelsData.CachedCharacterGUIDS, CurrentOpponentName);
	if guid then CurrentOpponent = rawget(LookingForDuelsData.CachedCharacterData, guid); end
	Print("STARTING DUEL: ", CurrentOpponentName);
	
	-- Scan for Target data until the player name matches the opponent.
	while not CurrentOpponent do
		if UnitIsPlayer("target") and UnitName("target") == CurrentOpponentName then
			guid = UnitGUID("target");
			if guid then
				-- Build a Cached Character Profile for the Target
				CurrentOpponent = setmetatable({
					["lvl"] = UnitLevel("target"),
					["class"] = select(3, UnitClass("target")),
					["race"] = select(3, UnitRace("target")),
					["faction"] = UnitFactionGroup("target"),
				}, OpponentClass);
				rawset(LookingForDuelsData.CachedCharacterGUIDS, CurrentOpponentName, guid);
				rawset(LookingForDuelsData.CachedCharacterData, guid, CurrentOpponent);
			else
				coroutine.yield();
			end
		else
			coroutine.yield();
		end
	end
	
	-- Notify the Player that the Duel is Starting
	local playerName = UnitName("player");
	CurrentOpponent.name = CurrentOpponentName;
	Print("OPPONENT:", CurrentOpponent.text);
	LookingForDuelsData.WinCondition = string.format(DUEL_WINNER_KNOCKOUT, playerName, CurrentOpponentName);
	LookingForDuelsData.WinRetreatCondition = string.format(DUEL_WINNER_RETREAT, playerName, CurrentOpponentName);
	LookingForDuelsData.LoseCondition = string.format(DUEL_WINNER_KNOCKOUT, CurrentOpponentName, playerName);
	LookingForDuelsData.LoseRetreatCondition = string.format(DUEL_WINNER_RETREAT, CurrentOpponentName, playerName);
	_:RegisterEvent("CHAT_MSG_SYSTEM");
	_:RegisterEvent("DUEL_OUTOFBOUNDS");
	_:RegisterEvent("DUEL_FINISHED");
	
	-- If the Duel hasn't already been started, then wait for it to start.
	if not LookingForDuelsData.IsDueling then
		-- While the Duel is pending, wait.
		LookingForDuelsData.IsPending = true;
		while LookingForDuelsData.IsPending do
			if InCombatLockdown() then
				-- We're in Combat, are we Hostile to the target?
				if UnitIsPlayer("target") and UnitIsEnemy("player", "target") and UnitName("target") == CurrentOpponentName then
					LookingForDuelsData.IsPending = nil;
					break;
				else
					coroutine.yield();
				end
			else
				coroutine.yield();
			end
		end
		LookingForDuelsData.IsDueling = true;
		_:UnregisterEvent("DUEL_FINISHED");
	end
	
	-- Play that sick Battle Music!
	PlayBattleMusic();
	
	-- While the Duel is going on, wait.
	while LookingForDuelsData.IsDueling do
		coroutine.yield();
	end
	
	-- Did you Win or Lose?
	if LookingForDuelsData.Victory then
		Print(LookingForDuelsData.OutOfBounds and "YOU WIN! (OUT OF BOUNDS)" or "YOU WIN!");
		PlayVictorySound();
	else
		Print(LookingForDuelsData.OutOfBounds and "YOU LOSE! (OUT OF BOUNDS)" or "YOU LOSE!");
		PlayDefeatSound();
	end
	
	-- The Duel has Ended, let's cut the music and clean up the persistent data.
	StopMusic();
	CleanUpDuel();
end


-- Hooks
local originalStartDuel = StartDuel;
StartDuel = function(target)
	events.DUEL_REQUESTED(target);
	originalStartDuel(target);
end

-- Event Handlers
events.VARIABLES_LOADED = function()
	if not LookingForDuelsData then LookingForDuelsData = {}; end
	setmetatable(LookingForDuelsData, DefaultSettings);
	if not LookingForDuelsData.CachedCharacterData then
		LookingForDuelsData.CachedCharacterData = {};
	else
		for guid,data in pairs(LookingForDuelsData.CachedCharacterData) do
			setmetatable(data, OpponentClass);
		end
	end
	if not LookingForDuelsData.CachedCharacterGUIDS then
		LookingForDuelsData.CachedCharacterGUIDS = {};
	end
	
	-- If a Duel was previously active, let's check to see if you're still dueling.
	if LookingForDuelsData.CurrentOpponentName then
		events.DUEL_REQUESTED(LookingForDuelsData.CurrentOpponentName);
	else
		CleanUpDuel();
	end
end
events.CHAT_MSG_SYSTEM = function(msg, ...)
	if LookingForDuelsData.IsDueling then
		if msg == LookingForDuelsData.WinCondition then
			LookingForDuelsData.Victory = true;
			LookingForDuelsData.OutOfBounds = nil;
			LookingForDuelsData.IsDueling = false;
		elseif msg == LookingForDuelsData.LoseCondition then
			LookingForDuelsData.Victory = nil;
			LookingForDuelsData.OutOfBounds = nil;
			LookingForDuelsData.IsDueling = false;
		elseif msg == LookingForDuelsData.WinRetreatCondition then
			LookingForDuelsData.Victory = true;
			LookingForDuelsData.OutOfBounds = true;
			LookingForDuelsData.IsDueling = false;
		elseif msg == LookingForDuelsData.LoseRetreatCondition then
			LookingForDuelsData.Victory = nil;
			LookingForDuelsData.OutOfBounds = true;
			LookingForDuelsData.IsDueling = false;
		end
	else
		-- We must be waiting for the Duel to Start.
		if string.find(msg, DUEL_COUNTDOWN) then
			LookingForDuelsData.IsPending = nil;
		end
	end
end
events.DUEL_REQUESTED = function(playerName)
	if not playerName or playerName == "" then playerName = UnitName("target"); end
	if playerName then
		LookingForDuelsData.CurrentOpponentName = select(1, UnitName(playerName)) or playerName;
		StopCoroutine("ProcessDuel");
		StartCoroutine("ProcessDuel", ProcessDuel);
	end
end
events.DUEL_INBOUNDS = function()
	LookingForDuelsData.OutOfBounds = nil;
	if LookingForDuelsData.OutOfBoundsAudioEnabled then
		StopMusic();
		PlayBattleMusic();
	end
	_:UnregisterEvent("DUEL_INBOUNDS");
end
events.DUEL_OUTOFBOUNDS = function()
	_:RegisterEvent("DUEL_INBOUNDS");
	LookingForDuelsData.OutOfBounds = true;
	if LookingForDuelsData.OutOfBoundsAudioEnabled then
		PlayRandomMusic(LookingForDuelsData.OutOfBoundsAudioOptions);
	end
end
events.DUEL_FINISHED = function()
	LookingForDuelsData.IsDueling = false;
	LookingForDuelsData.IsPending = nil;
end
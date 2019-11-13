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

-- Localization
local L = {
	TITLE = "|cffb4b4ffLookingForDuels|r",
	PREFIX = "|cffb4b4ffLFD|r",
	DUEL_CURRENT_TARGET = "Duel Current Target",
	DUEL_ACCEPT = "Accept Duel",
	DUEL_DECLINE = "Decline Duel",
	SYNC_TARGET = "Synchronize Target",
	SYNC_ALL = "Synchronize All Data",
	TOGGLE_UI = "Toggle UI",
	TOGGLE_SETTINGS_UI = "Toggle Settings UI",
};

-- Bindings
BINDING_HEADER_LFDUELS = L.TITLE;
BINDING_NAME_LFDUELS_DUELTARGET = L.DUEL_CURRENT_TARGET;
BINDING_NAME_LFDUELS_DUEL_ACCEPT = L.DUEL_ACCEPT;
BINDING_NAME_LFDUELS_DUEL_DECLINE = L.DUEL_DECLINE;
BINDING_NAME_LFDUELS_SYNC_TARGET = L.SYNC_TARGET;
BINDING_NAME_LFDUELS_SYNC_ALL = L.SYNC_ALL;
BINDING_NAME_LFDUELS_TOGGLE_UI = L.TOGGLE_UI;
BINDING_NAME_LFDUELS_TOGGLE_SETTINGS_UI = L.TOGGLE_SETTINGS_UI;

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
local function StopAllCoroutines()
	for i=#_.__stack,1,-1 do
		table.remove(_.__stack, i);
	end
	_:SetScript("OnUpdate", nil);
end
local function StopCoroutine(name)
	if app.refreshing[name] then
		for i=#_.__stack,1,-1 do
			if _.__stack[i][2] == name then
				table.remove(_.__stack, i);
			end
		end
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
	print(L.PREFIX .. ":", ...);
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
	StopMusic();
	if LookingForDuelsData.IsDueling or LookingForDuelsData.IsPending then
		Print(ERR_DUEL_CANCELLED);
	end
	LookingForDuelsData.IsDueling = nil;
	LookingForDuelsData.IsPending = nil;
	LookingForDuelsData.CurrentOpponentName = nil;
	LookingForDuelsData.WinCondition = nil;
	LookingForDuelsData.WinRetreatCondition = nil;
	LookingForDuelsData.LoseCondition = nil;
	LookingForDuelsData.LoseRetreatCondition = nil;
	LookingForDuelsData.OutOfBounds = nil;
	LookingForDuelsData.Victory = nil;
	LookingForDuelsData.ClearData = nil;
	_:UnregisterEvent("CHAT_MSG_SYSTEM");
	_:UnregisterEvent("DUEL_INBOUNDS");
	_:UnregisterEvent("DUEL_OUTOFBOUNDS");
	_:UnregisterEvent("DUEL_FINISHED");
end
function ConfirmDuel()
	AcceptDuel();
	StaticPopup_Hide("DUEL_REQUESTED");
end
function DeclineDuel()
	CancelDuel();
	StaticPopup_Hide("DUEL_REQUESTED");
end
function DuelTarget()
	DeclineDuel();
	StartDuel();
end
function ProcessDuel()
	-- Acquire the GUID of the Opponent. [Global Persistence]
	local CurrentOpponentName, CurrentOpponent = LookingForDuelsData.CurrentOpponentName, nil;
	local guid = rawget(LookingForDuelsData.CachedCharacterGUIDS, CurrentOpponentName);
	if guid then CurrentOpponent = rawget(LookingForDuelsData.CachedCharacterData, guid); end
	
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
	Print(CurrentOpponent.text);
	LookingForDuelsData.WinCondition = string.format(DUEL_WINNER_KNOCKOUT, playerName, CurrentOpponentName);
	LookingForDuelsData.WinRetreatCondition = string.format(DUEL_WINNER_RETREAT, playerName, CurrentOpponentName);
	LookingForDuelsData.LoseCondition = string.format(DUEL_WINNER_KNOCKOUT, CurrentOpponentName, playerName);
	LookingForDuelsData.LoseRetreatCondition = string.format(DUEL_WINNER_RETREAT, CurrentOpponentName, playerName);
	_:RegisterEvent("CHAT_MSG_SYSTEM");
	_:RegisterEvent("DUEL_OUTOFBOUNDS");
	
	-- If the Duel hasn't already been started, then wait for it to start.
	if not LookingForDuelsData.IsDueling then
		-- While the Duel is pending, wait.
		LookingForDuelsData.IsPending = true;
		_:RegisterEvent("DUEL_FINISHED");
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
			if LookingForDuelsData.ClearData then
				CleanUpDuel();
				return 0;
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
		if LookingForDuelsData.ClearData then
			CleanUpDuel();
			return 0;
		end
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
	CleanUpDuel();
end
function SyncAll()
	Print("Placeholder function for SyncAll.");
end
function SyncTarget()
	Print("Placeholder function for SyncTarget");
end
function ToggleUI()
	Print("Placeholder function for ToggleUI.");
end
function ToggleSettingsUI()
	Print("Placeholder function for ToggleSettingsUI.");
end

-- Exposed Functions
LookingForDuelsAPI.ConfirmDuel = ConfirmDuel;
LookingForDuelsAPI.DeclineDuel = DeclineDuel;
LookingForDuelsAPI.DuelTarget = DuelTarget;
LookingForDuelsAPI.SyncAll = SyncAll;
LookingForDuelsAPI.SyncTarget = SyncTarget;
LookingForDuelsAPI.ToggleUI = ToggleUI;
LookingForDuelsAPI.ToggleSettingsUI = ToggleSettingsUI;

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
		StopCoroutine(LookingForDuelsData.CurrentOpponentName);
		StartCoroutine(LookingForDuelsData.CurrentOpponentName, ProcessDuel);
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
	LookingForDuelsData.ClearData = true;
end

-- Slash Commands
SLASH_LFDUELS1 = "/lfd";
SLASH_LFDUELS2 = "/lfduel";
SLASH_LFDUELS3 = "/lfduels";
SLASH_LFDUELS4 = "/lookingforduel";
SLASH_LFDUELS5 = "/lookingforduels";
SlashCmdList["LFDUELS"] = function(cmd)
	if cmd and cmd ~= "" then
		if cmd == "start" or cmd == "duel" then
			DuelTarget();
			return 0;
		elseif cmd == "sync" or cmd == "u" then
			SyncTarget();
			return 0;
		elseif cmd == "syncall" or cmd == "sync all" or cmd == "all" then
			SyncAll();
			return 0;
		elseif cmd == "clean" or cmd == "clear" then
			LookingForDuelsData.ClearData = true;
			return 0;
		elseif cmd == "settings" then
			ToggleSettingsUI();
			return 0;
		end
	end
	ToggleUI();
end
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
_:RegisterEvent("PLAYER_LOGIN");
_:RegisterEvent("DUEL_REQUESTED");
_:RegisterEvent("DUEL_OUTOFBOUNDS");
_:RegisterEvent("DUEL_FINISHED");
_:SetSize(1, 1);
_:Show();

-- Persistent Data Storage
local LookingForDuelsData = {};
local LookingForDuelsDataPerCharacter = {};

-- Temporary Data Storage
local CurrentOpponentName, CurrentOpponent, IsDueling;

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
	--print("Push->" .. name);
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
	end
end};


-- Functionality
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
	LookingForDuelsData.IsDueling = false;
	LookingForDuelsData.CurrentOpponentName = nil;
	LookingForDuelsData.WinCondition = nil;
	LookingForDuelsData.WinRetreatCondition = nil;
	LookingForDuelsData.LoseCondition = nil;
	LookingForDuelsData.LoseRetreatCondition = nil;
	LookingForDuelsData.OutOfBounds = nil;
	LookingForDuelsData.Victory = nil;
	_:UnregisterEvent("CHAT_MSG_SYSTEM");
end
function ProcessDuel()
	print("STARTING DUEL: ", CurrentOpponentName);
	
	-- Acquire the GUID of the Opponent. [Global Persistence]
	local guid = rawget(LookingForDuelsData.CachedCharacterGUIDS, CurrentOpponentName);
	if guid then
		CurrentOpponent = rawget(LookingForDuelsData.CachedCharacterData, guid);
	else
		CurrentOpponent = nil;
	end
	
	-- Scan for Target data until the player name matches the opponent.
	while not CurrentOpponent do
		if UnitIsPlayer("target") and UnitName("target") == CurrentOpponentName then
			guid = UnitGUID("target");
			if guid then
				-- Build a Cached Character Profile for the Target
				opponent = setmetatable({
					["lvl"] = UnitLevel("target"),
					["class"] = select(3, UnitClass("target")),
					["race"] = select(3, UnitRace("target")),
					["faction"] = UnitFactionGroup("target"),
				}, OpponentClass);
				rawset(LookingForDuelsData.CachedCharacterGUIDS, CurrentOpponentName, guid);
				rawset(LookingForDuelsData.CachedCharacterData, guid, opponent);
				CurrentOpponent = opponent;
			else
				coroutine.yield();
			end
		else
			coroutine.yield();
		end
	end
	
	-- Notify the Player that the Duel is Starting
	local playerName = UnitName("player");
	local classInfo = C_CreatureInfo.GetClassInfo(opponent.class);
	local raceInfo = C_CreatureInfo.GetRaceInfo(opponent.race);
	print("OPPONENT FOUND: |c" .. (RAID_CLASS_COLORS[classInfo.classFile].colorStr or "ff1eff00") .. CurrentOpponentName .. " (Level " .. (opponent.lvl or "??") .. " " .. (raceInfo.raceName or "??").. " " .. (classInfo.className or "??") .. ")|r");
	LookingForDuelsData.CurrentOpponentName = CurrentOpponentName;
	LookingForDuelsData.WinCondition = string.format(DUEL_WINNER_KNOCKOUT, playerName, CurrentOpponentName);
	LookingForDuelsData.WinRetreatCondition = string.format(DUEL_WINNER_RETREAT, playerName, CurrentOpponentName);
	LookingForDuelsData.LoseCondition = string.format(DUEL_WINNER_KNOCKOUT, CurrentOpponentName, playerName);
	LookingForDuelsData.LoseRetreatCondition = string.format(DUEL_WINNER_RETREAT, CurrentOpponentName, playerName);
	LookingForDuelsData.IsDueling = true;
	_:RegisterEvent("CHAT_MSG_SYSTEM");
	
	-- While the Duel is going on, wait.
	while LookingForDuelsData.IsDueling do
		coroutine.yield();
	end
	
	print("DUEL ENDED");
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
events.PLAYER_LOGIN = function()
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
	if LookingForDuelsData.IsDueling and LookingForDuelsData.CurrentOpponentName then
		events.DUEL_REQUESTED(LookingForDuelsData.CurrentOpponentName);
	else
		CleanUpDuel();
	end
end
events.CHAT_MSG_SYSTEM = function(msg, ...)
	print("CHAT_MSG_SYSTEM", msg, ...);
	if LookingForDuelsData.IsDueling then
		if msg == LookingForDuelsData.WinCondition then
			print("YOU WIN!");
			LookingForDuelsData.Victory = true;
			LookingForDuelsData.OutOfBounds = nil;
			PlayVictorySound();
		elseif msg == LookingForDuelsData.LoseCondition then
			print("YOU LOSE!");
			LookingForDuelsData.Victory = nil;
			LookingForDuelsData.OutOfBounds = nil;
			PlayDefeatSound();
		elseif msg == LookingForDuelsData.WinRetreatCondition then
			print("YOU WIN! (OUT OF BOUNDS)");
			LookingForDuelsData.Victory = true;
			LookingForDuelsData.OutOfBounds = true;
			PlayVictorySound();
		elseif msg == LookingForDuelsData.LoseRetreatCondition then
			print("YOU LOSE! (OUT OF BOUNDS)");
			LookingForDuelsData.Victory = nil;
			LookingForDuelsData.OutOfBounds = true;
			PlayDefeatSound();
		end
	end
end
events.DUEL_REQUESTED = function(playerName)
	if not playerName or playerName == "" then playerName = UnitName("target"); end
	if playerName then
		CurrentOpponentName = select(1, UnitName(playerName)) or playerName;
		StopCoroutine("ProcessDuel");
		StartCoroutine("ProcessDuel", ProcessDuel);
	end
end
events.DUEL_INBOUNDS = function()
	print("DUEL_INBOUNDS");
	LookingForDuelsData.OutOfBounds = nil;
	if LookingForDuelsData.OutOfBoundsAudioEnabled then
		StopMusic();
	end
	_:UnregisterEvent("DUEL_INBOUNDS");
end
events.DUEL_OUTOFBOUNDS = function()
	print("DUEL_OUTOFBOUNDS");
	_:RegisterEvent("DUEL_INBOUNDS");
	LookingForDuelsData.OutOfBounds = true;
	if LookingForDuelsData.OutOfBoundsAudioEnabled then
		PlayRandomMusic(LookingForDuelsData.OutOfBoundsAudioOptions);
	end
end
events.DUEL_FINISHED = function()
	print("DUEL_FINISHED");
	LookingForDuelsData.IsDueling = false;
end
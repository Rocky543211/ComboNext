import "Turbine";
import "Turbine.Gameplay";
import "Turbine.UI";
import "Turbine.UI.Lotro";
import "ComboNext.Constants";
import "ComboNext.ComboLogic";
import "ComboNext.Localization";
import "ComboNext.OptionsPanel";
import "ComboNext.SequenceEditor";
import "ComboNext.ComboShare";
import "ComboNext.ClassSkills";
import "ComboNext.EffectCatalog";

ComboNext = {};
local ui = ComboNext;

local MAX_STEPS = ComboNextConstants.maxSteps;
local MAX_DISPLAY_ROWS = ComboNextConstants.maxDisplayRows;
local RESET_SECONDS = ComboNextConstants.resetSeconds;
local SLOT_BIG, SLOT_SMALL = 56, 36;
local WINDOW_WIDTH, WINDOW_HEIGHT = 390, 304;
local settings;

local function GetEffectiveUiScale()
    local requested = settings.uiScale or 1;
    local fitScale = math.min(
        (Turbine.UI.Display.GetWidth() - 24) / 500,
        (Turbine.UI.Display.GetHeight() - 24) / 500
    );
    return math.max(0.5, math.min(requested, fitScale));
end

local function ClampScaledWindow(window, scale)
    local width = window:GetWidth() * scale;
    local height = window:GetHeight() * scale;
    local x, y = window:GetPosition();
    window:SetPosition(
        math.max(0, math.min(x, Turbine.UI.Display.GetWidth() - width)),
        math.max(0, math.min(y, Turbine.UI.Display.GetHeight() - height))
    );
end
local RIGHT_BUTTON = (Turbine.UI.MouseButton and Turbine.UI.MouseButton.Right) or 2;
local SKILL_SHORTCUT = Turbine.UI.Lotro.ShortcutType.Skill;
local ITEM_SHORTCUT = Turbine.UI.Lotro.ShortcutType.Item;
local MAX_VISIBLE_FINISHERS = ComboNextConstants.maxVisibleFinishers;
local VERSION = ComboNextConstants.version;
local RECOMMENDATION_SECONDS = ComboNextConstants.recommendationSeconds;
local L = ComboNextL;
ui.textButtons = {};
local sequenceEditor;
local shareWindow;
local optionsPanel, optionsWindow;
local OpenSequenceEditor;
local OpenOptionsWindow;
local HandleSkill;
local UpdateActiveSequence;
local onHudKey;
local RefreshOptionsPanels;
local ApplyUiScale;
local ApplyUiTheme;
local RefreshConditions;
local GetFinisherReadiness;
local RecordItemUse;
local itemCooldowns = {};

local UI_THEMES = {
    gold = {
        background = { 0.3, 0.05, 0.05, 0.05 };
        accent = { 1, 1, 0.75 };
        hover = { 1, 1, 0.9 };
        status = { 1, 0.82, 0.48 };
        highlight = { 0.5, 0, 0.9, 0 };
    };
    blue = {
        background = { 0.3, 0.025, 0.055, 0.09 };
        accent = { 0.58, 0.82, 1 };
        hover = { 0.82, 0.94, 1 };
        status = { 0.68, 0.86, 1 };
        highlight = { 0.65, 0.12, 0.58, 1 };
    };
    violet = {
        background = { 0.3, 0.07, 0.035, 0.09 };
        accent = { 0.84, 0.68, 1 };
        hover = { 0.94, 0.86, 1 };
        status = { 0.88, 0.76, 1 };
        highlight = { 0.65, 0.68, 0.28, 0.92 };
    };
    green = {
        background = { 0.3, 0.025, 0.075, 0.055 };
        accent = { 0.62, 1, 0.73 };
        hover = { 0.84, 1, 0.9 };
        status = { 0.68, 1, 0.76 };
        highlight = { 0.65, 0.12, 0.9, 0.25 };
    };
};

local function NumberToInvariantString(value)
    if (value % 1 == 0) then
        return string.format("%.0f", value);
    end
    local formatted = string.gsub(string.format("%.12f", value), ",", ".");
    formatted = string.gsub(formatted, "0+$", "");
    return string.gsub(formatted, "%.$", "");
end

local function NumberFromInvariantString(value)
    local sign, whole, fraction = string.match(value, "^([+-]?)(%d+)%.?(%d*)$");
    if (not whole) then
        return tonumber(string.gsub(value, ",", "."));
    end
    local number = tonumber(whole);
    if (fraction and fraction ~= "") then
        number = number + tonumber(fraction) / (10 ^ #fraction);
    end
    return sign == "-" and -number or number;
end

local function EncodeSettings(value)
    if (type(value) == "number") then
        return "__CN_NUMBER__:" .. NumberToInvariantString(value);
    elseif (type(value) == "string" and string.sub(value, 1, 5) == "__CN_") then
        return "__CN_TEXT__:" .. value;
    elseif (type(value) ~= "table") then
        return value;
    end
    local encoded = {};
    for key, item in pairs(value) do
        local encodedKey;
        if (type(key) == "number") then
            encodedKey = "__CN_KEY__:" .. NumberToInvariantString(key);
        elseif (type(key) == "string" and string.sub(key, 1, 5) == "__CN_") then
            encodedKey = "__CN_TEXT_KEY__:" .. key;
        else
            encodedKey = key;
        end
        encoded[encodedKey] = EncodeSettings(item);
    end
    return encoded;
end

local function DecodeSettings(value)
    if (type(value) == "string") then
        local number = string.match(value, "^__CN_NUMBER__:(.+)$");
        if (number) then
            return NumberFromInvariantString(number);
        end
        local text = string.match(value, "^__CN_TEXT__:(.*)$");
        return text or value;
    elseif (type(value) ~= "table") then
        return value;
    end
    local decoded = {};
    for key, item in pairs(value) do
        local textKey = type(key) == "string" and string.match(key, "^__CN_TEXT_KEY__:(.*)$");
        local numericKey = type(key) == "string" and string.match(key, "^__CN_KEY__:(.+)$");
        local decodedKey = textKey or (numericKey and NumberFromInvariantString(numericKey)) or key;
        decoded[decodedKey] = DecodeSettings(item);
    end
    return decoded;
end

local settingsLoaded, loadedSettings = pcall(
    Turbine.PluginData.Load,
    Turbine.DataScope.Character,
    "ComboNext"
);
local settingsLoadError = not settingsLoaded and loadedSettings or nil;
local settingsRecoveredFromBackup = false;
if (settingsLoaded and loadedSettings ~= nil) then
    local decodeOk, decodedSettings = pcall(DecodeSettings, loadedSettings);
    if (decodeOk and type(decodedSettings) == "table") then
        loadedSettings = decodedSettings;
    else
        settingsLoaded = false;
        settingsLoadError = decodeOk and "saved settings are not a table" or decodedSettings;
    end
end
if (not settingsLoaded) then
    local backupLoaded, backupSettings = pcall(
        Turbine.PluginData.Load,
        Turbine.DataScope.Character,
        "ComboNextBackup"
    );
    if (backupLoaded and type(backupSettings) == "table") then
        local backupDecoded, decodedBackup = pcall(DecodeSettings, backupSettings);
        if (backupDecoded and type(decodedBackup) == "table") then
            loadedSettings = decodedBackup;
            settingsLoaded = true;
            settingsRecoveredFromBackup = true;
            settingsLoadError = nil;
        end
    end
end
settings = settingsLoaded and loadedSettings or nil;
if (type(settings) ~= "table") then
    settings = {};
end
if (type(settings.seqs) ~= "table") then
    settings.seqs = {};
end
for i = 1, #settings.seqs do
    if (type(settings.seqs[i]) ~= "table") then
        settings.seqs[i] = {};
    end
    local cfg = settings.seqs[i];
    cfg.name = (type(cfg.name) == "string" and cfg.name) or L("editor.comboDefault", i);
    if (type(cfg.skills) ~= "table") then
        cfg.skills = {};
    end
    cfg.secondFinisherEnabled = nil;
    cfg.finisher2 = nil;
    if (type(cfg.stepCount) ~= "number") then
        local lastStep = 0;
        for step = 1, MAX_STEPS do
            if (cfg.skills[step]) then
                lastStep = step;
            end
        end
        cfg.stepCount = math.max(1, lastStep);
    end
    cfg.stepCount = math.max(1, math.min(MAX_STEPS, math.floor(cfg.stepCount)));
    local lastConfiguredStep = 0;
    for step = 1, MAX_STEPS do
        if (cfg.skills[step]) then
            lastConfiguredStep = step;
        end
    end
    if (lastConfiguredStep > 0 and cfg.stepCount > lastConfiguredStep) then
        cfg.stepCount = lastConfiguredStep;
    end
end
if (#settings.seqs == 2
    and settings.seqs[1].name == "A" and settings.seqs[2].name == "B"
    and next(settings.seqs[1].skills) == nil and next(settings.seqs[2].skills) == nil
    and not settings.seqs[1].finisher and not settings.seqs[2].finisher) then
    settings.seqs = {};
end
if (type(settings.resetSeconds) ~= "number") then
    settings.resetSeconds = RESET_SECONDS;
end
do
    local maxGroupId = 0;
    for _, cfg in ipairs(settings.seqs) do
        if (type(cfg.groupId) == "number") then
            maxGroupId = math.max(maxGroupId, cfg.groupId);
        end
    end
    for _, cfg in ipairs(settings.seqs) do
        if (type(cfg.groupId) ~= "number") then
            maxGroupId = maxGroupId + 1;
            cfg.groupId = maxGroupId;
        end
    end
end
local validResetSeconds = {};
for _, seconds in ipairs(ComboNextConstants.resetOptions) do
    validResetSeconds[seconds] = true;
end
if (not validResetSeconds[settings.resetSeconds]) then
    settings.resetSeconds = RESET_SECONDS;
end
if (type(settings.opacity) ~= "number") then
    settings.opacity = 1;
end
if (type(settings.showAllFinishers) ~= "boolean") then
    settings.showAllFinishers = false;
end
if (type(settings.finisherSlots) ~= "number") then
    settings.finisherSlots = settings.showAllFinishers and 6 or 1;
end
settings.finisherSlots = math.max(1, math.min(ComboNextConstants.maxVisibleFinishers,
    math.floor(settings.finisherSlots)));
settings.showAllFinishers = settings.finisherSlots > 1;
if (type(settings.showInCombat) ~= "boolean") then
    settings.showInCombat = false;
end
if (type(settings.alwaysFirstFinisher) ~= "boolean") then
    settings.alwaysFirstFinisher = true;
end
if (type(settings.quietMode) ~= "boolean") then
    settings.quietMode = false;
end
if (type(settings.readyOnly) ~= "boolean") then
    settings.readyOnly = false;
end
if (type(settings.uiScale) ~= "number") then
    settings.uiScale = 1;
end
local validUiScale = {};
for _, scale in ipairs(ComboNextConstants.uiScales) do
    validUiScale[scale] = true;
end
if (not validUiScale[settings.uiScale]) then
    settings.uiScale = 1;
end
local validUiTheme = {};
for _, theme in ipairs(ComboNextConstants.uiThemes) do
    validUiTheme[theme] = true;
end
if (type(settings.uiTheme) ~= "string" or not validUiTheme[settings.uiTheme]) then
    settings.uiTheme = "gold";
end
ui.settings = settings;

local hasSavedSettings = settingsLoaded and type(loadedSettings) == "table";
local lastSavedSettings = hasSavedSettings and DecodeSettings(EncodeSettings(settings)) or nil;
local function Save()
    if (lastSavedSettings) then
        local backupOk, backupError = pcall(
            Turbine.PluginData.Save,
            Turbine.DataScope.Character,
            "ComboNextBackup",
            EncodeSettings(lastSavedSettings)
        );
        if (not backupOk) then
            Turbine.Shell.WriteLine(L("main.backupError", tostring(backupError)));
        end
    end
    Turbine.PluginData.Save(
        Turbine.DataScope.Character,
        "ComboNext",
        EncodeSettings(settings)
    );
    lastSavedSettings = DecodeSettings(EncodeSettings(settings));
end

local function AddCallback(object, event, func)
    if (object[event]) then
        local old = object[event];
        object[event] = function(...)
            old(...);
            func(...);
        end
    else
        object[event] = func;
    end
end

local function GetShortcutInfo(value)
    if (type(value) == "string") then
        return SKILL_SHORTCUT, value;
    elseif (type(value) == "table") then
        return value.shortcutType or value.type or value.Type,
            value.data or value.Data;
    end
end

local function GetSkillName(value)
    if (type(value) == "table" and type(value.skillName) == "string") then
        if (string.match(value.skillName, "^0[xX]")) then
            return nil;
        end

        return value.skillName;
    end

    local shortcutType, data = GetShortcutInfo(value);
    if (shortcutType == SKILL_SHORTCUT and data ~= nil) then
        local ok, name = pcall(function()
            local shortcut = Turbine.UI.Lotro.Shortcut(shortcutType, data);
            return shortcut:GetSkillName();
        end);
        if (ok and type(name) == "string" and name ~= ""
            and not string.match(name, "^0[xX]")) then
            return name;
        end
    end

    if (type(value) == "string") then
        if (string.match(value, "^0[xX]")) then
            return nil;
        end
        return value;
    elseif (type(value) == "table" and type(value.data) == "string") then
        if (string.match(value.data, "^0[xX]")) then
            return nil;
        end
        return value.data;
    end
end

local function GetFinisherName(value)
    if (type(value) == "table" and value.shortcutType == ITEM_SHORTCUT) then
        return value.itemName or value.skillName;
    end
    return GetSkillName(value);
end

local findCatalogSkill;
local function MakeShortcutRecord(shortcut)
    local shortcutType = shortcut:GetType();
    local shortcutTypes = Turbine.UI.Lotro.ShortcutType;
    if (shortcutType ~= SKILL_SHORTCUT and shortcutType ~= shortcutTypes.Item) then
        return nil;
    end

    local data = shortcut:GetData();
    local skillName;
    if (shortcutType == SKILL_SHORTCUT and shortcut.GetSkillName) then
        local ok, name = pcall(function()
            return shortcut:GetSkillName();
        end);
        if (ok) then
            skillName = name;
        end
    end
    if (type(skillName) == "table") then
        skillName = skillName[1];
    end
    if (type(skillName) ~= "string" or skillName == "") then
        skillName = nil;
    end
    if (type(skillName) == "string" and string.match(skillName, "^0[xX]")) then
        skillName = nil;
    end
    local icon;
    if (shortcutType == SKILL_SHORTCUT and findCatalogSkill) then
        local catalogSkill = findCatalogSkill(data);
        if (catalogSkill) then
            skillName = skillName or catalogSkill.skillName;
            icon = catalogSkill.icon;
        end
    end
    local itemName;
    if (shortcutType == shortcutTypes.Item and shortcut.GetItem) then
        local ok, name = pcall(function()
            local item = shortcut:GetItem();
            return item and item:GetName();
        end);
        if (ok and type(name) == "string") then
            itemName = name;
        end
    end
    return {
        shortcutType = shortcutType;
        data = data;
        skillName = skillName;
        itemName = itemName;
        icon = icon;
    };
end

local function MakeSkillRecord(shortcut)
    local record = MakeShortcutRecord(shortcut);
    if (record and record.shortcutType == SKILL_SHORTCUT) then
        return record;
    end
end

local classNamesCache;
local classSkillsCache = {};
local catalogByData;

local function GetClassNames()
    if (not classNamesCache) then
        classNamesCache = { ComboNextConstants.effectsClass };
        for className in pairs(ComboNextClassSkills) do
            table.insert(classNamesCache, className);
        end
        table.sort(classNamesCache);
    end
    return classNamesCache;
end

local function GetSkillLocale()
    local language = Turbine.Engine.GetLanguage();
    local languages = Turbine.Language or {};
    if (languages.German and language == languages.German) then
        return "de";
    elseif (languages.French and language == languages.French) then
        return "fr";
    elseif (languages.Russian and language == languages.Russian) then
        return "ru";
    end
    return "en";
end

local function GetLocalizedSkillRecord(skill, locale)
    local name = skill.names[locale] or skill.names.en;
    if (not name) then
        return nil;
    end
    return {
        shortcutType = SKILL_SHORTCUT;
        data = skill.data;
        skillName = name;
        icon = skill.icon;
        normalizedName = string.lower(name);
    };
end

local effectCatalogProvider;
local function GetClassSkills(className, search)
    if (className == ComboNextConstants.effectsClass) then
        return effectCatalogProvider and effectCatalogProvider(search) or {};
    end
    local locale = GetSkillLocale();
    local cacheKey = className .. "|" .. locale;
    local localizedSkills = classSkillsCache[cacheKey];
    if (not localizedSkills) then
        localizedSkills = {};
        for _, skill in ipairs(ComboNextClassSkills[className] or {}) do
            local record = GetLocalizedSkillRecord(skill, locale);
            if (record) then
                table.insert(localizedSkills, record);
            end
        end
        classSkillsCache[cacheKey] = localizedSkills;
    end

    local query = string.lower(search or "");
    local result = {};
    for _, skill in ipairs(localizedSkills) do
        if (query == "" or string.find(skill.normalizedName, query, 1, true)) then
            table.insert(result, skill);
        end
    end
    return result;
end

findCatalogSkill = function(data)
    local shortcutData = string.lower(tostring(data or ""));
    if (shortcutData == "") then
        return nil;
    end
    if (not catalogByData) then
        catalogByData = {};
        for _, className in ipairs(GetClassNames()) do
            for _, skill in ipairs(ComboNextClassSkills[className] or {}) do
                catalogByData[string.lower(tostring(skill.data or ""))] = skill;
            end
        end
    end
    local catalogSkill = catalogByData[shortcutData];
    return catalogSkill and GetLocalizedSkillRecord(catalogSkill, GetSkillLocale());
end

local function SetSkillIcon(slot, value)
    if (not value) then
        return true;
    end

    local shortcutType, data = GetShortcutInfo(value);
    if (not shortcutType or data == nil) then
        if (type(value) == "table" and type(value.skillName) == "string") then
            slot:SetVisible(false);
            return true;
        end
        slot:SetVisible(false);
        return false, L("main.invalidShortcut");
    end

    local ok, err = pcall(function()
        slot.comboNextUpdating = true;
        slot:SetShortcut(Turbine.UI.Lotro.Shortcut(shortcutType, data));
        slot.comboNextUpdating = false;
    end);
    if (not ok) then
        slot.comboNextUpdating = false;
        slot:SetVisible(false);
        return false, L("main.displayShortcutError", tostring(err));
    end
    slot:SetVisible(true);
    return true;
end

function ComboNextEffectKey(scope, event, name)
    return "@" .. (scope == "target" and "target" or "self") .. ":"
        .. (event == "lost" and "lost" or "gained") .. ":" .. tostring(name);
end

-- Effect families are bitmask categories; a family trigger is stored as effectName "#<Family>"
-- so it coexists with exact-name effect triggers, which are always matched independently.
local effectFamilies = {};
do
    local categories = Turbine.Gameplay.EffectCategory or {};
    for _, familyName in ipairs({ "Wound", "Poison", "Disease", "Fear", "Corruption",
        "Cry", "Song", "Elemental", "Physical", "Tactical" }) do
        local mask = categories[familyName] or (familyName == "Tactical" and 256 or nil);
        if (type(mask) == "number" and mask > 0) then
            effectFamilies[#effectFamilies + 1] = { name = familyName; mask = mask };
        end
    end
end

local function HasAllBits(value, mask)
    local bit = 1;
    while (bit <= mask) do
        if (math.floor(mask / bit) % 2 == 1 and math.floor(value / bit) % 2 == 0) then
            return false;
        end
        bit = bit * 2;
    end
    return true;
end

local function GetEffectFamilies(effect)
    local ok, category = pcall(effect.GetCategory, effect);
    local result = {};
    if (ok and type(category) == "number") then
        for _, family in ipairs(effectFamilies) do
            if (HasAllBits(category, family.mask)) then
                result[#result + 1] = family.name;
            end
        end
    end
    return result;
end

local function GetTriggers(cfg)
    local triggers = {};
    local stepCount = math.max(1, math.min(MAX_STEPS, cfg.stepCount or 1));
    for i = 1, stepCount do
        local value = cfg.skills[i];
        if (value) then
            local name = GetSkillName(value);
            local isEffect = type(value) == "table" and type(value.effectName) == "string";
            if (type(value) == "table" and value.shortcutType == ITEM_SHORTCUT) then
                name = value.itemName or value.skillName;
            end
            if (isEffect) then
                name = ComboNextEffectKey(value.effectScope, value.effectEvent, value.effectName);
            end
            local chatPattern = type(value) == "table"
                and type(value.chatPattern) == "string" and value.chatPattern or nil;
            if ((not name or name == "") and chatPattern and chatPattern ~= "") then
                name = chatPattern;
            end
            if (not name or name == "") then
                return {};
            end
            table.insert(triggers, {
                value = value;
                name = name;
                chatPattern = chatPattern;
                speech = type(value) == "table" and value.speech == true or nil;
                icon = (not isEffect) and type(value) == "table" and value.icon or nil;
                effectIcon = isEffect and tonumber(value.icon) or nil;
            });
        end
    end
    triggers.mode = ComboNextLogic.GetMode(cfg);
    return triggers;
end

local function NormalizeSkillName(name)
    local plainName = string.gsub(name or "", "<[^>]+>", "");
    return string.lower(string.gsub(plainName, "^%s*(.-)%s*$", "%1"));
end

local function TriggerMatchesSkill(trigger, skillName, icon, aliases)
    if (aliases and aliases[trigger.name]) then
        return true;
    end
    if (NormalizeSkillName(trigger.name) == NormalizeSkillName(skillName)) then
        return true;
    end
    return trigger.icon ~= nil and icon ~= nil and trigger.icon == icon;
end

local function IsLocalActor(actorName)
    local player = Turbine.Gameplay.LocalPlayer.GetInstance();
    local playerName = player and player.GetName and player:GetName();
    return actorName ~= nil and playerName ~= nil
        and string.lower(actorName) == string.lower(playerName);
end

local function GetObservedSkill(message)
    local plainMessage = string.gsub(message, "<[^>]+>", "");
    local normalizedMessage = string.lower(plainMessage);
    if (string.find(normalizedMessage, " applied a ", 1, true)
        and string.find(normalizedMessage, " heal ", 1, true)
        and string.find(normalizedMessage, " restoring ", 1, true)
        and string.find(normalizedMessage, " points to morale.", 1, true)) then
        return nil, nil, "heal amount";
    end
    local actionPatterns = {
        "^(.-) scored a ",
        "^(.-) applied a ",
        "^(.-) used ",
        "^(.-) uses ",
        "^(.-) gelang ein ",
        "^(.-) wandte ",
        "^(.-) setzte ",
        "^(.-) benutzte ",
        "^(.-) a infligé ",
        "^(.-) a appliqué ",
        "^(.-) a utilisé ",
        "^(.-) применил ",
        "^(.-) нанес ",
    };
    local actor;
    for _, pattern in ipairs(actionPatterns) do
        actor = string.match(plainMessage, pattern);
        if (actor) then
            break;
        end
    end
    if (not actor) then
        return nil;
    end
    actor = string.gsub(actor, "^%s*(.-)%s*$", "%1");
    local normalizedActor = string.lower(actor);
    if (normalizedActor == "you" or normalizedActor == "yourself"
        or normalizedActor == "ihr" or normalizedActor == "euch"
        or normalizedActor == "du" or normalizedActor == "vous"
        or normalizedActor == "tu" or normalizedActor == "вы") then
        local player = Turbine.Gameplay.LocalPlayer.GetInstance();
        actor = player and player.GetName and player:GetName() or actor;
    end
    local bestName;
    for r = 1, #settings.seqs do
        local cfg = settings.seqs[r];
        for _, trigger in ipairs(GetTriggers(cfg)) do
            local matchText = trigger.chatPattern or trigger.name;
            if (string.find(normalizedMessage, NormalizeSkillName(matchText), 1, true)
                and (not bestName or #trigger.name > #bestName)) then
                bestName = trigger.name;
            end
        end
        local function MatchFinisher(finisher)
            local finisherName = GetFinisherName(finisher);
            local normalizedName = NormalizeSkillName(finisherName);
            if (normalizedName ~= "" and string.find(normalizedMessage, normalizedName, 1, true)
                and (not bestName or #finisherName > #bestName)) then
                bestName = finisherName;
            end
        end
        MatchFinisher(cfg.finisher);
    end
    local player = Turbine.Gameplay.LocalPlayer.GetInstance();
    local playerName = player and player.GetName and player:GetName();
    if (playerName and string.lower(actor) == string.lower(playerName) and not bestName) then
        return nil, nil, "local skill";
    end
    return bestName, actor;
end

-- ========================= WINDOW =========================
ui.win = Turbine.UI.Window();
ui.win:SetSize(WINDOW_WIDTH, WINDOW_HEIGHT);
local currentUiScale = GetEffectiveUiScale();
ui.win:SetScale(currentUiScale);
ui.win:SetPosition(
    math.max(0, math.min(
        settings.windowX or math.floor((Turbine.UI.Display.GetWidth() - WINDOW_WIDTH * currentUiScale) / 2),
        Turbine.UI.Display.GetWidth() - WINDOW_WIDTH * currentUiScale
    )),
    math.max(0, math.min(
        settings.windowY or math.floor((Turbine.UI.Display.GetHeight() - WINDOW_HEIGHT * currentUiScale) / 2),
        Turbine.UI.Display.GetHeight() - WINDOW_HEIGHT * currentUiScale
    ))
);
ui.win:SetBackColor(Turbine.UI.Color(0.3, 0.05, 0.05, 0.05));
ui.win:SetOpacity(settings.opacity);
ui.win:SetVisible(true);

ui.setupBtn = Turbine.UI.Lotro.Button();
ui.setupBtn:SetParent(ui.win);
ui.setupBtn:SetPosition(102, 6);
ui.setupBtn:SetSize(70, 28);
ui.setupBtn:SetText(L("main.edit"));
ui.setupBtn.Click = function()
    if (OpenSequenceEditor) then
        OpenSequenceEditor();
    else
        Turbine.Shell.WriteLine(L("main.initError"));
    end
end;

ui.title = Turbine.UI.Label();
ui.title:SetParent(ui.win);
ui.title:SetPosition(12, 8);
ui.title:SetSize(86, 24);
ui.title:SetText("COMBONEXT");
ui.title:SetForeColor(Turbine.UI.Color(1, 1, 0.75));
ui.title:SetTextAlignment(Turbine.UI.ContentAlignment.MiddleLeft);

local dragging = false;
local dragMouseX, dragMouseY, dragStartX, dragStartY = 0, 0, 0, 0;
local function BeginWindowDrag(_, args)
    if (args.Button ~= nil and args.Button ~= Turbine.UI.MouseButton.Left) then
        return;
    end
    dragging = true;
    dragMouseX, dragMouseY = Turbine.UI.Display.GetMousePosition();
    dragStartX, dragStartY = ui.win:GetPosition();
end
local function MoveWindow()
    if (dragging) then
        local mouseX, mouseY = Turbine.UI.Display.GetMousePosition();
        local maxX = math.max(0, Turbine.UI.Display.GetWidth() - ui.win:GetWidth() * currentUiScale);
        local maxY = math.max(0, Turbine.UI.Display.GetHeight() - ui.win:GetHeight() * currentUiScale);
        local x = math.max(0, math.min(dragStartX + mouseX - dragMouseX, maxX));
        local y = math.max(0, math.min(dragStartY + mouseY - dragMouseY, maxY));
        local currentX, currentY = ui.win:GetPosition();
        if (x ~= currentX or y ~= currentY) then
            ui.win:SetPosition(x, y);
        end
    end
end
local function EndWindowDrag()
    if (dragging) then
        dragging = false;
        settings.windowX, settings.windowY = ui.win:GetPosition();
        Save();
    end
end

-- LOTRO sends mouse events to the child under the cursor rather than bubbling
-- them to its window, so support dragging from both the title and background.
for _, target in ipairs({ ui.win, ui.title }) do
    target.MouseDown = BeginWindowDrag;
    target.MouseMove = MoveWindow;
    target.MouseUp = EndWindowDrag;
end

local function MakeButton(parent, text, left, top, width, height, onClick)
    local button = Turbine.UI.Label();
    button:SetParent(parent);
    button:SetPosition(left, top);
    button:SetSize(width, height);
    button:SetText(text);
    button:SetForeColor(Turbine.UI.Color(1, 1, 0.75));
    table.insert(ui.textButtons, button);
    button:SetTextAlignment(Turbine.UI.ContentAlignment.MiddleCenter);
    button.MouseEnter = function()
        button:SetForeColor(button.themeHoverColor or Turbine.UI.Color(1, 1, 0.9));
    end
    button.MouseLeave = function()
        button:SetForeColor(Turbine.UI.Color(1, 1, 0.75));
    end
    button.MouseClick = function(_, args)
        if (args.Button == Turbine.UI.MouseButton.Left) then
            onClick();
        end
    end
    return button;
end

ui.status = Turbine.UI.Label();
ui.status:SetParent(ui.win);
ui.status:SetPosition(12, 258);
ui.status:SetSize(366, 40);
ui.status:SetForeColor(Turbine.UI.Color(0.8, 0.8, 0.8));
ui.status:SetTextAlignment(Turbine.UI.ContentAlignment.MiddleCenter);
ui.status:SetText(L("main.ready"));

ui.setupMode = false;
ui.captureTarget = nil;

ui.settingsBtn = Turbine.UI.Lotro.Button();
ui.settingsBtn:SetParent(ui.win);
ui.settingsBtn:SetPosition(180, 6);
ui.settingsBtn:SetSize(84, 28);
ui.settingsBtn:SetText(L("main.options"));
ui.settingsBtn.Click = function()
    OpenOptionsWindow();
end;
ui.hideBtn = Turbine.UI.Lotro.Button();
ui.hideBtn:SetParent(ui.win);
ui.hideBtn:SetPosition(272, 6);
ui.hideBtn:SetSize(92, 28);
ui.hideBtn:SetText(L("main.hide"));
ui.hideBtn.Click = function()
    ui.win:SetVisible(false);
end;

local launcherSize = 34;
ui.launcher = Turbine.UI.Window();
ui.launcher:SetSize(launcherSize, launcherSize);
ui.launcher:SetScale(currentUiScale);
ui.launcher:SetBackColor(Turbine.UI.Color(1, 0.025, 0.075, 0.065));
ui.launcher:SetOpacity(1);
ui.launcher:SetMouseVisible(true);
ui.launcher:SetPosition(
    math.max(0, math.min(settings.launcherX
        or (Turbine.UI.Display.GetWidth() - launcherSize * currentUiScale - 12),
        Turbine.UI.Display.GetWidth() - launcherSize * currentUiScale)),
    math.max(0, math.min(settings.launcherY
        or math.floor((Turbine.UI.Display.GetHeight() - launcherSize * currentUiScale) / 2),
        Turbine.UI.Display.GetHeight() - launcherSize * currentUiScale))
);
ui.launcher:SetVisible(true);
local launcherLabel = Turbine.UI.Label();
launcherLabel:SetParent(ui.launcher);
launcherLabel:SetPosition(0, 0);
launcherLabel:SetSize(launcherSize, launcherSize);
launcherLabel:SetText("");
launcherLabel:SetMouseVisible(true);

local function AddLauncherMark(x, y, width, height, color)
    local mark = Turbine.UI.Control();
    mark:SetParent(ui.launcher);
    mark:SetPosition(x, y);
    mark:SetSize(width, height);
    mark:SetBackColor(color);
    mark:SetMouseVisible(false);
    mark:SetZOrder(2);
    return mark;
end

local bronze = Turbine.UI.Color(0.95, 0.48, 0.25, 0.09);
local brightGold = Turbine.UI.Color(1, 1, 0.78, 0.29);
local dimGold = Turbine.UI.Color(0.8, 0.68, 0.43, 0.16);
local darkInlay = Turbine.UI.Color(1, 0.045, 0.095, 0.08);
AddLauncherMark(0, 0, launcherSize, 2, bronze);
AddLauncherMark(0, launcherSize - 2, launcherSize, 2, bronze);
AddLauncherMark(0, 2, 2, launcherSize - 4, bronze);
AddLauncherMark(launcherSize - 2, 2, 2, launcherSize - 4, bronze);
AddLauncherMark(4, 4, launcherSize - 8, launcherSize - 8, darkInlay);

-- Three rising links and a bright terminal mark form a compact combo-chain rune.
AddLauncherMark(6, 23, 5, 5, dimGold);
AddLauncherMark(11, 24, 4, 2, bronze);
AddLauncherMark(14, 20, 2, 5, bronze);
AddLauncherMark(14, 16, 5, 5, dimGold);
AddLauncherMark(19, 17, 4, 2, bronze);
AddLauncherMark(22, 12, 2, 6, bronze);
AddLauncherMark(22, 9, 5, 5, brightGold);
AddLauncherMark(24, 10, 1, 3, Turbine.UI.Color(1, 1, 0.92, 0.57));

local launcherDragging, launcherMoved = false, false;
local launcherMouseX, launcherMouseY, launcherStartX, launcherStartY = 0, 0, 0, 0;
launcherLabel.MouseDown = function(_, args)
    if (args.Button == Turbine.UI.MouseButton.Left) then
        launcherDragging, launcherMoved = true, false;
        launcherMouseX, launcherMouseY = Turbine.UI.Display.GetMousePosition();
        launcherStartX, launcherStartY = ui.launcher:GetPosition();
    end
end;
launcherLabel.MouseMove = function(_, args)
    if (launcherDragging) then
        local mouseX, mouseY = Turbine.UI.Display.GetMousePosition();
        local dx, dy = mouseX - launcherMouseX, mouseY - launcherMouseY;
        if (math.abs(dx) + math.abs(dy) > 2) then
            launcherMoved = true;
        end
        if (launcherMoved) then
            local maxX = math.max(0, Turbine.UI.Display.GetWidth() - launcherSize);
            local maxY = math.max(0, Turbine.UI.Display.GetHeight() - launcherSize);
            local x = math.max(0, math.min(launcherStartX + dx, maxX));
            local y = math.max(0, math.min(launcherStartY + dy, maxY));
            local currentX, currentY = ui.launcher:GetPosition();
            if (x ~= currentX or y ~= currentY) then
                ui.launcher:SetPosition(x, y);
            end
        end
    end
end;
launcherLabel.MouseUp = function()
    if (launcherDragging) then
        launcherDragging = false;
        settings.launcherX, settings.launcherY = ui.launcher:GetPosition();
        Save();
    end
end;
launcherLabel.MouseClick = function(_, args)
    if (args.Button == Turbine.UI.MouseButton.Left and not launcherMoved) then
        ui.win:SetVisible(not ui.win:IsVisible());
    end
end;

local help = Turbine.UI.Label();
help:SetParent(ui.win);
ui.diagnostic = help;
help:SetPosition(12, 234);
help:SetSize(366, 18);
help:SetText(L("main.waiting"));
help:SetForeColor(Turbine.UI.Color(0.95, 0.85, 0.55));
help:SetTextAlignment(Turbine.UI.ContentAlignment.MiddleCenter);
local function SetDiagnostic(key, ...)
    if (not settings.quietMode) then
        help:SetText(L(key, ...));
    end
end

local rowY = { 130, 176 };

-- A label above each inert quickslot receives drops, matching SequenceBars'
-- number-label drop target without making the displayed skill clickable.
local RebuildSlot;
local function CreateSlot(rowIndex, position, top, size, isRecommendation)
    local slot = {};
    local left = isRecommendation and 328 or (58 + (position - 1) * (SLOT_SMALL + 8));

    slot.surface = Turbine.UI.Label();
    slot.surface:SetParent(ui.win);
    slot.surface:SetPosition(left, top);
    slot.surface:SetSize(size, size);
    slot.surface:SetZOrder(91);
    slot.surface:SetAllowDrop(false);
    slot.surface:SetMouseVisible(true);
    slot.surface:SetTextAlignment(Turbine.UI.ContentAlignment.MiddleCenter);
    slot.surface:SetForeColor(Turbine.UI.Color(0.9, 0.9, 0.9));
    slot.surface:SetBackColor(Turbine.UI.Color(0.01, 0, 0, 0));

    slot.surface.DragDrop = function(_, args)
        if (not ui.setupMode) then
            return;
        end
        local dragInfo = args.DragDropInfo;
        local shortcut = dragInfo and dragInfo:GetShortcut();
        local record = shortcut and MakeShortcutRecord(shortcut);
        if (not record) then
            if (dragInfo) then
                dragInfo:SetSuccessful(false);
            end
            ui.status:SetText(L("main.onlySkills"));
            return;
        end
        if (not isRecommendation
            and (record.shortcutType ~= SKILL_SHORTCUT or not record.skillName)) then
            if (dragInfo) then
                dragInfo:SetSuccessful(false);
            end
            ui.status:SetText(L("main.editorSkills"));
            return;
        end
        local comboIndex = rowIndex;
        local cfg = settings.seqs[comboIndex];
        if (not cfg) then
            if (dragInfo) then
                dragInfo:SetSuccessful(false);
            end
            ui.status:SetText(L("main.createCombo"));
            return;
        end
        if (isRecommendation) then
            cfg.finisher = record;
        else
            cfg.skills[position] = record;
        end
        Save();
        ui.status:SetText(L("main.skillSaved"));
        ui.ResetProgress();
        ui.ApplyTheme();
        ui.UpdateDisplay();
        if (dragInfo) then
            dragInfo:SetSuccessful(false);
        end
    end

    slot.surface.MouseClick = function(_, args)
        if (ui.setupMode and args.Button == Turbine.UI.MouseButton.Left) then
            local comboIndex = rowIndex;
            if (settings.seqs[comboIndex]) then
                OpenSequenceEditor(comboIndex, isRecommendation and MAX_STEPS + 1 or position);
            end
            return;
        end
        if (ui.setupMode and args.Button == RIGHT_BUTTON) then
            local cfg = settings.seqs[rowIndex];
            if (not cfg) then
                return;
            end
            if (isRecommendation) then
                cfg.finisher = nil;
            else
                cfg.skills[position] = nil;
            end
            RebuildSlot(rowIndex, position, isRecommendation);
            Save();
            ui.ResetProgress();
            ui.UpdateDisplay();
        end
    end

    return slot;
end

RebuildSlot = function(rowIndex, position, isRecommendation)
    local row = ui.rows[rowIndex];
    local old = isRecommendation and row.recommendation or row.slots[position];
    old.surface:SetParent(nil);
    local replacement = CreateSlot(
        rowIndex,
        position,
        rowY[rowIndex],
        SLOT_SMALL,
        isRecommendation
    );
    if (isRecommendation) then
        row.recommendation = replacement;
    else
        row.slots[position] = replacement;
    end
end

ui.rows = {};
ui.states = {};
ui.active = nil;
ui.recommendations = {};
local function NewProgressState()
    return { progress = 0; done = false; matched = {}; lastProgressAt = nil; };
end
for i = 1, #settings.seqs do
    ui.states[i] = NewProgressState();
end

for r = 1, 2 do
    local row = { slots = {}; };
    for p = 1, MAX_STEPS do
        row.slots[p] = CreateSlot(r, p, rowY[r], SLOT_SMALL, false);
    end
    row.recommendation = CreateSlot(r, 0, rowY[r], SLOT_SMALL, true);
    ui.rows[r] = row;
end

ui.finisherChoices = {};
local function PlaceFinisherChoice(choice, index)
    local count = math.max(1, settings.finisherSlots or 1);
    local spacing = math.min(62, math.floor(366 / count));
    local size = math.min(SLOT_BIG, spacing - 2);
    local x = 12 + (index - 1) * spacing;
    local thickness = 2;
    local hx, hy, hs = x + 1, 41, size - 2;
    local rects = {
        { hx, hy, hs, thickness },
        { hx, hy + hs - thickness, hs, thickness },
        { hx, hy + thickness, thickness, hs - 2 * thickness },
        { hx + hs - thickness, hy + thickness, thickness, hs - 2 * thickness },
    };
    for i, edge in ipairs(choice.highlight) do
        edge:SetPosition(rects[i][1], rects[i][2]);
        edge:SetSize(rects[i][3], rects[i][4]);
    end
    choice.icon:SetPosition(x, 40);
    choice.icon:SetSize(size, size);
    choice.label:SetPosition(x - 2, 42 + size);
    choice.label:SetSize(size + 4, 24);
    choice.labelChars = spacing >= 62 and 10 or math.max(3, math.floor(spacing / 7));
end
for index = 1, MAX_VISIBLE_FINISHERS do
    local choice = {};
    choice.highlight = {};
    for _ = 1, 4 do
        local edge = Turbine.UI.Control();
        edge:SetParent(ui.win);
        edge:SetZOrder(91);
        edge:SetVisible(false);
        table.insert(choice.highlight, edge);
    end
    choice.icon = Turbine.UI.Lotro.Quickslot();
    choice.icon:SetParent(ui.win);
    choice.icon:SetAllowDrop(false);
    choice.icon:SetMouseVisible(true);
    choice.icon:SetZOrder(90);
    choice.label = Turbine.UI.Label();
    choice.label:SetParent(ui.win);
    choice.label:SetFont(Turbine.UI.Lotro.Font.Verdana10);
    choice.label:SetTextAlignment(Turbine.UI.ContentAlignment.MiddleCenter);
    choice.label:SetForeColor(Turbine.UI.Color(0.95, 0.9, 0.75));
    choice.label:SetMouseVisible(false);
    choice.icon:SetVisible(false);
    choice.label:SetVisible(false);
    ui.finisherChoices[index] = choice;
    PlaceFinisherChoice(choice, index);
end
function ui.RelayoutFinishers()
    for index, choice in ipairs(ui.finisherChoices) do
        PlaceFinisherChoice(choice, index);
    end
end

function ui.ResetProgress()
    ui.recommendations = {};
    for r = 1, #settings.seqs do
        if (not ui.states[r]) then
            ui.states[r] = NewProgressState();
        end

        ui.states[r].progress = 0;
        ui.states[r].done = false;
        ui.states[r].matched = {};
        ui.states[r].lastProgressAt = nil;
        ui.states[r].eventTimes = {};
        ui.states[r].conditions = nil;
        ui.states[r].conditionConsumed = nil;
    end
    for r = #ui.states, #settings.seqs + 1, -1 do
        ui.states[r] = nil;
    end
    if (UpdateActiveSequence) then
        UpdateActiveSequence();
    else
        ui.active = nil;
    end
end

local highlightColor = Turbine.UI.Color(0.5, 0.0, 0.9, 0.0);
ui.ApplyTheme = function()
    local theme = UI_THEMES[settings.uiTheme] or UI_THEMES.gold;
    ui.win:SetBackColor(Turbine.UI.Color(unpack(theme.background)));
    local accent = Turbine.UI.Color(1, unpack(theme.accent));
    local hover = Turbine.UI.Color(1, unpack(theme.hover));
    if (ui.title) then
        ui.title:SetForeColor(accent);
    end
    for _, button in ipairs(ui.textButtons) do
        button:SetForeColor(accent);
        button.themeHoverColor = hover;
    end
    local statusColor = Turbine.UI.Color(1, unpack(theme.status));
    if (ui.diagnostic) then
        ui.diagnostic:SetForeColor(statusColor);
    end
    if (ui.status) then
        ui.status:SetForeColor(Turbine.UI.Color(0.9, unpack(theme.status)));
    end
    if (sequenceEditor and sequenceEditor.ApplyTheme) then
        sequenceEditor:ApplyTheme(accent, statusColor);
    end
    if (shareWindow and shareWindow.ApplyTheme) then
        shareWindow:ApplyTheme(accent, statusColor);
    end
    for _, choice in ipairs(ui.finisherChoices or {}) do
        choice.label:SetForeColor(accent);
    end
    highlightColor = Turbine.UI.Color(unpack(theme.highlight));
    ui.UpdateDisplay();
end;

-- The first rule of a combo with no trigger skills is always offered as a finisher.
local function IsStarterRule(index)
    local cfg = settings.seqs[index];
    if (not settings.alwaysFirstFinisher or not cfg or not cfg.finisher) then
        return false;
    end
    local previous = settings.seqs[index - 1];
    if (not cfg.starter and previous and previous.groupId == cfg.groupId) then
        return false;
    end
    return #GetTriggers(cfg) == 0;
end

local function GetProgressText(index)
    local cfg, state = settings.seqs[index], ui.states[index];
    if (state.conditionConsumed) then
        return L("main.conditionsConsumed", cfg.name);
    end
    local triggers = GetTriggers(cfg);
    local waiting = {};
    local matched = {};
    for _, name in ipairs(state.matched or {}) do
        matched[name] = (matched[name] or 0) + 1;
    end
    for step, trigger in ipairs(triggers) do
        local condition = state.conditions and state.conditions[step];
        local label = type(trigger.value) == "table"
            and (trigger.value.skillName or trigger.value.itemName);
        label = label or trigger.name;
        if (ComboNextLogic.IsCurrent(triggers.mode)) then
            if (not condition or condition.satisfied ~= true) then
                waiting[#waiting + 1] = condition and condition.detail or label;
            end
        elseif (matched[trigger.name] and matched[trigger.name] > 0) then
            matched[trigger.name] = matched[trigger.name] - 1;
        else
            waiting[#waiting + 1] = label;
            if (triggers.mode == "ordered") then
                break;
            end
        end
    end
    if (#waiting > 0) then
        local joiner = (triggers.mode == "or" or triggers.mode == "anyConditions")
            and L("main.orJoin") or L("main.andJoin");
        return L("main.waitingFor", cfg.name, table.concat(waiting, joiner));
    end
    return L("main.comboProgress", cfg.name);
end

function ui.UpdateDisplay()
    local warning;
    local primaryRecommendation;
    if (ui.active and ui.recommendations[ui.active]) then
        primaryRecommendation = ui.active;
    else
        for comboIndex = 1, #settings.seqs do
            if (ui.recommendations[comboIndex]) then
                primaryRecommendation = comboIndex;
                break;
            end
        end
    end
    local matchedRecommendationCount = 0;
    local finisherRecommendations = {};
    local shownFinishers = {};
    local blockedReason;
    local function AddRecommendation(comboIndex)
        local cfg = settings.seqs[comboIndex];
        if (not cfg.finisher) then
            return;
        end
        local ready, detail;
        if (settings.readyOnly and GetFinisherReadiness) then
            ready, detail = GetFinisherReadiness(cfg.finisher);
        end
        if (settings.readyOnly and ready ~= true) then
            blockedReason = blockedReason or L("main.finisherBlocked", cfg.name,
                detail or L("main.readinessUnknown"));
            return;
        end
        local key = NormalizeSkillName(GetFinisherName(cfg.finisher) or "");
        if (key ~= "" and shownFinishers[key]) then
            return;
        end
        shownFinishers[key] = key ~= "" or nil;
        matchedRecommendationCount = matchedRecommendationCount + 1;
        local limit = settings.showAllFinishers and settings.finisherSlots or 1;
        if (#finisherRecommendations < limit) then
            finisherRecommendations[#finisherRecommendations + 1] = comboIndex;
        end
    end
    if (not settings.showAllFinishers and primaryRecommendation) then
        AddRecommendation(primaryRecommendation);
    end
    for comboIndex = 1, #settings.seqs do
        if ((ui.recommendations[comboIndex] or IsStarterRule(comboIndex))
            and (settings.showAllFinishers or comboIndex ~= primaryRecommendation)) then
            AddRecommendation(comboIndex);
        end
    end
    ui.visibleRecommendation = finisherRecommendations[1];
    if (ui.visibleRecommendation and ui.recommendations[ui.visibleRecommendation]) then
        primaryRecommendation = ui.visibleRecommendation;
    end
    for r = 1, MAX_DISPLAY_ROWS do
        local comboIndex = r;
        local cfg, row = settings.seqs[comboIndex], ui.rows[r];

        for p = 1, MAX_STEPS do
            local slot = row.slots[p];
            slot.surface:SetVisible(false);
        end

        row.recommendation.surface:SetVisible(cfg ~= nil and ui.setupMode);
        row.recommendation.surface:SetAllowDrop(ui.setupMode);
        row.recommendation.surface:SetMouseVisible(ui.setupMode);
        row.recommendation.surface:SetText(ui.setupMode and L("main.next") or "");
        row.recommendation.surface:SetBackground(
            ui.setupMode and type(cfg) == "table" and type(cfg.finisher) == "table"
                and cfg.finisher.icon or nil
        );
    end

    if (ui.setupMode) then
        for _, choice in ipairs(ui.finisherChoices) do
            choice.icon:SetVisible(false);
            for _, edge in ipairs(choice.highlight) do
                edge:SetVisible(false);
            end
            choice.label:SetVisible(false);
        end
        ui.status:SetText(warning or L("main.editing"));
        return;
    end

    local active = ui.active;
    for index, choice in ipairs(ui.finisherChoices) do
        local comboIndex = finisherRecommendations[index];
        local combo = comboIndex and settings.seqs[comboIndex];
        if (combo) then
            local ok, err = SetSkillIcon(choice.icon, combo.finisher);
            if (not ok) then
                warning = err;
            end
            choice.icon:SetVisible(ok);
            for _, edge in ipairs(choice.highlight) do
                edge:SetBackColor(highlightColor);
                edge:SetVisible(ok);
            end
            choice.label:SetText(string.sub(combo.name
                or L("editor.comboDefault", comboIndex), 1, choice.labelChars or 10));
            choice.label:SetVisible(ok);
        else
            choice.icon:SetVisible(false);
            for _, edge in ipairs(choice.highlight) do
                edge:SetVisible(false);
            end
            choice.label:SetVisible(false);
        end
    end
    if (active and ui.states[active].done) then
        local cfg = settings.seqs[active];
        local status;
        if (settings.showAllFinishers and matchedRecommendationCount > 0) then
            status = L("main.choicesReady",
                math.min(matchedRecommendationCount, settings.finisherSlots));
            if (matchedRecommendationCount > settings.finisherSlots) then
                status = status .. " " .. L("main.combosMatched", matchedRecommendationCount);
            end
        elseif (settings.showAllFinishers and primaryRecommendation) then
            status = L("main.matchedNoFinisher", settings.seqs[primaryRecommendation].name);
        elseif (primaryRecommendation) then
            status = L("main.comboMatched", settings.seqs[primaryRecommendation].name);
        else
            status = L("main.sequenceMatched", cfg.name);
        end
        ui.status:SetText(warning or (#finisherRecommendations == 0 and blockedReason) or status);
    elseif (active and ui.states[active].progress > 0) then
        local cfg = settings.seqs[active];
        ui.status:SetText(warning or GetProgressText(active));
    else
        if (#settings.seqs == 0) then
            ui.status:SetText(warning or L("main.noCombos"));
        else
            local pending;
            for index, cfg in ipairs(settings.seqs) do
                if (#GetTriggers(cfg) > 0 and not ui.states[index].done) then
                    pending = index;
                    break;
                end
            end
            ui.status:SetText(warning or (#finisherRecommendations == 0 and blockedReason)
                or (pending and GetProgressText(pending)) or L("main.ready"));
        end
    end
end

ApplyUiScale = function()
    currentUiScale = GetEffectiveUiScale();
    for _, window in pairs({
        main = ui.win;
        launcher = ui.launcher;
        editor = sequenceEditor;
        share = shareWindow;
        options = optionsWindow;
    }) do
        if (window) then
            window:SetScale(currentUiScale);
            ClampScaledWindow(window, currentUiScale);
        end
    end
end

ApplyUiTheme = function()
    ui.ApplyTheme();
end

OpenSequenceEditor = function(rowIndex, slotIndex)
    if (not sequenceEditor) then
        local created, editorOrError = pcall(ComboNextSequenceEditor,
            settings,
            GetClassSkills,
            GetClassNames,
            MakeShortcutRecord,
            Save,
            function()
                ui.recommendations = {};
                ui.ResetProgress();
                ui.UpdateDisplay();
            end,
            function(comboIndex, slotIndex, mode)
                if (ui.captureTarget
                    and ui.captureTarget.comboIndex == comboIndex
                    and ui.captureTarget.slotIndex == slotIndex) then
                    ui.captureTarget = nil;
                    return false;
                end
                ui.captureTarget = {
                    comboIndex = comboIndex;
                    slotIndex = slotIndex;
                };
                return true;
            end,
            function()
                if (RefreshOptionsPanels) then
                    RefreshOptionsPanels();
                else
                    ui.UpdateDisplay();
                end
            end,
            function(record)
                if (record.shortcutType == ITEM_SHORTCUT) then
                    itemCooldowns[NormalizeSkillName(GetFinisherName(record))] =
                        Turbine.Engine.GetGameTime();
                    ui.UpdateDisplay();
                end
            end
        );
        if (not created) then
            Turbine.Shell.WriteLine("ComboNext editor error: " .. tostring(editorOrError));
            return;
        end
        sequenceEditor = editorOrError;
        sequenceEditor:SetScale(GetEffectiveUiScale());
        ClampScaledWindow(sequenceEditor, GetEffectiveUiScale());
        sequenceEditor.openShare = function()
            if (not shareWindow) then
                local made, window = pcall(ComboNextShareWindow, settings, Save,
                    sequenceEditor.changed, function(data)
                        return findCatalogSkill and findCatalogSkill(data);
                    end, sequenceEditor);
                if (not made) then
                    Turbine.Shell.WriteLine("ComboNext share error: " .. tostring(window));
                    return;
                end
                shareWindow = window;
                shareWindow:SetScale(GetEffectiveUiScale());
                ClampScaledWindow(shareWindow, GetEffectiveUiScale());
                pcall(function()
                    shareWindow:SetWantsKeyEvents(true);
                    shareWindow.KeyDown = onHudKey;
                end);
            end
            shareWindow:SetVisible(true);
        end;
        pcall(function()
            sequenceEditor:SetWantsKeyEvents(true);
            sequenceEditor.KeyDown = onHudKey;
        end);
        if (rowIndex and slotIndex) then
            sequenceEditor:SelectSlot(rowIndex, slotIndex);
        end
    elseif (rowIndex and slotIndex) then
        sequenceEditor:SelectSlot(rowIndex, slotIndex);
    end
    local refreshed, refreshError = pcall(sequenceEditor.Refresh, sequenceEditor);
    if (not refreshed) then
        Turbine.Shell.WriteLine("ComboNext editor error: " .. tostring(refreshError));
    end
    sequenceEditor:SetVisible(true);
end

UpdateActiveSequence = function()
    ui.active = nil;
    for r = 1, #settings.seqs do
        local state = ui.states[r];
        if (state.progress > 0) then
            if (ui.active == nil) then
                ui.active = r;
            else
                local activeState = ui.states[ui.active];
                if ((state.done and not activeState.done)
                    or (state.done == activeState.done and state.progress > activeState.progress)) then
                    ui.active = r;
                end
            end
        end
    end
end

local function AdvanceState(state, triggers, skillName, skillIcon, aliases)
    ComboNextLogic.Advance(state, triggers, function(trigger)
        return TriggerMatchesSkill(trigger, skillName, skillIcon, aliases);
    end);
end

local function WouldAdvance(state, triggers, skillName, skillIcon)
    local candidate = {
        progress = state.progress;
        done = state.done;
        matched = {};
        lastProgressAt = state.lastProgressAt;
    };
    for index, name in ipairs(state.matched or {}) do
        candidate.matched[index] = name;
    end
    AdvanceState(candidate, triggers, skillName, skillIcon);
    if (candidate.progress ~= state.progress or candidate.done ~= state.done) then
        return true;
    end
    for index, name in ipairs(candidate.matched) do
        if (name ~= state.matched[index]) then
            return true;
        end
    end
    return false;
end

local function WouldChangeFromSkillEvent(skillName, skillIcon, actorName)
    for r = 1, #settings.seqs do
        local state = ui.states[r];
        if (ui.recommendations[r]) then
            if (IsLocalActor(actorName)) then
                local cfg = settings.seqs[r];
                local firstFinisher = GetFinisherName(cfg.finisher);
                if (firstFinisher and NormalizeSkillName(firstFinisher) == NormalizeSkillName(skillName)) then
                    return true;
                end
            end
        else
            local triggers = GetTriggers(settings.seqs[r]);
            if (not ComboNextLogic.IsCurrent(triggers.mode)
                and WouldAdvance(state, triggers, skillName, skillIcon)) then
                return true;
            end
        end
    end
    return false;
end

HandleSkill = function(skillName, actorName, skillIcon, aliases)
    local now = Turbine.Engine.GetGameTime();
    SetDiagnostic("main.detected", string.sub(string.gsub(skillName, "^@%a+:%a+:", ""), 1, 38),
        string.sub(actorName or L("main.unknown"), 1, 24));
    if (not aliases and ui.lastObservedSkill == skillName and ui.lastObservedAt
        and ui.lastObservedActor == actorName
        and (now - ui.lastObservedAt) < 0.3) then
        if (not WouldChangeFromSkillEvent(skillName, skillIcon, actorName)) then
            return;
        end
    end
    ui.lastObservedSkill, ui.lastObservedActor, ui.lastObservedAt = skillName, actorName, now;
    if (RecordItemUse and IsLocalActor(actorName)) then
        RecordItemUse(skillName);
    end

    for r = 1, #settings.seqs do
        local cfg = settings.seqs[r];
        if (ui.recommendations[r] and IsLocalActor(actorName)) then
            local firstFinisher = GetFinisherName(cfg.finisher);
            if (firstFinisher and NormalizeSkillName(firstFinisher) == NormalizeSkillName(skillName)) then
                ui.recommendations[r] = nil;
                local state = ui.states[r];
                if (state) then
                    ComboNextLogic.Consume(state);
                end
            end
        end
    end

    for r = 1, #settings.seqs do
        local state = ui.states[r];
        local triggers = GetTriggers(settings.seqs[r]);
        if (ComboNextLogic.IsCurrent(triggers.mode)) then
            state.eventTimes = state.eventTimes or {};
            for index, trigger in ipairs(triggers) do
                if (not (type(trigger.value) == "table" and trigger.value.effectName)
                    and TriggerMatchesSkill(trigger, skillName, skillIcon, aliases)) then
                    state.eventTimes[index] = now;
                end
            end
        elseif (not (state.done and ui.recommendations[r])) then
            AdvanceState(state, triggers, skillName, skillIcon, aliases);
            state.lastProgressAt = state.progress > 0 and now or nil;
        end
    end
    if (RefreshConditions) then
        RefreshConditions();
    end
    UpdateActiveSequence();
    for r = 1, #settings.seqs do
        local cfg = settings.seqs[r];
        if (ui.states[r].done and cfg.finisher) then
            ui.recommendations[r] = true;
        end
    end
    if (ui.active and ui.states[ui.active].done) then
        local cfg = settings.seqs[ui.active];
        if (cfg.finisher) then
            help:SetText(L("main.matchedBy", cfg.name, actorName or L("main.unknown")));
        end
    end
    ui.UpdateDisplay();
end

local player = Turbine.Gameplay.LocalPlayer.GetInstance();
local lastLocalSkillAt = {};
local watchedSkills = {};
local trainedByName = {};
local function OnLocalSkillActivated(observedSkillName, icon)
    local now = Turbine.Engine.GetGameTime();
    local eventKey = icon or observedSkillName;
    if (lastLocalSkillAt[eventKey]
        and now - lastLocalSkillAt[eventKey] < 0.3
        and not WouldChangeFromSkillEvent(observedSkillName, icon,
            player and player.GetName and player:GetName())) then
        return;
    end
    lastLocalSkillAt[eventKey] = now;

    local configured = false;
    for r = 1, #settings.seqs do
        local cfg = settings.seqs[r];
        for _, trigger in ipairs(GetTriggers(cfg)) do
            if (TriggerMatchesSkill(trigger, observedSkillName, icon)) then
                configured = true;
                break;
            end
        end
        local finisherMatched = false;
        local finisher = cfg.finisher;
        local finisherName = finisher and (finisher.itemName or finisher.skillName)
            or GetSkillName(finisher);
        if (finisher and TriggerMatchesSkill({
            name = finisherName;
            icon = type(finisher) == "table" and finisher.icon or nil;
        }, observedSkillName, icon)) then
            finisherMatched = true;
        end
        if (ui.recommendations[r] and finisherMatched) then
            ui.recommendations[r] = nil;
            local state = ui.states[r];
            if (state) then
                ComboNextLogic.Consume(state);
            end
        end
    end
    UpdateActiveSequence();
    if (configured) then
        local actorName = player and player.GetName and player:GetName() or "You";
        HandleSkill(observedSkillName, actorName, icon);
    else
        SetDiagnostic("main.localEvent", string.sub(observedSkillName, 1, 36));
        ui.UpdateDisplay();
    end
end

local function BindTrainedSkillListeners()
    local skills = player and player.GetTrainedSkills and player:GetTrainedSkills();
    if (not skills) then
        return;
    end
    local skillCount = skills:GetCount();
    trainedByName = {};
    for i = 1, skillCount do
        local skill = skills:GetItem(i);
        if (skill) then
            local skillInfo = skill:GetSkillInfo();
            local skillName = skillInfo and skillInfo:GetName();
            if (type(skillName) == "string" and skillName ~= "") then
                trainedByName[NormalizeSkillName(skillName)] = skill;
                if (not watchedSkills[skill]) then
                    watchedSkills[skill] = true;
                    local observedSkillName = skillName;
                    local icon = skillInfo:GetIconImageID();
                    local previousReset = skill:GetResetTime();
                    AddCallback(skill, "ResetTimeChanged", function(sender)
                        local now = Turbine.Engine.GetGameTime();
                        local resetTime = sender:GetResetTime();
                        local started = type(resetTime) == "number" and resetTime > now
                            and (type(previousReset) ~= "number" or resetTime > previousReset);
                        previousReset = resetTime;
                        if (started) then
                            OnLocalSkillActivated(observedSkillName, icon);
                        end
                    end);
                end
            end
        end
    end
end
BindTrainedSkillListeners();

RecordItemUse = function(name)
    local key = NormalizeSkillName(name);
    local duration = 0;
    for _, cfg in ipairs(settings.seqs) do
        local function CheckItem(record)
            if (type(record) == "table" and record.shortcutType == ITEM_SHORTCUT
                and NormalizeSkillName(record.itemName or record.skillName) == key) then
                duration = math.max(duration, tonumber(record.itemCooldown) or 0);
            end
        end
        CheckItem(cfg.finisher);
        for _, record in pairs(cfg.skills) do
            CheckItem(record);
        end
    end
    if (duration > 0) then
        itemCooldowns[key] = Turbine.Engine.GetGameTime() + duration;
    end
end

GetFinisherReadiness = function(record)
    local shortcutType = GetShortcutInfo(record);
    local key = NormalizeSkillName(GetFinisherName(record));
    local now = Turbine.Engine.GetGameTime();
    if (shortcutType == SKILL_SHORTCUT) then
        local skill = trainedByName[key];
        if (not skill or not skill.GetResetTime) then
            return nil, L("main.readinessUnknown");
        end
        local ok, resetTime = pcall(skill.GetResetTime, skill);
        if (not ok) then
            return nil, L("main.readinessUnknown");
        end
        local ready = ComboNextLogic.CooldownReady(resetTime, now);
        if (ready == false) then
            return false, L("main.cooldownRemaining", math.ceil(resetTime - now));
        end
        if (ready and skill.IsUsable) then
            local usableOk, usable = pcall(skill.IsUsable, skill);
            if (not usableOk) then
                return nil, L("main.readinessUnknown");
            elseif (not usable) then
                return false, L("main.skillUnavailable");
            end
        end
        return ready, ready == nil and L("main.readinessUnknown") or nil;
    elseif (shortcutType == ITEM_SHORTCUT) then
        local duration = type(record) == "table" and tonumber(record.itemCooldown);
        if (not duration or duration < 1 or duration > 3600) then
            return nil, L("main.itemTimerUnknown");
        end
        local expiry = itemCooldowns[key];
        if (expiry and expiry > now) then
            return false, L("main.cooldownRemaining", math.ceil(expiry - now));
        end
        local backpack = player and player.GetBackpack and player:GetBackpack();
        if (not backpack) then
            return nil, L("main.readinessUnknown");
        end
        for index = 1, backpack:GetSize() do
            local item = backpack:GetItem(index);
            if (item and NormalizeSkillName(item:GetName()) == key
                and item:GetQuantity() > 0) then
                if (not expiry) then
                    return nil, L("main.itemTimerUnknown");
                end
                return true;
            end
        end
        return false, L("main.itemMissing");
    end
    return nil, L("main.readinessUnknown");
end

local recentEffects = {};
local hookedEffectLists = setmetatable({}, { __mode = "k" });
local lastTargetChangeAt = 0;

local function RememberEffect(name, icon)
    for i = #recentEffects, 1, -1 do
        if (recentEffects[i].skillName == name) then
            icon = icon or recentEffects[i].icon;
            table.remove(recentEffects, i);
        end
    end
    table.insert(recentEffects, 1, { skillName = name; effectName = name; icon = icon });
    for i = #recentEffects, 41, -1 do
        recentEffects[i] = nil;
    end
end

local function OnEffectEvent(scope, event, effect)
    local ok, name = pcall(effect.GetName, effect);
    if (not ok or type(name) ~= "string" or name == "") then
        return;
    end
    local _, icon = pcall(effect.GetIcon, effect);
    RememberEffect(name, type(icon) == "number" and icon or nil);
    if (scope == "target" and Turbine.Engine.GetGameTime() - lastTargetChangeAt < 0.5) then
        return;
    end
    local key = ComboNextEffectKey(scope, event, name);
    local prefix = ComboNextEffectKey(scope, event, "");
    local useIcon = GetSkillLocale() ~= "en" and type(icon) == "number";
    local fired = {};
    for r = 1, #settings.seqs do
        for _, trigger in ipairs(GetTriggers(settings.seqs[r])) do
            if (not fired[trigger.name]
                and (trigger.name == key
                    or (useIcon and trigger.effectIcon == icon
                        and string.sub(trigger.name, 1, #prefix) == prefix))) then
                fired[trigger.name] = true;
            end
        end
    end
    for _, familyName in ipairs(GetEffectFamilies(effect)) do
        local familyKey = ComboNextEffectKey(scope, event, "#" .. familyName);
        for r = 1, #settings.seqs do
            for _, trigger in ipairs(GetTriggers(settings.seqs[r])) do
                if (trigger.name == familyKey) then
                    fired[familyKey] = true;
                end
            end
        end
    end
    local actorName = player and player.GetName and player:GetName() or "You";
    if (next(fired)) then
        HandleSkill(key, actorName, nil, fired);
    end
end

local function HookEffectList(list, scope)
    if (not list or hookedEffectLists[list]) then
        return;
    end
    hookedEffectLists[list] = true;
    local function IsCurrentTargetList()
        if (scope ~= "target") then
            return true;
        end
        local target = player:GetTarget();
        return target and target.GetEffects and target:GetEffects() == list;
    end
    AddCallback(list, "EffectAdded", function(_, args)
        if (not IsCurrentTargetList()) then
            return;
        end
        local ok, err = pcall(function()
            local effect = list:Get(args.Index);
            if (effect) then
                OnEffectEvent(scope, "gained", effect);
            end
        end);
        if (not ok) then
            Turbine.Shell.WriteLine("ComboNext effect event error: " .. tostring(err));
        end
    end);
    AddCallback(list, "EffectRemoved", function(_, args)
        if (not IsCurrentTargetList()) then
            return;
        end
        local ok, err = pcall(function()
            if (args.Effect) then
                OnEffectEvent(scope, "lost", args.Effect);
            end
        end);
        if (not ok) then
            Turbine.Shell.WriteLine("ComboNext effect event error: " .. tostring(err));
        end
    end);
end

local healthArmed = { self = {}; target = {} };
local function GetMoralePercent(actor)
    local ok, percent = pcall(function()
        local morale = actor:GetMorale();
        local maxMorale = actor.GetMaxMorale and actor:GetMaxMorale() or actor:GetBaseMaxMorale();
        if (type(morale) == "number" and type(maxMorale) == "number" and maxMorale > 0) then
            return morale / maxMorale * 100;
        end
    end);
    return ok and percent or nil;
end

local function GetConditionStatus(trigger, actors, now, state, index)
    local record = trigger.value;
    if (type(record) ~= "table" or not record.effectName) then
        local eventTime = state.eventTimes and state.eventTimes[index];
        return eventTime ~= nil and now - eventTime <= settings.resetSeconds,
            L("main.recentEvent", type(record) == "table"
                and (record.skillName or record.itemName or trigger.name) or trigger.name);
    end
    local scope = record.effectScope == "target" and "target" or "self";
    local actor = actors[scope];
    local scopeLabel = L(scope == "target" and "main.target" or "main.self");
    if (not actor) then
        return nil, L("main.actorUnavailable", scopeLabel);
    end
    local threshold = tonumber(string.match(record.effectName, "^!hp<(%d+)$"));
    if (threshold) then
        local percent = GetMoralePercent(actor);
        if (percent == nil) then
            return nil, L("main.actorUnavailable", scopeLabel);
        end
        return percent < threshold,
            L("main.healthCondition", scopeLabel, math.floor(percent), threshold);
    end
    if (not actor.GetEffects) then
        return nil, L("main.actorUnavailable", scopeLabel);
    end
    local ok, found = pcall(function()
        local effects = actor:GetEffects();
        local family = string.match(record.effectName, "^#(%a+)$");
        for effectIndex = 1, effects:GetCount() do
            local effect = effects:Get(effectIndex);
            if (family) then
                local category = effect:GetCategory();
                if (type(category) ~= "number") then
                    error("effect category unavailable");
                end
                local known = false;
                for _, entry in ipairs(effectFamilies) do
                    if (entry.name == family) then
                        known = true;
                    end
                    if (entry.name == family and HasAllBits(category, entry.mask)) then
                        return true;
                    end
                end
                if (not known) then
                    error("effect family unavailable");
                end
            elseif (NormalizeSkillName(effect:GetName()) == NormalizeSkillName(record.effectName)
                or (GetSkillLocale() ~= "en" and record.icon
                    and effect:GetIcon() == record.icon)) then
                return true;
            end
        end
        return false;
    end);
    if (not ok) then
        return nil, L("main.actorUnavailable", scopeLabel);
    end
    local satisfied = found;
    if (record.effectEvent == "lost") then
        satisfied = not found;
    end
    return satisfied, L(record.effectEvent == "lost" and "main.effectAbsent"
        or "main.effectPresent", record.skillName or record.effectName, scopeLabel);
end

RefreshConditions = function()
    local actors = { self = player; target = player:GetTarget() };
    local now = Turbine.Engine.GetGameTime();
    for index, cfg in ipairs(settings.seqs) do
        local triggers = GetTriggers(cfg);
        if (ComboNextLogic.IsCurrent(triggers.mode)) then
            local state = ui.states[index];
            local done = ComboNextLogic.EvaluateConditions(state, triggers, function(trigger, step)
                return GetConditionStatus(trigger, actors, now, state, step);
            end);
            ui.recommendations[index] = done and cfg.finisher ~= nil or nil;
            state.lastProgressAt = state.progress > 0 and now or nil;
        end
    end
end

local function CheckHealthTriggers()
    local actors = { self = player };
    local okTarget, target = pcall(function() return player:GetTarget(); end);
    if (okTarget and target and target.GetMorale) then
        actors.target = target;
    end
    local wanted = { self = {}; target = {} };
    for r = 1, #settings.seqs do
        local triggers = GetTriggers(settings.seqs[r]);
        for _, trigger in ipairs(not ComboNextLogic.IsCurrent(triggers.mode) and triggers or {}) do
            local scope, threshold = string.match(trigger.name, "^@(%a+):gained:!hp<(%d+)$");
            if (scope and wanted[scope]) then
                wanted[scope][tonumber(threshold)] = trigger.name;
            end
        end
    end
    local actorName = player.GetName and player:GetName() or "You";
    for scope, thresholds in pairs(wanted) do
        local percent = actors[scope] and GetMoralePercent(actors[scope]);
        local fired = {};
        local first;
        for threshold, triggerName in pairs(thresholds) do
            if (not percent or percent >= threshold) then
                healthArmed[scope][threshold] = percent and true or nil;
            elseif (healthArmed[scope][threshold] ~= false) then
                healthArmed[scope][threshold] = false;
                fired[triggerName] = true;
                first = first or triggerName;
            end
        end
        if (first) then
            HandleSkill(first, actorName, nil, fired);
        end
    end
end

pcall(function()
    AddCallback(player, "MoraleChanged", function() CheckHealthTriggers(); end);
    AddCallback(player, "MaxMoraleChanged", function() CheckHealthTriggers(); end);
end);

local healthPoller = Turbine.UI.Control();
healthPoller:SetSize(1, 1);
healthPoller:SetVisible(false);
local lastHealthPoll = 0;
healthPoller.Update = function()
    local now = Turbine.Engine.GetGameTime();
    if (now - lastHealthPoll >= 0.5) then
        lastHealthPoll = now;
        CheckHealthTriggers();
        RefreshConditions();
        UpdateActiveSequence();
        ui.UpdateDisplay();
    end
end;
healthPoller:SetWantsUpdates(true);

local function HookTargetEffects()
    pcall(function()
        local target = player:GetTarget();
        if (target and target.GetEffects) then
            HookEffectList(target:GetEffects(), "target");
        end
    end);
end

pcall(function()
    HookEffectList(player:GetEffects(), "self");
    AddCallback(player, "TargetChanged", function()
        lastTargetChangeAt = Turbine.Engine.GetGameTime();
        healthArmed.target = {};
        for index, cfg in ipairs(settings.seqs) do
            for _, record in pairs(cfg.skills) do
                if (type(record) == "table" and record.effectScope == "target") then
                    ui.states[index] = NewProgressState();
                    ui.recommendations[index] = nil;
                    break;
                end
            end
        end
        HookTargetEffects();
    end);
    HookTargetEffects();
end);

effectCatalogProvider = function(search)
    local result, seen = {}, {};
    local query = string.lower(NormalizeSkillName(search or ""));
    local function add(name, icon)
        local plain = NormalizeSkillName(name);
        if (type(name) == "string" and name ~= "" and not seen[plain]
            and (query == "" or string.find(plain, query, 1, true))) then
            seen[plain] = true;
            result[#result + 1] = {
                skillName = (string.gsub(name, "<[^>]+>", ""));
                effectName = (string.gsub(name, "<[^>]+>", ""));
                icon = icon;
            };
        end
    end
    for _, percent in ipairs({ 10, 20, 30, 50, 75 }) do
        local label = L("editor.healthBelow", percent);
        if (query == "" or string.find(string.lower(label), query, 1, true)) then
            result[#result + 1] = {
                skillName = label;
                effectName = "!hp<" .. percent;
                healthBelow = percent;
            };
        end
    end
    for _, family in ipairs(effectFamilies) do
        local label = L("editor.family", family.name);
        if (query == "" or string.find(string.lower(label), query, 1, true)) then
            result[#result + 1] = {
                skillName = label;
                effectName = "#" .. family.name;
                effectFamily = family.name;
            };
        end
    end
    pcall(function()
        local effects = player:GetEffects();
        for i = 1, effects:GetCount() do
            local effect = effects:Get(i);
            local _, icon = pcall(effect.GetIcon, effect);
            add(effect:GetName(), type(icon) == "number" and icon or nil);
        end
    end);
    for _, entry in ipairs(recentEffects) do
        add(entry.skillName, entry.icon);
    end
    if (#query >= 2) then
        for _, entry in ipairs(ComboNextEffectCatalog or {}) do
            if (#result >= 400) then
                break;
            end
            add(entry[1], entry[2]);
        end
    end
    return result;
end

local speechSkipChannels = {};
for _, channelName in ipairs({ "PlayerCombat", "EnemyCombat", "Tell", "Fellowship", "Kinship",
    "Raid", "Officer", "Advancement", "Death", "SelfLoot", "Trade", "Regional", "LFF", "Help" }) do
    local channel = Turbine.ChatType[channelName];
    if (channel ~= nil) then
        speechSkipChannels[channel] = true;
    end
end

local function HandleSpeech(message)
    local normalizedMessage = NormalizeSkillName(message);
    local fired = {};
    for r = 1, #settings.seqs do
        for _, trigger in ipairs(GetTriggers(settings.seqs[r])) do
            if ((trigger.speech or trigger.chatPattern) and not fired[trigger.name]) then
                local phrase = NormalizeSkillName(trigger.chatPattern or trigger.name);
                if (phrase ~= "" and string.find(normalizedMessage, phrase, 1, true)) then
                    fired[trigger.name] = true;
                end
            end
        end
    end
    for triggerName in pairs(fired) do
        HandleSkill(triggerName, L("main.npc"), nil);
    end
end

AddCallback(Turbine.Chat, "Received", function(_, args)
    if (type(args.Message) ~= "string") then
        return;
    end
    if (args.ChatType ~= Turbine.ChatType.PlayerCombat) then
        if (speechSkipChannels[args.ChatType]) then
            return;
        end
        if (ui.captureTarget) then
            ui.captureTarget = nil;
            if (sequenceEditor) then
                sequenceEditor:CaptureChatMessage(args.Message, "speech");
            end
            return;
        end
        pcall(HandleSpeech, args.Message);
        return;
    end
    if (ui.captureTarget) then
        ui.captureTarget = nil;
        if (sequenceEditor) then
            sequenceEditor:CaptureChatMessage(args.Message, "combat");
        end
        return;
    end
    local skillName, actorName, ignoredReason = GetObservedSkill(args.Message);
    if (skillName) then
        HandleSkill(skillName, actorName);
    elseif (ignoredReason == "heal amount") then
        SetDiagnostic("main.healIgnored");
    elseif (ignoredReason == "local skill") then
        SetDiagnostic("main.localIgnored");
    else
        SetDiagnostic("main.noMatch", string.sub(args.Message, 1, 42));
    end
end);

ui.ticker = Turbine.UI.Control();
ui.ticker:SetWantsUpdates(true);
ui.ticker.Update = function()
    local now = Turbine.Engine.GetGameTime();
    if (not ui.nextSkillListenerRefresh or now >= ui.nextSkillListenerRefresh) then
        BindTrainedSkillListeners();
        ui.nextSkillListenerRefresh = now + 2;
    end
    local resetAny = false;
    for index, state in ipairs(ui.states) do
        local cfg = settings.seqs[index];
        local timeout = state.done and ui.recommendations[index]
            and RECOMMENDATION_SECONDS or settings.resetSeconds;
        if (state.done and ui.recommendations[index] and settings.readyOnly
            and GetFinisherReadiness(cfg.finisher) ~= true) then
            state.lastProgressAt = now;
        end
        if (not ComboNextLogic.IsCurrent(ComboNextLogic.GetMode(cfg))
            and state.progress > 0 and state.lastProgressAt
            and now - state.lastProgressAt > timeout) then
            state.progress, state.done, state.matched, state.lastProgressAt = 0, false, {}, nil;
            ui.recommendations[index] = nil;
            resetAny = true;
        end
    end
    if (resetAny) then
        UpdateActiveSequence();
        ui.UpdateDisplay();
        ui.status:SetText(L("main.sequenceReset"));
    end
end

local optionsPanels = {};
RefreshOptionsPanels = function()
    for _, panel in ipairs(optionsPanels) do
        panel:RefreshValues();
    end
    ui.RelayoutFinishers();
    ui.UpdateDisplay();
end
local function CreateOptionsPanel()
    local panel = ComboNextOptionsPanel(settings, Save, RefreshOptionsPanels,
        ApplyUiScale, ApplyUiTheme);
    table.insert(optionsPanels, panel);
    return panel;
end

plugin.GetOptionsPanel = function()
    if (optionsPanel == nil) then
        optionsPanel = CreateOptionsPanel();
    else
        optionsPanel:RefreshValues();
    end
    return optionsPanel
end

OpenOptionsWindow = function()
    if (not optionsWindow) then
        optionsWindow = Turbine.UI.Lotro.Window();
        optionsWindow:SetText(L("main.optionsTitle"));
        optionsWindow:SetWantsKeyEvents(true);
        optionsWindow.KeyDown = onHudKey;
        optionsWindow:SetSize(430, 348);
        optionsWindow:SetScale(GetEffectiveUiScale());
        optionsWindow:SetPosition(
            math.max(0, math.floor((Turbine.UI.Display.GetWidth() - 430) / 2)),
            math.max(0, math.floor((Turbine.UI.Display.GetHeight() - 348) / 2))
        );

        local panel = CreateOptionsPanel();
        panel:SetParent(optionsWindow);
        panel:SetPosition(12, 32);
        ClampScaledWindow(optionsWindow, GetEffectiveUiScale());
        optionsWindow:SetVisible(true);
    else
        optionsWindow:SetVisible(not optionsWindow:IsVisible());
    end
end

ui.title.MouseClick = function(_, args)
    if (args.Button == RIGHT_BUTTON) then
        local menu = Turbine.UI.ContextMenu();
        local items = menu:GetItems();

        local editItem = Turbine.UI.MenuItem(L("main.editCombos"));
        editItem.Click = function()
            OpenSequenceEditor();
        end
        items:Add(editItem);

        local skillsItem = Turbine.UI.MenuItem(L("main.chooseSkills"));
        skillsItem.Click = function()
            OpenSequenceEditor();
        end
        items:Add(skillsItem);

        local optionsItem = Turbine.UI.MenuItem(L("main.openOptions"));
        optionsItem.Click = function()
            OpenOptionsWindow();
        end
        items:Add(optionsItem);

        local hideItem = Turbine.UI.MenuItem(L("main.hideAdvisor"));
        hideItem.Click = function()
            ui.win:SetVisible(false);
        end
        items:Add(hideItem);
        menu:ShowMenu();
    end
end

ui.ApplyTheme();
ui.UpdateDisplay();

local commandRegistered = true;
local shellCommand = Turbine.ShellCommand();
function shellCommand:GetShortHelp()
    return L("main.usage");
end
function shellCommand:GetHelp()
    return self:GetShortHelp();
end
function shellCommand:Execute(_, args)
    local normalizedArgs = string.lower(string.gsub(args or "", "^%s*(.-)%s*$", "%1"));
    local action = string.match(normalizedArgs, "^(%S+)") or "";
    if (action == "show") then
        ui.win:SetVisible(true);
    elseif (action == "hide") then
        ui.win:SetVisible(false);
    elseif (action == "edit" or action == "skills") then
        OpenSequenceEditor();
    elseif (action == "options" or action == "settings") then
        OpenOptionsWindow();
    elseif (action == "quiet") then
        settings.quietMode = not settings.quietMode;
        Save();
        Turbine.Shell.WriteLine("ComboNext quiet mode: " .. (settings.quietMode and "ON" or "OFF"));
    elseif (action == "verify") then
        local verifyDetails = string.lower(
            string.match(args or "", "^%s*%S+%s*(.-)%s*$") or ""
        );
        local verifyCatalog = verifyDetails == "catalog";
        local passed, failed, unchecked = 0, 0, 0;
        local function Check(name, test)
            local ok, detail = pcall(test);
            if (ok and type(detail) == "table" and detail.unchecked) then
                unchecked = unchecked + 1;
                Turbine.Shell.WriteLine(L("main.verifyUnchecked", name, detail.unchecked));
            elseif (ok and detail ~= false) then
                passed = passed + 1;
                Turbine.Shell.WriteLine(L("main.verifyPass", name
                    .. (type(detail) == "string" and (" - " .. detail) or "")));
            else
                failed = failed + 1;
                Turbine.Shell.WriteLine(L("main.verifyFail", name,
                    tostring(ok and "check failed" or detail)));
            end
        end

        Check("saved settings loaded", function()
            if (settingsLoadError) then
                error(tostring(settingsLoadError));
            end
            return type(settings) == "table";
        end);
        Check("required LOTRO APIs available", function()
            return type(Turbine.PluginData.Load) == "function"
                and type(Turbine.PluginData.Save) == "function"
                and type(Turbine.Engine.GetGameTime) == "function"
                and type(Turbine.Gameplay.LocalPlayer.GetInstance) == "function"
                and type(Turbine.Shell.AddCommand) == "function"
                and Turbine.Chat ~= nil
                and Turbine.UI.Lotro.Shortcut ~= nil;
        end);
        Check("language-stable settings encoding", function()
            local sample = { scalar = 1.25; list = { "skill"; 10; }; };
            local encoded = EncodeSettings(sample);
            local copy = DecodeSettings(encoded);
            if (copy.scalar ~= sample.scalar or copy.list[2] ~= 10 or copy.list[1] ~= "skill") then
                error("encoding round trip changed a test value");
            end
            if (string.find(encoded.scalar, ",", 1, true)) then
                error("numeric encoding contains a locale decimal separator");
            end
            return true;
        end);
        Check("localized skill catalog", function()
            local classes = GetClassNames();
            local skillCount, unresolvedCount = 0, 0;
            for _, className in ipairs(classes) do
                for _, skill in ipairs(className ~= ComboNextConstants.effectsClass
                    and GetClassSkills(className, "") or {}) do
                    skillCount = skillCount + 1;
                    if (type(skill.data) ~= "string" or type(skill.skillName) ~= "string"
                        or type(skill.icon) ~= "number") then
                        unresolvedCount = unresolvedCount + 1;
                    else
                        local ok = pcall(function()
                            return Turbine.UI.Lotro.Shortcut(SKILL_SHORTCUT, skill.data);
                        end);
                        if (not ok) then
                            unresolvedCount = unresolvedCount + 1;
                        end
                    end
                end
            end
            if (#classes == 0 or skillCount == 0) then
                error("no class skills found");
            end
            if (unresolvedCount > 0) then
                error(tostring(unresolvedCount) .. " catalog entries failed shortcut checks");
            end
            return tostring(#classes) .. " classes, " .. tostring(skillCount) .. " shortcuts valid";
        end);
        if (verifyCatalog) then
            Check("configured skills match trained skills", function()
                local skills = player and player.GetTrainedSkills and player:GetTrainedSkills();
                if (not skills or type(skills.GetCount) ~= "function") then
                    error("trained skill collection unavailable");
                end
                local trainedNames = {};
                for index = 1, skills:GetCount() do
                    local skill = skills:GetItem(index);
                    local info = skill and skill:GetSkillInfo();
                    local name = info and info:GetName();
                    if (type(name) == "string" and name ~= "") then
                        trainedNames[NormalizeSkillName(name)] = true;
                    end
                end
                local checked, missing, unresolved = 0, 0, 0;
                local function CheckRecord(record)
                    local shortcutType, data = GetShortcutInfo(record);
                    if (type(record) == "table" and record.effectName) then
                        return;
                    end
                    if (shortcutType ~= SKILL_SHORTCUT or data == nil
                        or (type(record) == "table" and record.chatPattern)) then
                        return;
                    end
                    local okShortcut, shortcut = pcall(Turbine.UI.Lotro.Shortcut, SKILL_SHORTCUT, data);
                    if (not okShortcut or not shortcut) then
                        missing = missing + 1;
                        return;
                    end
                    if (type(shortcut.GetSkillName) ~= "function") then
                        unresolved = unresolved + 1;
                        return;
                    end
                    local okName, name = pcall(shortcut.GetSkillName, shortcut);
                    if (type(name) == "table") then
                        name = name[1];
                    end
                    if (okName and type(name) == "string" and name ~= ""
                        and not string.match(name, "^0[xX]")) then
                        checked = checked + 1;
                        if (not trainedNames[NormalizeSkillName(name)]) then
                            missing = missing + 1;
                        end
                    else
                        unresolved = unresolved + 1;
                    end
                end
                for _, combo in ipairs(settings.seqs) do
                    for step = 1, combo.stepCount or 0 do
                        CheckRecord(combo.skills[step]);
                    end
                    CheckRecord(combo.finisher);
                end
                if (missing > 0) then
                    error(tostring(missing) .. " configured skills are not trained or invalid; "
                        .. tostring(unresolved) .. " could not be checked");
                end
                if (unresolved > 0) then
                    return { unchecked = tostring(checked) .. " checked; "
                        .. tostring(unresolved) .. " could not be read through the LOTRO API" };
                end
                return tostring(checked) .. " configured skills checked";
            end);
        end
        Check("trained-skill event listeners", function()
            local skills = player and player.GetTrainedSkills and player:GetTrainedSkills();
            if (not skills or type(skills.GetCount) ~= "function") then
                error("trained skill collection unavailable");
            end
            local watchedCount = 0;
            for _ in pairs(watchedSkills) do
                watchedCount = watchedCount + 1;
            end
            if (skills:GetCount() > 0 and watchedCount == 0) then
                error("no trained skill listeners were registered");
            end
            return tostring(skills:GetCount()) .. " trained; "
                .. tostring(watchedCount) .. " watched";
        end);
        Check("combo and shortcut data", function()
            local combos, triggers, finishers = 0, 0, 0;
            local function CheckShortcut(record, label, allowChatPattern)
                if (type(record) == "table" and type(record.effectName) == "string") then
                    return;
                end
                local shortcutType, data = GetShortcutInfo(record);
                if (shortcutType ~= nil and data ~= nil) then
                    local ok, shortcut = pcall(function()
                        return Turbine.UI.Lotro.Shortcut(shortcutType, data);
                    end);
                    if (not ok or not shortcut) then
                        error(label .. " shortcut cannot be constructed");
                    end
                    if (shortcutType == SKILL_SHORTCUT
                        and (type(record) ~= "table" or type(record.skillName) ~= "string"
                            or record.skillName == "" or string.match(record.skillName, "^0[xX]"))) then
                        error(label .. " has no stored skill name");
                    end
                    if (shortcutType == ITEM_SHORTCUT and type(record) == "table"
                        and record.itemCooldown ~= nil) then
                        local duration = tonumber(record.itemCooldown);
                        if (not duration or duration < 1 or duration > 3600 or duration % 1 ~= 0) then
                            error(label .. " has an invalid item cooldown");
                        end
                    end
                elseif (allowChatPattern and type(record) == "table"
                    and type(record.chatPattern) == "string" and record.chatPattern ~= "") then
                    return;
                else
                    error(label .. " has neither a shortcut nor chat pattern");
                end
            end
            for index, combo in ipairs(settings.seqs) do
                if (type(combo) ~= "table" or type(combo.skills) ~= "table") then
                    error("combo " .. index .. " has invalid data");
                end
                if (type(combo.stepCount) ~= "number" or combo.stepCount < 1
                    or combo.stepCount > MAX_STEPS) then
                    error("combo " .. index .. " has invalid trigger count");
                end
                combos = combos + 1;
                local mode = ComboNextLogic.GetMode(combo);
                if (mode ~= "ordered" and mode ~= "any" and mode ~= "or"
                    and mode ~= "allConditions" and mode ~= "anyConditions") then
                    error("combo " .. index .. " has invalid trigger mode");
                end
                for step = 1, combo.stepCount do
                    local record = combo.skills[step];
                    if (record) then
                        triggers = triggers + 1;
                        local name = type(record) == "table" and (record.itemName or record.skillName);
                        if (type(name) ~= "string" or name == "") then
                            error("combo " .. index .. " trigger " .. step .. " has no trigger name");
                        end
                        CheckShortcut(record, "combo " .. index .. " trigger " .. step, true);
                    end
                end
                if (combo.finisher) then
                    finishers = finishers + 1;
                    CheckShortcut(combo.finisher, "combo " .. index .. " finisher", false);
                end
            end
            return tostring(combos) .. " combos, " .. tostring(triggers) .. " triggers, "
                .. tostring(finishers) .. " finishers";
        end);
        Check("nine finisher display slots", function()
            if (#ui.finisherChoices ~= MAX_VISIBLE_FINISHERS
                or MAX_VISIBLE_FINISHERS ~= 9) then
                error("expected nine finisher quickslots");
            end
            for index, choice in ipairs(ui.finisherChoices) do
                local x = choice.icon:GetPosition();
                if (index <= math.max(1, settings.finisherSlots or 1) and x + choice.icon:GetWidth() > WINDOW_WIDTH) then
                    error("finisher slot " .. index .. " extends outside the advisor");
                end
            end
            return true;
        end);
        Check("slash command registration", function()
            return commandRegistered;
        end);
        Check("finisher readiness coverage", function()
            local known, unknown = 0, 0;
            for _, cfg in ipairs(settings.seqs) do
                if (cfg.finisher) then
                    if (GetFinisherReadiness(cfg.finisher) == nil) then
                        unknown = unknown + 1;
                    else
                        known = known + 1;
                    end
                end
            end
            if (unknown > 0) then
                return { unchecked = tostring(known) .. " known; " .. tostring(unknown)
                    .. " unknown (item timers need a duration and observed use or Mark ready)" };
            end
            return tostring(known) .. " finishers have known readiness";
        end);
        Turbine.Shell.WriteLine(L("main.verifyDone", passed, failed, unchecked));
    elseif (action == "") then
        ui.win:SetVisible(not ui.win:IsVisible());
    else
        Turbine.Shell.WriteLine(self:GetShortHelp());
    end
end
local commandCount = Turbine.Shell.AddCommand("combnext;cn", shellCommand);
if (type(commandCount) == "number" and commandCount < 1) then
    commandRegistered = false;
    Turbine.Shell.WriteLine(L("main.commandFailed"));
else
    Turbine.Shell.WriteLine(L("main.loaded", VERSION));
end
if (settingsLoadError) then
    Turbine.Shell.WriteLine(L("main.loadError", tostring(settingsLoadError)));
elseif (settingsRecoveredFromBackup) then
    Turbine.Shell.WriteLine(L("main.backupRestored"));
end
-- F12 hides LOTRO's UI but not plain plugin windows, so mirror it here.
local hudHidden = false;
local hiddenState = {};
local hudKeyWindow = Turbine.UI.Window();
hudKeyWindow:SetPosition(-10, -10);
hudKeyWindow:SetSize(5, 5);
hudKeyWindow:SetVisible(true);
hudKeyWindow:SetWantsKeyEvents(true);
local lastHudToggle = -1;
local toggleHudAction = Turbine.UI.Lotro.Action.ToggleHUD
    or Turbine.UI.Lotro.Action.UI_Toggle
    or 0x100000B3;
onHudKey = function(_, args)
    if (args.Action ~= toggleHudAction) then
        return;
    end
    local now = Turbine.Engine.GetGameTime();
    if (now - lastHudToggle < 0.3) then
        return;
    end
    lastHudToggle = now;
    hudHidden = not hudHidden;
    local targets = { ui.win, ui.launcher, sequenceEditor, optionsWindow };
    for i = 1, 4 do
        local target = targets[i];
        if (target) then
            if (hudHidden) then
                hiddenState[i] = target:IsVisible();
                target:SetVisible(false);
            elseif (hiddenState[i]) then
                target:SetVisible(true);
            end
        end
    end
end
pcall(function()
    AddCallback(player, "InCombatChanged", function()
        if (settings.showInCombat and not hudHidden and player:IsInCombat()
            and not ui.win:IsVisible()) then
            ui.win:SetVisible(true);
        end
    end);
end);
for _, w in ipairs({ hudKeyWindow, ui.win, ui.launcher }) do
    w:SetWantsKeyEvents(true);
    w.KeyDown = onHudKey;
end
plugin.Unload = function()
    Turbine.Shell.RemoveCommand(shellCommand);
end
if (#settings.seqs == 0) then
    OpenSequenceEditor();
end

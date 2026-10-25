-- Run from ComboNext/: lua tests/run.lua
local controls, output, loaded = {}, {}, {};
local now = 100;
local command;
unpack = unpack or table.unpack;

local methods = {};
function methods:SetSize(w, h) self.width, self.height = w, h; end
function methods:GetWidth() return self.width or 0; end
function methods:GetHeight() return self.height or 0; end
function methods:SetPosition(x, y) self.x, self.y = x, y; end
function methods:GetPosition() return self.x or 0, self.y or 0; end
function methods:SetText(text) self.text = text; end
function methods:GetText() return self.text or ""; end
function methods:SetVisible(value) self.visible = value; end
function methods:IsVisible() return self.visible; end
function methods:SetEnabled(value) self.enabled = value; end
function methods:SetShortcut(value) self.shortcut = value; end
function methods:GetShortcut() return self.shortcut; end
function methods:SetWantsUpdates(value) self.updates = value; end
function methods:GetItems() return self.items; end
function methods:SetParent(parent) self.parent = parent; end
for _, name in ipairs({ "SetBackColor", "SetForeColor", "SetBackground", "SetFont",
    "SetTextAlignment", "SetMouseVisible", "SetZOrder", "SetAllowDrop", "SetOpacity",
    "SetScale", "SetWantsKeyEvents", "SetMultiline", "SelectAll", "Focus", "ShowMenu",
    "SetStretchMode", "SetBlendMode", "SetFontStyle", "SetReadOnly", "SetMaxLength",
    "SetMarkupEnabled", "SetOutlineColor", "SetSuccessful" }) do
    methods[name] = function() end;
end
function class(base)
    local result = {};
    result.__index = result;
    return setmetatable(result, {
        __index = base;
        __call = function(kind, ...)
            local instance = setmetatable({}, kind);
            if (instance.Constructor) then instance:Constructor(...); end
            return instance;
        end;
    });
end
local Control = class(methods);
function Control:Constructor()
    controls[#controls + 1] = self;
    self.items = {};
    function self.items:Add(value) table.insert(self, value); end
end
local function collection(values)
    return {
        GetCount = function() return #values; end;
        GetSize = function() return #values; end;
        GetItem = function(_, index) return values[index]; end;
        Get = function(_, index) return values[index]; end;
    };
end
local function skill(name, icon)
    return {
        reset = -1; usable = true;
        GetResetTime = function(self) return self.reset; end;
        IsUsable = function(self) return self.usable; end;
        GetSkillInfo = function() return {
            GetName = function() return name; end;
            GetIconImageID = function() return icon; end;
        }; end;
    };
end
local heal, attack = skill("Heal", 1), skill("Attack", 2);
local effectValues = {};
local effects = collection(effectValues);
local backpackValues = { {
    GetName = function() return "Health Potion"; end;
    GetQuantity = function() return 3; end;
} };
local player = {
    morale = 100; maxMorale = 100;
    GetName = function() return "Tester"; end;
    GetMorale = function(self) return self.morale; end;
    GetMaxMorale = function(self) return self.maxMorale; end;
    GetTarget = function(self) return self.target; end;
    GetEffects = function() return effects; end;
    GetTrainedSkills = function() return collection({ heal, attack }); end;
    GetBackpack = function() return collection(backpackValues); end;
};
local function shortcut(kind, data)
    return {
        GetType = function() return kind; end;
        GetData = function() return data; end;
    };
end
local saved = {
    alwaysFirstFinisher = false;
    seqs = { {
        name = "Test"; skills = { { skillName = "Attack"; shortcutType = 1; data = "attack" } };
        stepCount = 1; finisher = { skillName = "Heal"; shortcutType = 1; data = "heal" };
    } };
};
Turbine = {
    UI = {
        Control = Control; Window = Control; Label = Control; ContextMenu = Control;
        MenuItem = function(text) local item = Control(); item:SetText(text); return item; end;
        Color = function(...) return { ... }; end;
        ContentAlignment = { MiddleCenter = 1; MiddleLeft = 2 };
        BlendMode = { AlphaBlend = 1 }; FontStyle = { Outline = 1 };
        MouseButton = { Left = 1; Right = 2 };
        Display = { GetWidth = function() return 1920; end;
            GetHeight = function() return 1080; end; GetMousePosition = function() return 0, 0; end };
        Lotro = { Window = Control; Button = Control; TextBox = Control; Quickslot = Control;
            Font = { Verdana10 = 10 }; Action = {}; ShortcutType = { Skill = 1; Item = 2 };
            Shortcut = shortcut };
    };
    Gameplay = { LocalPlayer = { GetInstance = function() return player; end };
        EffectCategory = { Wound = 1; Poison = 2; Disease = 4; Fear = 8; Corruption = 16;
            Cry = 32; Song = 64; Elemental = 128; Physical = 512; Tactical = 256 } };
    Engine = { GetGameTime = function() return now; end; GetLanguage = function() return 1; end };
    Language = { English = 1; German = 2; French = 3 };
    ChatType = { PlayerCombat = 1; EnemyCombat = 2 }; Chat = {};
    DataScope = { Character = 1 };
    PluginData = { Load = function() return saved; end; Save = function() end };
    ShellCommand = function() return {}; end;
    Shell = { WriteLine = function(text) output[#output + 1] = text; end;
        AddCommand = function(_, value) command = value; return 1; end;
        RemoveCommand = function() end };
};
plugin = {};
function import(name)
    if (loaded[name] or string.match(name, "^Turbine")) then return; end
    loaded[name] = true;
    local path = string.gsub(name, "^ComboNext%.", "");
    dofile(path .. ".lua");
end
import "ComboNext.Main";
local ui = ComboNext;
local count = 0;
local function check(value, label)
    assert(value, label);
    count = count + 1;
end
local function tick()
    now = now + 0.6;
    for _, control in ipairs(controls) do
        if (control.updates and control.Update) then control:Update(); end
    end
end
local function health(scope, percent)
    return { skillName = "Health"; effectName = "!hp<" .. percent;
        healthBelow = percent; effectScope = scope; effectEvent = "gained" };
end
local function effect(name, scope, event)
    return { skillName = name; effectName = name; effectScope = scope or "self";
        effectEvent = event or "gained" };
end
local function configure(mode, records, finisher)
    ui.settings.seqs = { { name = "Test"; triggerMode = mode; skills = records;
        stepCount = #records; finisher = finisher
            or { skillName = "Heal"; shortcutType = 1; data = "heal" } } };
    ui.ResetProgress();
end
local function chat(name)
    Turbine.Chat:Received({ ChatType = 1; Message = "You used " .. name .. "." });
end
local function wound(name)
    return { GetName = function() return name; end; GetCategory = function() return 3; end;
        GetIcon = function() return 10; end };
end

configure("allConditions", { health("self", 20), effect("#Wound") });
player.morale = 15;
tick();
check(not ui.recommendations[1], "health alone must not satisfy AND");
effectValues[1] = wound("Raid Wound");
tick();
check(ui.recommendations[1], "health first, wound second must satisfy current AND");
check(string.find(ui.status:GetText(), "matched"), "completed condition status");
effectValues[1] = nil;
tick();
check(not ui.recommendations[1], "cleared wound invalidates current AND");
effectValues[1] = wound("Raid Wound");
player.morale = 100;
tick();
check(not ui.recommendations[1], "wound alone must not satisfy AND");
player.morale = 10;
tick();
check(ui.recommendations[1], "wound first, health second satisfies AND");
chat("Heal");
tick();
check(not ui.recommendations[1], "used finisher stays consumed until conditions reset");
player.morale = 100;
tick();
player.morale = 10;
tick();
check(ui.recommendations[1], "current condition re-arms after false");
player.morale = 20;
tick();
check(not ui.recommendations[1], "health threshold is strictly below");

configure("anyConditions", { health("self", 20), effect("#Wound") });
tick();
check(ui.recommendations[1], "OR conditions require just one true");
effectValues[1] = nil;
tick();
check(not ui.recommendations[1], "OR clears when no conditions true");
configure("allConditions", { effect("Raid Wound", "target", "lost") });
player.target = nil;
tick();
check(not ui.recommendations[1], "missing target is unknown, not an absent effect");
local targetEffects = collection({});
player.target = { morale = 15; GetMorale = function(self) return self.morale; end;
    GetBaseMaxMorale = function() return 100; end;
    GetEffects = function() return targetEffects; end };
configure("allConditions", { health("target", 20) });
tick();
check(ui.recommendations[1], "target morale uses base max API");
player.target.morale = 20;
tick();
check(not ui.recommendations[1], "target recovery hides condition recommendation");

configure("or", { { skillName = "Attack" }, { skillName = "Other" } });
chat("Other");
check(ui.recommendations[1], "OR event accepts second trigger alone");
configure("ordered", { effect("#Wound"), effect("Raid Wound") });
effectValues[1] = wound("Raid Wound");
effects:EffectAdded({ Index = 1 });
check(ui.states[1].progress == 1 and not ui.states[1].done,
    "one effect matching family and exact name advances just one ordered step");
effects:EffectAdded({ Index = 1 });
check(ui.states[1].done, "a second distinct effect event advances the second step");
configure("any", { effect("#Wound"), effect("Raid Wound") });
effects:EffectAdded({ Index = 1 });
check(ui.states[1].progress == 1, "one physical effect advances one any-order step");
configure("or", { effect("#Wound") });
effects:EffectAdded({ Index = 1 });
check(ui.recommendations[1], "family remains independently usable");
configure("or", { effect("Raid Wound") });
effects:EffectAdded({ Index = 1 });
check(ui.recommendations[1], "raid-critical exact effect remains independently usable");

ui.settings.readyOnly = true;
configure("allConditions", { health("self", 50) });
player.morale = 10;
heal.reset = now + 60;
tick();
check(ui.recommendations[1] and not ui.finisherChoices[1].icon:IsVisible(),
    "cooldown filter hides finisher without clearing match");
now = now + 31;
tick();
check(ui.recommendations[1], "cooldown hiding preserves event/condition progress");
heal.reset = -1;
tick();
check(ui.finisherChoices[1].icon:IsVisible(), "finisher returns when cooldown ends");
heal.usable = false;
tick();
check(not ui.finisherChoices[1].icon:IsVisible(), "unusable skill is hidden in ready-only mode");
ui.settings.readyOnly = false;
tick();
check(ui.finisherChoices[1].icon:IsVisible(), "show-always option retains cooldown finishers");
heal.usable = true;

local potion = { itemName = "Health Potion"; shortcutType = 2; data = "potion"; itemCooldown = 5 };
configure("or", { { skillName = "Attack" } }, potion);
ui.settings.readyOnly = true;
chat("Attack");
check(not ui.finisherChoices[1].icon:IsVisible(), "unobserved item timer must be unknown");
ui.setupBtn:Click();
local editor;
for _, control in ipairs(controls) do
    if (control.itemReadyButton) then editor = control; end
end
check(editor ~= nil, "editor opens without API errors: " .. table.concat(output, "\n"));
editor:SelectSlot(1, editor.finisherSlot);
editor.itemReadyButton:Click();
check(ui.finisherChoices[1].icon:IsVisible(), "explicit Mark ready enables available potion");
chat("Health Potion");
chat("Attack");
check(ui.recommendations[1] and not ui.finisherChoices[1].icon:IsVisible(),
    "observed potion use starts manual cooldown");
now = now + 6;
tick();
check(ui.finisherChoices[1].icon:IsVisible(), "potion returns when configured timer expires");
backpackValues[1] = nil;
tick();
check(not ui.finisherChoices[1].icon:IsVisible(), "missing potion is hidden even after timer expires");
backpackValues[1] = { GetName = function() return "Health Potion"; end;
    GetQuantity = function() return 3; end };
editor.itemTimerText:SetText("0");
editor.itemTimerSave:Click();
check(potion.itemCooldown == 5, "invalid zero-second timer rejected");
editor.itemTimerText:SetText("10");
editor.itemTimerSave:Click();
check(potion.itemCooldown == 10 and editor.itemReadyButton.enabled, "valid item timer saved");
editor.itemTimerText:SetText("5");
editor.itemTimerSave:Click();

local share = ComboNextShareWindow(ui.settings, function() end, function() ui.ResetProgress(); end,
    function() return nil; end, editor);
ui.settings.seqs[1].triggerMode = "anyConditions";
share:Export(false);
local exported = share.box:GetText();
check(string.sub(exported, 1, 4) == "CN2!", "new share format is versioned");
share:Import(true);
check(ui.settings.seqs[1].triggerMode == "anyConditions", "share preserves current OR mode");
check(ui.settings.seqs[1].finisher.itemCooldown == 5, "share preserves item duration");
share.box:SetText("CN1!Legacy|1|E:SG:%23Wound:|I:potion:Health%20Potion");
share:Import(true);
check(ui.settings.seqs[1].triggerMode == "ordered", "legacy CN1 remains importable");
share.box:SetText("CN2!Invalid|1:futureMode|E:SG:%23Wound:|I:potion:Health%20Potion");
share:Import(true);
check(ui.settings.seqs[1].name == "Legacy", "unknown mode rejects import without changing settings");

configure("ordered", { { skillName = "Attack"; shortcutType = 1; data = "attack" } });
output = {};
command:Execute("cn", "verify catalog");
local log = table.concat(output, "\n");
check(string.find(log, "VERIFY NOT CHECKED: configured skills match trained skills", 1, true),
    "unavailable GetSkillName API is not reported as PASS");
check(not string.find(log, "VERIFY FAIL", 1, true), "verification has no unexpected failures: " .. log);
check(string.find(log, "not checked", 1, true), "verification summary includes not-checked count");
Turbine.UI.Lotro.Shortcut = function(kind, data)
    local value = shortcut(kind, data);
    value.GetSkillName = function() return data == "heal" and "Heal" or "Attack"; end;
    return value;
end;
output = {};
command:Execute("cn", "verify catalog");
log = table.concat(output, "\n");
check(string.find(log, "VERIFY PASS: configured skills match trained skills", 1, true),
    "readable trained skills report PASS");
Turbine.UI.Lotro.Shortcut = function(kind, data)
    local value = shortcut(kind, data);
    value.GetSkillName = function() return "Not trained"; end;
    return value;
end;
output = {};
command:Execute("cn", "verify catalog");
log = table.concat(output, "\n");
check(string.find(log, "VERIFY FAIL: configured skills match trained skills", 1, true),
    "known missing trained skills still report FAIL: " .. log);
Turbine.UI.Lotro.Shortcut = shortcut;

configure("allConditions", { health("self", 20), { skillName = "Attack" } });
player.morale = 10;
tick();
check(not ui.recommendations[1], "mixed mode requires recent skill event");
chat("Attack");
check(ui.recommendations[1], "mixed mode combines live health with recent skill event");
now = now + ui.settings.resetSeconds + 1;
tick();
check(not ui.recommendations[1], "recent event expires in current-condition mode");

configure("ordered", { health("target", 75) });
player.target.morale = 50;
player:TargetChanged();
tick();
check(ui.recommendations[1], "health event fires for newly selected low-health target");
player.target = nil;
player:TargetChanged();
tick();
check(not ui.recommendations[1], "old target recommendations clear on target switch");
local oldTarget = player.target;
local staleEffects = collection({ wound("Raid Wound") });
player.target = { GetEffects = function() return staleEffects; end };
player:TargetChanged();
tick();
player.target = { GetEffects = function() return collection({}); end };
player:TargetChanged();
tick();
configure("or", { effect("Raid Wound", "target") });
staleEffects:EffectAdded({ Index = 1 });
check(not ui.recommendations[1], "events from old target's effect list are ignored");
player.target = oldTarget;

configure("ordered", { { skillName = "Attack" } });
chat("Attack");
check(ui.recommendations[1], "ordered event combo matches normally");
heal.reset = now + 90;
tick();
now = now + 40;
tick();
check(ui.recommendations[1], "completed event combo is retained while finisher is on cooldown");
heal.reset = -1;
tick();
check(ui.finisherChoices[1].icon:IsVisible(), "retained event recommendation returns when ready");

local logic = ComboNextLogic;
check(logic.GetMode({ anyOrder = true }) == "any", "legacy any-order settings retain behavior");
check(logic.GetMode({}) == "ordered", "default settings retain ordered behavior");
local state = { progress = 0; done = false; matched = {} };
local triggers = { { name = "A" }, { name = "A" }, { name = "B" }, mode = "ordered" };
for _, name in ipairs({ "A", "A", "A", "B" }) do
    logic.Advance(state, triggers, function(trigger) return trigger.name == name; end);
end
check(state.done, "ordered matching preserves overlapping prefixes");
state = { progress = 0; done = false; matched = {} };
triggers.mode = "any";
for _, name in ipairs({ "B", "A" }) do
    logic.Advance(state, triggers, function(trigger) return trigger.name == name; end);
end
check(not state.done and state.progress == 2, "duplicate any-order triggers require separate events");
logic.Advance(state, triggers, function(trigger) return trigger.name == "A"; end);
check(state.done, "any-order duplicate completes on second occurrence");
check(logic.CooldownReady(nil, now) == nil, "unknown cooldown is not guessed ready");
check(logic.CooldownReady(now, now) == true, "cooldown ending exactly now is ready");

ui.setupBtn:Click();
editor.anyOrderButton:Click();
local modeMenu = controls[#controls];
check(#modeMenu:GetItems() == 0, "last menu item has no child menu");
local foundMode;
for _, control in ipairs(controls) do
    if (#control:GetItems() == 5) then
        foundMode = control;
    end
end
check(foundMode ~= nil, "editor exposes all five trigger modes");
foundMode:GetItems()[3]:Click();
check(ui.settings.seqs[1].triggerMode == "or", "editor changes combo to OR event mode");
editor:InsertCell("T");
check(ui.settings.seqs[1].triggerMode == "or", "editing the chain preserves chosen logic mode");

configure("or", { { itemName = "Health Potion"; shortcutType = 2; data = "potion" } });
output = {};
command:Execute("cn", "verify");
log = table.concat(output, "\n");
check(not string.find(log, "VERIFY FAIL", 1, true), "item-only names are valid trigger data: " .. log);
chat("Health Potion");
check(ui.recommendations[1], "item triggers match without a skillName field");

ui.settingsBtn:Click();
local options;
for _, control in ipairs(controls) do
    if (control.readyButton) then options = control; end
end
check(options ~= nil, "options panel opens with readiness setting");
local previousReadyOnly = ui.settings.readyOnly;
options.readyButton:Click();
check(ui.settings.readyOnly ~= previousReadyOnly, "readiness setting toggles through native options");

configure("allConditions", { health("self", 20) });
for _, mode in ipairs({ "ordered", "any", "or", "allConditions", "anyConditions" }) do
    ui.settings.seqs[1].triggerMode = mode;
    editor:EnsureGroups();
    share:Export(false);
    share:Import(true);
    check(ui.settings.seqs[1].triggerMode == mode, "share round trip: " .. mode);
end
print(tostring(count) .. " ComboNext assertions passed.");

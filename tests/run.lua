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
check(string.sub(exported, 1, 4) == "CN4!", "new share format is versioned");
share:Import(true);
check(ui.settings.seqs[1].triggerMode == "allConditions", "share migrates legacy current OR mode");
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
    if (#control:GetItems() == 3) then
        foundMode = control;
    end
end
check(foundMode ~= nil, "editor exposes three modes without combo-wide OR choices");
foundMode:GetItems()[3]:Click();
check(ui.settings.seqs[1].triggerMode == "allConditions", "editor selects current-condition evaluation");
editor:InsertCell("T");
check(ui.settings.seqs[1].triggerMode == "allConditions", "editing the chain preserves chosen logic mode");

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
    check(ui.settings.seqs[1].triggerMode == logic.GetMode({ triggerMode = mode }),
        "share round trip/migration: " .. mode);
end

local records = { effect("#Poison"), health("self", 50), effect("#Wound") };
local rule;
local function mixed(mode, joins)
    configure(mode, records);
    rule = ui.settings.seqs[1];
    rule.triggerJoins = joins;
end
effectValues[1] = nil;
player.morale = 30;
mixed("allConditions", { [2] = "OR"; [3] = "AND" });
tick();
check(not ui.recommendations[1], "Poison OR (low health AND wound): low health alone is insufficient");
check(string.find(ui.status:GetText(), " OR ", 1, true), "progress text preserves OR alternatives");
effectValues[1] = { GetName = function() return "Poison"; end;
    GetCategory = function() return 2; end; GetIcon = function() return 20; end };
player.morale = 100;
tick();
check(ui.recommendations[1], "Poison OR (low health AND wound): poison alone is sufficient");
effectValues[1] = nil;
tick();
effectValues[1] = { GetName = function() return "Wound"; end;
    GetCategory = function() return 1; end; GetIcon = function() return 30; end };
player.morale = 30;
tick();
check(ui.recommendations[1], "Poison OR (low health AND wound): second AND branch is sufficient");
effectValues[1] = nil;
tick();
check(not ui.recommendations[1], "clearing wound invalidates low-health AND wound branch");

mixed("allConditions", { [2] = "AND"; [3] = "OR" });
effectValues[1] = { GetName = function() return "Poison"; end;
    GetCategory = function() return 2; end; GetIcon = function() return 20; end };
player.morale = 30;
tick();
check(ui.recommendations[1], "(Poison AND low health) OR wound: first AND branch is sufficient");
effectValues[1] = nil;
tick();
check(not ui.recommendations[1], "AND before OR: low health alone still insufficient");
effectValues[1] = { GetName = function() return "Wound"; end;
    GetCategory = function() return 1; end; GetIcon = function() return 30; end };
player.morale = 100;
tick();
check(ui.recommendations[1], "final OR wound trigger works independently");

mixed("allConditions", nil);
tick();
check(not ui.recommendations[1], "AND remains default without connector settings");
rule.triggerJoins = { [2] = "OR"; [3] = "OR" };
tick();
check(ui.recommendations[1], "per-trigger OR works without a combo-wide OR mode");
for _, oldMode in ipairs({ "or", "anyConditions" }) do
    local cfg = { triggerMode = oldMode; stepCount = 3 };
    logic.NormalizeRule(cfg);
    check(cfg.triggerMode == (oldMode == "or" and "ordered" or "allConditions")
        and cfg.triggerJoins[2] == "OR" and cfg.triggerJoins[3] == "OR",
        "legacy OR settings migrate all connectors: " .. oldMode);
    logic.NormalizeRule(cfg);
    check(cfg.triggerJoins[2] == "OR" and cfg.triggerJoins[3] == "OR",
        "migration is idempotent: " .. oldMode);
end
share.box:SetText("CN2!OldOR|2:or|E:SG:%23Poison:,E:SG:%21hp%3C50:|I:potion:Health%20Potion:10");
share:Import(true);
check(ui.settings.seqs[1].triggerMode == "ordered"
    and ui.settings.seqs[1].triggerJoins[2] == "OR", "CN2 event OR imports as per-trigger OR");
share.box:SetText("CN2!OldConditions|2:anyConditions|E:SG:%23Poison:,E:SG:%21hp%3C50:|I:potion:Health%20Potion:10");
share:Import(true);
check(ui.settings.seqs[1].triggerMode == "allConditions"
    and ui.settings.seqs[1].triggerJoins[2] == "OR", "CN2 current OR imports as per-trigger OR");

for _, mode in ipairs({ "ordered", "any", "allConditions" }) do
    mixed(mode, { [2] = "OR"; [3] = "AND" });
    editor:EnsureGroups();
    share:Export(false);
    share:Import(true);
    check(ui.settings.seqs[1].triggerJoins[2] == "OR"
        and ui.settings.seqs[1].triggerJoins[3] == "AND"
        and ui.settings.seqs[1].triggerMode == mode, "mixed connector sharing: " .. mode);
end
for _, token in ipairs({ "3:allConditions:O", "3:allConditions:OOO",
    "3:allConditions:OX", "3:or:OO", "9:ordered:AAAAAAAA" }) do
    local previous = ui.settings.seqs;
    share.box:SetText("CN3!Bad|" .. token .. "|E:SG:%23Poison:|I:potion:Health%20Potion");
    share:Import(true);
    check(ui.settings.seqs == previous, "invalid connector metadata rejects import: " .. token);
end
local previousRules = ui.settings.seqs;
share.box:SetText("CN3!BadTrigger|2:allConditions:A|E:SG:%23Poison:,X:invalid|I:potion:Health%20Potion");
share:Import(true);
check(ui.settings.seqs == previousRules, "invalid imported AND trigger cannot silently weaken a rule");

local function runEvents(mode, joins, names)
    configure(mode, { { skillName = "Attack" }, { skillName = "B" }, { skillName = "C" } });
    ui.settings.seqs[1].triggerJoins = joins;
    for _, name in ipairs(names) do
        now = now + 1;
        chat(name);
    end
end
runEvents("ordered", { [2] = "OR" }, { "Attack" });
check(ui.recommendations[1], "event A OR (B AND C) completes on A");
runEvents("ordered", { [2] = "OR" }, { "B" });
check(not ui.recommendations[1], "event B alone does not complete B AND C branch");
now = now + 1;
chat("C");
check(ui.recommendations[1], "event B then C completes second branch");
runEvents("ordered", { [2] = "OR" }, { "C", "B" });
check(not ui.recommendations[1], "ordered AND branch retains order");
runEvents("any", { [2] = "OR" }, { "C", "B" });
check(ui.recommendations[1], "any-order AND branch accepts C then B");
runEvents("ordered", { [3] = "OR" }, { "C" });
check(ui.recommendations[1], "(A AND B) OR C completes on C");

configure("ordered", { effect("#Wound"), effect("Raid Wound"), effect("#Poison") });
ui.settings.seqs[1].triggerJoins = { [3] = "OR" };
effectValues[1] = { GetName = function() return "Raid Wound"; end;
    GetCategory = function() return 1; end; GetIcon = function() return 10; end };
effects:EffectAdded({ Index = 1 });
check(ui.states[1].progress == 1 and not ui.recommendations[1],
    "one effect cannot satisfy two AND events inside an OR expression");
effects:EffectAdded({ Index = 1 });
check(ui.recommendations[1], "second physical event completes an AND group inside OR expression");

mixed("allConditions", { [2] = "AND"; [3] = "AND" });
editor:EnsureGroups();
editor:SelectSlot(1, 2);
check(editor.triggerJoinButton:IsVisible()
    and editor.triggerJoinButton:GetText():find("AND", 1, true), "selected trigger defaults to AND");
editor.triggerJoinButton:Click();
check(ui.settings.seqs[1].triggerJoins[2] == "OR", "selected connector toggles to OR");
check(ui.settings.seqs[1].triggerJoins[3] == "AND", "connector edit changes only the selected trigger");
check(editor.slots[2].joinButton:GetText() == "OR", "slot shows individual OR connector");
editor.slots[3].joinButton:Click();
check(ui.settings.seqs[1].triggerJoins[3] == "OR", "slot connector toggles individually");
editor:SelectSlot(1, 1);
check(not editor.triggerJoinButton:IsVisible()
    and not editor.slots[1].joinButton:IsVisible(), "first trigger has no preceding connector");
editor:SelectSlot(1, editor.finisherSlot);
check(not editor.triggerJoinButton:IsVisible(), "finisher is not an AND/OR trigger");
editor:SelectSlot(1, 2);
editor:MoveCellTo(2, 3);
check(ui.settings.seqs[1].triggerJoins[2] == "OR"
    and ui.settings.seqs[1].triggerJoins[3] == "OR", "moving trigger preserves its connector");
editor:InsertCell("F");
for _, cfg in ipairs(ui.settings.seqs) do
    check(not cfg.triggerJoins[1], "new rule never inherits a connector on its first trigger");
end
for joinBits = 0, 15 do
    for values = 0, 31 do
        local inputs = {};
        local groupTrue, expected = true, false;
        for index = 1, 5 do
            local satisfied = math.floor(values / 2 ^ (index - 1)) % 2 == 1;
            local isOr = index > 1 and math.floor(joinBits / 2 ^ (index - 2)) % 2 == 1;
            if (isOr) then
                expected = expected or groupTrue;
                groupTrue = true;
            end
            groupTrue = groupTrue and satisfied;
            inputs[index] = { name = tostring(index); join = isOr and "OR" or "AND" };
        end
        expected = expected or groupTrue;
        inputs.mode = "allConditions";
        local testState = {};
        logic.EvaluateConditions(testState, inputs, function(_, index)
            return math.floor(values / 2 ^ (index - 1)) % 2 == 1;
        end);
        check(testState.done == expected, "AND/OR truth table " .. joinBits .. "/" .. values);
    end
end
local unknownState = {};
logic.EvaluateConditions(unknownState, {
    { name = "Unknown" }, { name = "True"; join = "OR" }, mode = "allConditions"
}, function(_, index) return index == 2 and true or nil; end);
check(unknownState.done, "known true OR alternative works with an unknown condition");
local unknownAnd = {};
logic.EvaluateConditions(unknownAnd, {
    { name = "Unknown" }, { name = "True"; join = "AND" }, mode = "allConditions"
}, function(_, index) return index == 2 and true or nil; end);
check(not unknownAnd.done, "unknown AND condition does not satisfy a branch");

configure("allConditions", { health("self", 50), effect("#Poison") });
ui.settings.seqs[1].triggerJoins = { [2] = "OR" };
player.morale = 80;
effectValues[1] = { GetName = function() return "Poison"; end;
    GetCategory = function() return 2; end; GetIcon = function() return 20; end };
tick();
check(ui.recommendations[1], "user example: poisoned OR under 50 percent, poison only");
effectValues[1] = nil;
player.morale = 30;
tick();
check(ui.recommendations[1], "user example: poisoned OR under 50 percent, health only");
player.morale = 80;
tick();
check(not ui.recommendations[1], "user example: neither condition hides recommendation");

configure("allConditions", { health("self", 50), effect("#Poison") });
ui.settings.seqs[2] = {
    name = "Other branch"; groupId = ui.settings.seqs[1].groupId;
    skills = { effect("#Wound"), health("self", 20) }; stepCount = 2;
    triggerMode = "allConditions"; triggerJoins = { [2] = "OR" };
    finisher = { skillName = "Attack"; shortcutType = 1; data = "attack" };
};
ui.ResetProgress();
editor:EnsureGroups();
editor:SelectSlot(1, 2);
editor.triggerJoinButton:Click();
check(ui.settings.seqs[1].triggerJoins[2] == "OR"
    and ui.settings.seqs[2].triggerJoins[2] == "OR", "connector edit preserves other rule's joins");
editor:SelectSlot(2, 2);
editor.triggerJoinButton:Click();
check(ui.settings.seqs[1].triggerJoins[2] == "OR"
    and ui.settings.seqs[2].triggerJoins[2] == "AND", "connectors are individual to each trigger rule");
output = {};
command:Execute("cn", "verify");
check(not table.concat(output, "\n"):find("VERIFY FAIL", 1, true),
    "mixed connector rules pass configuration verification");
local classTriggers = ComboNextClassTriggers;
Turbine.Gameplay.Class = { Hunter = 1; Champion = 2; Beorning = 3; RuneKeeper = 4;
    Mariner = 5; Warden = 6; Brawler = 7; Guardian = 8; Minstrel = 9 };
Turbine.Gameplay.Attributes = {
    HunterStance = { Endurance = 1; Precision = 2; Strength = 3 };
    WardenStance = { Assailment = 1; Determination = 2 };
};
player.GetClass = function(self) return self.class; end;
player.GetClassAttributes = function(self) return self.attributes; end;
local attributes;
local function asClass(name, values)
    player.class = Turbine.Gameplay.Class[name];
    attributes = values or {};
    player.attributes = attributes;
    return attributes;
end
for _, case in ipairs({
    { "Hunter", "focus", "GetFocus", 9 },
    { "Champion", "fervour", "GetFervor", 5 },
    { "Beorning", "wrath", "GetWrath", 100 },
    { "Mariner", "balance", "GetBalance", 50 },
}) do
    asClass(case[1], { [case[3]] = function() return case[4]; end });
    local record = classTriggers.Record(case[2], "ge", case[4]);
    check(classTriggers.Evaluate(record, player, "en") == true, case[2] .. " direct resource");
    for _, comparison in ipairs({ "lt", "le", "eq", "ge", "gt" }) do
        record = classTriggers.Record(case[2], comparison, case[4]);
        local expected = comparison == "le" or comparison == "eq" or comparison == "ge";
        check(classTriggers.Evaluate(record, player, "en") == expected,
            case[2] .. " exact comparison boundary " .. comparison);
    end
    attributes[case[3]] = function() return nil; end;
    check(classTriggers.Evaluate(record, player, "en") == nil, case[2] .. " nil stays unknown");
    attributes[case[3]] = function() error("unreadable"); end;
    local value, reason = classTriggers.Evaluate(record, player, "en");
    check(value == nil and reason:find("unreadable", 1, true), case[2] .. " read error exposed");
end
for _, value in ipairs({ 1, 10, 19 }) do
    asClass("RuneKeeper", { GetAttunement = function() return value; end });
    check(classTriggers.Read(classTriggers.Record("battle", "ge", 0), player, "en")
        == math.max(0, 10 - value), "battle attunement mapping " .. value);
    check(classTriggers.Read(classTriggers.Record("healing", "ge", 0), player, "en")
        == math.max(0, value - 10), "healing attunement mapping " .. value);
end
for _, value in ipairs({ 0, 20, 9.5 }) do
    asClass("RuneKeeper", { GetAttunement = function() return value; end });
    for _, key in ipairs({ "battle", "healing" }) do
        check(classTriggers.Read(classTriggers.Record(key, "eq", 0), player, "en") == nil,
            "invalid raw attunement is not guessed neutral " .. key .. "/" .. value);
    end
end
for _, case in ipairs({ { "Beorning", "bear", "IsInBearForm" },
    { "RuneKeeper", "charged", "IsCharged" } }) do
    for _, active in ipairs({ false, true }) do
        asClass(case[1], { [case[3]] = function() return active; end });
        check(classTriggers.Evaluate(classTriggers.Record(case[2], "eq", 1), player, "en") == active,
            case[2] .. " boolean state " .. tostring(active));
        check(classTriggers.Evaluate(classTriggers.Record(case[2], "eq", 0), player, "en") == not active,
            case[2] .. " inverted state " .. tostring(active));
    end
end
asClass("Warden", { GetMaxGambitCount = function() return 5; end;
    GetGambit = function(_, slot) return slot <= 3 and slot or 0; end });
for slot = 1, 5 do
    local expected = slot <= 3 and slot or 0;
    check(classTriggers.Evaluate(classTriggers.Record("gambit" .. slot, "eq", expected),
        player, "en") == true, "gambit slot reader " .. slot);
end
attributes.GetGambit = function() return 4; end;
check(classTriggers.Evaluate(classTriggers.Record("gambit1", "eq", 0), player, "en") == nil,
    "unverified gambit builder is not empty");
attributes.GetMaxGambitCount = function() return 3; end;
check(classTriggers.Evaluate(classTriggers.Record("gambit5", "eq", 0), player, "en") == nil,
    "unavailable gambit slot is not empty");
for _, case in ipairs({ { "Hunter", "Precision", 2 }, { "Warden", "Assailment", 1 },
    { "Minstrel", "Dissonance", 1 } }) do
    asClass(case[1], { GetStance = function() return case[3]; end });
    local record = classTriggers.Record(case[1] .. "_" .. case[2], "eq", 1);
    check(classTriggers.Evaluate(record, player, "en") == nil, "unconfirmed stance unknown " .. case[1]);
    check(classTriggers.Evaluate(record, player, "en", { [attributes] = true }) == true,
        "confirmed stance " .. case[1]);
    attributes.GetStance = function() return 99; end;
    check(classTriggers.Evaluate(record, player, "en", { [attributes] = true }) == nil,
        "invalid stance unknown " .. case[1]);
end
for _, case in ipairs({
    { "Brawler", "mettle", "Battle Flow 9", 9, "en" },
    { "Brawler", "mettle", "Kampffluss (Stufe 3)", 3, "de" },
    { "Brawler", "mettle", "Flot de Bataille 5", 5, "fr" },
    { "Guardian", "fortification", "Improved Fortification V", 5, "en" },
    { "Warden", "technique", "Advanced Technique IV", 4, "en" },
}) do
    asClass(case[1]);
    effectValues[1] = wound(case[3]);
    local record = classTriggers.Record(case[2], "eq", case[4]);
    check(classTriggers.Evaluate(record, player, case[5]) == true, "effect resource " .. case[3]);
    effectValues[1] = nil;
    check(classTriggers.Read(record, player, case[5]) == 0, "absent supported effect is zero " .. case[3]);
    if (case[2] ~= "mettle") then
        check(classTriggers.Read(record, player, "de") == nil,
            "unverified localized effect is unknown, not zero " .. case[2]);
    end
end
asClass("Hunter", { GetFocus = function(self) return self.focus; end;
    focus = 0; GetStance = function(self) return self.stance; end; stance = 2 });
local focus = classTriggers.Record("focus", "ge", 3);
for _, invalid in ipairs({
    { classTrigger = "missing"; classCompare = "eq"; classValue = 1 },
    { classTrigger = "focus"; classCompare = "bad"; classValue = 1 },
    { classTrigger = "focus"; classCompare = "ge"; classValue = 10 },
    { classTrigger = "focus"; classCompare = "ge"; classValue = -1 },
    { classTrigger = "focus"; classCompare = "eq"; classValue = 1.5 },
    { classTrigger = "bear"; classCompare = "gt"; classValue = 1 },
    { classTrigger = "bear"; classCompare = "eq"; classValue = 2 },
}) do
    check(not classTriggers.Validate(invalid), "reject invalid class configuration");
end
local oldClass = player.class;
player.class = Turbine.Gameplay.Class.Champion;
check(classTriggers.Evaluate(focus, player, "en") == nil, "wrong class is unknown");
player.class = oldClass;
local readFocus = attributes.GetFocus;
attributes.GetFocus = nil;
check(classTriggers.Evaluate(focus, player, "en") == nil, "absent class resource API stays unknown");
attributes.GetFocus = readFocus;
configure("allConditions", { focus, health("self", 50) });
player.morale = 30;
attributes.focus = 0;
tick();
tick();
tick();
tick();
check(not ui.recommendations[1], "class condition AND health needs enough focus");
check(type(attributes.FocusChanged) == "function" and attributes.WrathChanged == nil,
    "only supported class-specific event listeners installed");
attributes.focus = 3;
attributes:FocusChanged();
check(ui.recommendations[1], "focus event immediately refreshes mixed live conditions");
attributes.focus = 2;
tick();
check(not ui.recommendations[1], "polling fallback notices class resource changes");
ui.settings.seqs[1].triggerJoins = { [2] = "OR" };
tick();
check(ui.recommendations[1], "class condition supports individual OR");

configure("ordered", { focus, focus });
attributes.focus = 0;
attributes:FocusChanged();
attributes.focus = 3;
attributes:FocusChanged();
check(ui.states[1].progress == 1 and not ui.recommendations[1], "one focus change advances one event step");
attributes:FocusChanged();
tick();
check(ui.states[1].progress == 1, "continuously true class predicate does not fire again");
attributes.GetFocus = nil;
tick();
check(ui.status:GetText():find("unavailable", 1, true), "event progress explains unavailable class APIs");
attributes.GetFocus = readFocus;
attributes:FocusChanged();
check(ui.states[1].progress == 1, "unavailable-then-readable does not invent a new resource crossing");
attributes.focus = 2;
attributes:FocusChanged();
attributes.focus = 3;
attributes:FocusChanged();
check(ui.recommendations[1], "false-to-true class comparison re-arms");
configure("any", { focus, classTriggers.Record("focus", "ge", 5) });
attributes.focus = 0;
attributes:FocusChanged();
attributes.focus = 9;
attributes:FocusChanged();
check(ui.states[1].progress == 1, "simultaneous class thresholds are one physical event");

configure("allConditions", { focus });
attributes.focus = 9;
tick();
check(ui.recommendations[1], "class-only live condition recommends");
chat("Heal");
tick();
check(not ui.recommendations[1], "class-only condition consumption waits for reset");
attributes.focus = 0;
attributes:FocusChanged();
attributes.focus = 5;
attributes:FocusChanged();
check(ui.recommendations[1], "class-only live condition re-arms after becoming false");

local stance = classTriggers.Record("Hunter_Precision", "eq", 1);
configure("allConditions", { stance });
tick();
check(not ui.recommendations[1], "stance starts unknown");
attributes:StanceChanged();
check(ui.recommendations[1], "explicit stance event confirms reading");
for _ = 1, 5 do tick(); end
check(ui.recommendations[1], "unchanged trained skill list does not invalidate confirmed stance");
Turbine.Chat:Received({ ChatType = 1;
    Message = "You have acquired the Class Specialization Bonus Trait test." });
tick();
check(not ui.recommendations[1], "trait change invalidates unreliable stance");
attributes:StanceChanged();
check(ui.recommendations[1], "stance can be confirmed again after trait change");

configure("allConditions", { focus });
editor:EnsureGroups();
editor:SelectSlot(1, 1);
check(editor.classValueSave:IsVisible(), "class configuration row visible for class triggers");
editor.classCompareButton:Click();
editor.classValueText:SetText("6");
editor.classValueSave:Click();
check(ui.settings.seqs[1].skills[1].classValue == 6
    and ui.settings.seqs[1].skills[1].classCompare == "gt", "editor saves comparison and value");
check(focus.classValue == 3 and focus.classCompare == "ge", "class editing does not mutate catalog prototypes");
editor.classValueText:SetText("10");
editor.classValueSave:Click();
check(ui.settings.seqs[1].skills[1].classValue == 6, "invalid editor value preserves saved condition");
editor:SelectSlot(1, editor.finisherSlot);
local finisherBefore = ui.settings.seqs[1].finisher;
editor:Assign(focus);
check(ui.settings.seqs[1].finisher == finisherBefore, "class trigger cannot be assigned as a finisher");
editor:SelectSlot(1, 1);
editor:SwitchRole("F");
check(ui.settings.seqs[1].skills[1].classTrigger == "focus", "class trigger cannot be converted to finisher");
for _, className in ipairs({ "Hunter", "Champion", "Beorning", "RuneKeeper", "Mariner",
    "Brawler", "Guardian", "Warden", "Minstrel" }) do
    local catalog = editor.getSkills(className, "");
    check(catalog[1].classTrigger ~= nil, "class conditions live within " .. className .. " catalog");
    for _, record in ipairs(classTriggers.Catalog(className)) do
        check(classTriggers.Validate(record), "catalog class condition valid");
        configure("allConditions", { record });
        editor:EnsureGroups();
        share:Export(false);
        check(share.box:GetText():sub(1, 4) == "CN4!", "class record uses CN4 sharing");
        share:Import(true);
        local imported = ui.settings.seqs[1].skills[1];
        check(imported.classTrigger == record.classTrigger and imported.classCompare == record.classCompare
            and imported.classValue == record.classValue, "class condition share round trip");
    end
end
for _, record in ipairs(editor.getSkills(ComboNextConstants.effectsClass, "")) do
    check(not record.classTrigger, "class conditions are not under Effects");
end
check(#classTriggers.Catalog("Burglar") == 0 and #classTriggers.Catalog("Captain") == 0
    and #classTriggers.Catalog("LoreMaster") == 0, "no invented class resources");
check(editor.getSkills("Hunter", "focus")[1].classTrigger == "focus", "class condition catalog searchable");
for _, token in ipairs({ "C:focus:ge:10", "C:focus:bad:3", "C:missing:eq:1",
    "C:focus:ge:1.5", "C:bear:eq:2", "C:focus:ge:3:extra" }) do
    local previous = ui.settings.seqs;
    share.box:SetText("CN4!Bad|2:allConditions:A|C:focus:ge:1," .. token .. "|S:heal:Heal");
    share:Import(true);
    check(ui.settings.seqs == previous, "invalid shared class condition rejected atomically " .. token);
end
for _, header in ipairs({ "CN1", "CN2", "CN3" }) do
    local metadata = header == "CN1" and "1" or header == "CN2" and "1:ordered" or "1:ordered:";
    local previous = ui.settings.seqs;
    share.box:SetText(header .. "!Bad|" .. metadata .. "|C:focus:ge:3|I:potion:Health%20Potion");
    share:Import(true);
    check(ui.settings.seqs == previous, "legacy format cannot smuggle new class record " .. header);
end
local previous = ui.settings.seqs;
share.box:SetText("CN4!Bad|1:ordered:|C:focus:ge:3|C:focus:ge:3");
share:Import(true);
check(ui.settings.seqs == previous, "import rejects class trigger as finisher");
share.box:SetText("CN3!Legacy|1:ordered:|E:SG:%23Poison:|I:potion:Health%20Potion");
share:Import(true);
check(ui.settings.seqs[1].skills[1].effectName == "#Poison", "CN3 remains importable");
configure("allConditions", { focus });
output = {};
command:Execute("cn", "verify catalog");
log = table.concat(output, "\n");
check(not log:find("VERIFY FAIL", 1, true), "class configuration and catalog verification: " .. log);
player.class = Turbine.Gameplay.Class.Champion;
output = {};
command:Execute("cn", "verify");
check(table.concat(output, "\n"):find("VERIFY NOT CHECKED: class trigger API coverage", 1, true),
    "wrong-class resource verification honestly reports NOT CHECKED");
local oldAttributes = attributes;
asClass("Hunter", { focus = 0; GetFocus = readFocus });
configure("ordered", { focus });
for _ = 1, 4 do tick(); end
oldAttributes.focus = 9;
oldAttributes:FocusChanged();
check(not ui.recommendations[1], "stale attribute callbacks cannot fire class triggers");
attributes.focus = 3;
attributes:FocusChanged();
check(ui.recommendations[1], "replacement class attributes receive listeners");

asClass("Brawler");
configure("ordered", { effect("Battle Flow 3"), classTriggers.Record("mettle", "ge", 3) });
effectValues[1] = nil;
tick();
effectValues[1] = wound("Battle Flow 3");
effects:EffectAdded({ Index = 1 });
check(ui.states[1].progress == 1 and not ui.recommendations[1],
    "one effect cannot advance both its exact-effect and class-stack steps");
configure("allConditions", { classTriggers.Record("mettle", "ge", 3) });
tick();
check(ui.recommendations[1], "effect-derived class condition reads current stacks");
local removedEffect = effectValues[1];
effectValues[1] = nil;
effects:EffectRemoved({ Effect = removedEffect });
check(not ui.recommendations[1], "effect removal immediately refreshes class conditions");
effectValues[1] = wound("Battle Flow 100");
check(classTriggers.Read(classTriggers.Record("mettle", "ge", 1), player, "en") == nil,
    "unsupported effect stack count is unknown");
effectValues[1] = nil;

configure("ordered", { { skillName = "Invalid"; classTrigger = "missing" } });
ui.settings.alwaysFirstFinisher = true;
tick();
check(not ui.recommendations[1], "invalid class trigger cannot become a starter recommendation");
ui.settings.alwaysFirstFinisher = false;
print(tostring(count) .. " ComboNext assertions passed.");

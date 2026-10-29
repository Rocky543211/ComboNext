import "Turbine";
import "Turbine.UI";
import "Turbine.UI.Lotro";
import "ComboNext.Constants";
import "ComboNext.Localization";
import "ComboNext.Theme";

local L = ComboNextL;

ComboNextOptionsPanel = class(Turbine.UI.Control);

function ComboNextOptionsPanel:Constructor(settings, saveSettings, refresh, applyScale, applyTheme)
    Turbine.UI.Control.Constructor(self);
    self.settings = settings;
    self.saveSettings = saveSettings;
    self.refresh = refresh;
    self.applyScale = applyScale;
    self.applyTheme = applyTheme;
    self:SetSize(390, 462);

    local function AddLabel(text, x, y, w, h, color)
        local label = Turbine.UI.Label();
        label:SetParent(self);
        label:SetPosition(x, y);
        label:SetSize(w, h);
        label:SetText(text);
        label:SetMultiline(true);
        label:SetForeColor(color or Turbine.UI.Color(0.9, 0.9, 0.9));
        label:SetTextAlignment(Turbine.UI.ContentAlignment.MiddleLeft);
        return label;
    end

    local function AddButton(text, x, y, w, callback)
        local button = ComboNextTheme.Button();
        button:SetParent(self);
        button:SetPosition(x, y);
        button:SetSize(w, 24);
        button:SetText(text);
        button.Click = callback;
        return button;
    end

    AddLabel(L("options.title"), 12, 8, 300, 26, Turbine.UI.Color(1, 0.9, 0.5));
    AddLabel(L("options.description", ComboNextConstants.recommendationSeconds),
        12, 34, 366, 36);

    AddLabel(L("options.resetAfter"), 12, 78, 235, 24);
    self.timeoutValue = AddLabel("", 306, 78, 42, 24, Turbine.UI.Color(1, 1, 0.45));
    self.timeoutValue:SetTextAlignment(Turbine.UI.ContentAlignment.MiddleCenter);
    self.timeoutValue:SetBackColor(Turbine.UI.Color(0.9, 0.08, 0.08, 0.08));
    self.timeoutValue:SetZOrder(10);
    AddLabel(L("options.sec"), 350, 78, 34, 24);
    AddButton("-", 246, 78, 24, function()
        self:ChangeTimeout(-1);
    end);
    AddButton("+", 274, 78, 24, function()
        self:ChangeTimeout(1);
    end);

    self.opacityButton = AddButton("", 12, 112, 180, function()
        self:ChangeOpacity();
    end);
    self.finisherSlotsLabel = AddLabel("", 198, 112, 124, 24);
    self.finisherSlotsLabel:SetFont(Turbine.UI.Lotro.Font.Verdana10);
    self.fewerSlotsButton = AddButton("-", 326, 112, 24, function()
        self:ChangeFinisherSlots(-1);
    end);
    self.moreSlotsButton = AddButton("+", 354, 112, 24, function()
        self:ChangeFinisherSlots(1);
    end);
    self.scaleButton = AddButton("", 12, 144, 366, function()
        self:ChangeScale();
    end);
    self.starterButton = AddButton("", 12, 176, 366, function()
        self.settings.alwaysFirstFinisher = not self.settings.alwaysFirstFinisher;
        self:RefreshValues();
        self.saveSettings();
        self.refresh();
    end);
    self.combatButton = AddButton("", 12, 208, 366, function()
        self.settings.showInCombat = not self.settings.showInCombat;
        self:RefreshValues();
        self.saveSettings();
    end);
    self.readyButton = AddButton("", 12, 240, 366, function()
        self.settings.readyOnly = not self.settings.readyOnly;
        self:RefreshValues();
        self.saveSettings();
        self.refresh();
    end);
    self.styleButton = AddButton("", 12, 276, 366, function()
        self.settings.uiStyle = self.settings.uiStyle == "classic" and "custom" or "classic";
        self:ApplyAppearance();
    end);
    self.appearanceButton = AddButton("", 12, 308, 366, function()
        local menu = Turbine.UI.ContextMenu();
        for _, mode in ipairs(ComboNextTheme.modes) do
            local chosen = mode;
            local item = Turbine.UI.MenuItem(L("theme.mode." .. chosen));
            item.Click = function()
                self.settings.appearanceMode = chosen;
                self:ApplyAppearance();
            end;
            menu:GetItems():Add(item);
        end
        menu:ShowMenu();
    end);
    local function ProfileMenu(kind, values)
        local menu = Turbine.UI.ContextMenu();
        local choices = { "automatic" };
        for _, value in ipairs(values) do choices[#choices + 1] = value; end
        for _, value in ipairs(choices) do
            local chosen = value;
            local item = Turbine.UI.MenuItem(L("theme.name." .. chosen));
            item.Click = function()
                self.settings[kind] = chosen;
                self:ApplyAppearance();
            end;
            menu:GetItems():Add(item);
        end
        menu:ShowMenu();
    end
    self.raceButton = AddButton("", 12, 340, 366, function()
        ProfileMenu("appearanceRace", ComboNextTheme.races);
    end);
    self.classThemeButton = AddButton("", 12, 372, 366, function()
        ProfileMenu("appearanceClass", ComboNextTheme.classes);
    end);
    self.appearanceStatus = AddLabel("", 12, 404, 366, 38);
    self.appearanceStatus:SetFont(Turbine.UI.Lotro.Font.Verdana10);
    AddLabel(L("options.scaleHint"), 12, 444, 366, 18);

    self:RefreshValues();
end

function ComboNextOptionsPanel:ApplyAppearance()
    if (self.applyTheme) then self.applyTheme(); end
    self:RefreshValues();
    self.saveSettings();
    self.refresh();
end

function ComboNextOptionsPanel:ChangeFinisherSlots(direction)
    local current = self.settings.finisherSlots or 1;
    local slots = math.max(1, math.min(ComboNextConstants.maxVisibleFinishers, current + direction));
    if (slots == current) then return; end
    self.settings.finisherSlots = slots;
    self.settings.showAllFinishers = slots > 1;
    self:RefreshValues();
    self.saveSettings();
    self.refresh();
end

function ComboNextOptionsPanel:ChangeTimeout(direction)
    local values = ComboNextConstants.resetOptions;
    local current = self.settings.resetSeconds or 10;
    local index = 1;
    for i = 1, #values do
        if (values[i] == current) then
            index = i;
            break;
        end
    end
    index = ((index - 1 + direction) % #values) + 1;
    self.settings.resetSeconds = values[index];
    self:RefreshValues();
    self.saveSettings();
    self.refresh();
end

function ComboNextOptionsPanel:ChangeOpacity()
    local values = { 1, 0.85, 0.7, 0.55 };
    local index = 1;
    for i = 1, #values do
        if (math.abs(values[i] - self.settings.opacity) < 0.01) then
            index = i;
            break;
        end
    end
    index = (index % #values) + 1;
    self.settings.opacity = values[index];
    ComboNext.win:SetOpacity(self.settings.opacity);
    self:RefreshValues();
    self.saveSettings();
    self.refresh();
end

function ComboNextOptionsPanel:ChangeScale()
    local values = ComboNextConstants.uiScales;
    local index = 1;
    for i = 1, #values do
        if (math.abs(values[i] - (self.settings.uiScale or 1)) < 0.01) then
            index = i;
            break;
        end
    end
    index = (index % #values) + 1;
    self.settings.uiScale = values[index];
    if (self.applyScale) then
        self.applyScale();
    end
    self:RefreshValues();
    self.saveSettings();
    self.refresh();
end

function ComboNextOptionsPanel:RefreshValues()
    self.timeoutValue:SetText(tostring(self.settings.resetSeconds or 10));
    self.opacityButton:SetText(L("options.opacity",
        math.floor((self.settings.opacity or 1) * 100)));
    local slots = self.settings.finisherSlots or 1;
    self.finisherSlotsLabel:SetText(L("options.finisherSlots", slots));
    self.fewerSlotsButton:SetEnabled(slots > 1);
    self.moreSlotsButton:SetEnabled(slots < ComboNextConstants.maxVisibleFinishers);
    self.combatButton:SetText(L(self.settings.showInCombat
        and "options.combatOn" or "options.combatOff"));
    self.starterButton:SetText(L(self.settings.alwaysFirstFinisher
        and "options.starterOn" or "options.starterOff"));
    self.scaleButton:SetText(L("options.scale", math.floor((self.settings.uiScale or 1) * 100)));
    self.readyButton:SetText(L(self.settings.readyOnly and "options.readyOnly"
        or "options.showCooldowns"));
    local profile = ComboNextTheme.Profile();
    local mode = profile.mode or "automatic";
    self.styleButton:SetText(L("theme.style", L(self.settings.uiStyle == "classic"
        and "theme.classic" or "theme.custom")));
    self.appearanceButton:SetText(L("theme.mode", L("theme.mode." .. mode)));
    self.raceButton:SetText(L("theme.race", L("theme.name." .. (self.settings.appearanceRace or "automatic"))));
    self.classThemeButton:SetText(L("theme.class", L("theme.name." .. (self.settings.appearanceClass or "automatic"))));
    local custom = self.settings.uiStyle ~= "classic";
    self.appearanceButton:SetEnabled(custom);
    self.raceButton:SetEnabled(custom and (mode == "race" or mode == "raceClass"));
    self.classThemeButton:SetEnabled(custom and (mode == "class" or mode == "raceClass"));
    self.appearanceStatus:SetText(custom and (profile.warning or L("theme.resolved",
        L("theme.name." .. profile.race),
        profile.class and L("theme.name." .. profile.class) or L("theme.noBadge")))
        or L("theme.classicHint"));
end

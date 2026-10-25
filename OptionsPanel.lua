import "Turbine";
import "Turbine.UI";
import "Turbine.UI.Lotro";
import "ComboNext.Constants";
import "ComboNext.Localization";

local L = ComboNextL;

ComboNextOptionsPanel = class(Turbine.UI.Control);

function ComboNextOptionsPanel:Constructor(settings, saveSettings, refresh, applyScale, applyTheme)
    Turbine.UI.Control.Constructor(self);
    self.settings = settings;
    self.saveSettings = saveSettings;
    self.refresh = refresh;
    self.applyScale = applyScale;
    self.applyTheme = applyTheme;
    self:SetSize(390, 266);

    local function AddLabel(text, x, y, w, h, color)
        local label = Turbine.UI.Label();
        label:SetParent(self);
        label:SetPosition(x, y);
        label:SetSize(w, h);
        label:SetText(text);
        label:SetForeColor(color or Turbine.UI.Color(0.9, 0.9, 0.9));
        label:SetTextAlignment(Turbine.UI.ContentAlignment.MiddleLeft);
        return label;
    end

    local function AddButton(text, x, y, w, callback)
        local button = Turbine.UI.Lotro.Button();
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
    self.finisherModeButton = AddButton("", 198, 112, 180, function()
        local maxSlots = ComboNextConstants.maxVisibleFinishers;
        self.settings.finisherSlots = ((self.settings.finisherSlots or 1) % maxSlots) + 1;
        self.settings.showAllFinishers = self.settings.finisherSlots > 1;
        self:RefreshValues();
        self.saveSettings();
        self.refresh();
    end);
    self.scaleButton = AddButton("", 12, 144, 180, function()
        self:ChangeScale();
    end);
    self.themeButton = AddButton("", 198, 144, 180, function()
        self:ChangeTheme();
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
    AddLabel(L("options.scaleHint"), 12, 240, 366, 18);

    self:RefreshValues();
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

function ComboNextOptionsPanel:ChangeTheme()
    local values = ComboNextConstants.uiThemes;
    local index = 1;
    for i = 1, #values do
        if (values[i] == self.settings.uiTheme) then
            index = i;
            break;
        end
    end
    index = (index % #values) + 1;
    self.settings.uiTheme = values[index];
    if (self.applyTheme) then
        self.applyTheme();
    end
    self:RefreshValues();
    self.saveSettings();
    self.refresh();
end

function ComboNextOptionsPanel:RefreshValues()
    self.timeoutValue:SetText(tostring(self.settings.resetSeconds or 10));
    self.opacityButton:SetText(L("options.opacity",
        math.floor((self.settings.opacity or 1) * 100)));
    self.finisherModeButton:SetText(L("options.finisherSlots", self.settings.finisherSlots or 1));
    self.combatButton:SetText(L(self.settings.showInCombat
        and "options.combatOn" or "options.combatOff"));
    self.starterButton:SetText(L(self.settings.alwaysFirstFinisher
        and "options.starterOn" or "options.starterOff"));
    self.scaleButton:SetText(L("options.scale", math.floor((self.settings.uiScale or 1) * 100)));
    self.themeButton:SetText(L("options.theme", L("options.theme." .. (self.settings.uiTheme or "gold"))));
end

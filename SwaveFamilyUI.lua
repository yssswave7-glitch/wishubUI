local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local TextService = game:GetService("TextService")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer

local Library = {
    Version = "2.0.0",
    Brand = "SwaveFamilyHub",
    Windows = {},
}

local DEFAULT_THEME = {
    Background = Color3.fromRGB(9, 10, 14),
    Sidebar = Color3.fromRGB(12, 13, 18),
    Surface = Color3.fromRGB(16, 18, 24),
    Surface2 = Color3.fromRGB(20, 22, 29),
    Surface3 = Color3.fromRGB(25, 27, 35),
    Border = Color3.fromRGB(39, 42, 54),
    BorderSoft = Color3.fromRGB(31, 34, 44),
    Text = Color3.fromRGB(242, 243, 247),
    TextSoft = Color3.fromRGB(177, 181, 194),
    TextMuted = Color3.fromRGB(119, 124, 140),
    Accent = Color3.fromRGB(125, 91, 255),
    AccentSoft = Color3.fromRGB(96, 72, 194),
    Success = Color3.fromRGB(79, 205, 138),
    Warning = Color3.fromRGB(241, 185, 73),
    Danger = Color3.fromRGB(241, 91, 105),
    Shadow = Color3.fromRGB(0, 0, 0),
}

local function cloneTable(source)
    local out = {}
    for key, value in pairs(source) do
        out[key] = value
    end
    return out
end

local function mergeTheme(overrides)
    local theme = cloneTable(DEFAULT_THEME)
    if type(overrides) == "table" then
        for key, value in pairs(overrides) do
            if theme[key] ~= nil and typeof(value) == "Color3" then
                theme[key] = value
            end
        end
    end
    return theme
end

local function safeCallback(callback, ...)
    if type(callback) ~= "function" then
        return
    end
    local ok, err = pcall(callback, ...)
    if not ok then
        warn("[SwaveFamilyUI] callback error:", err)
    end
end

local function make(className, properties, parent)
    local object = Instance.new(className)
    if properties then
        for key, value in pairs(properties) do
            object[key] = value
        end
    end
    if parent then
        object.Parent = parent
    end
    return object
end

local function addCorner(parent, radius)
    return make("UICorner", { CornerRadius = UDim.new(0, radius or 8) }, parent)
end

local function addStroke(parent, color, transparency, thickness)
    return make("UIStroke", {
        Color = color,
        Transparency = transparency or 0,
        Thickness = thickness or 1,
    }, parent)
end

local function addPadding(parent, left, right, top, bottom)
    return make("UIPadding", {
        PaddingLeft = UDim.new(0, left or 0),
        PaddingRight = UDim.new(0, right or 0),
        PaddingTop = UDim.new(0, top or 0),
        PaddingBottom = UDim.new(0, bottom or 0),
    }, parent)
end

local function tween(instance, duration, properties, style, direction)
    local info = TweenInfo.new(
        duration or 0.16,
        style or Enum.EasingStyle.Quint,
        direction or Enum.EasingDirection.Out
    )
    local animation = TweenService:Create(instance, info, properties)
    animation:Play()
    return animation
end

local function normalizeAsset(asset)
    if asset == nil then
        return ""
    end
    if type(asset) == "number" then
        return "rbxassetid://" .. tostring(asset)
    end
    return tostring(asset)
end

local function normalizeSingle(value)
    if type(value) == "table" then
        return value[1]
    end
    return value
end

local function arrayCopy(value)
    local out = {}
    if type(value) == "table" then
        for _, item in ipairs(value) do
            table.insert(out, item)
        end
    elseif value ~= nil then
        table.insert(out, value)
    end
    return out
end

local function slug(value)
    local s = tostring(value or "config")
    s = s:gsub("[^%w%-%_ ]", "")
    s = s:gsub("%s+", "_")
    if s == "" then
        s = "config"
    end
    return s:sub(1, 48)
end

local function resolveParent()
    local candidates = {}

    pcall(function()
        if type(gethui) == "function" then
            table.insert(candidates, gethui())
        end
    end)

    table.insert(candidates, CoreGui)

    pcall(function()
        if LocalPlayer then
            table.insert(candidates, LocalPlayer:WaitForChild("PlayerGui", 2))
        end
    end)

    for _, parent in ipairs(candidates) do
        if parent then
            local probe
            local ok = pcall(function()
                probe = Instance.new("ScreenGui")
                probe.Name = "__SFH_UI_PROBE"
                probe.ResetOnSpawn = false
                probe.Parent = parent
            end)
            if probe then
                pcall(function()
                    probe:Destroy()
                end)
            end
            if ok then
                return parent
            end
        end
    end

    return LocalPlayer and LocalPlayer:FindFirstChildOfClass("PlayerGui") or CoreGui
end

local function bindDrag(handle, target)
    local dragging = false
    local dragStart
    local startPosition
    local activeInput

    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPosition = target.Position
            activeInput = input
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if not dragging then
            return
        end
        if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end
        local delta = input.Position - dragStart
        target.Position = UDim2.new(
            startPosition.X.Scale,
            startPosition.X.Offset + delta.X,
            startPosition.Y.Scale,
            startPosition.Y.Offset + delta.Y
        )
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input == activeInput or input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
            activeInput = nil
        end
    end)
end

local function createText(parent, text, size, color, font, alignment)
    return make("TextLabel", {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Text = tostring(text or ""),
        TextColor3 = color,
        TextSize = size or 13,
        Font = font or Enum.Font.Gotham,
        TextXAlignment = alignment or Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
    }, parent)
end

local function createButtonBase(parent, theme)
    local button = make("TextButton", {
        AutoButtonColor = false,
        BackgroundColor3 = theme.Surface3,
        BorderSizePixel = 0,
        Text = "",
    }, parent)
    addCorner(button, 7)
    addStroke(button, theme.Border, 0, 1)
    return button
end

local Window = {}
Window.__index = Window

local Tab = {}
Tab.__index = Tab

local Section = {}
Section.__index = Section

local function makeFlag(window, tabName, sectionName, title, explicitFlag)
    local base = explicitFlag and tostring(explicitFlag) or (tostring(tabName) .. "." .. tostring(sectionName) .. "." .. tostring(title))
    base = base:gsub("%s+", "_")
    if not window._configControls[base] then
        return base
    end
    local index = 2
    while window._configControls[base .. "_" .. index] do
        index += 1
    end
    return base .. "_" .. index
end

function Window:_registerConfigControl(control, options, tabName, sectionName, title)
    if options and options.NoConfig then
        return
    end
    if type(control.Get) ~= "function" or type(control.Set) ~= "function" then
        return
    end

    local flag = makeFlag(self, tabName, sectionName, title, options and options.Flag)
    control.Flag = flag
    self._configControls[flag] = control
end

function Window:_configAvailable()
    return type(writefile) == "function"
        and type(readfile) == "function"
        and type(isfile) == "function"
end

function Window:_ensureConfigFolder()
    if type(makefolder) ~= "function" or type(isfolder) ~= "function" then
        return
    end
    pcall(function()
        if not isfolder("SwaveFamilyHub") then
            makefolder("SwaveFamilyHub")
        end
        if not isfolder("SwaveFamilyHub/configs") then
            makefolder("SwaveFamilyHub/configs")
        end
    end)
end

function Window:_listConfigs()
    local out = {}
    if type(listfiles) ~= "function" then
        return out
    end
    self:_ensureConfigFolder()
    local ok, files = pcall(listfiles, "SwaveFamilyHub/configs")
    if not ok or type(files) ~= "table" then
        return out
    end
    for _, path in ipairs(files) do
        local name = tostring(path):match("([^/\\]+)%.json$")
        if name then
            table.insert(out, name)
        end
    end
    table.sort(out)
    return out
end

function Window:_saveConfig(name)
    if not self:_configAvailable() then
        return false, "Filesystem API is unavailable"
    end
    self:_ensureConfigFolder()
    name = slug(name)
    local values = {}
    for flag, control in pairs(self._configControls) do
        local ok, value = pcall(control.Get, control)
        if ok then
            values[flag] = value
        end
    end
    local payload = {
        version = 2,
        brand = "SwaveFamilyHub",
        values = values,
    }
    local ok, encoded = pcall(HttpService.JSONEncode, HttpService, payload)
    if not ok then
        return false, encoded
    end
    local success, err = pcall(writefile, "SwaveFamilyHub/configs/" .. name .. ".json", encoded)
    return success, err
end

function Window:_loadConfig(name)
    if not self:_configAvailable() then
        return false, "Filesystem API is unavailable"
    end
    name = slug(name)
    local path = "SwaveFamilyHub/configs/" .. name .. ".json"
    local exists = false
    pcall(function()
        exists = isfile(path)
    end)
    if not exists then
        return false, "Config not found"
    end
    local okRead, raw = pcall(readfile, path)
    if not okRead then
        return false, raw
    end
    local okDecode, payload = pcall(HttpService.JSONDecode, HttpService, raw)
    if not okDecode or type(payload) ~= "table" then
        return false, payload
    end
    local values = payload.values or payload
    for flag, value in pairs(values) do
        local control = self._configControls[flag]
        if control then
            pcall(control.Set, control, value)
        end
    end
    return true
end

function Window:_deleteConfig(name)
    if type(delfile) ~= "function" or type(isfile) ~= "function" then
        return false, "Delete API is unavailable"
    end
    name = slug(name)
    local path = "SwaveFamilyHub/configs/" .. name .. ".json"
    local exists = false
    pcall(function()
        exists = isfile(path)
    end)
    if not exists then
        return false, "Config not found"
    end
    local ok, err = pcall(delfile, path)
    return ok, err
end

function Window:_setAutoLoad(name)
    if not self:_configAvailable() then
        return false, "Filesystem API is unavailable"
    end
    self:_ensureConfigFolder()
    name = slug(name)
    local ok, err = pcall(writefile, "SwaveFamilyHub/autoload.txt", name)
    return ok, err
end

function Window:_autoLoad()
    if not self:_configAvailable() then
        return
    end
    local path = "SwaveFamilyHub/autoload.txt"
    local exists = false
    pcall(function()
        exists = isfile(path)
    end)
    if not exists then
        return
    end
    local ok, name = pcall(readfile, path)
    if ok and type(name) == "string" and name ~= "" then
        self:_loadConfig(name)
    end
end

function Window:_showToast(options)
    options = type(options) == "table" and options or { Description = tostring(options) }
    local title = tostring(options.Title or "SwaveFamilyHub")
    local description = tostring(options.Description or options.Content or "")
    local lifetime = tonumber(options.Time or options.Duration) or 4

    local toast = make("Frame", {
        BackgroundColor3 = self.Theme.Surface2,
        BorderSizePixel = 0,
        Size = UDim2.fromOffset(330, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
    }, self.ToastContainer)
    addCorner(toast, 9)
    addStroke(toast, self.Theme.Border, 0, 1)
    addPadding(toast, 14, 14, 12, 11)

    local layout = make("UIListLayout", {
        Padding = UDim.new(0, 5),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, toast)

    local titleLabel = createText(toast, title, 13, self.Theme.Text, Enum.Font.GothamSemibold)
    titleLabel.Size = UDim2.new(1, 0, 0, 18)
    titleLabel.LayoutOrder = 1

    local descLabel = createText(toast, description, 12, self.Theme.TextSoft, Enum.Font.Gotham)
    descLabel.Size = UDim2.new(1, 0, 0, 0)
    descLabel.AutomaticSize = Enum.AutomaticSize.Y
    descLabel.TextWrapped = true
    descLabel.TextYAlignment = Enum.TextYAlignment.Top
    descLabel.LayoutOrder = 2

    local bar = make("Frame", {
        BackgroundColor3 = self.Theme.BorderSoft,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 2),
        LayoutOrder = 3,
    }, toast)
    addCorner(bar, 2)
    local fill = make("Frame", {
        BackgroundColor3 = self.Theme.Accent,
        BorderSizePixel = 0,
        Size = UDim2.fromScale(1, 1),
    }, bar)
    addCorner(fill, 2)

    toast.BackgroundTransparency = 1
    titleLabel.TextTransparency = 1
    descLabel.TextTransparency = 1
    bar.BackgroundTransparency = 1
    fill.BackgroundTransparency = 1
    tween(toast, 0.18, { BackgroundTransparency = 0 })
    tween(titleLabel, 0.18, { TextTransparency = 0 })
    tween(descLabel, 0.18, { TextTransparency = 0 })
    tween(bar, 0.18, { BackgroundTransparency = 0 })
    tween(fill, 0.18, { BackgroundTransparency = 0 })

    task.defer(function()
        task.wait()
        tween(fill, lifetime, { Size = UDim2.new(0, 0, 1, 0) }, Enum.EasingStyle.Linear)
        task.wait(lifetime)
        if not toast.Parent then
            return
        end
        tween(toast, 0.18, { BackgroundTransparency = 1 })
        tween(titleLabel, 0.18, { TextTransparency = 1 })
        tween(descLabel, 0.18, { TextTransparency = 1 })
        task.wait(0.2)
        pcall(function()
            toast:Destroy()
        end)
    end)
end

function Window:SetVisible(visible)
    self.Visible = visible and true or false
    if self.Gui then
        self.Gui.Enabled = self.Visible
    end
end

function Window:Toggle()
    self:SetVisible(not self.Visible)
end

function Window:Destroy()
    if self._keybindConnection then
        self._keybindConnection:Disconnect()
        self._keybindConnection = nil
    end
    if self.Gui then
        self.Gui:Destroy()
    end
    self.Gui = nil
end

function Window:_selectTab(tab)
    if self.ActiveTab == tab then
        return
    end

    if self.ActiveTab then
        self.ActiveTab.Page.Visible = false
        tween(self.ActiveTab.NavButton, 0.15, { BackgroundTransparency = 1 })
        self.ActiveTab.NavLabel.TextColor3 = self.Theme.TextMuted
        if self.ActiveTab.NavIcon then
            self.ActiveTab.NavIcon.ImageColor3 = self.Theme.TextMuted
        end
        self.ActiveTab.NavAccent.Visible = false
    end

    self.ActiveTab = tab
    tab.Page.Visible = true
    tween(tab.NavButton, 0.15, { BackgroundTransparency = 0 })
    tab.NavLabel.TextColor3 = self.Theme.Text
    if tab.NavIcon then
        tab.NavIcon.ImageColor3 = self.Theme.Text
    end
    tab.NavAccent.Visible = true
    self.PageTitle.Text = tab.Name
    self.SearchBox.Text = ""
    tab:ApplySearch("")
end

function Window:CreateTab(options)
    if type(options) == "string" then
        options = { Name = options }
    end
    options = options or {}

    local tab = setmetatable({}, Tab)
    tab.Window = self
    tab.Name = tostring(options.Name or "Tab")
    tab.Sections = {}
    tab.Controls = {}

    local navButton = make("TextButton", {
        AutoButtonColor = false,
        BackgroundColor3 = self.Theme.Surface2,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 38),
        Text = "",
        LayoutOrder = #self.Tabs + 1,
    }, self.NavList)
    addCorner(navButton, 7)
    tab.NavButton = navButton

    local accent = make("Frame", {
        BackgroundColor3 = self.Theme.Accent,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(0, 8),
        Size = UDim2.fromOffset(2, 22),
        Visible = false,
    }, navButton)
    addCorner(accent, 2)
    tab.NavAccent = accent

    local iconAsset = normalizeAsset(options.Icon)
    local left = 12
    if iconAsset ~= "" then
        local icon = make("ImageLabel", {
            BackgroundTransparency = 1,
            Image = iconAsset,
            ImageColor3 = self.Theme.TextMuted,
            Position = UDim2.fromOffset(12, 10),
            Size = UDim2.fromOffset(18, 18),
            ScaleType = Enum.ScaleType.Fit,
        }, navButton)
        tab.NavIcon = icon
        left = 40
    end

    local navLabel = createText(navButton, tab.Name, 12, self.Theme.TextMuted, Enum.Font.GothamMedium)
    navLabel.Position = UDim2.fromOffset(left, 0)
    navLabel.Size = UDim2.new(1, -(left + 8), 1, 0)
    tab.NavLabel = navLabel

    local page = make("ScrollingFrame", {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Position = UDim2.fromScale(0, 0),
        Size = UDim2.fromScale(1, 1),
        CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollBarThickness = 2,
        ScrollBarImageColor3 = self.Theme.Border,
        ScrollBarImageTransparency = 0.25,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        Visible = false,
    }, self.PageContainer)
    addPadding(page, 0, 6, 2, 12)
    make("UIListLayout", {
        Padding = UDim.new(0, 10),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, page)
    tab.Page = page

    navButton.MouseEnter:Connect(function()
        if self.ActiveTab ~= tab then
            tween(navButton, 0.12, { BackgroundTransparency = 0.55 })
        end
    end)
    navButton.MouseLeave:Connect(function()
        if self.ActiveTab ~= tab then
            tween(navButton, 0.12, { BackgroundTransparency = 1 })
        end
    end)
    navButton.MouseButton1Click:Connect(function()
        self:_selectTab(tab)
    end)

    table.insert(self.Tabs, tab)
    if not self.ActiveTab then
        self:_selectTab(tab)
    end
    return tab
end

function Tab:ApplySearch(query)
    query = tostring(query or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    for _, section in ipairs(self.Sections) do
        section:_applySearch(query)
    end
end

function Tab:AddSection(name, collapsible)
    local section = setmetatable({}, Section)
    section.Tab = self
    section.Window = self.Window
    section.Name = tostring(name or "Section")
    section.Controls = {}
    section.Collapsible = collapsible == true
    section.Collapsed = false

    local frame = make("Frame", {
        BackgroundColor3 = self.Window.Theme.Surface,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        LayoutOrder = #self.Sections + 1,
    }, self.Page)
    addCorner(frame, 9)
    addStroke(frame, self.Window.Theme.BorderSoft, 0, 1)
    section.Frame = frame

    local header = make("TextButton", {
        AutoButtonColor = false,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 40),
        Text = "",
        LayoutOrder = 1,
    }, frame)
    section.Header = header

    local title = createText(header, section.Name, 12, self.Window.Theme.Text, Enum.Font.GothamSemibold)
    title.Position = UDim2.fromOffset(14, 0)
    title.Size = UDim2.new(1, -44, 1, 0)

    local chevron
    if section.Collapsible then
        chevron = createText(header, "⌄", 14, self.Window.Theme.TextMuted, Enum.Font.GothamMedium, Enum.TextXAlignment.Center)
        chevron.AnchorPoint = Vector2.new(1, 0)
        chevron.Position = UDim2.new(1, -12, 0, 0)
        chevron.Size = UDim2.fromOffset(22, 40)
        section.Chevron = chevron
    end

    local divider = make("Frame", {
        BackgroundColor3 = self.Window.Theme.BorderSoft,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(14, 39),
        Size = UDim2.new(1, -28, 0, 1),
    }, header)

    local body = make("Frame", {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        LayoutOrder = 2,
    }, frame)
    addPadding(body, 8, 8, 8, 8)
    make("UIListLayout", {
        Padding = UDim.new(0, 4),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, body)
    section.Body = body

    local function setCollapsed(collapsed)
        section.Collapsed = collapsed
        body.Visible = not collapsed
        divider.Visible = not collapsed
        if chevron then
            chevron.Text = collapsed and "›" or "⌄"
        end
    end

    section.SetCollapsed = function(_, collapsed)
        setCollapsed(collapsed and true or false)
    end

    if section.Collapsible then
        header.MouseButton1Click:Connect(function()
            setCollapsed(not section.Collapsed)
        end)
        header.MouseEnter:Connect(function()
            title.TextColor3 = self.Window.Theme.Accent
        end)
        header.MouseLeave:Connect(function()
            title.TextColor3 = self.Window.Theme.Text
        end)
    end

    table.insert(self.Sections, section)
    return section
end

function Section:_registerControl(control, searchText)
    control.SearchText = tostring(searchText or ""):lower()
    table.insert(self.Controls, control)
    table.insert(self.Tab.Controls, control)
end

function Section:_applySearch(query)
    if query == "" then
        self.Frame.Visible = true
        for _, control in ipairs(self.Controls) do
            if control.Container then
                control.Container.Visible = true
            end
        end
        return
    end

    local sectionMatch = self.Name:lower():find(query, 1, true) ~= nil
    local any = false
    for _, control in ipairs(self.Controls) do
        local match = sectionMatch or (control.SearchText and control.SearchText:find(query, 1, true) ~= nil)
        if control.Container then
            control.Container.Visible = match
        end
        any = any or match
    end
    self.Frame.Visible = any or sectionMatch
end

function Section:_row(options, rightWidth)
    options = options or {}
    local titleText = tostring(options.Title or "Control")
    local descriptionText = tostring(options.Content or options.Description or "")

    local right = rightWidth or 150
    local descriptionHeight = 0
    if descriptionText ~= "" then
        local ok, bounds = pcall(function()
            return TextService:GetTextSize(descriptionText, 10, Enum.Font.Gotham, Vector2.new(315, 1000))
        end)
        descriptionHeight = ok and math.max(bounds.Y, 14) or 22
    end
    local rowHeight = descriptionText ~= "" and math.max(58, 36 + descriptionHeight) or 44

    local row = make("Frame", {
        BackgroundColor3 = self.Window.Theme.Surface2,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, rowHeight),
        LayoutOrder = #self.Controls + 1,
    }, self.Body)
    addCorner(row, 7)

    local title = createText(row, titleText, 12, self.Window.Theme.Text, Enum.Font.GothamMedium)
    title.Position = UDim2.fromOffset(10, descriptionText ~= "" and 8 or 0)
    title.Size = UDim2.new(1, -(right + 24), 0, descriptionText ~= "" and 18 or 44)

    local description
    if descriptionText ~= "" then
        description = createText(row, descriptionText, 10, self.Window.Theme.TextMuted, Enum.Font.Gotham)
        description.Position = UDim2.fromOffset(10, 28)
        description.Size = UDim2.new(1, -(right + 24), 0, descriptionHeight)
        description.TextWrapped = true
        description.TextYAlignment = Enum.TextYAlignment.Top
    end

    row.MouseEnter:Connect(function()
        tween(row, 0.12, { BackgroundTransparency = 0.35 })
    end)
    row.MouseLeave:Connect(function()
        tween(row, 0.12, { BackgroundTransparency = 1 })
    end)

    return row, title, description
end

function Section:AddSubSection(name)
    local frame = make("Frame", {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 32),
        LayoutOrder = #self.Controls + 1,
    }, self.Body)

    local label = createText(frame, tostring(name or ""), 10, self.Window.Theme.TextMuted, Enum.Font.GothamSemibold)
    label.Position = UDim2.fromOffset(10, 2)
    label.Size = UDim2.new(0, 130, 1, -4)

    local line = make("Frame", {
        AnchorPoint = Vector2.new(0, 0.5),
        BackgroundColor3 = self.Window.Theme.BorderSoft,
        BorderSizePixel = 0,
        Position = UDim2.new(0, 140, 0.5, 0),
        Size = UDim2.new(1, -150, 0, 1),
    }, frame)

    local control = { Container = frame, Get = function() return nil end, Set = function() end }
    self:_registerControl(control, tostring(name or ""))
    return control
end

function Section:AddParagraph(options)
    options = options or {}
    local titleText = tostring(options.Title or "Info")
    local contentText = tostring(options.Content or options.Description or "")

    local frame = make("Frame", {
        BackgroundColor3 = self.Window.Theme.Surface2,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        LayoutOrder = #self.Controls + 1,
    }, self.Body)
    addCorner(frame, 7)
    addStroke(frame, self.Window.Theme.BorderSoft, 0.15, 1)
    addPadding(frame, 10, 10, 9, 9)

    local layout = make("UIListLayout", {
        Padding = UDim.new(0, 4),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, frame)

    local title = createText(frame, titleText, 11, self.Window.Theme.Text, Enum.Font.GothamSemibold)
    title.Size = UDim2.new(1, 0, 0, 17)
    title.LayoutOrder = 1

    local content = createText(frame, contentText, 10, self.Window.Theme.TextSoft, Enum.Font.Gotham)
    content.Size = UDim2.new(1, 0, 0, 0)
    content.AutomaticSize = Enum.AutomaticSize.Y
    content.TextWrapped = true
    content.TextYAlignment = Enum.TextYAlignment.Top
    content.LayoutOrder = 2

    local control = { Container = frame }
    function control:Set(value)
        if type(value) == "table" then
            if value.Title ~= nil then
                title.Text = tostring(value.Title)
            end
            if value.Content ~= nil or value.Description ~= nil then
                content.Text = tostring(value.Content or value.Description or "")
            end
        else
            content.Text = tostring(value or "")
        end
        control.SearchText = (title.Text .. " " .. content.Text):lower()
    end
    function control:Get()
        return { Title = title.Text, Content = content.Text }
    end

    self:_registerControl(control, titleText .. " " .. contentText)
    return control
end

function Section:AddButton(options)
    options = options or {}
    local row, title = self:_row(options, 58)
    row.Active = true

    local action = createText(row, "RUN", 9, self.Window.Theme.TextMuted, Enum.Font.GothamBold, Enum.TextXAlignment.Center)
    action.AnchorPoint = Vector2.new(1, 0.5)
    action.Position = UDim2.new(1, -10, 0.5, 0)
    action.Size = UDim2.fromOffset(42, 24)
    action.BackgroundTransparency = 0
    action.BackgroundColor3 = self.Window.Theme.Surface3
    addCorner(action, 6)
    addStroke(action, self.Window.Theme.Border, 0, 1)

    local click = make("TextButton", {
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        Text = "",
        AutoButtonColor = false,
        ZIndex = 4,
    }, row)

    click.MouseEnter:Connect(function()
        action.TextColor3 = self.Window.Theme.Text
        tween(action, 0.12, { BackgroundColor3 = self.Window.Theme.AccentSoft })
    end)
    click.MouseLeave:Connect(function()
        action.TextColor3 = self.Window.Theme.TextMuted
        tween(action, 0.12, { BackgroundColor3 = self.Window.Theme.Surface3 })
    end)
    click.MouseButton1Click:Connect(function()
        safeCallback(options.Callback)
    end)

    local control = { Container = row }
    function control:Set() end
    function control:Get() return nil end
    self:_registerControl(control, tostring(options.Title or "") .. " " .. tostring(options.Content or ""))
    return control
end

function Section:AddToggle(options)
    options = options or {}
    local row = self:_row(options, 68)
    local value = options.Default == true

    local toggle = make("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5),
        AutoButtonColor = false,
        BackgroundColor3 = self.Window.Theme.Surface3,
        BorderSizePixel = 0,
        Position = UDim2.new(1, -12, 0.5, 0),
        Size = UDim2.fromOffset(42, 24),
        Text = "",
    }, row)
    addCorner(toggle, 12)
    addStroke(toggle, self.Window.Theme.Border, 0, 1)

    local knob = make("Frame", {
        AnchorPoint = Vector2.new(0, 0.5),
        BackgroundColor3 = self.Window.Theme.TextMuted,
        BorderSizePixel = 0,
        Position = UDim2.new(0, 4, 0.5, 0),
        Size = UDim2.fromOffset(16, 16),
    }, toggle)
    addCorner(knob, 8)

    local control = { Container = row }
    local function render(animated)
        local bg = value and self.Window.Theme.Accent or self.Window.Theme.Surface3
        local knobColor = value and Color3.fromRGB(255, 255, 255) or self.Window.Theme.TextMuted
        local pos = value and UDim2.new(1, -20, 0.5, 0) or UDim2.new(0, 4, 0.5, 0)
        if animated then
            tween(toggle, 0.14, { BackgroundColor3 = bg })
            tween(knob, 0.14, { Position = pos, BackgroundColor3 = knobColor })
        else
            toggle.BackgroundColor3 = bg
            knob.Position = pos
            knob.BackgroundColor3 = knobColor
        end
    end

    function control:Set(newValue, silent)
        value = newValue and true or false
        render(true)
        if not silent then
            safeCallback(options.Callback, value)
        end
    end
    function control:Get()
        return value
    end

    toggle.MouseButton1Click:Connect(function()
        control:Set(not value)
    end)
    render(false)

    self:_registerControl(control, tostring(options.Title or "") .. " " .. tostring(options.Content or ""))
    self.Window:_registerConfigControl(control, options, self.Tab.Name, self.Name, options.Title or "Toggle")
    return control
end

function Section:AddSlider(options)
    options = options or {}
    local minimum = tonumber(options.Min) or 0
    local maximum = tonumber(options.Max) or 100
    local increment = tonumber(options.Increment) or 1
    if maximum < minimum then
        minimum, maximum = maximum, minimum
    end
    if increment <= 0 then
        increment = 1
    end

    local value = tonumber(options.Default) or minimum
    local row = self:_row(options, 190)

    local valueLabel = createText(row, "", 10, self.Window.Theme.TextSoft, Enum.Font.GothamMedium, Enum.TextXAlignment.Right)
    valueLabel.AnchorPoint = Vector2.new(1, 0)
    valueLabel.Position = UDim2.new(1, -12, 0, 8)
    valueLabel.Size = UDim2.fromOffset(56, 18)

    local bar = make("Frame", {
        AnchorPoint = Vector2.new(1, 0.5),
        BackgroundColor3 = self.Window.Theme.Surface3,
        BorderSizePixel = 0,
        Position = UDim2.new(1, -12, 0.5, 11),
        Size = UDim2.fromOffset(154, 6),
    }, row)
    addCorner(bar, 3)

    local fill = make("Frame", {
        BackgroundColor3 = self.Window.Theme.Accent,
        BorderSizePixel = 0,
        Size = UDim2.new(0, 0, 1, 0),
    }, bar)
    addCorner(fill, 3)

    local thumb = make("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = self.Window.Theme.Text,
        BorderSizePixel = 0,
        Position = UDim2.new(0, 0, 0.5, 0),
        Size = UDim2.fromOffset(12, 12),
    }, bar)
    addCorner(thumb, 6)
    addStroke(thumb, self.Window.Theme.Accent, 0, 1)

    local hitbox = make("TextButton", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, -6, 0, -8),
        Size = UDim2.new(1, 12, 1, 16),
        Text = "",
        AutoButtonColor = false,
    }, bar)

    local control = { Container = row }

    local function roundToIncrement(number)
        local snapped = minimum + math.floor(((number - minimum) / increment) + 0.5) * increment
        return math.clamp(snapped, minimum, maximum)
    end

    local function formatNumber(number)
        if math.abs(number - math.floor(number)) < 0.000001 then
            return tostring(math.floor(number))
        end
        return string.format("%.3f", number):gsub("0+$", ""):gsub("%.$", "")
    end

    local function render()
        local alpha = maximum == minimum and 0 or ((value - minimum) / (maximum - minimum))
        fill.Size = UDim2.new(alpha, 0, 1, 0)
        thumb.Position = UDim2.new(alpha, 0, 0.5, 0)
        valueLabel.Text = formatNumber(value)
    end

    function control:Set(newValue, silent)
        local number = tonumber(newValue)
        if not number then
            return
        end
        value = roundToIncrement(number)
        render()
        if not silent then
            safeCallback(options.Callback, value)
        end
    end
    function control:Get()
        return value
    end

    local dragging = false
    local function updateFromPosition(x)
        local alpha = math.clamp((x - bar.AbsolutePosition.X) / math.max(bar.AbsoluteSize.X, 1), 0, 1)
        control:Set(minimum + (maximum - minimum) * alpha)
    end

    hitbox.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            updateFromPosition(input.Position.X)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            updateFromPosition(input.Position.X)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    value = roundToIncrement(value)
    render()
    self:_registerControl(control, tostring(options.Title or "") .. " " .. tostring(options.Content or ""))
    self.Window:_registerConfigControl(control, options, self.Tab.Name, self.Name, options.Title or "Slider")
    return control
end

function Section:AddInput(options)
    options = options or {}
    local row = self:_row(options, 230)
    local value = tostring(options.Default or "")

    local box = make("TextBox", {
        AnchorPoint = Vector2.new(1, 0.5),
        BackgroundColor3 = self.Window.Theme.Surface3,
        BorderSizePixel = 0,
        ClearTextOnFocus = false,
        Font = Enum.Font.Gotham,
        PlaceholderColor3 = self.Window.Theme.TextMuted,
        PlaceholderText = tostring(options.Placeholder or "Type..."),
        Position = UDim2.new(1, -12, 0.5, 0),
        Size = UDim2.fromOffset(214, 30),
        Text = value,
        TextColor3 = self.Window.Theme.Text,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, row)
    addCorner(box, 6)
    addStroke(box, self.Window.Theme.Border, 0, 1)
    addPadding(box, 10, 10, 0, 0)

    local control = { Container = row }
    function control:Set(newValue, silent)
        value = tostring(newValue or "")
        box.Text = value
        if not silent then
            safeCallback(options.Callback, value)
        end
    end
    function control:Get()
        return value
    end

    box.FocusLost:Connect(function()
        if box.Text ~= value then
            value = box.Text
            safeCallback(options.Callback, value)
        end
    end)

    self:_registerControl(control, tostring(options.Title or "") .. " " .. tostring(options.Content or ""))
    self.Window:_registerConfigControl(control, options, self.Tab.Name, self.Name, options.Title or "Input")
    return control
end

function Section:AddDropdown(options)
    options = options or {}
    local isMulti = options.Multi == true
    local optionsList = arrayCopy(options.Options or {})
    local selected = {}
    local expanded = false

    if isMulti then
        selected = arrayCopy(options.Default or {})
    else
        local initial = normalizeSingle(options.Default)
        if initial ~= nil then
            selected = { initial }
        end
    end

    local container = make("Frame", {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 58),
        AutomaticSize = Enum.AutomaticSize.Y,
        LayoutOrder = #self.Controls + 1,
    }, self.Body)
    make("UIListLayout", {
        Padding = UDim.new(0, 4),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, container)

    local row, title, description = self:_row(options, 230)
    row.Parent = container
    row.LayoutOrder = 1

    local picker = createButtonBase(row, self.Window.Theme)
    picker.AnchorPoint = Vector2.new(1, 0.5)
    picker.Position = UDim2.new(1, -12, 0.5, 0)
    picker.Size = UDim2.fromOffset(214, 30)

    local pickerText = createText(picker, "", 10, self.Window.Theme.TextSoft, Enum.Font.Gotham, Enum.TextXAlignment.Left)
    pickerText.Position = UDim2.fromOffset(10, 0)
    pickerText.Size = UDim2.new(1, -36, 1, 0)
    pickerText.TextTruncate = Enum.TextTruncate.AtEnd

    local caret = createText(picker, "⌄", 12, self.Window.Theme.TextMuted, Enum.Font.GothamMedium, Enum.TextXAlignment.Center)
    caret.AnchorPoint = Vector2.new(1, 0)
    caret.Position = UDim2.new(1, -4, 0, 0)
    caret.Size = UDim2.fromOffset(28, 30)

    local optionsFrame = make("ScrollingFrame", {
        BackgroundColor3 = self.Window.Theme.Surface2,
        BorderSizePixel = 0,
        CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollBarThickness = 2,
        ScrollBarImageColor3 = self.Window.Theme.Border,
        Size = UDim2.new(1, 0, 0, 0),
        Visible = false,
        LayoutOrder = 2,
    }, container)
    addCorner(optionsFrame, 7)
    addStroke(optionsFrame, self.Window.Theme.BorderSoft, 0, 1)
    addPadding(optionsFrame, 6, 6, 6, 6)
    local optionsLayout = make("UIListLayout", {
        Padding = UDim.new(0, 3),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, optionsFrame)

    local control = { Container = container }
    local optionButtons = {}

    local function isSelected(item)
        for _, value in ipairs(selected) do
            if tostring(value) == tostring(item) then
                return true
            end
        end
        return false
    end

    local function displayText()
        if #selected == 0 then
            return options.Placeholder or "Select..."
        end
        if isMulti then
            if #selected <= 2 then
                local names = {}
                for _, value in ipairs(selected) do
                    table.insert(names, tostring(value))
                end
                return table.concat(names, ", ")
            end
            return tostring(#selected) .. " selected"
        end
        return tostring(selected[1])
    end

    local function renderSelection()
        pickerText.Text = displayText()
        pickerText.TextColor3 = #selected > 0 and self.Window.Theme.Text or self.Window.Theme.TextMuted
        for item, buttonData in pairs(optionButtons) do
            local active = isSelected(item)
            buttonData.Button.BackgroundTransparency = active and 0.2 or 1
            buttonData.Button.BackgroundColor3 = active and self.Window.Theme.AccentSoft or self.Window.Theme.Surface2
            buttonData.Label.TextColor3 = active and self.Window.Theme.Text or self.Window.Theme.TextSoft
            buttonData.Mark.Text = active and "✓" or ""
        end
    end

    local function setExpanded(state)
        expanded = state and true or false
        optionsFrame.Visible = expanded
        caret.Text = expanded and "⌃" or "⌄"
        if expanded then
            local height = math.min(math.max(#optionsList, 1) * 31 + 12, 190)
            optionsFrame.Size = UDim2.new(1, 0, 0, height)
        else
            optionsFrame.Size = UDim2.new(1, 0, 0, 0)
        end
    end

    local function emit()
        if isMulti then
            safeCallback(options.Callback, arrayCopy(selected))
        else
            safeCallback(options.Callback, selected[1])
        end
    end

    local function rebuildOptions()
        for _, data in pairs(optionButtons) do
            pcall(function()
                data.Button:Destroy()
            end)
        end
        table.clear(optionButtons)

        for index, item in ipairs(optionsList) do
            local key = tostring(item)
            local optionButton = make("TextButton", {
                AutoButtonColor = false,
                BackgroundColor3 = self.Window.Theme.Surface2,
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                Size = UDim2.new(1, -2, 0, 28),
                Text = "",
                LayoutOrder = index,
            }, optionsFrame)
            addCorner(optionButton, 5)

            local label = createText(optionButton, key, 10, self.Window.Theme.TextSoft, Enum.Font.Gotham)
            label.Position = UDim2.fromOffset(8, 0)
            label.Size = UDim2.new(1, -38, 1, 0)

            local mark = createText(optionButton, "", 11, self.Window.Theme.Accent, Enum.Font.GothamBold, Enum.TextXAlignment.Center)
            mark.AnchorPoint = Vector2.new(1, 0)
            mark.Position = UDim2.new(1, -5, 0, 0)
            mark.Size = UDim2.fromOffset(24, 28)

            optionButtons[item] = { Button = optionButton, Label = label, Mark = mark }

            optionButton.MouseButton1Click:Connect(function()
                if isMulti then
                    if isSelected(item) then
                        local nextSelected = {}
                        for _, value in ipairs(selected) do
                            if tostring(value) ~= tostring(item) then
                                table.insert(nextSelected, value)
                            end
                        end
                        selected = nextSelected
                    else
                        table.insert(selected, item)
                    end
                    renderSelection()
                    emit()
                else
                    selected = { item }
                    renderSelection()
                    setExpanded(false)
                    emit()
                end
            end)
        end
        renderSelection()
        if expanded then
            setExpanded(true)
        end
    end

    function control:Set(value, silent)
        if isMulti then
            selected = arrayCopy(value)
        else
            local single = normalizeSingle(value)
            selected = single ~= nil and { single } or {}
        end
        renderSelection()
        if not silent then
            emit()
        end
    end

    function control:Get()
        if isMulti then
            return arrayCopy(selected)
        end
        return selected[1]
    end

    function control:Refresh(newOptions, keepSelection)
        optionsList = arrayCopy(newOptions or {})
        if not keepSelection then
            local valid = {}
            for _, item in ipairs(optionsList) do
                valid[tostring(item)] = item
            end
            local nextSelected = {}
            for _, item in ipairs(selected) do
                if valid[tostring(item)] ~= nil then
                    table.insert(nextSelected, valid[tostring(item)])
                end
            end
            selected = nextSelected
        end
        rebuildOptions()
    end

    picker.MouseButton1Click:Connect(function()
        setExpanded(not expanded)
    end)

    rebuildOptions()
    setExpanded(false)
    self:_registerControl(control, tostring(options.Title or "") .. " " .. tostring(options.Content or "") .. " " .. table.concat((function()
        local names = {}
        for _, item in ipairs(optionsList) do
            table.insert(names, tostring(item))
        end
        return names
    end)(), " "))
    self.Window:_registerConfigControl(control, options, self.Tab.Name, self.Name, options.Title or "Dropdown")
    return control
end

function Section:AddConfigPanel(options)
    options = options or {}
    local window = self.Window
    self:AddSubSection(options.Title or "Configuration")

    local nameInput = self:AddInput({
        Title = "Config Name",
        Content = options.Content or "Save, load, delete and auto-load your settings.",
        Placeholder = "default",
        Default = "default",
        NoConfig = true,
    })

    local savedDropdown = self:AddDropdown({
        Title = "Saved Config",
        Content = "Pick an existing configuration.",
        Multi = false,
        Options = window:_listConfigs(),
        Default = {},
        NoConfig = true,
    })

    local function selectedName()
        local picked = savedDropdown:Get()
        if picked and tostring(picked) ~= "" then
            return tostring(picked)
        end
        local typed = nameInput:Get()
        return typed ~= "" and typed or "default"
    end

    local panel = {}
    function panel:Refresh()
        savedDropdown:Refresh(window:_listConfigs(), true)
    end

    self:AddButton({
        Title = "Save Config",
        Content = "Write the current control state to disk.",
        NoConfig = true,
        Callback = function()
            local ok, err = window:_saveConfig(nameInput:Get())
            panel:Refresh()
            window:_showToast({
                Title = ok and "Config saved" or "Config error",
                Description = ok and ("Saved " .. slug(nameInput:Get())) or tostring(err),
                Time = 3,
            })
        end,
    })

    self:AddButton({
        Title = "Load Config",
        Content = "Apply the selected configuration now.",
        NoConfig = true,
        Callback = function()
            local name = selectedName()
            local ok, err = window:_loadConfig(name)
            window:_showToast({
                Title = ok and "Config loaded" or "Config error",
                Description = ok and ("Loaded " .. slug(name)) or tostring(err),
                Time = 3,
            })
        end,
    })

    self:AddButton({
        Title = "Set Auto-Load",
        Content = "Load this config automatically when the UI is built.",
        NoConfig = true,
        Callback = function()
            local name = selectedName()
            local ok, err = window:_setAutoLoad(name)
            window:_showToast({
                Title = ok and "Auto-load set" or "Config error",
                Description = ok and (slug(name) .. " will load automatically") or tostring(err),
                Time = 3,
            })
        end,
    })

    self:AddButton({
        Title = "Delete Config",
        Content = "Delete the selected configuration.",
        NoConfig = true,
        Callback = function()
            local name = selectedName()
            local ok, err = window:_deleteConfig(name)
            panel:Refresh()
            window:_showToast({
                Title = ok and "Config deleted" or "Config error",
                Description = ok and ("Deleted " .. slug(name)) or tostring(err),
                Time = 3,
            })
        end,
    })

    task.defer(function()
        window:_autoLoad()
    end)

    return panel
end

function Library:CreateWindow(options)
    options = options or {}
    local theme = mergeTheme(options.Theme)
    if typeof(options.Accent) == "Color3" then
        theme.Accent = options.Accent
    end

    local parent = resolveParent()
    for _, child in ipairs(parent:GetChildren()) do
        if child:IsA("ScreenGui") and (child.Name == "SwaveFamilyHubRuntime" or child:GetAttribute("__SwaveFamilyHubOwned") == true) then
            pcall(function()
                child:Destroy()
            end)
        end
    end

    local self = setmetatable({}, Window)
    self.Theme = theme
    self.Tabs = {}
    self.ActiveTab = nil
    self.Visible = true
    self._configControls = {}

    local requestedSize = options.SizeUi
    local width = 760
    local height = 500
    if typeof(requestedSize) == "UDim2" then
        width = requestedSize.X.Offset > 0 and requestedSize.X.Offset or width
        height = requestedSize.Y.Offset > 0 and requestedSize.Y.Offset or height
    end
    width = math.max(width, 660)
    height = math.max(height, 430)

    local sidebarWidth = tonumber(options["Tab Width"] or options.TabWidth) or 168
    sidebarWidth = math.clamp(sidebarWidth, 150, 210)

    local gui = make("ScreenGui", {
        Name = "SwaveFamilyHubRuntime",
        ResetOnSpawn = false,
        IgnoreGuiInset = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        DisplayOrder = 9998,
    }, parent)
    gui:SetAttribute("__SwaveFamilyHubOwned", true)
    gui:SetAttribute("__WisHubOwned", true) -- legacy cleanup compatibility
    self.Gui = gui

    local holder = make("Frame", {
        Name = "DropShadowHolder",
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundTransparency = 1,
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(width, height),
    }, gui)
    self.Holder = holder

    local shadow = make("ImageLabel", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundTransparency = 1,
        Image = "rbxassetid://6015897843",
        ImageColor3 = theme.Shadow,
        ImageTransparency = 0.5,
        Position = UDim2.fromScale(0.5, 0.5),
        ScaleType = Enum.ScaleType.Slice,
        SliceCenter = Rect.new(49, 49, 450, 450),
        Size = UDim2.new(1, 46, 1, 46),
        ZIndex = 0,
    }, holder)

    local main = make("Frame", {
        BackgroundColor3 = theme.Background,
        BorderSizePixel = 0,
        Size = UDim2.fromScale(1, 1),
        ZIndex = 1,
        ClipsDescendants = true,
    }, holder)
    addCorner(main, 10)
    addStroke(main, theme.Border, 0, 1)
    self.Main = main

    make("Frame", {
        BackgroundColor3 = theme.Accent,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 2),
        ZIndex = 3,
    }, main)

    local sidebar = make("Frame", {
        BackgroundColor3 = theme.Sidebar,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(0, 2),
        Size = UDim2.new(0, sidebarWidth, 1, -2),
    }, main)
    self.Sidebar = sidebar

    make("Frame", {
        AnchorPoint = Vector2.new(1, 0),
        BackgroundColor3 = theme.BorderSoft,
        BorderSizePixel = 0,
        Position = UDim2.new(1, 0, 0, 0),
        Size = UDim2.new(0, 1, 1, 0),
    }, sidebar)

    local brand = make("Frame", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(12, 13),
        Size = UDim2.new(1, -24, 0, 54),
    }, sidebar)

    local logoAsset = normalizeAsset(options.Logo)
    if logoAsset ~= "" then
        local logo = make("ImageLabel", {
            BackgroundColor3 = theme.Surface2,
            BackgroundTransparency = 0,
            Image = logoAsset,
            Position = UDim2.fromOffset(0, 5),
            Size = UDim2.fromOffset(36, 36),
            ScaleType = Enum.ScaleType.Fit,
        }, brand)
        addCorner(logo, 9)
        addStroke(logo, theme.Border, 0, 1)
    else
        local monogram = createText(brand, "SF", 12, theme.Text, Enum.Font.GothamBold, Enum.TextXAlignment.Center)
        monogram.BackgroundTransparency = 0
        monogram.BackgroundColor3 = theme.AccentSoft
        monogram.Position = UDim2.fromOffset(0, 5)
        monogram.Size = UDim2.fromOffset(36, 36)
        addCorner(monogram, 9)
    end

    local brandTitle = createText(brand, tostring(options.Title or "SwaveFamilyHub"), 12, theme.Text, Enum.Font.GothamBold)
    brandTitle.Position = UDim2.fromOffset(46, 4)
    brandTitle.Size = UDim2.new(1, -46, 0, 22)
    brandTitle.TextTruncate = Enum.TextTruncate.AtEnd

    local subtitle = tostring(options.Description or "")
    local brandSub = createText(brand, subtitle, 9, theme.TextMuted, Enum.Font.Gotham)
    brandSub.Position = UDim2.fromOffset(46, 25)
    brandSub.Size = UDim2.new(1, -46, 0, 18)
    brandSub.TextTruncate = Enum.TextTruncate.AtEnd

    local nav = make("ScrollingFrame", {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(10, 76),
        Size = UDim2.new(1, -20, 1, -132),
        CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollBarThickness = 0,
    }, sidebar)
    addPadding(nav, 0, 0, 2, 8)
    make("UIListLayout", {
        Padding = UDim.new(0, 4),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, nav)
    self.NavList = nav

    local footer = make("Frame", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 12, 1, -48),
        Size = UDim2.new(1, -24, 0, 36),
    }, sidebar)

    local keyText = createText(footer, "RightShift", 9, theme.TextMuted, Enum.Font.GothamMedium)
    keyText.Size = UDim2.new(1, 0, 0, 16)
    local versionText = createText(footer, "SwaveFamilyUI 2.0", 8, theme.TextMuted, Enum.Font.Gotham)
    versionText.Position = UDim2.fromOffset(0, 17)
    versionText.Size = UDim2.new(1, 0, 0, 14)

    local topbar = make("Frame", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(sidebarWidth + 1, 2),
        Size = UDim2.new(1, -(sidebarWidth + 1), 0, 60),
    }, main)
    self.Topbar = topbar

    local pageTitle = createText(topbar, "", 15, theme.Text, Enum.Font.GothamSemibold)
    pageTitle.Position = UDim2.fromOffset(18, 10)
    pageTitle.Size = UDim2.new(1, -320, 0, 22)
    self.PageTitle = pageTitle

    local pageHint = createText(topbar, "Controls", 9, theme.TextMuted, Enum.Font.Gotham)
    pageHint.Position = UDim2.fromOffset(18, 31)
    pageHint.Size = UDim2.new(1, -320, 0, 16)

    local searchBox = make("TextBox", {
        AnchorPoint = Vector2.new(1, 0.5),
        BackgroundColor3 = theme.Surface2,
        BorderSizePixel = 0,
        ClearTextOnFocus = false,
        Font = Enum.Font.Gotham,
        PlaceholderColor3 = theme.TextMuted,
        PlaceholderText = "Search controls...",
        Position = UDim2.new(1, -78, 0.5, 0),
        Size = UDim2.fromOffset(210, 30),
        Text = "",
        TextColor3 = theme.Text,
        TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, topbar)
    addCorner(searchBox, 7)
    addStroke(searchBox, theme.Border, 0, 1)
    addPadding(searchBox, 10, 10, 0, 0)
    self.SearchBox = searchBox

    local closeButton = createButtonBase(topbar, theme)
    closeButton.AnchorPoint = Vector2.new(1, 0.5)
    closeButton.Position = UDim2.new(1, -18, 0.5, 0)
    closeButton.Size = UDim2.fromOffset(34, 30)
    local closeText = createText(closeButton, "×", 16, theme.TextSoft, Enum.Font.GothamMedium, Enum.TextXAlignment.Center)
    closeText.Size = UDim2.fromScale(1, 1)

    closeButton.MouseEnter:Connect(function()
        tween(closeButton, 0.12, { BackgroundColor3 = theme.Danger })
        closeText.TextColor3 = Color3.fromRGB(255, 255, 255)
    end)
    closeButton.MouseLeave:Connect(function()
        tween(closeButton, 0.12, { BackgroundColor3 = theme.Surface3 })
        closeText.TextColor3 = theme.TextSoft
    end)
    closeButton.MouseButton1Click:Connect(function()
        self:SetVisible(false)
    end)

    local content = make("Frame", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(sidebarWidth + 19, 62),
        Size = UDim2.new(1, -(sidebarWidth + 37), 1, -78),
    }, main)
    self.PageContainer = content

    local toastContainer = make("Frame", {
        AnchorPoint = Vector2.new(1, 1),
        BackgroundTransparency = 1,
        Position = UDim2.new(1, -16, 1, -16),
        Size = UDim2.fromOffset(340, 360),
        ZIndex = 50,
    }, gui)
    make("UIListLayout", {
        HorizontalAlignment = Enum.HorizontalAlignment.Right,
        VerticalAlignment = Enum.VerticalAlignment.Bottom,
        Padding = UDim.new(0, 8),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, toastContainer)
    self.ToastContainer = toastContainer

    bindDrag(topbar, holder)

    searchBox:GetPropertyChangedSignal("Text"):Connect(function()
        if self.ActiveTab then
            self.ActiveTab:ApplySearch(searchBox.Text)
        end
    end)

    local keybind = options.Keybind
    if typeof(keybind) ~= "EnumItem" then
        keybind = Enum.KeyCode.RightShift
    end
    keyText.Text = keybind.Name .. " to toggle"
    self._keybindConnection = UserInputService.InputBegan:Connect(function(input, processed)
        if processed then
            return
        end
        if input.KeyCode == keybind then
            self:Toggle()
        end
    end)

    Library._activeWindow = self
    table.insert(Library.Windows, self)
    return self
end

function Library:SetNotification(options)
    local window = self._activeWindow or Library._activeWindow
    if window then
        window:_showToast(options)
    end
end

function Library:DestroyAll()
    for _, window in ipairs(self.Windows) do
        pcall(function()
            window:Destroy()
        end)
    end
    table.clear(self.Windows)
    self._activeWindow = nil
end

return Library

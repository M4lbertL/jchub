-- OFFLINE LOADER: complete dashboard included below; execute this entire file.
-- JcHub Restaurant Dashboard v1.0.0
-- Self-contained offline entry point. No downloads, purchases or remote requests.
-- Run on the client in EquipmentTesting (PlaceId 110767861733691).

local VERSION = "1.0.0"
local EXPECTED_PLACE = 110767861733691
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
if not player then error("JcHub Restaurant must run on the client.") end
local playerGui = player:WaitForChild("PlayerGui")
local GUI_NAME = "JcHubRestaurantDashboard"
local previous = playerGui:FindFirstChild(GUI_NAME)
if previous then previous:Destroy() end

-- CORE_BEGIN: pure selection and display helpers, also used by offline tests.
local Core = {}
function Core.selectPlot(candidates, userId)
    local owned = {}
    for _, item in ipairs(candidates) do
        if item.claimed == true and tonumber(item.owner) == userId and item.plotId ~= nil then
            table.insert(owned, item)
        end
    end
    if #owned == 1 then return owned[1].instance, "Owned plot found" end
    if #owned > 1 then return nil, "Multiple owned plots found. Waiting for a unique match." end
    return nil, "No claimed plot belongs to your player yet."
end
function Core.number(value)
    if type(value) ~= "number" or value ~= value or math.abs(value) == math.huge then return nil end
    return value
end
function Core.text(value, fallback)
    if value == nil or value == "" then return fallback or "Unknown" end
    local kind = type(value)
    if kind == "string" or kind == "number" or kind == "boolean" then return tostring(value) end
    return fallback or "Unknown"
end
function Core.count(value)
    local n = Core.number(value)
    if not n then return "Unknown" end
    return string.format("%g", n)
end
function Core.stockSummary(slots)
    local quantity, reserved, known, reservationsKnown = 0, 0, 0, 0
    for _, slot in ipairs(slots) do
        local q, r = Core.number(slot.quantity), Core.number(slot.reserved)
        if q then quantity += q; known += 1 end
        if r then reserved += r; reservationsKnown += 1 end
    end
    return quantity, reserved, known, reservationsKnown
end
function Core.distance(a, b)
    if not a or not b then return nil end
    return (a - b).Magnitude
end
function Core.clock(hour)
    if not Core.number(hour) then return "Unknown" end
    local total = math.floor((hour % 24) * 60)
    local h, m = math.floor(total / 60), total % 60
    return string.format("%d:%02d %s", (h % 12 == 0) and 12 or h % 12, m, h < 12 and "AM" or "PM")
end
-- CORE_END

local colors = {
    background = Color3.fromRGB(17, 21, 29), sidebar = Color3.fromRGB(22, 28, 38),
    card = Color3.fromRGB(29, 37, 49), stroke = Color3.fromRGB(45, 56, 72),
    text = Color3.fromRGB(237, 243, 250), muted = Color3.fromRGB(158, 176, 196),
    accent = Color3.fromRGB(84, 216, 177), warning = Color3.fromRGB(255, 197, 111),
    selected = Color3.fromRGB(35, 73, 70),
}
local rarityColors = {
    Common = colors.muted, Uncommon = Color3.fromRGB(112, 222, 153),
    Rare = Color3.fromRGB(113, 181, 255), Epic = Color3.fromRGB(198, 149, 255),
    Legendary = Color3.fromRGB(255, 202, 102), Mythic = Color3.fromRGB(255, 133, 166),
}
local connections, running = {}, true
local function connect(signal, fn)
    local c = signal:Connect(fn); table.insert(connections, c); return c
end
local function make(className, props, parent)
    local object = Instance.new(className)
    for key, value in pairs(props) do object[key] = value end
    object.Parent = parent
    return object
end
local function corner(object, radius)
    make("UICorner", {CornerRadius = UDim.new(0, radius or 10)}, object)
end
local function label(parent, text, size, color)
    return make("TextLabel", {
        BackgroundTransparency = 1, Text = text, Font = Enum.Font.Gotham,
        TextSize = size or 14, TextColor3 = color or colors.text,
        TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
        TextWrapped = true, RichText = false, AutomaticSize = Enum.AutomaticSize.Y,
        Size = UDim2.new(1, 0, 0, 0),
    }, parent)
end
local function button(parent, text, size, position)
    local b = make("TextButton", {
        BackgroundColor3 = colors.card, BorderSizePixel = 0, Text = text,
        TextColor3 = colors.text, Font = Enum.Font.GothamMedium, TextSize = 13,
        Size = size, Position = position or UDim2.new(), AutoButtonColor = true,
    }, parent)
    corner(b, 8); return b
end
local gui = make("ScreenGui", {Name = GUI_NAME, ResetOnSpawn = false,
    DisplayOrder = 85, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    IgnoreGuiInset = false}, playerGui)
local function cleanup()
    if not running then return end
    running = false
    for _, c in ipairs(connections) do c:Disconnect() end
    table.clear(connections)
end
connect(gui.Destroying, cleanup)
local main = make("Frame", {Name = "Window", BackgroundColor3 = colors.background,
    BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(820, 560)}, gui)
corner(main, 14)
make("UIStroke", {Color = colors.stroke, Thickness = 1}, main)
local scale = make("UIScale", {Scale = 1}, main)
local header = make("Frame", {Name = "DragHeader", BackgroundTransparency = 1,
    Size = UDim2.new(1, 0, 0, 66), Active = true}, main)
local brand = label(header, "JcHub  /  RESTAURANT", 19)
brand.Font = Enum.Font.GothamBold; brand.Position = UDim2.fromOffset(20, 13)
brand.Size = UDim2.new(1, -190, 0, 24); brand.AutomaticSize = Enum.AutomaticSize.None
local subtitle = label(header, "v" .. VERSION .. "  •  Live restaurant companion", 12, colors.muted)
subtitle.Position = UDim2.fromOffset(20, 39); subtitle.Size = UDim2.new(1, -150, 0, 18)
subtitle.AutomaticSize = Enum.AutomaticSize.None
local minimize = button(header, "—", UDim2.fromOffset(34, 30), UDim2.new(1, -88, 0, 16))
local close = button(header, "×", UDim2.fromOffset(34, 30), UDim2.new(1, -46, 0, 16))
local body = make("Frame", {BackgroundTransparency = 1, Position = UDim2.fromOffset(12, 76),
    Size = UDim2.new(1, -24, 1, -110)}, main)
local sidebar = make("Frame", {BackgroundColor3 = colors.sidebar, BorderSizePixel = 0,
    Size = UDim2.new(0, 132, 1, 0)}, body)
corner(sidebar)
make("UIPadding", {PaddingTop = UDim.new(0, 10), PaddingLeft = UDim.new(0, 8),
    PaddingRight = UDim.new(0, 8)}, sidebar)
make("UIListLayout", {Padding = UDim.new(0, 7), SortOrder = Enum.SortOrder.LayoutOrder}, sidebar)
local content = make("ScrollingFrame", {Name = "Content", BackgroundTransparency = 1,
    BorderSizePixel = 0, Position = UDim2.fromOffset(146, 0), Size = UDim2.new(1, -146, 1, 0),
    ScrollBarThickness = 4, ScrollBarImageColor3 = colors.accent,
    CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y}, body)
make("UIPadding", {PaddingRight = UDim.new(0, 8), PaddingBottom = UDim.new(0, 10)}, content)
make("UIListLayout", {Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder}, content)
local footer = label(main, "Finding your restaurant…", 11, colors.muted)
footer.Position = UDim2.new(0, 20, 1, -25); footer.Size = UDim2.new(1, -40, 0, 18)
footer.AutomaticSize = Enum.AutomaticSize.None
local restore = button(gui, "JcHub Restaurant  •  v" .. VERSION, UDim2.fromOffset(248, 38), UDim2.fromOffset(18, 60))
restore.Visible = false
connect(close.Activated, function() gui:Destroy() end)
connect(minimize.Activated, function() main.Visible = false; restore.Visible = true end)
connect(restore.Activated, function() main.Visible = true; restore.Visible = false end)

local function fitWindow()
    local camera = Workspace.CurrentCamera
    if camera then
        local v = camera.ViewportSize
        scale.Scale = math.min(1, math.max(0.2, (v.X - 24) / 820), math.max(0.2, (v.Y - 90) / 560))
    end
end
local cameraConnection
local function watchCamera()
    if cameraConnection then cameraConnection:Disconnect() end
    if Workspace.CurrentCamera then
        cameraConnection = connect(Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"), fitWindow)
    end
    fitWindow()
end
connect(Workspace:GetPropertyChangedSignal("CurrentCamera"), watchCamera)
watchCamera()
local dragging, dragStart, startPosition, touchInput
local function clampWindow()
    local camera = Workspace.CurrentCamera
    if not camera then return end
    local v = camera.ViewportSize
    local x, y = main.AbsolutePosition.X + main.AbsoluteSize.X / 2, main.AbsolutePosition.Y + main.AbsoluteSize.Y / 2
    main.Position = UDim2.fromOffset(math.clamp(x, 70, math.max(70, v.X - 70)), math.clamp(y, 35, math.max(35, v.Y - 65)))
end
connect(header.InputBegan, function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true; dragStart = input.Position; startPosition = main.Position
        touchInput = input.UserInputType == Enum.UserInputType.Touch and input or nil
    end
end)
connect(UserInputService.InputChanged, function(input)
    if dragging and (input == touchInput or (not touchInput and input.UserInputType == Enum.UserInputType.MouseMovement)) then
        local delta = input.Position - dragStart
        main.Position = UDim2.new(startPosition.X.Scale, startPosition.X.Offset + delta.X,
            startPosition.Y.Scale, startPosition.Y.Offset + delta.Y)
    end
end)
connect(UserInputService.InputEnded, function(input)
    if input == touchInput or (not touchInput and input.UserInputType == Enum.UserInputType.MouseButton1) then
        if dragging then dragging = false; touchInput = nil; clampWindow() end
    end
end)

local function path(root, dotted)
    local current = root
    for segment in string.gmatch(dotted, "[^.]+") do
        if not current then return nil end
        current = current:FindFirstChild(segment)
    end
    return current
end
local function attr(object, key) return object:GetAttribute(key) end
local function uiText(dotted)
    local object = path(playerGui, dotted)
    if object and (object:IsA("TextLabel") or object:IsA("TextButton")) and object.Text ~= "" then return object.Text end
    return nil
end
local function position(object)
    if object:IsA("BasePart") then return object.Position end
    if object:IsA("Model") then return object:GetPivot().Position end
    return nil
end
local function ownerMatches(object, boundary)
    local current = object
    while current do
        local owner = attr(current, "OwnerUserId")
        if owner ~= nil and tonumber(owner) ~= player.UserId then return false end
        if current == boundary then break end
        current = current.Parent
    end
    return true
end
local function nameOf(object)
    return Core.text(attr(object, "NPCName"), object.Name)
end
local function sortNamed(items)
    table.sort(items, function(a, b)
        local left, right = nameOf(a), nameOf(b)
        if left == right then
            return Core.text(attr(a, "FurnitureInstanceId"), a:GetFullName()) < Core.text(attr(b, "FurnitureInstanceId"), b:GetFullName())
        end
        return left < right
    end)
end

-- Cache models, not a hardcoded plot name. Ownership is rechecked each refresh.
local models = {}
for _, object in ipairs(Workspace:GetDescendants()) do
    if object:IsA("Model") or object:IsA("Folder") then models[object] = true end
end
connect(Workspace.DescendantAdded, function(object)
    if object:IsA("Model") or object:IsA("Folder") then models[object] = true end
end)
connect(Workspace.DescendantRemoving, function(object) models[object] = nil end)
local dayRemote, dayConnection, dayState, dayReceived
local function bindDayCycle()
    local candidate = path(ReplicatedStorage, "Shared.Remotes.DayCycle.DayCycleStateChanged")
    if candidate == dayRemote then return end
    if dayConnection then dayConnection:Disconnect() end
    dayRemote, dayState, dayReceived = candidate, nil, nil
    if candidate and candidate:IsA("RemoteEvent") then
        dayConnection = connect(candidate.OnClientEvent, function(state)
            if type(state) == "table" then dayState = state; dayReceived = os.clock() end
        end)
    end
end
local function collect()
    bindDayCycle()
    local candidates = {}
    for object in pairs(models) do
        if object:IsDescendantOf(Workspace) and attr(object, "Claimed") ~= nil and attr(object, "PlotId") ~= nil then
            table.insert(candidates, {instance = object, claimed = attr(object, "Claimed"),
                owner = attr(object, "OwnerUserId"), plotId = attr(object, "PlotId")})
        end
    end
    local plot, reason = Core.selectPlot(candidates, player.UserId)
    local state = {plot = plot, reason = reason, workers = {}, applicants = {}, garbage = {},
        equipment = {}, displays = {}, slots = {}, prompts = {}}
    local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    state.playerPosition = hrp and hrp.Position
    if plot then
        local furniture = plot:FindFirstChild("PlacedFurniture")
        local workers = plot:FindFirstChild("ActiveWorkers")
        local garbageRoot = path(plot, "Cleaning.Garbage")
        for _, object in ipairs(plot:GetDescendants()) do
            if ownerMatches(object, plot) then
                if workers and object.Parent == workers and attr(object, "WorkerId") then
                    table.insert(state.workers, object)
                end
                if garbageRoot and object:IsDescendantOf(garbageRoot) and attr(object, "GarbageType") then
                    table.insert(state.garbage, object)
                end
                if furniture and object:IsDescendantOf(furniture) then
                    if attr(object, "FurnitureInstanceId") and (attr(object, "EquipmentId") or attr(object, "Condition") ~= nil
                        or attr(object, "FurnitureType") == "PrepTable" or attr(object, "FurnitureType") == "Fridge") then
                        table.insert(state.equipment, object)
                    end
                    if attr(object, "DisplayCapacity") ~= nil then table.insert(state.displays, object) end
                    if object.Parent and object.Parent.Name == "DisplayPoints" and attr(object, "Quantity") ~= nil
                        and (attr(object, "DisplayId") or attr(object, "ReservedQuantity") ~= nil) then
                        table.insert(state.slots, {instance = object, quantity = attr(object, "Quantity"),
                            reserved = attr(object, "ReservedQuantity"), recipe = attr(object, "RecipeId"),
                            assigned = attr(object, "AssignedRecipeId")})
                    end
                    if object:IsA("ProximityPrompt") then table.insert(state.prompts, object) end
                end
            end
        end
    end
    local applicants = path(Workspace, "Gameplay.BarangayHall.ApplicantArea.LocalApplicants")
    if applicants then
        for _, object in ipairs(applicants:GetChildren()) do
            if attr(object, "ApplicantId") and ownerMatches(object) then table.insert(state.applicants, object) end
        end
    end
    sortNamed(state.workers); sortNamed(state.applicants); sortNamed(state.equipment); sortNamed(state.displays)
    table.sort(state.slots, function(a, b)
        return Core.text(a.recipe, "") .. a.instance:GetFullName() < Core.text(b.recipe, "") .. b.instance:GetFullName()
    end)
    table.sort(state.garbage, function(a, b)
        return (Core.distance(state.playerPosition, position(a)) or math.huge) < (Core.distance(state.playerPosition, position(b)) or math.huge)
    end)
    return state
end

local selectedTab, tabButtons, render = "Overview", {}, nil
local lastSignature, lastState, lastPlot
local function card(title, lines, titleColor)
    local frame = make("Frame", {BackgroundColor3 = colors.card, BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y}, content)
    corner(frame)
    make("UIPadding", {PaddingTop = UDim.new(0, 13), PaddingBottom = UDim.new(0, 13),
        PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14)}, frame)
    make("UIListLayout", {Padding = UDim.new(0, 7), SortOrder = Enum.SortOrder.LayoutOrder}, frame)
    local titleLabel = label(frame, title, 15, titleColor or colors.text); titleLabel.Font = Enum.Font.GothamBold
    titleLabel.LayoutOrder = 0
    for index, line in ipairs(lines) do local l = label(frame, line, 13, colors.muted); l.LayoutOrder = index end
end
local function shortId(object, key)
    local value = attr(object, key or "FurnitureInstanceId")
    return value and string.sub(tostring(value), 1, 8) or object.Name
end
local function plotRequired(state)
    if state.plot then return true end
    card("Waiting for your restaurant", {state.reason, "Claim a restaurant, then keep the dashboard open. It refreshes automatically."}, colors.warning)
    return false
end
local function overview(state)
    if not plotRequired(state) then return end
    local plot = state.plot
    card("Your restaurant", {
        "Player: " .. player.DisplayName .. " (@" .. player.Name .. ")",
        "Plot: " .. Core.text(attr(plot, "PlotId")) .. "  •  Owner verified",
        "Expansion: " .. Core.text(attr(plot, "RestaurantExpansionStage")) .. "  •  "
            .. Core.count(attr(plot, "RestaurantWidthTiles")) .. " × " .. Core.count(attr(plot, "RestaurantDepthTiles")) .. " tiles",
    }, colors.accent)
    local quantity, _, known = Core.stockSummary(state.slots)
    card("At a glance", {
        "Workers: " .. #state.workers .. "  •  Stations: " .. #state.equipment .. "  •  Garbage: " .. #state.garbage,
        "Recorded servings: " .. (known > 0 and Core.count(quantity) or "Unknown") .. "  •  Displays: " .. #state.displays,
    })
    card("Game display", {
        "Balance: " .. Core.text(uiText("CurrencyGui.CoinsDisplay.AmountLabel")),
        "Level: " .. Core.text(uiText("RestaurantGui.Backdrop.Panel.Content.LevelCard.LevelValue")),
        "Experience: " .. Core.text(uiText("RestaurantGui.Backdrop.Panel.Content.LevelCard.ExperienceLabel")),
        "Restaurant: " .. Core.text(uiText("RestaurantGui.Backdrop.Panel.Content.StatusCard.StatusLabel")),
        "Values above come from the game's UI and may wait for its screens to refresh.",
    })
end
local function stock(state)
    if not plotRequired(state) then return end
    local q, r, known, reservedKnown = Core.stockSummary(state.slots)
    card("Display stock", {"Recorded servings: " .. (known > 0 and Core.count(q) or "Unknown"),
        "Recorded reservations: " .. (reservedKnown > 0 and Core.count(r) or "Unknown"),
        "Reservations are shown separately. Available-to-sell stock is not inferred."}, colors.accent)
    for _, display in ipairs(state.displays) do
        card(display.Name .. "  ·  " .. shortId(display), {
            "Occupied slots: " .. Core.count(attr(display, "DisplayedCount")) .. " / " .. Core.count(attr(display, "DisplayCapacity")),
            "Full: " .. Core.text(attr(display, "IsFull")) .. "  •  Layout: " .. Core.text(attr(display, "DisplayLayout")),
        })
    end
    for _, slot in ipairs(state.slots) do
        local low = Core.number(slot.quantity) and slot.quantity <= 5
        card(Core.text(slot.recipe, Core.text(slot.assigned, "Unassigned slot")) .. "  ·  " .. shortId(slot.instance, "DisplayId"), {
            slot.instance.Parent.Parent.Name .. " / " .. slot.instance.Name,
            "Quantity: " .. Core.count(slot.quantity) .. "  •  Reserved: " .. Core.count(slot.reserved),
            low and "Low stock: 5 or fewer recorded servings." or "Assigned recipe: " .. Core.text(slot.assigned),
        }, low and colors.warning or nil)
    end
    if #state.displays == 0 then card("No displays loaded", {"Place a food display in your restaurant to see its stock here."}) end
    card("Ingredients", {"Current ingredient quantities are not verified in this version. Open the game's fridge to inspect them."})
end
local function workers(state)
    if plotRequired(state) then
        card("Restaurant staff", {#state.workers .. " workers loaded. Assignments are shown as reported by the game."}, colors.accent)
        for _, worker in ipairs(state.workers) do
            local rarity = attr(worker, "Rarity")
            card(nameOf(worker) .. "  ·  " .. shortId(worker, "WorkerId"), {
                "Role: " .. Core.text(attr(worker, "Role")) .. "  •  Rarity: " .. Core.text(rarity),
                "Status: " .. Core.text(attr(worker, "WorkerStatus")) .. "  •  On duty: " .. Core.text(attr(worker, "IsOnDuty")),
                "Recipe: " .. Core.text(attr(worker, "RecipeId"), "Not assigned"),
                "Stove: " .. Core.text(attr(worker, "StoveInstanceId"), "Not reported"),
                "Prep table: " .. Core.text(attr(worker, "PrepTableInstanceId"), "Not reported"),
            }, rarityColors[rarity])
        end
    end
    card("Local applicant previews", {#state.applicants .. " applicants loaded at the employment desk. Prices and eligibility are not verified."}, colors.accent)
    for _, applicant in ipairs(state.applicants) do
        local rarity = attr(applicant, "Rarity")
        card(nameOf(applicant), {"Rarity: " .. Core.text(rarity) .. "  •  Pool: " .. Core.text(attr(applicant, "Pool")),
            "Applicant: " .. Core.text(attr(applicant, "ApplicantId"))}, rarityColors[rarity])
    end
end
local function cleaning(state)
    if not plotRequired(state) then return end
    card("Cleaning route", {#state.garbage .. " garbage objects in your restaurant, nearest first.",
        "Equip your broom and use the game's normal cleaning controls."}, colors.accent)
    for _, garbage in ipairs(state.garbage) do
        local distance = Core.distance(state.playerPosition, position(garbage))
        card(Core.text(attr(garbage, "GarbageType")) .. "  ·  " .. garbage.Name, {
            "Distance: " .. (distance and string.format("%.1f studs", distance) or "Unknown"),
            "Clean progress: " .. Core.count(attr(garbage, "CleanProgress")),
        })
    end
    local found = false
    for _, prompt in ipairs(state.prompts) do
        if prompt.Name == "WipePrompt" or prompt.Name == "RepairPrompt" then
            if prompt.Enabled then
                found = true
                card(prompt.ObjectText .. "  ·  " .. prompt.ActionText, {
                    "Interaction range: " .. Core.count(prompt.MaxActivationDistance) .. " studs",
                    "Line of sight required: " .. tostring(prompt.RequiresLineOfSight),
                }, colors.warning)
            end
        end
    end
    if not found then card("Surface tasks", {"No enabled wipe or repair prompts were found on your loaded furniture."}) end
end
local function equipment(state)
    if not plotRequired(state) then return end
    card("Kitchen equipment", {"Condition at 25 or lower is highlighted as a dashboard warning; the game's repair threshold is unknown."}, colors.accent)
    for _, station in ipairs(state.equipment) do
        local condition = Core.number(attr(station, "Condition"))
        card(station.Name .. "  ·  " .. shortId(station), {
            "Type: " .. Core.text(attr(station, "FurnitureType")) .. "  •  Equipment: " .. Core.text(attr(station, "EquipmentId")),
            "Condition: " .. Core.count(condition) .. "  •  Cooking: " .. Core.text(attr(station, "CookingState"), "Not reported"),
            "In use: " .. Core.text(attr(station, "InUse")) .. "  •  Occupied: " .. Core.text(attr(station, "Occupied")),
        }, condition and condition <= 25 and colors.warning or nil)
    end
    if #state.equipment == 0 then card("No stations loaded", {"Kitchen stations will appear when placed in your restaurant."}) end
end
local function scalarSummary(value)
    if type(value) ~= "table" then return Core.text(value, "Not reported") end
    local keys, parts = {}, {}
    for key, item in pairs(value) do
        if type(key) == "string" and (type(item) == "string" or type(item) == "number" or type(item) == "boolean") then table.insert(keys, key) end
    end
    table.sort(keys)
    for index, key in ipairs(keys) do
        if index > 8 then break end
        table.insert(parts, key .. ": " .. Core.text(value[key]))
    end
    return #parts > 0 and table.concat(parts, "  •  ") or "Details not reported"
end
local function schedule()
    local age = dayReceived and os.clock() - dayReceived
    if dayState and age then
        card(age <= 10 and "Live day cycle" or "Last day-cycle update", {
            "Time: " .. Core.text(dayState.TimeText, Core.clock(dayState.GameHour)),
            "Phase: " .. Core.text(dayState.Phase) .. "  •  Traffic: " .. Core.text(dayState.TrafficState),
            "Open hours: " .. Core.text(dayState.IsOpenHours) .. "  •  Paused: " .. Core.text(dayState.IsPaused),
            "Update age: " .. string.format("%.0fs", age),
        }, age <= 10 and colors.accent or colors.warning)
        card("Reported events", {"Current rush: " .. scalarSummary(dayState.CurrentRush),
            "Next event: " .. scalarSummary(dayState.NextEvent), "Tomorrow: " .. scalarSummary(dayState.TomorrowRush)})
    else
        card("Waiting for live time", {"Game clock: " .. Core.text(uiText("DayCycleGui.Backdrop.ClockButton.TimeLabel")),
            "Phase: " .. Core.text(uiText("DayCycleGui.Backdrop.MainPanel.CurrentPhaseCard.PhaseNameLabel")),
            "A live time update has not arrived yet. Game display values may be stale."}, colors.warning)
    end
    local base = "DayCycleGui.Backdrop.MainPanel."
    local rows = {}
    for _, entry in ipairs({{"Opening", "Timeline.OpenMarker.TimeLabel"}, {"Normal hours", "Timeline.NormalMarker.TimeLabel"},
        {"Daily rush", "EventList.DailyRushCard.TimeLabel"}, {"Slow hours", "EventList.SlowHoursCard.TimeLabel"},
        {"Closing", "RestaurantClosingCard.TimeLabel"}, {"Tomorrow", "EventList.TomorrowRushCard.TimeLabel"}}) do
        table.insert(rows, entry[1] .. ": " .. Core.text(uiText(base .. entry[2])))
    end
    table.insert(rows, "Schedule above is copied from the game's display. Future outcomes are not predicted.")
    card("Game schedule", rows)
end
local renderers = {Overview = overview, Stock = stock, Workers = workers, Cleaning = cleaning, Equipment = equipment, Schedule = schedule}
render = function(state, resetScroll)
    local oldScroll = content.CanvasPosition
    for _, child in ipairs(content:GetChildren()) do if child:IsA("Frame") then child:Destroy() end end
    if game.PlaceId ~= EXPECTED_PLACE then
        card("Different game", {"This dashboard supports EquipmentTesting, place " .. EXPECTED_PLACE .. ".", "Restaurant data is not read in this game."}, colors.warning)
    else renderers[selectedTab](state) end
    local order = 0
    for _, child in ipairs(content:GetChildren()) do
        if child:IsA("Frame") then order += 1; child.LayoutOrder = order end
    end
    content.CanvasPosition = resetScroll and Vector2.zero or oldScroll
end
for index, name in ipairs({"Overview", "Stock", "Workers", "Cleaning", "Equipment", "Schedule"}) do
    local tab = button(sidebar, name, UDim2.new(1, 0, 0, 42))
    tab.LayoutOrder = index; tabButtons[name] = tab
    connect(tab.Activated, function()
        selectedTab = name; lastSignature = nil
        for tabName, b in pairs(tabButtons) do
            b.BackgroundColor3 = tabName == selectedTab and colors.selected or colors.card
            b.TextColor3 = tabName == selectedTab and colors.accent or colors.text
        end
        if lastState then render(lastState, true) end
    end)
end
tabButtons.Overview.BackgroundColor3 = colors.selected; tabButtons.Overview.TextColor3 = colors.accent
local function update()
    if not running then return end
    if game.PlaceId ~= EXPECTED_PLACE then
        lastState = {reason = "Different game"}; render(lastState, false)
        footer.Text = "v" .. VERSION .. "  •  Unsupported place"; return
    end
    local state = collect()
    local changedPlot = state.plot ~= lastPlot
    lastPlot, lastState = state.plot, state
    footer.Text = state.plot and ("v" .. VERSION .. "  •  " .. Core.text(attr(state.plot, "PlotId")) .. "  •  Owner verified  •  Read-only  •  Updated " .. os.date("%H:%M:%S"))
        or ("v" .. VERSION .. "  •  " .. state.reason)
    -- Rebuild only when visible text changes; stable scrolling while idle.
    -- A detached frame collects the text signature before changing live cards.
    local oldContent = content
    local probe = make("Frame", {}, nil)
    content = probe
    local ok, err = pcall(function()
        if game.PlaceId == EXPECTED_PLACE then renderers[selectedTab](state) end
    end)
    local parts = {selectedTab, state.reason}
    if ok then
        for _, object in ipairs(probe:GetDescendants()) do if object:IsA("TextLabel") then table.insert(parts, object.Text) end end
    end
    content = oldContent; probe:Destroy()
    if not ok then error(err) end
    local signature = table.concat(parts, "\n")
    if signature ~= lastSignature or changedPlot then
        lastSignature = signature; render(state, changedPlot)
    end
end
local function safeUpdate()
    local ok, err = pcall(update)
    if not ok and running then
        footer.Text = "v" .. VERSION .. "  •  Waiting for restaurant data; retrying…"
        warn("[JcHub Restaurant v" .. VERSION .. "] " .. tostring(err))
    end
end
safeUpdate()
local elapsed = 0
connect(RunService.Heartbeat, function(delta)
    elapsed += delta
    if elapsed >= 2 then
        elapsed = 0
        if main.Visible then safeUpdate() end
    end
end)

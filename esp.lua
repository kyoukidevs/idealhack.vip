local esp_table = {}
local Players = game:GetService("Players")
local lplr = Players.LocalPlayer
local workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local Camera = workspace.CurrentCamera
local container = Instance.new("Folder", game:GetService("CoreGui"))

esp_table = {
    __loaded = false,
    main_settings = {
        textSize = 15,
        textFont = 2,
        distancelimit = false,
        maxdistance = 200,
        boxWidth = 80,
        boxHeight = 120,
        cornerLength = 15, -- stupid corner box
    },
    settings = {
        enemy = {
            enabled = false,
            box = false,
            box_fill = false,
            corner_box = false,
            health_bar = false,
            realname = false,
            health = false,
            dist = false,
            skeleton = false,
            chams = false,
            
            box_color = Color3.new(1, 1, 1),
            corner_color = Color3.new(1, 1, 1),
            realname_color = Color3.new(1, 1, 1),
            health_color = Color3.new(1, 1, 1),
            dist_color = Color3.new(1, 1, 1),
            skeleton_color = Color3.new(1, 1, 1),
            health_bar_color = Color3.fromRGB(0, 255, 0),
            health_bar_bg_color = Color3.fromRGB(255, 0, 0),
        }
    }
}

local loaded_plrs = {}
local connections = {}

local function is_player_alive(player)
    if not player then return false end
    local character = player.Character
    if not character then return false end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    return humanoid and humanoid.Health > 0
end

local function get_character(player)
    if not player then return end
    return player.Character
end

local function get_bounding_box_corners(character)
    if not character then return nil end
    
    local parts = {}
    for _, part in pairs(character:GetChildren()) do
        if part:IsA("BasePart") then
            table.insert(parts, part)
        end
    end
    
    if #parts == 0 then return nil end
    
    local min_x, min_y = math.huge, math.huge
    local max_x, max_y = -math.huge, -math.huge
    
    for _, part in pairs(parts) do
        local corners = {
            part.CFrame * CFrame.new(part.Size.X/2, part.Size.Y/2, part.Size.Z/2),
            part.CFrame * CFrame.new(-part.Size.X/2, part.Size.Y/2, part.Size.Z/2),
            part.CFrame * CFrame.new(part.Size.X/2, -part.Size.Y/2, part.Size.Z/2),
            part.CFrame * CFrame.new(-part.Size.X/2, -part.Size.Y/2, part.Size.Z/2),
            part.CFrame * CFrame.new(part.Size.X/2, part.Size.Y/2, -part.Size.Z/2),
            part.CFrame * CFrame.new(-part.Size.X/2, part.Size.Y/2, -part.Size.Z/2),
            part.CFrame * CFrame.new(part.Size.X/2, -part.Size.Y/2, -part.Size.Z/2),
            part.CFrame * CFrame.new(-part.Size.X/2, -part.Size.Y/2, -part.Size.Z/2)
        }
        
        for _, corner in pairs(corners) do
            local screen_pos, on_screen = Camera:WorldToViewportPoint(corner.Position)
            if on_screen then
                min_x = math.min(min_x, screen_pos.X)
                min_y = math.min(min_y, screen_pos.Y)
                max_x = math.max(max_x, screen_pos.X)
                max_y = math.max(max_y, screen_pos.Y)
            end
        end
    end
    
    if min_x == math.huge then return nil end
    
    return {
        top_left = Vector2.new(min_x, min_y),
        bottom_right = Vector2.new(max_x, max_y)
    }
end

local function create_esp(player)
    if not player or loaded_plrs[player] then return end
    
    local drawingObjects = {
        box = Drawing.new("Square"),
        corner_tl1 = Drawing.new("Line"),
        corner_tl2 = Drawing.new("Line"), 
        corner_tr1 = Drawing.new("Line"), 
        corner_tr2 = Drawing.new("Line"), 
        corner_bl1 = Drawing.new("Line"), 
        corner_bl2 = Drawing.new("Line"), 
        corner_br1 = Drawing.new("Line"), 
        corner_br2 = Drawing.new("Line"), 
        health_bar_bg = Drawing.new("Square"),
        health_bar = Drawing.new("Square"),
        realname = Drawing.new("Text"),
        healthtext = Drawing.new("Text"),
        dist = Drawing.new("Text")
    }

    drawingObjects.box.Filled = false
    drawingObjects.box.Thickness = 1
    drawingObjects.box.Visible = false
    
    for _, corner in pairs({
        drawingObjects.corner_tl1, drawingObjects.corner_tl2,
        drawingObjects.corner_tr1, drawingObjects.corner_tr2, 
        drawingObjects.corner_bl1, drawingObjects.corner_bl2,
        drawingObjects.corner_br1, drawingObjects.corner_br2
    }) do
        corner.Thickness = 2
        corner.Visible = false
    end
    
    drawingObjects.health_bar_bg.Filled = true
    drawingObjects.health_bar_bg.Thickness = 1
    drawingObjects.health_bar_bg.Visible = false
    
    drawingObjects.health_bar.Filled = true
    drawingObjects.health_bar.Thickness = 1
    drawingObjects.health_bar.Visible = false
    
    drawingObjects.realname.Center = true
    drawingObjects.realname.Visible = false
    drawingObjects.realname.Text = player.Name
    drawingObjects.realname.Outline = true
    
    drawingObjects.healthtext.Center = false
    drawingObjects.healthtext.Visible = false
    drawingObjects.healthtext.Outline = true
    
    drawingObjects.dist.Center = true
    drawingObjects.dist.Visible = false
    drawingObjects.dist.Outline = true

    local skeletonObjects = {}
    local skeleton_order = {
        {"Head", "HumanoidRootPart"},
        {"HumanoidRootPart", "LeftUpperArm"},
        {"LeftUpperArm", "LeftLowerArm"},
        {"HumanoidRootPart", "RightUpperArm"},
        {"RightUpperArm", "RightLowerArm"},
        {"HumanoidRootPart", "LeftUpperLeg"},
        {"LeftUpperLeg", "LeftLowerLeg"},
        {"HumanoidRootPart", "RightUpperLeg"},
        {"RightUpperLeg", "RightLowerLeg"}
    }
    
    for i = 1, #skeleton_order do
        skeletonObjects[i] = Drawing.new("Line")
        skeletonObjects[i].Visible = false
        skeletonObjects[i].Thickness = 1
    end

    local chamsObject = Instance.new("Highlight")
    chamsObject.Parent = container
    chamsObject.Enabled = false

    local plr_data = {
        obj = drawingObjects,
        skeleton = skeletonObjects,
        chams_object = chamsObject,
        plr_instance = player
    }

    function plr_data:update_visibility()
        local settings = esp_table.settings.enemy
        
        self.obj.box.Visible = settings.enabled and settings.box and self.is_visible
        
        local cornerVisible = settings.enabled and settings.corner_box and self.is_visible
        self.obj.corner_tl1.Visible = cornerVisible
        self.obj.corner_tl2.Visible = cornerVisible
        self.obj.corner_tr1.Visible = cornerVisible
        self.obj.corner_tr2.Visible = cornerVisible
        self.obj.corner_bl1.Visible = cornerVisible
        self.obj.corner_bl2.Visible = cornerVisible
        self.obj.corner_br1.Visible = cornerVisible
        self.obj.corner_br2.Visible = cornerVisible
        
        self.obj.health_bar_bg.Visible = settings.enabled and settings.health_bar and self.is_visible
        self.obj.health_bar.Visible = settings.enabled and settings.health_bar and self.is_visible
        self.obj.realname.Visible = settings.enabled and settings.realname and self.is_visible
        self.obj.healthtext.Visible = settings.enabled and settings.health and self.is_visible
        self.obj.dist.Visible = settings.enabled and settings.dist and self.is_visible
        
        for _, line in pairs(self.skeleton) do
            line.Visible = settings.enabled and settings.skeleton and self.is_visible
        end
        
        self.chams_object.Enabled = settings.enabled and settings.chams and self.is_visible
    end

    function plr_data:update()
        local settings = esp_table.settings.enemy
        local main_settings = esp_table.main_settings

        if not settings.enabled then
            self.is_visible = false
            self:update_visibility()
            return
        end

        if not player or not player.Parent then
            self:destroy()
            return
        end

        local character = get_character(player)
        local target = character
        
        if not target then
            self.is_visible = false
            self:update_visibility()
            return
        end

        local humanoid = target:FindFirstChildOfClass("Humanoid")
        local head = target:FindFirstChild("Head")

            if not (character and humanoid and head and humanoid.Health > 0) then
                self.is_visible = false
                self:update_visibility()
                return
            end

        local headScreenPos, onScreen = Camera:WorldToViewportPoint(head.Position)
        if not onScreen then
            self.is_visible = false
            self:update_visibility()
            return
        end

        local distance = (Camera.CFrame.Position - head.Position).Magnitude
        if main_settings.distancelimit and distance > main_settings.maxdistance then
            self.is_visible = false
            self:update_visibility()
            return
        end

        self.is_visible = true
        self:update_visibility()

        local boxPos, boxSize
        if settings.box or settings.corner_box or settings.health_bar then
            local bbox = get_bounding_box_corners(target)
            
            if bbox then
                boxSize = bbox.bottom_right - bbox.top_left
                boxPos = bbox.top_left
            else
                boxSize = Vector2.new(main_settings.boxWidth, main_settings.boxHeight)
                boxPos = Vector2.new(headScreenPos.X - boxSize.X/2, headScreenPos.Y - boxSize.Y/2)
            end
        end

        if settings.box then
            self.obj.box.Position = boxPos
            self.obj.box.Size = boxSize
            self.obj.box.Color = settings.box_color
        end

        if settings.corner_box then
            local cornerLength = main_settings.cornerLength
            local x, y = boxPos.X, boxPos.Y
            local w, h = boxSize.X, boxSize.Y
            
            -- ┌
            self.obj.corner_tl1.From = Vector2.new(x, y)
            self.obj.corner_tl1.To = Vector2.new(x + cornerLength, y)
            self.obj.corner_tl1.Color = settings.corner_color
            
            self.obj.corner_tl2.From = Vector2.new(x, y)
            self.obj.corner_tl2.To = Vector2.new(x, y + cornerLength)
            self.obj.corner_tl2.Color = settings.corner_color
            
            -- ┐
            self.obj.corner_tr1.From = Vector2.new(x + w, y)
            self.obj.corner_tr1.To = Vector2.new(x + w - cornerLength, y)
            self.obj.corner_tr1.Color = settings.corner_color
            
            self.obj.corner_tr2.From = Vector2.new(x + w, y)
            self.obj.corner_tr2.To = Vector2.new(x + w, y + cornerLength)
            self.obj.corner_tr2.Color = settings.corner_color
            
            -- └
            self.obj.corner_bl1.From = Vector2.new(x, y + h)
            self.obj.corner_bl1.To = Vector2.new(x + cornerLength, y + h)
            self.obj.corner_bl1.Color = settings.corner_color
            
            self.obj.corner_bl2.From = Vector2.new(x, y + h)
            self.obj.corner_bl2.To = Vector2.new(x, y + h - cornerLength)
            self.obj.corner_bl2.Color = settings.corner_color
            
            -- ┘
            self.obj.corner_br1.From = Vector2.new(x + w, y + h)
            self.obj.corner_br1.To = Vector2.new(x + w - cornerLength, y + h)
            self.obj.corner_br1.Color = settings.corner_color
            
            self.obj.corner_br2.From = Vector2.new(x + w, y + h)
            self.obj.corner_br2.To = Vector2.new(x + w, y + h - cornerLength)
            self.obj.corner_br2.Color = settings.corner_color
        end

        if settings.health_bar then
            local healthBarWidth = 3
            local healthBarOffset = 2
            local healthBarX = boxPos.X - healthBarWidth - healthBarOffset
            local healthBarY = boxPos.Y
            local healthBarHeight = boxSize.Y
            
            self.obj.health_bar_bg.Position = Vector2.new(healthBarX, healthBarY)
            self.obj.health_bar_bg.Size = Vector2.new(healthBarWidth, healthBarHeight)
            self.obj.health_bar_bg.Color = settings.health_bar_bg_color
            
            local healthPercent = 1
            if humanoid then
                healthPercent = math.clamp(humanoid.Health / humanoid.MaxHealth, 0, 1)
            end
            
            local currentHealthHeight = healthBarHeight * healthPercent
            local currentHealthY = healthBarY + (healthBarHeight - currentHealthHeight)
            
            self.obj.health_bar.Position = Vector2.new(healthBarX, currentHealthY)
            self.obj.health_bar.Size = Vector2.new(healthBarWidth, currentHealthHeight)
            
            if humanoid then
                local red = 1 - healthPercent
                local green = healthPercent
                self.obj.health_bar.Color = Color3.new(red, green, 0)
            else
                self.obj.health_bar.Color = settings.health_bar_color
            end
        end

        if settings.realname then
            local boxCenter = Vector2.new(
                boxPos.X + boxSize.X / 2,
                boxPos.Y
            )

            local displayName = player.Name

            self.obj.realname.Position = Vector2.new(boxCenter.X, boxPos.Y - 20)
            self.obj.realname.Color = settings.realname_color
            self.obj.realname.Text = displayName
        end

        if settings.health then
            self.obj.healthtext.Position = Vector2.new(
                boxPos.X - 30, 
                boxPos.Y
            )
            self.obj.healthtext.Color = settings.health_color

                self.obj.healthtext.Text = tostring(math.floor(humanoid.Health))
        end

        if settings.dist then
            local boxCenter = Vector2.new(
                boxPos.X + boxSize.X / 2,
                boxPos.Y + boxSize.Y
            )

            self.obj.dist.Position = Vector2.new(boxCenter.X, boxCenter.Y + 10)
            self.obj.dist.Color = settings.dist_color
            self.obj.dist.Text = math.floor(distance) .. "m"
        end

        if settings.skeleton then
            for i, bones in ipairs(skeleton_order) do
                local part1 = target:FindFirstChild(bones[1])
                local part2 = target:FindFirstChild(bones[2])
                
                if part1 and part2 then
                    local pos1 = Camera:WorldToViewportPoint(part1.Position)
                    local pos2 = Camera:WorldToViewportPoint(part2.Position)
                    
                    if pos1.Z > 0 and pos2.Z > 0 then
                        self.skeleton[i].From = Vector2.new(pos1.X, pos1.Y)
                        self.skeleton[i].To = Vector2.new(pos2.X, pos2.Y)
                        self.skeleton[i].Color = settings.skeleton_color
                    end
                end
            end
        end

        if settings.chams then
            self.chams_object.Adornee = target
        end
    end

    function plr_data:destroy()
        if self.render_connection then
            self.render_connection:Disconnect()
        end
        
        for name, obj in pairs(self.obj) do
            if obj then
                pcall(function()
                    obj.Visible = false
                    obj:Remove()
                end)
            end
        end
        
        for _, line in pairs(self.skeleton) do
            if line then
                pcall(function()
                    line.Visible = false
                    line:Remove()
                end)
            end
        end
        
        if self.chams_object then
            pcall(function()
                self.chams_object.Enabled = false
                self.chams_object:Destroy()
            end)
        end
        
        loaded_plrs[player] = nil
    end
    plr_data.render_connection = RunService.RenderStepped:Connect(function()
        plr_data:update()
    end)

    loaded_plrs[player] = plr_data
end

local function destroy_esp(player)
    if loaded_plrs[player] then
        loaded_plrs[player]:destroy()
    end
end

function esp_table.load()
    if esp_table.__loaded then return end

    for _, player in pairs(Players:GetPlayers()) do
        if player ~= lplr then
            create_esp(player)
        end
    end

    connections.playerAdded = Players.PlayerAdded:Connect(function(player)
        create_esp(player)
    end)

    connections.playerRemoving = Players.PlayerRemoving:Connect(function(player)
        destroy_esp(player)
    end)

    esp_table.__loaded = true
end

function esp_table.unload()
    if not esp_table.__loaded then return end

    for name, connection in pairs(connections) do
        if connection then
            connection:Disconnect()
        end
    end
    connections = {}

    for player, data in pairs(loaded_plrs) do
        if data then
            data:destroy()
        end
    end
    loaded_plrs = {}

    esp_table.__loaded = false
end

function esp_table.refresh()
    for player, data in pairs(loaded_plrs) do
        if data then
            data:update()
        end
    end
end

function esp_table.icaca()
    for _, v in pairs(loaded_plrs) do
        task.spawn(function() 
            if v and v.forceupdate then
                v:forceupdate() 
            elseif v and v.update then
                v:update()
            end
        end)
    end
end

return esp_table

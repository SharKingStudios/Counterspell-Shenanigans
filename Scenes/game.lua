--------------------------
--  game.lua
--------------------------
game = {}

local minigame = {}

local socket = require "socket"
local Camera = require("Libraries/hump/camera")  -- We assume you already added HUMP for your camera

-- the address and port of the server
local address, port = "37.27.51.34", 45169

local entity
local updaterate = 0.1
local diffx, diffy = 0, 0

screenWidthA = love.graphics.getWidth()
screenHeightA = love.graphics.getHeight()
screenWidth = 1920
screenHeight = 1080

world = {}
local t
local cam

TOP_BOUNDS = 165
BOTTOM_BOUNDS = 700
LEFT_BOUNDS = 210
RIGHT_BOUNDS = 1825

local cameraX, cameraY = 0, 0
local cameraSmoothSpeed = 2

local function lerp(a, b, t)
    return a + (b - a) * t
end

local function parseData(data)
    data = data:gsub("{", ""):gsub("}", "")
    local result = {}
    for k, v in string.gmatch(data, "([%w_]+)=([%w_.-]+)") do
        local number = tonumber(v)
        if number then
            result[k] = number
        else
            result[k] = v
        end
    end
    return result
end

function game.load()
    gamblingchildimage = love.graphics.newImage("Sprites/gamblingminor.png")
    childimageWidth = gamblingchildimage:getWidth()
    childimageHeight = gamblingchildimage:getHeight()

    udp = socket.udp()
    udp:settimeout(0)
    udp:setpeername(address, port)

    math.randomseed(os.time())
    -- entity = tostring(math.random(99999))
    entity = nameInput.text
    world[entity] = {
        x = 600,
        y = 500,
        params = {
            x = 600,
            y = 500,
            timestamp = os.time(),
            money = 10000
        },
        walkTime = 0
    }

    local dg = string.format("%s %s {x=%d,y=%d,money=%d}", entity, 'at', 600, 500, 10000)
    udp:send(dg)

    t = 0

    -- Initialize camera
    cam = Camera(world[entity].params.x, world[entity].params.y)
    cameraX = world[entity].params.x
    cameraY = world[entity].params.y

    minigame.current = require("Scenes/Minigames/slots")
    minigame.current.load()
end

function game.update(dt)
    local nextminigame = minigame.current.update(dt)
    if nextminigame == "startSlots" then
        print("Switching to Slots!")
        minigame.current = require("Scenes/Minigames/slots")
        minigame.current.load()
    elseif nextminigame == "startRoulette" then
        print("Switching to Roulette!")
        minigame.current = require("Scenes/Minigames/roulette")
        minigame.current.load()
    end

    lobbyupdate(dt)

    -- Get the target position of the main player
    local px, py = 0, 0
    if world[entity] and world[entity].x and world[entity].y then
        px = world[entity].x
        py = world[entity].y
    end

    -- NEW: Apply LERP for smooth camera movement
    cameraX = lerp(cameraX, px, cameraSmoothSpeed * dt)
    cameraY = lerp(cameraY, py, cameraSmoothSpeed * dt)

    -- Set the camera to the smoothly interpolated position
    cam:lookAt(cameraX, cameraY)
end

function lobbyupdate(dt)
    t = t + dt
    local currentTime = os.time()

    local movementSpeed = 100

    -- (1) Handle local player's movement input
    local moving = false
    if love.keyboard.isDown("w") then
        diffy = diffy - (movementSpeed * dt)
        moving = true
    end
    if love.keyboard.isDown("s") then
        diffy = diffy + (movementSpeed * dt)
        moving = true
    end
    if love.keyboard.isDown("a") then
        diffx = diffx - (movementSpeed * dt)
        moving = true
    end
    if love.keyboard.isDown("d") then
        diffx = diffx + (movementSpeed * dt)
        moving = true
    end

    -- If our main/local player is moving, update local walkTime right away
    if world[entity] then
        if moving then
            world[entity].walkTime = (world[entity].walkTime or 0) + dt
        else
            world[entity].walkTime = 0
        end
    end

    -- Apply bounds to the player's movement
    if world[entity] then
        local newX = world[entity].x + diffx
        local newY = world[entity].y + diffy

        if newX < LEFT_BOUNDS then
            diffx = 10
        elseif newX > RIGHT_BOUNDS then
            diffx = -10
        end

        if newY < TOP_BOUNDS then
            diffy = 10
        elseif newY > BOTTOM_BOUNDS then
            diffy = -10
        end
    end
    
    -- (2) Networking updates for local movement
    if t > updaterate then
        local moveParams = string.format("{x=%d,y=%d}", diffx, diffy)
        local dg = string.format("%s %s %s", entity, "move", moveParams)
        udp:send(dg)
        diffx, diffy = 0, 0

        dg = string.format("%s %s {}", entity, "update")
        udp:send(dg)

        t = t - updaterate
    end

    -- (3) Process all incoming messages
    repeat
        data, msg = udp:receive()
        if data then
            local ent, cmd, parms = data:match("^(%S*) (%S*) (.*)")
            if cmd == "update" then
                local params = parseData(parms)

                if not world[ent] then
                    world[ent] = { x = 0, y = 0, params = {}, walkTime = 0, oldX = 0, oldY = 0 }
                end

                local oldX = world[ent].x
                local oldY = world[ent].y

                world[ent].x = params.x or oldX
                world[ent].y = params.y or oldY
                world[ent].params.money = params.money or world[ent].params.money
                world[ent].timestamp = currentTime

                local dx = world[ent].x - oldX
                local dy = world[ent].y - oldY
                local distMoved = math.sqrt(dx*dx + dy*dy)

                local moveThreshold = 0.001 
                if distMoved > moveThreshold then
                    world[ent].walkTime = (world[ent].walkTime or 0) + dt
                else
                    world[ent].walkTime = 0
                end
            elseif cmd == "exit" then
                world[ent] = nil
            else
                print("Unrecognized command:", cmd)
            end
        end
    until not data

    -- (5) Cleanup inactive entities
    for k, v in pairs(world) do
        if currentTime - (v.timestamp or 0) > 2 then
            world[k] = nil
        end
    end
end

function game.draw()
    love.graphics.setColor(1, 1, 1)
    -- Draw background box white
    love.graphics.rectangle("fill", 0, 0, screenWidthA, screenHeightA)

    cam:attach()

    -- Draw the minigame (slots, etc.)
    minigame.current.draw()

    -- Draw all entities
    for k, v in pairs(world) do
        if v.x and v.y then
            local angle = 0
            local scaleX, scaleY = 1, 1
            if v.walkTime and v.walkTime > 0 then
                local swayFreq = 5
                local rotAmp   = 0.1
                local sclAmp   = 0.4
    
                angle = math.sin(v.walkTime * swayFreq) * rotAmp
                local squish = 1 + math.sin(v.walkTime * swayFreq) * sclAmp
                scaleX = 1/squish
                scaleY = 1 + (sclAmp*3) - scaleX

            end
            if v.x > love.graphics.getWidth()/2 then scaleX = -scaleX end

            love.graphics.setColor(0.1, 0.1, 0.1)
            love.graphics.print(k, v.x - 25, v.y - 100)
    
            if gamblingchildimage then
                love.graphics.setColor(1,1,1)
                love.graphics.draw(
                    gamblingchildimage,
                    v.x, v.y,
                    angle,
                    scaleX, scaleY,
                    childimageWidth/2,
                    childimageHeight/2
                )
            else
                -- fallback
                love.graphics.setColor(1,0,0)
                love.graphics.rectangle("fill", v.x, v.y, 50, 50)
                love.graphics.setColor(1,1,1)
            end

        end
    end

    -- **Draw Boundary Debug Lines**
    -- love.graphics.setColor(1, 0, 0) -- Red for visibility
    -- love.graphics.setLineWidth(6)   -- Make lines thicker for debugging

    -- -- Top Boundary
    -- love.graphics.line(LEFT_BOUNDS, TOP_BOUNDS, RIGHT_BOUNDS, TOP_BOUNDS)

    -- -- Bottom Boundary
    -- love.graphics.line(LEFT_BOUNDS, BOTTOM_BOUNDS, RIGHT_BOUNDS, BOTTOM_BOUNDS)

    -- -- Left Boundary
    -- love.graphics.line(LEFT_BOUNDS, TOP_BOUNDS, LEFT_BOUNDS, BOTTOM_BOUNDS)

    -- -- Right Boundary
    -- love.graphics.line(RIGHT_BOUNDS, TOP_BOUNDS, RIGHT_BOUNDS, BOTTOM_BOUNDS)

    -- -- Reset color to white
    -- love.graphics.setColor(1, 1, 1)

    cam:detach()

    -- UI or debug text after detach
    love.graphics.setColor(0,0,0)
    love.graphics.print("Press [ or ESC to quit", 10, 10)
    love.graphics.setColor(0,1,0)
    love.graphics.print("CONNETED TO SERVER!", 10, 40)
end

-------------------------------------------------------
-- The rest of your game.lua code (keypressed, quit, etc.)
-------------------------------------------------------
function love.keypressed(key)
    if key == "[" then
        local dg = string.format("%s %s $", entity, 'quit')
        udp:send(dg)
    end
    if key == "]" or key == "escape" then
        love.event.quit()
    end
end

function love.quit()
    local rq = string.format("%s %s $", entity, 'exit')
    udp:send(rq)
    udp:close()
end

return game

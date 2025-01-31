----------------------------
-- slots.lua
----------------------------
local slots = {}

local suit = require("Libraries/SUIT")

-- Access the global "game" table. (Assuming you have 'game' globally.)
local gameModule = game


local leverUpImage = nil
local leverDownImage = nil
local tickSound = nil
local winSound = love.audio.newSource("Sounds/win.mp3", "static")
local superwinSound = love.audio.newSource("Sounds/superwin.mp3", "static")
winSound:setVolume(0.5)
superwinSound:setVolume(0.5)

-- Reels & spinning state
local game = {
    images = {},
    slots = {1, 1, 1},         -- current visible symbols for each of 3 reels
    finalSlots = {1, 1, 1},    -- the final symbol for each reel after the spin

    spinning = false,          -- are we spinning?
    currentReel = 1,           -- which reel we’re spinning (1..3)
    reelTimer = 0,             -- how long the current reel has spun so far
    reelSpinDuration = 1.0,    -- how many seconds each reel spins
    timeBetweenTicks = 0.07,   -- how often we advance the reel to the next symbol
    tickAccumulator = 0,       -- accumulates time to know when to "tick"

    betAmount = 100,
    result = "",
    resultTimer = 0,

    -- Lever state
    leverState = "up",   -- "up" or "down"
    leverDownTimer = 0.0 -- how long the lever remains "down"
}

leverUpImage = love.graphics.newImage("Sprites/lever_up.png")
leverDownImage = love.graphics.newImage("Sprites/lever_down.png")
leverUpImage:setFilter("nearest","nearest")
leverDownImage:setFilter("nearest","nearest")

moneyImage = love.graphics.newImage("Sprites/money.png")

-- Example “room” backgrounds, flipping every half second
room_image = love.graphics.newImage("Sprites/room.png")
room_image2 = love.graphics.newImage("Sprites/room2.png")
room_image:setFilter("nearest", "nearest")
room_image2:setFilter("nearest", "nearest")

globaltimer = 0
globaltimertick = 1
globaltimerflipflop = globaltimertick / 2

screenWidthA = love.graphics.getWidth()
screenHeightA = love.graphics.getHeight()
screenWidth = 1920
screenHeight = 1080

-- Constants
local SLOT_WIDTH = 100
local SLOT_HEIGHT = 120
local REEL_SPACING = 15

-- *** Money particle system
local moneyParticles = {}  -- table of active particles

---------------------------------------------------------------------
-- Helper: create a money "explosion" at a position (x,y)
---------------------------------------------------------------------
local function spawnMoneyExplosion(x, y, count)
    for i=1, count do
        local p = {
            x = x,
            y = y,
            vx = (math.random()-0.5) * 200,  -- random velocity
            vy = -math.random(50, 150),
            rot = math.random()*2*math.pi,   -- random rotation
            rotSpeed = (math.random()-0.5)*4,
            alpha = 1,
            life = 3.0  -- lifespan in seconds
        }
        table.insert(moneyParticles, p)
    end
end

---------------------------------------------------------------------
-- scaleStuff (from your existing code)
---------------------------------------------------------------------
local function scaleStuff(widthorheight)
    local scale = 1
    if widthorheight == "w" then
        scale = screenWidthA / screenWidth
    elseif widthorheight == "h" then
        scale = screenHeightA / screenHeight
    end
    return scale
end

---------------------------------------------------------------------
-- slots.load()
---------------------------------------------------------------------
function slots.load()
    -- Load images
    game.images = {
        love.graphics.newImage("Sprites/i1.jpg"),
        love.graphics.newImage("Sprites/i2.jpg"),
        love.graphics.newImage("Sprites/i3.jpg"),
        love.graphics.newImage("Sprites/i4.jpg"),
        love.graphics.newImage("Sprites/i5.jpg"),
    }

    -- Adjust fonts
    game.font = love.graphics.newFont("/Fonts/VCR_OSD_MONO.ttf", 14 * math.min(scaleStuff("w"), scaleStuff("h")))
    game.largeFont = love.graphics.newFont("/Fonts/VCR_OSD_MONO.ttf", 24 * math.min(scaleStuff("w"), scaleStuff("h")))

    globaltimer = 0

    tickSound = love.audio.newSource("Sounds/tick.mp3", "static")
    tickSound:setVolume(0.5)
end

---------------------------------------------------------------------
-- slots.update(dt)
---------------------------------------------------------------------
function slots.update(dt)
    -- *** Background flicker timer
    globaltimer = globaltimer + dt
    if globaltimer > globaltimertick then
        globaltimer = 0
    end

    -- 1) Lever down timer
    if game.leverState == "down" then
        game.leverDownTimer = game.leverDownTimer - dt
        if game.leverDownTimer <= 0 then
            game.leverState = "up"
            game.leverDownTimer = 0
        end
    end

    -- 2) If we’re spinning, spin the current reel
    if game.spinning then
        game.reelTimer = game.reelTimer + dt
        game.tickAccumulator = game.tickAccumulator + dt

        -- “Tick” the current reel at intervals
        while game.tickAccumulator >= game.timeBetweenTicks do
            game.tickAccumulator = game.tickAccumulator - game.timeBetweenTicks

            local r = game.currentReel
            game.slots[r] = game.slots[r] + 1
            if game.slots[r] > #game.images then
                game.slots[r] = 1
            end

            -- Play a NEW instance of the sound so clicks can overlap
            if tickSound then
                local s = tickSound:clone()
                s:play()
            end
        end

        -- If the current reel has spun long enough, lock it & move on
        if game.reelTimer >= game.reelSpinDuration then
            -- Lock reel to finalSlots
            local r = game.currentReel
            game.slots[r] = game.finalSlots[r]

            -- Next reel
            game.currentReel = game.currentReel + 1
            game.reelTimer = 0
            game.tickAccumulator = 0

            -- If we’ve done all 3 reels, done => check result
            if game.currentReel > 3 then
                game.spinning = false
                slots.checkWin()
            end
        end
    end

    -- 3) Update result message timer
    if game.resultTimer > 0 then
        game.resultTimer = game.resultTimer - dt
        if game.resultTimer <= 0 then
            game.result = ""
        end
    end

    -- 4) Update money particles
    for i=#moneyParticles,1,-1 do
        local p = moneyParticles[i]
        p.life = p.life - dt
        if p.life <= 0 then
            table.remove(moneyParticles, i)
        else
            p.x = p.x + p.vx*dt
            p.y = p.y + p.vy*dt
            p.vy = p.vy + 150*dt
            p.rot = p.rot + p.rotSpeed*dt
            p.alpha = math.max(0, p.life/2.0)
        end
    end
end

---------------------------------------------------------------------
    -- slots.draw()
---------------------------------------------------------------------
function slots.draw()
    -- 1) Background flicker
    if globaltimer < globaltimerflipflop then
        love.graphics.draw(room_image2, 0, 0, 0, 1.5, 1.5)
    else
        love.graphics.draw(room_image, 0, 0, 0, 1.5, 1.5)
    end

    -- Leaderboard
    love.graphics.setColor(0, 0, 0)
    love.graphics.print("Leaderboard:", 300, 265)
    love.graphics.print("Note: The Nest server is having some trouble rn. You may momentarily disconnect.", 300, -50)

    -- 2) Draw the slot reels
    local SLOT_WIDTH, SLOT_HEIGHT = 100, 120
    local REEL_SPACING = 15
    local startX = (love.graphics.getWidth() - (3 * SLOT_WIDTH + 2 * REEL_SPACING)) / 2
    local startY = 50

    for i = 1, 3 do
        -- Reel BG
        love.graphics.setColor(0.2, 0.2, 0.2)
        love.graphics.rectangle("fill", 
            startX + (i-1) * (SLOT_WIDTH + REEL_SPACING),
            startY,
            SLOT_WIDTH,
            SLOT_HEIGHT,
            10, 10
        )
        -- Symbol
        love.graphics.setColor(1,1,1)
        local index = game.slots[i]
        local img = game.images[index]
        if img then
            love.graphics.draw(
                img,
                startX + (i-1)*(SLOT_WIDTH + REEL_SPACING),
                startY,
                0,
                SLOT_WIDTH / img:getWidth(),
                SLOT_HEIGHT / img:getHeight()
            )
        end
        -- Reel border
        love.graphics.setColor(1,0.84,0)
        love.graphics.rectangle("line",
            startX + (i-1)*(SLOT_WIDTH + REEL_SPACING),
            startY,
            SLOT_WIDTH,
            SLOT_HEIGHT,
            10, 10
        )
    end

    -- 3) Lever
    local leverX, leverY = startX - 150, startY + 20
    love.graphics.setColor(1,1,1)
    if leverUpImage and leverDownImage then
        if game.leverState == "up" then
            love.graphics.draw(leverUpImage, leverX, leverY, 0, 1, 1)
        else
            love.graphics.draw(leverDownImage, leverX, leverY, 0, 1, 1)
        end
    else
        -- placeholder if no images
        love.graphics.setColor(0,1,0)
        love.graphics.print("Lever: "..game.leverState, leverX, leverY)
    end

    -- 4) Button prompt (or user instruction)
    local buttonX = love.graphics.getWidth()/2 - 200
    local buttonY = 200
    love.graphics.setColor(198/255, 57/255, 57/255)
    love.graphics.rectangle("fill", buttonX, buttonY, 400, 50, 15, 15)
    love.graphics.setColor(235/255, 48/255, 48/255)
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", buttonX, buttonY, 400, 50, 15, 15)
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1,1,1)
    love.graphics.printf("CLICK ANYWHERE TO SPIN", buttonX, buttonY + 10, 400, "center")

    -- 5) Result message
    if game.result ~= "" then
        love.graphics.setFont(game.largeFont)
        love.graphics.setColor(0.2, 0.2, 0.2, 0.8)
        love.graphics.rectangle("fill", love.graphics.getWidth()/2 - 250, -10, 500, 50, 20, 20)
        love.graphics.setColor(1, 0.84, 0)
        love.graphics.rectangle("line", love.graphics.getWidth()/2 - 250, -10, 500, 50, 20, 20)
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf(game.result, 0, 0, love.graphics.getWidth(), "center")
    end

    -- 6) Money/leaderboard
    love.graphics.setFont(game.largeFont)

    -------------------------------------------
    -- NEW: Build a sortable list of all players
    -------------------------------------------
    local leaderboard = {}
    for playerName, playerData in pairs(world) do
        local money = playerData.params.money or 0
        table.insert(leaderboard, {name = playerName, money = money})
    end

    -------------------------------------------
    -- NEW: Sort the list by money descending
    -------------------------------------------
    table.sort(leaderboard, function(a, b)
        return a.money > b.money
    end)

    -------------------------------------------
    -- NEW: Draw them in sorted order
    -------------------------------------------
    local yOffset = 300
    love.graphics.setColor(1,0.84,0)
    for i, entry in ipairs(leaderboard) do
        local displayText = entry.name .. ": " .. tostring(entry.money)
        love.graphics.print(displayText, 300, yOffset)
        yOffset = yOffset + 35
    end

    -- 7) Money particles
    for _,p in ipairs(moneyParticles) do
        love.graphics.setColor(1,1,1, p.alpha)
        love.graphics.draw(moneyImage, p.x, p.y, p.rot, 0.5, 0.5, moneyImage:getWidth()/2, moneyImage:getHeight()/2)
    end
end

---------------------------------------------------------------------
-- love.mousepressed => Start the spin
---------------------------------------------------------------------
function love.mousepressed(mx, my, button)
    -- Only spin if not currently spinning
    if not game.spinning then
        slots.spin()
    end
end

---------------------------------------------------------------------
-- Start the spin with a more immersive approach
---------------------------------------------------------------------
function slots.spin()
    -- 1) Check money
    local player = world[nameInput.text]
    if player and player.params and player.params.money then
        if player.params.money < game.betAmount then
            game.result = "You don't have enough money to play!"
            game.resultTimer = 2
            return
        end
        player.params.money = player.params.money - game.betAmount
        setParameter(nameInput.text, 'money', player.params.money)
    else
        game.result = "Money data not available."
        game.resultTimer = 2
        return
    end

    -- 2) Decide final results
    for i=1,3 do
        game.finalSlots[i] = love.math.random(1, #game.images)
    end

    -- 3) Start the spin on reel 1
    game.currentReel = 1
    game.reelTimer = 0
    game.tickAccumulator = 0
    game.spinning = true
    game.result = ""

    -- 4) Lever down for 0.5s
    game.leverState = "down"
    game.leverDownTimer = 0.5
end

---------------------------------------------------------------------
-- checkWin => Once all reels are locked, see if you won
---------------------------------------------------------------------
function slots.checkWin()
    local s1, s2, s3 = game.slots[1], game.slots[2], game.slots[3]
    local winAmount = 0

    if (s1 == s2) and (s2 == s3) then
        winAmount = game.betAmount * 5
        game.result = "Jackpot! You win $"..winAmount.."!"
        superwinSound:play()
        spawnMoneyExplosion(love.graphics.getWidth()/2, 100, 100)
    elseif (s1 == s2) or (s2 == s3) or (s1 == s3) then
        winAmount = game.betAmount * 2
        game.result = "Matched two peeps! You win $"..winAmount.."!"
        winSound:play()
        spawnMoneyExplosion(love.graphics.getWidth()/2, 100, 50)
    else
        winAmount = 0
        game.result = "No match! Better luck next time."
    end

    -- Update player's money
    local player = world[nameInput.text]
    if player and player.params then
        player.params.money = player.params.money + winAmount
        setParameter(nameInput.text, 'money', player.params.money)
    end

    game.resultTimer = 2
end

---------------------------------------------------------------------
-- Utility function: setParameter
---------------------------------------------------------------------
function setParameter(playerName, param, value)
    if world[playerName] then
        world[playerName].params = world[playerName].params or {}
        world[playerName].params[param] = value
        -- Send update to server
        local params = string.format("{%s=%d}", param, value)
        local dg = string.format("%s %s %s", playerName, "at", params)
        udp:send(dg)
        return true
    end
    return false
end

return slots

------------------------------------------------------
-- mainMenu.lua (key changes)
------------------------------------------------------
mainMenu = {}

local suit = require("Libraries/SUIT")
local CScreen = require("Libraries/cscreen")

nameInput = { text = "" }

-------------------------------------------
-- We'll store and manage these outside
local fallingMoney = {}  -- list of money objects
local spawnTimer = 0     -- track when to spawn next
local moneyImage = nil   -- will hold the loaded sprite
-------------------------------------------

function mainMenu.load()
    love.window.setTitle("Awesome Game - Main Menu")

    screenWidthA = love.graphics.getWidth()
    screenHeightA = love.graphics.getHeight()
    screenWidth= 1920
    screenHeight = 1080

    -- Initialize
    CScreen.init(1920, 1080, true)
    love.keyboard.setKeyRepeat(true)

    moneyImage = love.graphics.newImage("Sprites/money.png")

    love.math.setRandomSeed(os.time())

    -- Set SUIT colors
    suit.theme.color.normal.fg = {255,255,255}
    suit.theme.color.hovered = {bg = {200,230,255}, fg = {0,0,0}}
    suit.theme.color.active = {bg = {150,150,150}, fg = {0,0,0}}

    -- -- Load font
    font = love.graphics.newFont("/Fonts/VCR_OSD_MONO.ttf", 100 * math.min(scaleStuff("w"), scaleStuff("h"))) -- The font
    font1 = love.graphics.newFont("/Fonts/VCR_OSD_MONO.ttf", 75 * math.min(scaleStuff("w"), scaleStuff("h")))
    font2 = love.graphics.newFont("/Fonts/VCR_OSD_MONO.ttf", 50 * math.min(scaleStuff("w"), scaleStuff("h")))
    font3 = love.graphics.newFont("/Fonts/VCR_OSD_MONO.ttf", 25 * math.min(scaleStuff("w"), scaleStuff("h")))
    love.graphics.setFont(font)
    love.keyboard.setKeyRepeat(true)
end

function mainMenu.update(dt)

    ------------------------------------------------------
    -- 1) Update “falling money” logic
    ------------------------------------------------------
    spawnTimer = spawnTimer - dt
    if spawnTimer <= 0 then
        spawnTimer = 0.3 -- reset
        spawnMoney()
    end

    for i = #fallingMoney, 1, -1 do
        local m = fallingMoney[i]
        m.y = m.y + (m.speed * dt)
        m.rotation = m.rotation + (m.rotationSpeed * dt)

        -- remove if off-screen
        if m.y > screenHeightA + 200 then
            table.remove(fallingMoney, i)
        end
    end

    ------------------------------------------------------
    -- 2) SUIT Elements (Labels, Input, Buttons)
    ------------------------------------------------------

    -- Create suit GUI elements
    love.graphics.setFont(font)
    suit.Label("Welcome to Multiplayer Minor Gambling (MMG)", (screenWidthA/ 2 - 750) * scaleStuff("w"), (25) * scaleStuff("h"), 1500, 200)
    love.graphics.setFont(font2)
    suit.Label("The Online Multiplayer Gambling Game For Minors", (screenWidthA/ 2 - 400) * scaleStuff("w"), (300) * scaleStuff("h"), 800, 100)
    
    love.graphics.setFont(font3)
    suit.Label("Please enter your name to start:", (screenWidthA/ 2 - 400) * scaleStuff("w"), (screenHeight / 2 - 25) * scaleStuff("h"), 800, 100)
    suit.Input(nameInput, screenWidthA / 2 - 200, 75 + screenHeightA/2, 400, 75)

    love.graphics.setFont(font)
    if suit.Button("Start", ((screenWidthA/ 2) - 200) * scaleStuff("w"), (screenHeight - 275) * scaleStuff("h"),
        400 * scaleStuff("w"), 150 * scaleStuff("h")).hit then
        -- Strip spaces from nameInput.text
        nameInput.text = nameInput.text:gsub("%s+", "")

        if nameInput.text ~= "" then
            return "startGame"
        end
    end

end

function mainMenu.draw()
    CScreen.apply()

    -- Draw a background color
    love.graphics.clear(0.1, 0.1, 0.1)

    -- 1) Draw the fallingMoney sprites BEHIND the UI
    drawFallingMoney()

    CScreen.cease()

    -- 2) Draw SUIT UI on top
    suit.draw()
end

------------------------------------------------------
-- Helper: spawnMoney spawns one "bill" up top
------------------------------------------------------
function spawnMoney()
    if not moneyImage then return end

    local m = {}
    m.x = math.random(0, screenWidthA)
    m.y = -moneyImage:getHeight() -- just above the screen
    m.speed = math.random(40, 120) -- random fall speed
    m.rotation = math.random() * 2 * math.pi
    m.rotationSpeed = (math.random() - 0.5) * 2  -- random spin

    table.insert(fallingMoney, m)
end

------------------------------------------------------
-- Helper: draw the falling money
------------------------------------------------------
function drawFallingMoney()
    if not moneyImage then return end

    for i, m in ipairs(fallingMoney) do
        local cx = moneyImage:getWidth() / 2
        local cy = moneyImage:getHeight() / 2
        love.graphics.draw(
            moneyImage,
            m.x, m.y,
            m.rotation,
            1, 1,
            cx, cy
        )
    end
end

------------------------------------------------------
-- SUIT input bridging
------------------------------------------------------
function love.textinput(t)
    suit.textinput(t)
end

function love.keypressed(key)
    suit.keypressed(key)
    if key == "]" or key == "escape" then
        love.event.quit()
    end
end


function mainMenu.drawSUIT() -- Draws SUIT Elements
    suit.draw()
end

function menuGUIUpdate(dt)
    
end

function love.textinput(t)
    suit.textinput(t)
end

function love.keypressed(key)
    suit.keypressed(key)
    
    if key == "]" or key == "escape" then -- Exit the game (Debug)
    love.event.quit()
    end
end

function scaleStuff(widthorheight)
    local scale = 1
    if widthorheight == "w" then -- width calc
        scale = screenWidthA / screenWidth
    elseif widthorheight == "h" then -- height calc
        scale = screenHeightA / screenHeight
    else
        print("Function usage error: scaleStuff() w/h not specified.")
    end

    return scale
end

-- Scaling Function
function love.resize(width, height)
    CScreen.update(width, height)
end

function love.resize(width, height)
    CScreen.update(width, height)
end

return mainMenu

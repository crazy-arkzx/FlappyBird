-- Flappy Bird Feito em lua com Löve2d
-- Licence MIT
-- Execute o Jogo no Aplicado Oficial da Löve2d
-- Link: https://github.com/love2d/love/releases/download/11.5/love-11.5-android.apk
-- Execute o Arquivo FlappyBird.love Para Iniciar o Game!
-- OBS: O Script Pega Apenas no Mobile

-- Variáveis
local bird = {}
local pipes = {}
local grounds = {}
local gameState = "start"
local score = 0
local highScore = 0
local font
local particles = {}
local stars = {}
local mode = "day"
local difficultyLevel = 1
local frameCount = 0
local levelUpScore = 10

-- Cores
local colors = {
    skyDay = {0.4, 0.7, 1},
    skyNight = {0.1, 0.1, 0.3},
    ground = {0.82, 0.7, 0.2},
    pipe = {0.2, 0.8, 0.2},
    pipeShade = {0.1, 0.6, 0.1},
    birdOrange = {0.9, 0.6, 0.1},
    birdYellow = {1, 0.9, 0.2},
    birdWhite = {1, 1, 1},
    birdRed = {0.9, 0.2, 0.2},
    birdEye = {0, 0, 0},
    star = {1, 1, 0.8}
}

-- Constantes
local GRAVITY = 700
local JUMP_VELOCITY = -350
local BIRD_WIDTH = 34
local BIRD_HEIGHT = 24
local PIPE_WIDTH = 52
local PIPE_GAP = 150
local GROUND_HEIGHT = 112
local PIPE_SPEED = 150
local PIPE_SPAWN_TIME = 2
local timeUntilNextPipe = 0
local screenScale = 1
local PARTICLE_LIFETIME = 1
local STAR_COUNT = 50
local ACHIEVEMENTS = {
    {score = 5, message = "Ninja", displayed = false},
    {score = 10, message = "Expert", displayed = false},
    {score = 25, message = "Hacker", displayed = false},
    {score = 50, message = "Deus", displayed = false}
}
local achievementDisplay = {message = "", timer = 0, duration = 2}
local sounds = {}
local canvasCache = {}

function love.load()
    love.graphics.setDefaultFilter("nearest", "nearest")
    
    math.randomseed(os.time())
    
    font = love.graphics.newFont(36)
    
    setupMobile()
    createSounds()
    createStars()
    
    resetGame()
end

function createSounds()
    sounds.jump = love.audio.newSource(createJumpSound(), "static")
    sounds.score = love.audio.newSource(createScoreSound(), "static")
    sounds.hit = love.audio.newSource(createHitSound(), "static")
end

function createJumpSound()
    local sampleRate = 44100
    local soundData = love.sound.newSoundData(sampleRate / 4, sampleRate, 16, 1)
    
    for i = 0, soundData:getSampleCount() - 1 do
        local t = i / sampleRate
        local s = math.sin(2 * math.pi * 440 * t) * math.exp(-t * 10) * 0.5
        soundData:setSample(i, s)
    end
    
    return soundData
end

function createScoreSound()
    local sampleRate = 44100
    local soundData = love.sound.newSoundData(sampleRate / 4, sampleRate, 16, 1)
    
    for i = 0, soundData:getSampleCount() - 1 do
        local t = i / sampleRate
        local s = math.sin(2 * math.pi * 880 * t) * math.exp(-t * 5) * 0.5
        soundData:setSample(i, s)
    end
    
    return soundData
end

function createHitSound()
    local sampleRate = 44100
    local soundData = love.sound.newSoundData(sampleRate / 3, sampleRate, 16, 1)
    
    for i = 0, soundData:getSampleCount() - 1 do
        local t = i / sampleRate
        local s = math.sin(2 * math.pi * 220 * t) * math.exp(-t * 8) * 0.7
        soundData:setSample(i, s)
    end
    
    return soundData
end

function setupMobile()
    love.window.setMode(0, 0, {resizable=false})
    
    local width, height = love.graphics.getDimensions()
    
    screenScale = height / 512
    
    if love.system.getOS() == "Android" or love.system.getOS() == "iOS" then
        love.touch = {}
        love.touch.getTouches = love.touch.getTouches or function() return {} end
    end
end

function createStars()
    for i = 1, STAR_COUNT do
        table.insert(stars, {
            x = math.random(0, love.graphics.getWidth()),
            y = math.random(0, love.graphics.getHeight() - GROUND_HEIGHT * screenScale),
            size = math.random(1, 3),
            alpha = math.random(5, 10) / 10,
            blinkSpeed = math.random(1, 5) / 10
        })
    end
end

function resetGame()
    bird = {
        x = love.graphics.getWidth() / 4,
        y = love.graphics.getHeight() / 2,
        width = BIRD_WIDTH,
        height = BIRD_HEIGHT,
        velocity = 0,
        rotation = 0,
        color = "orange",
        animation = {
            frames = {1, 2, 3, 2},
            currentFrame = 1,
            timer = 0,
            interval = 0.1
        },
        trail = {}
    }
    
    pipes = {}
    grounds = {}
    particles = {}
    createGrounds()
    
    gameState = "start"
    score = 0
    timeUntilNextPipe = 0
    difficultyLevel = 1
    
    for i, achievement in ipairs(ACHIEVEMENTS) do
        achievement.displayed = false
    end
    
    if math.random() > 0.5 then
        mode = "night"
    else
        mode = "day"
    end
    
    local birdColors = {"orange", "yellow", "red", "white"}
    bird.color = birdColors[math.random(1, #birdColors)]
    
    canvasCache = {}
end

function createGrounds()
    local groundWidth = 336
    local screenWidth = love.graphics.getWidth()
    local numGrounds = math.ceil(screenWidth / groundWidth) + 1
    
    for i = 1, numGrounds do
        table.insert(grounds, {
            x = (i - 1) * groundWidth * screenScale,
            y = love.graphics.getHeight() - GROUND_HEIGHT * screenScale
        })
    end
end

function love.update(dt)
    frameCount = frameCount + 1
    
    bird.animation.timer = bird.animation.timer + dt
    if bird.animation.timer >= bird.animation.interval then
        bird.animation.timer = bird.animation.timer - bird.animation.interval
        bird.animation.currentFrame = bird.animation.currentFrame % #bird.animation.frames + 1
    end
    
    for i, star in ipairs(stars) do
        star.alpha = 0.5 + math.sin(love.timer.getTime() * star.blinkSpeed) * 0.5
    end
    
    if achievementDisplay.timer > 0 then
        achievementDisplay.timer = achievementDisplay.timer - dt
    end
    
    if gameState == "play" then
        bird.velocity = bird.velocity + GRAVITY * dt
        bird.y = bird.y + bird.velocity * dt
        
        bird.rotation = math.min(math.max(-0.5, bird.velocity / 800), 1.3)
        
        if frameCount % 5 == 0 then
            table.insert(bird.trail, {
                x = bird.x,
                y = bird.y,
                age = 0
            })
            
            if #bird.trail > 5 then
                table.remove(bird.trail, 1)
            end
        end
        
        for i, trailPoint in ipairs(bird.trail) do
            trailPoint.age = trailPoint.age + dt
            if trailPoint.age > 0.5 then
                table.remove(bird.trail, i)
            end
        end
        
        for i, ground in ipairs(grounds) do
            ground.x = ground.x - PIPE_SPEED * difficultyLevel * dt
            
            if ground.x <= -336 * screenScale then
                ground.x = ground.x + 336 * screenScale * #grounds
            end
        end
        
        timeUntilNextPipe = timeUntilNextPipe - dt
        if timeUntilNextPipe <= 0 then
            spawnPipe()
            timeUntilNextPipe = PIPE_SPAWN_TIME / difficultyLevel
        end
        
        for i = #pipes, 1, -1 do
            local pipe = pipes[i]
            pipe.x = pipe.x - PIPE_SPEED * difficultyLevel * dt
            
            if pipe.x < -PIPE_WIDTH * screenScale then
                table.remove(pipes, i)
            end
            
            if not pipe.scored and pipe.x + PIPE_WIDTH * screenScale < bird.x then
                pipe.scored = true
                score = score + 1
                sounds.score:stop()
                sounds.score:play()
                
                checkAchievements()
                
                updateDifficulty()
                
                if score > highScore then
                    highScore = score
                end
            end
        end
        
        for i = #particles, 1, -1 do
            local p = particles[i]
            p.x = p.x + p.vx * dt
            p.y = p.y + p.vy * dt
            p.vy = p.vy + GRAVITY * 0.5 * dt
            p.life = p.life - dt
            
            if p.life <= 0 then
                table.remove(particles, i)
            end
        end
        
        checkCollisions()
    end
end

function updateDifficulty()
    local newLevel = math.floor(score / levelUpScore) + 1
    newLevel = math.min(newLevel, 3)
    
    if newLevel > difficultyLevel then
        difficultyLevel = newLevel
        showAchievement("Nível " .. difficultyLevel .. "!")
    end
end

function checkAchievements()
    for i, achievement in ipairs(ACHIEVEMENTS) do
        if score >= achievement.score and not achievement.displayed then
            achievement.displayed = true
            showAchievement(achievement.message)
            return
        end
    end
end

function showAchievement(message)
    achievementDisplay.message = message
    achievementDisplay.timer = achievementDisplay.duration
end

function spawnPipe()
    local screenHeight = love.graphics.getHeight()
    local groundY = screenHeight - GROUND_HEIGHT * screenScale
    
    local adjustedGap = PIPE_GAP * screenScale * (1.2 - (difficultyLevel * 0.1))
    
    local minY = 100 * screenScale
    local maxY = groundY - adjustedGap - 100 * screenScale
    local pipeY = love.math.random(minY, maxY)
    
    local oscillation = 0
    if difficultyLevel >= 2 then
        oscillation = difficultyLevel - 1
    end
    
    table.insert(pipes, {
        x = love.graphics.getWidth(),
        y = pipeY,
        width = PIPE_WIDTH * screenScale,
        scored = false,
        oscillation = oscillation,
        oscillationSpeed = love.math.random(1, 3),
        oscillationPhase = love.math.random() * math.pi * 2
    })
end

function createExplosion(x, y)
    for i = 1, 20 do
        local angle = math.random() * math.pi * 2
        local speed = math.random(50, 150)
        table.insert(particles, {
            x = x,
            y = y,
            vx = math.cos(angle) * speed,
            vy = math.sin(angle) * speed,
            color = bird.color,
            size = math.random(2, 6),
            life = math.random() * PARTICLE_LIFETIME
        })
    end
end

function checkCollisions()
    local birdBox = {
        x = bird.x - bird.width * screenScale / 2,
        y = bird.y - bird.height * screenScale / 2,
        width = bird.width * screenScale * 0.8,
        height = bird.height * screenScale * 0.8
    }
    
    if bird.y + bird.height * screenScale / 2 >= love.graphics.getHeight() - GROUND_HEIGHT * screenScale then
        createExplosion(bird.x, bird.y)
        sounds.hit:play()
        gameState = "gameover"
        return
    end
    
    if bird.y - bird.height * screenScale / 2 <= 0 then
        bird.y = bird.height * screenScale / 2
        bird.velocity = 0
    end
    
    for _, pipe in ipairs(pipes) do
        local pipeYOffset = 0
        if pipe.oscillation > 0 then
            pipeYOffset = math.sin(love.timer.getTime() * pipe.oscillationSpeed + pipe.oscillationPhase) * 30 * pipe.oscillation
        end
        
        if checkBoxCollision(birdBox, {
            x = pipe.x,
            y = 0,
            width = pipe.width,
            height = pipe.y + pipeYOffset
        }) then
            createExplosion(bird.x, bird.y)
            sounds.hit:play()
            gameState = "gameover"
            return
        end
        
        if checkBoxCollision(birdBox, {
            x = pipe.x,
            y = pipe.y + pipeYOffset + PIPE_GAP * screenScale,
            width = pipe.width,
            height = love.graphics.getHeight() - (pipe.y + pipeYOffset + PIPE_GAP * screenScale)
        }) then
            createExplosion(bird.x, bird.y)
            sounds.hit:play()
            gameState = "gameover"
            return
        end
    end
end

function checkBoxCollision(a, b)
    return a.x < b.x + b.width and
           a.x + a.width > b.x and
           a.y < b.y + b.height and
           a.y + a.height > b.y
end

function drawBird(x, y, rotation, frame, color)
    for i, trailPoint in ipairs(bird.trail) do
        local alpha = 0.3 * (1 - trailPoint.age / 0.5)
        local size = (1 - trailPoint.age / 0.5) * 0.5
        
        local birdColor = getBirdMainColor(color)
        love.graphics.setColor(birdColor[1], birdColor[2], birdColor[3], alpha)
        love.graphics.circle("fill", trailPoint.x, trailPoint.y, BIRD_WIDTH * screenScale * 0.2 * size)
    end
    
    love.graphics.push()
    love.graphics.translate(x, y)
    love.graphics.rotate(rotation)
    
    love.graphics.setColor(getBirdMainColor(color))
    love.graphics.ellipse("fill", 0, 0, BIRD_WIDTH/2 * screenScale, BIRD_HEIGHT/2 * screenScale)
    
    local wingOffset = 0
    if frame == 1 then wingOffset = -2
    elseif frame == 2 then wingOffset = 0
    elseif frame == 3 then wingOffset = 2
    end
    
    love.graphics.setColor(getBirdSecondaryColor(color))
    love.graphics.ellipse("fill", -BIRD_WIDTH/4 * screenScale, wingOffset * screenScale, BIRD_WIDTH/4 * screenScale, BIRD_HEIGHT/3 * screenScale)
    
    love.graphics.setColor(1, 1, 1)
    love.graphics.circle("fill", BIRD_WIDTH/4 * screenScale, -BIRD_HEIGHT/6 * screenScale, BIRD_WIDTH/8 * screenScale)
    
    love.graphics.setColor(0, 0, 0)
    love.graphics.circle("fill", BIRD_WIDTH/4 * screenScale + BIRD_WIDTH/20 * screenScale, -BIRD_HEIGHT/6 * screenScale, BIRD_WIDTH/16 * screenScale)
    
    love.graphics.setColor(0.9, 0.6, 0.1)
    love.graphics.polygon("fill", 
        BIRD_WIDTH/2 * screenScale, 0,
        BIRD_WIDTH/2 * screenScale + BIRD_WIDTH/4 * screenScale, BIRD_HEIGHT/8 * screenScale,
        BIRD_WIDTH/2 * screenScale + BIRD_WIDTH/4 * screenScale, -BIRD_HEIGHT/8 * screenScale
    )
    
    love.graphics.pop()
end

function getBirdMainColor(colorName)
    if colorName == "orange" then return colors.birdOrange
    elseif colorName == "yellow" then return colors.birdYellow
    elseif colorName == "red" then return colors.birdRed
    elseif colorName == "white" then return colors.birdWhite
    else return colors.birdOrange
    end
end

function getBirdSecondaryColor(colorName)
    local mainColor = getBirdMainColor(colorName)
    return {mainColor[1] * 0.8, mainColor[2] * 0.8, mainColor[3] * 0.8}
end

function drawPipe(x, y, isTop)
    local cacheKey = "pipe_" .. tostring(isTop)
    if not canvasCache[cacheKey] then
        local canvas = love.graphics.newCanvas(PIPE_WIDTH * screenScale, love.graphics.getHeight())
        love.graphics.setCanvas(canvas)
        
        love.graphics.setColor(colors.pipe)
        
        if isTop then
            love.graphics.rectangle("fill", 0, 0, PIPE_WIDTH * screenScale, love.graphics.getHeight())
            
            love.graphics.setColor(colors.pipeShade)
            love.graphics.rectangle("fill", 0, love.graphics.getHeight() - 30 * screenScale, PIPE_WIDTH * screenScale, 30 * screenScale)
            
            love.graphics.setColor(colors.pipe)
            love.graphics.rectangle("fill", 3 * screenScale, love.graphics.getHeight() - 30 * screenScale + 3 * screenScale, 
                                    PIPE_WIDTH * screenScale - 6 * screenScale, 24 * screenScale)
        else
            love.graphics.rectangle("fill", 0, 0, PIPE_WIDTH * screenScale, love.graphics.getHeight())
            
            love.graphics.setColor(colors.pipeShade)
            love.graphics.rectangle("fill", 0, 0, PIPE_WIDTH * screenScale, 30 * screenScale)
            
            love.graphics.setColor(colors.pipe)
            love.graphics.rectangle("fill", 3 * screenScale, 3 * screenScale, 
                                    PIPE_WIDTH * screenScale - 6 * screenScale, 24 * screenScale)
        end
        
        love.graphics.setCanvas()
        canvasCache[cacheKey] = canvas
    end
    
    love.graphics.setColor(1, 1, 1)
    if isTop then
        love.graphics.draw(canvasCache[cacheKey], x, 0, 0, 1, y / love.graphics.getHeight())
    else
        love.graphics.draw(canvasCache[cacheKey], x, y)
    end
end

function drawGround(x, y)
    if not canvasCache["ground"] then
        local groundWidth = 336 * screenScale
        local canvas = love.graphics.newCanvas(groundWidth, GROUND_HEIGHT * screenScale)
        love.graphics.setCanvas(canvas)
        
        love.graphics.setColor(colors.ground)
        love.graphics.rectangle("fill", 0, 0, groundWidth, GROUND_HEIGHT * screenScale)
        
        love.graphics.setColor(0.7, 0.6, 0.1)
        for i = 0, 10 do
            love.graphics.rectangle("fill", i * 30 * screenScale, 0, 15 * screenScale, 15 * screenScale)
            love.graphics.rectangle("fill", (i * 30 + 15) * screenScale, 15 * screenScale, 15 * screenScale, 15 * screenScale)
        end
        
        love.graphics.setCanvas()
        canvasCache["ground"] = canvas
    end
    
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(canvasCache["ground"], x, y)
end

function drawBackground()
    if mode == "day" then
        love
        .graphics.setColor(colors.skyDay)
    else
        love.graphics.setColor(colors.skyNight)
    end
    love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
    
    if mode == "night" then
        for _, star in ipairs(stars) do
            love.graphics.setColor(colors.star[1], colors.star[2], colors.star[3], star.alpha)
            love.graphics.circle("fill", star.x, star.y, star.size * screenScale)
        end
    end
    
    if mode == "day" then
        love.graphics.setColor(0.9, 0.9, 1, 0.8)
        love.graphics.ellipse("fill", 
            love.graphics.getWidth() * 0.2, 
            love.graphics.getHeight() * 0.2, 
            80 * screenScale, 40 * screenScale)
            
        love.graphics.ellipse("fill", 
            love.graphics.getWidth() * 0.7, 
            love.graphics.getHeight() * 0.3, 
            60 * screenScale, 30 * screenScale)
    else
        love.graphics.setColor(0.9, 0.9, 0.8)
        love.graphics.circle("fill", love.graphics.getWidth() * 0.8, love.graphics.getHeight() * 0.2, 40 * screenScale)
        
        love.graphics.setColor(0.8, 0.8, 0.7)
        love.graphics.circle("fill", love.graphics.getWidth() * 0.8 - 15 * screenScale, love.graphics.getHeight() * 0.2 - 10 * screenScale, 8 * screenScale)
        love.graphics.circle("fill", love.graphics.getWidth() * 0.8 + 10 * screenScale, love.graphics.getHeight() * 0.2 + 15 * screenScale, 6 * screenScale)
        love.graphics.circle("fill", love.graphics.getWidth() * 0.8 + 5 * screenScale, love.graphics.getHeight() * 0.2 - 12 * screenScale, 5 * screenScale)
    end
end

function love.draw()
    drawBackground()
    
    for _, pipe in ipairs(pipes) do
        local pipeYOffset = 0
        if pipe.oscillation > 0 then
            pipeYOffset = math.sin(love.timer.getTime() * pipe.oscillationSpeed + pipe.oscillationPhase) * 30 * pipe.oscillation
        end
        
        drawPipe(pipe.x, pipe.y + pipeYOffset, true)
        
        drawPipe(pipe.x, pipe.y + pipeYOffset + PIPE_GAP * screenScale, false)
    end
    
    for _, ground in ipairs(grounds) do
        drawGround(ground.x, ground.y)
    end
    
    drawBird(bird.x, bird.y, bird.rotation, bird.animation.frames[bird.animation.currentFrame], bird.color)
    
    for _, p in ipairs(particles) do
        local particleColor = getBirdMainColor(p.color)
        love.graphics.setColor(particleColor[1], particleColor[2], particleColor[3], p.life / PARTICLE_LIFETIME)
        love.graphics.circle("fill", p.x, p.y, p.size * screenScale)
    end
    
    love.graphics.setFont(font)
    
    if gameState == "play" or gameState == "gameover" then
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf(tostring(score), 0, 50 * screenScale, love.graphics.getWidth(), "center")
    end
    
    if gameState == "start" then
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf("Toque Para Começar", 0, love.graphics.getHeight() / 3, love.graphics.getWidth(), "center")
        
        love.graphics.setColor(1, 1, 1, 0.8)
        love.graphics.printf("Toque na Tela Para Fazer o Bird Voar", 0, love.graphics.getHeight() / 2, love.graphics.getWidth(), "center")
        
        if highScore > 0 then
            love.graphics.printf("Recorde: " .. highScore, 0, love.graphics.getHeight() / 2 + 50 * screenScale, love.graphics.getWidth(), "center")
        end
    elseif gameState == "gameover" then
        love.graphics.setColor(1, 0.3, 0.3)
        love.graphics.printf("Game Over", 0, love.graphics.getHeight() / 3, love.graphics.getWidth(), "center")
        
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf("Pontuação: " .. score, 0, love.graphics.getHeight() / 2 - 30 * screenScale, love.graphics.getWidth(), "center")
        love.graphics.printf("Recorde: " .. highScore, 0, love.graphics.getHeight() / 2 + 30 * screenScale, love.graphics.getWidth(), "center")
        love.graphics.printf("Toque Para Reiniciar", 0, love.graphics.getHeight() / 2 + 90 * screenScale, love.graphics.getWidth(), "center")
    end
    
    if gameState == "play" then
        love.graphics.setColor(1, 1, 1, 0.7)
        love.graphics.printf("Nível: " .. difficultyLevel, 20 * screenScale, 20 * screenScale, 200 * screenScale, "left")
    end
    
    if achievementDisplay.timer > 0 then
        local alpha = math.min(achievementDisplay.timer, 1)
        local y = love.graphics.getHeight() / 3 - 80 * screenScale
        
        love.graphics.setColor(0, 0, 0, 0.7 * alpha)
        love.graphics.rectangle("fill", 
            love.graphics.getWidth() / 2 - 150 * screenScale,
            y - 10 * screenScale,
            300 * screenScale,
            50 * screenScale,
            10 * screenScale
        )
        
        love.graphics.setColor(1, 1, 0, alpha)
        love.graphics.printf(achievementDisplay.message, 0, y, love.graphics.getWidth(), "center")
    end
end

function love.mousepressed(x, y, button)
    handleInput()
end

function love.touchpressed(id, x, y)
    handleInput()
end

function love.keypressed(key)
    if key == "space" then
        handleInput()
    end
end

function handleInput()
    if gameState == "start" then
        gameState = "play"
    elseif gameState == "play" then
        bird.velocity = JUMP_VELOCITY
        sounds.jump:stop()
        sounds.jump:play()
    elseif gameState == "gameover" then
        resetGame()
    end
end
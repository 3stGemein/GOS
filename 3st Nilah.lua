require('GGPrediction')


local version = "1.0"
local author = "3stGemein"
local champ = myHero.charName

local GameHeroCount     = Game.HeroCount
local GameHero          = Game.Hero
local GameMinionCount   = Game.MinionCount
local GameMinion        = Game.Minion
local Orbwalker         = _G.SDK.Orbwalker
local TargetSelector    = _G.SDK.TargetSelector
local TableInsert       = _G.table.insert
local ObjectManager     = _G.SDK.ObjectManager
local DamageLib         = _G.SDK.Damage
local Spell             = _G.SDK.Spell

local minenemies = 0
local Units = {}
local Turrets = {}
local Enemies = {}
local Allies = {}


local Enemys = {}
local Allys  = {}

local lastAttack = 0
local lastMove = 0

local function getDistanceSqr(p1, p2)
    local dx = p1.x - p2.x
    local dy = (p1.z or p1.y) - (p2.z or p2.y)
    return dx * dx + dy * dy
end

local function isValid(unit)
    if (unit and unit.valid
        and unit.isTargetable
        and unit.alive
        and unit.visible
        and unit.networkID
        and unit.health > 0
        and not unit.dead
    ) then 
        return true;
    end
    return false;
end

local function isReady(spell)
    return  myHero:GetSpellData(spell).currentCd == 0 and
            myHero:GetSpellData(spell).level > 0 and
            myHero:GetSpellData(spell).mana <= myHero.mana and
            Game.CanUseSpell(spell) == 0
end

local function LoadUnits()
	for i = 1, GameHeroCount() do
		local unit = GameHero(i); Units[i] = {unit = unit, spell = nil}
		if unit.team ~= myHero.team then TableInsert(Enemies, unit)
		elseif unit.team == myHero.team and unit ~= myHero then TableInsert(Allies, unit) end
	end
	for i = 1, GameTurretCount() do
		local turret = GameTurret(i)
		if turret and turret.isEnemy then TableInsert(Turrets, turret) end
	end
end

local function getEnemiesinRange(p1, range)
    local enemiesinrange = {}
    for i = 1, Game.HeroCount() do
        local hero = Game.Hero(i)
        if hero.isEnemy and not hero.dead and hero.pos:DistanceTo(p1) < range then
            TableInsert(enemiesinrange, hero)
        end
    end
    return enemiesinrange
end

local function getEnemyHeroesinRange(p1)
    return getEnemiesinRange(myHero.pos, p1)
end

local function onProcessSpell()
    for i = 1, #Units do
        local unit = Units[i].unit;
        local last = Units[i].spell; 
        local spell = unit.activeSpell
        if spell and last ~= (spell.name .. spell.endTime) and unit.activeSpell.valid then
            Units[i].spell = spell.name .. spell.endTime; return unit, spell
        end
    end
    return nil, nil
end

function onAA(hero)
    local unit, spell = onProcessSpell()
    if hero and isValid(hero) then
        if unit and unit.isEnemy and spell and spell.target == hero.handle then
            return true
        end
    end
    return false
end

class "Nilah"

local Menu = {}

function Nilah:__init()
    QSpelldata = {Hitchance = _G.HITCHANCE_HIGH, Type = _G.SPELLTYPE_LINE, Delay = 0.25, Radius = 150, Range = 600, Speed = 2600, Collision = false, MaxCollision = 0}
    ESpelldata = {Range = 550}
    RSpelldata = {Range = 450}

    Nilah:LoadMenu()

    local getDamage = function()
            local levelDmgTbl  = {5 , 10 , 15 , 20 , 25}
            local levelPctTbl  = { 0.9 , 1.0 , 1.1 , 1.15 , 1.2 }
            local levelDmg = levelDmgTbl[myHero:GetSpellData(_Q).level]
            local levelPct = levelPctTbl[myHero:GetSpellData(_Q).level]
            local dmg = levelDmg + myHero.totalDamage*levelPct
        return dmg
    end
    local QPred = GGPrediction:SpellPrediction(QSpelldata)
    local canLastHit = function()
        return false
    end
    local canLaneClear = function()
        return Menu.Clear.Qclear:Value()
    end

    local isReadyQ = function()
        return Spell:IsReady(_Q)
    end

    local clearmana = function()
        return Menu.Clear.Mana:Value()
    end

    
    Spell:SpellClear(_Q, QPred, isReadyQ, canLastHit, canLaneClear, getDamage)
    

    Callback.Add("Tick", function() Nilah:Tick() end)
    Callback.Add("Draw", function() Nilah:Draw() end)
end

function Nilah:LoadMenu()
    Menu = MenuElement({type = MENU, id = "3stNilah", name = "3st Nilah"})

    Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
        Menu.Combo:MenuElement({id = "Q", name = "Use [Q]", value = true})
        Menu.Combo:MenuElement({id = "R", name = "Use [R]", value = true})
        Menu.Combo:MenuElement({id = "Rhit", name = "Use [R] if hit", value = 3, min = 1, max = 5, step = 1})
    
    Menu:MenuElement({type = MENU, id = "AutoW", name = "Auto W"})
        Menu.AutoW:MenuElement({id = "W", name = "Auto [W]", value = false})
        Menu.AutoW:MenuElement({id = "HP", name = "HP %", value = 20, min = 0, max = 100, step = 1, identifier = "%"})

    Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
        Menu.Harass:MenuElement({id = "Q", name = "Use [Q]", value = false})
    
    Menu:MenuElement({type = MENU, id = "Clear", name = "WaveClear"})
        Menu.Clear:MenuElement({id = "Qclear", name = "Use [Q] for WaveClear", value = false})
    
    Menu:MenuElement({type = MENU, id = "Setting", name = "Settings"})
        Menu.Setting:MenuElement({id = "Qrange", name = "Max [Q] Range", value = 600, min = 0, max = 600, step = 1, callback = function(value)
            QSpelldata.Range = value
        end})
        Menu.Setting:MenuElement({id = "Rrange", name = "Max [R] Range", value = 450, min = 1, max = 450, step = 1, callback = function(value)
            RSpelldata.Range = value
        end})
        
        Menu.Setting:MenuElement({name = "[Q] HitChance", drop = {"High", "Normal"}, callback = function(value)
            if value == 1 then
                QSpelldata.Hitchance = _G.HITCHANCE_HIGH
            end
            if value == 2 then
                QSpelldata.Hitchance = _G.HITCHANCE_NORMAL
            end
        end})

    Menu:MenuElement({type = MENU, id = "Draw", name = "Drawing"})
        Menu.Draw:MenuElement({id = "Q", name = "Draw [Q] Range", value = false})
        Menu.Draw:MenuElement({id = "E", name = "Draw [E] Range", value = false})
        Menu.Draw:MenuElement({id = "R", name = "Draw [R] Range", value = false})
end

function Nilah:Tick()
    if myHero.dead or Game.IsChatOpen() or (ExtLibEvade and ExtLibEvade.Evading == true) then
        return
    end

    if Orbwalker.Modes[0] then
        Nilah:Combo()
    elseif Orbwalker.Modes[1] then
        Nilah:Harass()
    end

    Nilah:AutoW()
end

function Nilah:getTargetsInRange(range)
    local counter = 0
    for i = 1, #Enemies do
        local hero = Enemies[i]
        if isValid(hero) and getDistanceSqr(hero.pos, myHero.pos) < range * range then
            counter = counter + 1
        end
    end
    return counter
end

function Nilah:Combo()
    local target = TargetSelector:GetTarget(QSpelldata.Range)
    if target and Menu.Combo.Q:Value() then
        Nilah:CastQ(target)
    end
    if Menu.Combo.R:Value() then
        local number = Menu.Combo.Rhit:Value()
        Nilah:CastR(number)
    end
end

function Nilah:Harass()
    local target = TargetSelector:GetTarget(QSpelldata.Range)
    if target and Menu.Harass.Q:Value() then
        Nilah:CastQ(target)
    end
end

function Nilah:AutoW()
    if isReady(_W) and Menu.AutoW.W:Value() and myHero.health/myHero.maxHealth <= Menu.AutoW.HP:Value() / 100 then
        if onAA(myHero) then
            Control.CastSpell(HK_W)
        end
    end
end

function Nilah:CastQ(target)
    local QPred = GGPrediction:SpellPrediction(QSpelldata)
    QPred:GetPrediction(target, myHero)
    if isReady(_Q) and QPred:CanHit(QSpelldata.Hitchance) then
        Control.CastSpell(HK_Q, QPred.CastPosition)
    end
end

function Nilah:CastR(number)
    local Enemycount = getEnemyHeroesinRange(RSpelldata.Range)
    if #Enemycount >= number and isReady(_R) then
        Control.CastSpell(HK_R, myHero)
    end
end

function Nilah:Draw()
    if myHero.dead then
        return
    end

    if Menu.Draw.Q:Value() and isReady(_Q) then
        Draw.Circle(myHero.pos, QSpelldata.Range, Draw.Color(255, 255, 125, 149))
    end
    if Menu.Draw.E:Value() and isReady(_E) then
        Draw.Circle(myHero.pos, ESpelldata.Range, Draw.Color(255, 201, 125, 255))
    end
    if Menu.Draw.R:Value() and isReady(_R) then
        Draw.Circle(myHero.pos, RSpelldata.Range, Draw.Color(255, 125, 134, 255))
    end
end

function loadScript()
    if myHero.charName == "Nilah" then
        Nilah()
    end
end

local IsLoaded = false
Callback.Add("Tick", function()  
	if heroes == false then 
		local EnemyCount = CheckLoadedEnemyies()			
		if EnemyCount < 1 then
			LoadUnits()
		else
			heroes = true
		end
	else	
		if not IsLoaded then
            loadScript()
			DelayAction(function()
				if not Menu.Pred then return end
				if Menu.Pred.Change:Value() == 1 then
					require('GamsteronPrediction')
				elseif Menu.Pred.Change:Value() == 2 then
					require('PremiumPrediction')
				else
					require('GGPrediction')
				end	
			end, 1)
			IsLoaded = true
		end	
	end	
end)
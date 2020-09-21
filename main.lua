-- InfiniTurbo v1.1
--
-- Allow ship to turbo constantly even if the engine drains more than the power cell provides.
--
-- Binds:
--   /infiniturbo                Toggle turbo.
--   /infiniturbo on             Activate turbo.
--   /infiniturbo off            Deactivate turbo.
--
-- To change modes (can be changed with turbo active):
--   /infiniturbo stacking       Keep ship at exact speed to stack missiles (80m/s)
--   /infiniturbo speed          Turbo as fast as possible (keeping 25% charge for warp)
--   /infiniturbo energy         Keep the ship running fast, but slowly charge cell to 100%.
--
--
-- Written by igrok
--
--


infiniturbo = {}

-- functions
infiniturbo.turboon = {}
infiniturbo.turbooff = {}
infiniturbo.turbo = {}
infiniturbo.infiniturbo = {}
infiniturbo.on = {}
infiniturbo.off = {}


infiniturbo.running = false

-- Different turbo strategies are needed in different situations:
-- stacking  Keep ship at exact speed to stack missiles.
-- speed     Keep ship as fast as possible (keeping 25% charge for warp)
-- energy    Keep the ship running fast, but charge cell to 100%.
--
-- Default mode is speed.
infiniturbo.mode = "speed"

-- Missile stacking speed
infiniturbo.stackingSpeed = 80

-- Update status every 25 milliseconds
infiniturbo.timer = Timer()
infiniturbo.timeout = 25

-- Amount of energy in the cell when turbo started (or when current turbo stage started)
infiniturbo.cellStart = {}

-- Capacity of the power cell
infiniturbo.cellFull = {}

-- We can't keep the ship at exactly the same speed - we'll need a little leeway.
infiniturbo.delta = 1

-- Track energy as cell recharges
infiniturbo.charged = 0


-- In energy turbo mode, there are different stages:
-- init         infiniturbo just started recently - we'll bring the ship up to speed
-- recharge     Once up to speed, we will charge the cell
-- maintain     Once cell is charged, we will maintain
infiniturbo.energyStage = 'init'


function infiniturbo.turboon() gkinterface.GKProcessCommand('+turbo 1') end
function infiniturbo.turbooff() gkinterface.GKProcessCommand('+turbo 0') end


function infiniturbo.turbo()
    -- We can't work if there is currently no ship
    if infiniturbo.running and GetActiveShipID() then
        if infiniturbo.mode == "stacking" then
            local currentSpeed = GetActiveShipSpeed()

            if currentSpeed < infiniturbo.stackingSpeed then
                infiniturbo.turboon()
            elseif currentSpeed > (infiniturbo.stackingSpeed + infiniturbo.delta) then
                infiniturbo.turbooff()
            end

        elseif infiniturbo.mode == "speed" then
            local cellCurrent = GetActiveShipEnergy()

            -- turbo until the cell is almost 25% empty
            if cellCurrent < (0.26 * infiniturbo.cellFull) then
                infiniturbo.turbooff()
            else
                infiniturbo.turboon()
            end

        elseif infiniturbo.mode == "energy" then
            local cellCurrent = GetActiveShipEnergy()
        
            if infiniturbo.energyStage == 'init' then
                -- bring the ship up to speed (use 25% of the power cell)
                local use = infiniturbo.cellStart * 0.25

                if (infiniturbo.cellStart - cellCurrent) >= use  then
                    infiniturbo.turbooff()
                    infiniturbo.energyStage = 'recharge'
                    infiniturbo.charged = cellCurrent
                else
                    infiniturbo.turboon()
                end
            elseif infiniturbo.energyStage == 'recharge' then
                -- recharge the power cell without slowing down too much
                if cellCurrent >= (infiniturbo.cellFull - 1) then
                    infiniturbo.energyStage = 'maintain'
                elseif cellCurrent <= (infiniturbo.charged + 2) then
                    infiniturbo.charged = cellCurrent
                    infiniturbo.turbooff()
                elseif cellCurrent >= (infiniturbo.charged + 6) then
                    infiniturbo.turboon()
                end
            else
                -- try to keep the same velocity and cell charge
                local use = infiniturbo.cellFull * 0.98

                if cellCurrent <= use then
                    infiniturbo.turbooff()
                else
                    infiniturbo.turboon()
                end
            end
        end

        infiniturbo.timer:SetTimeout(infiniturbo.timeout, infiniturbo.turbo)
    end
end


function infiniturbo.on()
    -- determine the starting and max energy in the power cell
    infiniturbo.cellStart, infiniturbo.cellFull = GetActiveShipEnergy()
    -- full energy is returned as a float [0,1] - convert to actual energy value.
    if (infiniturbo.cellStart and infiniturbo.cellFull) then
        infiniturbo.cellFull = infiniturbo.cellStart / infiniturbo.cellFull
    end
    infiniturbo.running = true
    infiniturbo.energyStage = 'init'
    infiniturbo.charged = 0
    infiniturbo.timer:SetTimeout(infiniturbo.timeout, infiniturbo.turbo)
    infiniturbo.turboon()
end


function infiniturbo.off()
    infiniturbo.running = false
    infiniturbo.timer:Kill()
    infiniturbo.turbooff()
end


function infiniturbo.infiniturbo(data, args)
    if args == nil then
        -- Toggle infiniturbo
        if infiniturbo.running then
            infiniturbo.off()
        else
            infiniturbo.on()
        end
    else
        if args[1] == "on" then
            infiniturbo.on()
        elseif args[1] == "off" then
            infiniturbo.off()

        elseif args[1] == "stacking" then
            -- set missile stacking mode
            HUD:PrintSecondaryMsg("\127cd5c00Stacking turbo mode.\127o")
            infiniturbo.mode = "stacking"
        elseif args[1] == "speed" then
            -- set top speed mode
            HUD:PrintSecondaryMsg("\127cd5c00Speed turbo mode.\127o")
            infiniturbo.mode = "speed"
        elseif args[1] == "energy" then
            -- set energy conservation mode
            HUD:PrintSecondaryMsg("\127cd5c00Warp energy turbo mode.\127o")
            infiniturbo.mode = "energy"
        end

        -- reset condition/state when changing modes
        if infiniturbo.running then
            infiniturbo.on()
        end
    end

end

RegisterUserCommand("infiniturbo", infiniturbo.infiniturbo)


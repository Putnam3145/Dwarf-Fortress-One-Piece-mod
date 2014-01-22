function findDevilFruitPlant()
    local plants=df.global.world.raws.plants
    local nums={'bushes'={},'trees'={},'grasses'={}}
    for k,v in ipairs(nums) do
        v['min'],v['max']=plants[k..'_idx'][0],plants[k..'_idx'][#plants[k..'_idx']]
    end
    if nums.trees.min-nums.bushes.max<2 then devilFruitPlant=plants.all[nums.trees.min-1]
    elseif nums.bushes.min-nums.grasses.max<2 then devilFruitPlant=plants.all[nums.bushes.min-1] 
    else devilFruitPlant=plants.all[nums.grasses.min-1]
    end
    if not devilFruitPlant['id']:find('DEVIL_FRUIT') then
        for k,v in ipairs(df.global.world.raws.plants.all) do
            if v['id']:find('DEVIL_FRUIT') then return v,k end
        end
    end
end

function findStringInTable(tbl,str,key)
    if key then
        for k,v in ipairs(tbl) do
            if str:find(v[key]) then return true end
        end
    else
        for k,v in ipairs(tbl) do
            if str:find(v) then return true end
        end
    end
    return false
end

function unitHasDevilFruit(unitID)
    local unit = df.unit.find(unitID)
    for k,v in ipairs(unit.syndromes.active) do
        if findStringInTable(df.syndrome.find(v.type).syn_class,'DEVIL_FRUIT','value') then return true,v.type end
    end
    return false
end

function getDevilFruitMat(synID)
    for k,v in ipairs(devilFruitPlant.material) do
        if v.syndrome[0].id==synID then
            return dfhack.matinfo.find(devilFruitPlant.id,v.id)
        end
    end
end

function compareDistance(pos1,pos2)
    return math.sqrt((pos2.x-pos1.x)^2+(pos2.y-pos1.y)^2+(pos2.z-pos1.z)^2)
end

eventful=require('plugins.eventful')

eventful.enableEvent(eventful.eventType.SYNDROME,5)

eventful.enableEvent(eventful.eventType.UNIT_DEATH,5)

--[[
eventful.eventType=={
CONSTRUCTION
BUILDING
UNIT_DEATH
JOB_COMPLETED
INVASION
JOB_INITIATED
TICK
EVENT_MAX
SYNDROME
INVENTORY_CHANGE
ITEM_CREATED
}
]]

eventful.onSyndrome['onePieceDevilFruit']=function(unit_id,syndrome_index)
    local syndrome=df.syndrome.find(syndrome_index)
    if findStringInTable(syndrome.syn_class,'DEVIL_FRUIT','value') then
        local hasDevilFruit,devilFruitType=unitHasDevilFruit(unit_id)
        if devilFruitType~=syndrome_index then df.unit.find(unit_id).body.blood_count=0 end
    end
end

eventful.onUnitDeath['onePieceDevilFruitUser']=function(unit_id)
    local hasDevilFruit,unitDevilFruit=unitHasDevilFruit(unit_id)
    if hasDevilFruit then
        local closestPlant,unit,devilFruitMat={0,df.global.world.items.other.PLANT[0]},df.unit.find(unit_id),getDevilFruitMat(unitDevilFruit)
        for k,v in ipairs(df.global.world.items.other.PLANT) do
            if compareDistance(v.pos,unit.pos)<closestPlant[1] then closestPlant[2]=v end
        end
        closestPlant[2]:setMaterial(devilFruitMat.type)
        closestPlant[2]:setMaterialIndex(devilFruitMat.subtype)
    end
end

--[[function raceIsIntelligent(raceID,casteID)
    local creature=df.creature_raw.find(raceID)
    if not creature then return false end
    local flags=creature.caste[casteID].flags
    return (flags.CAN_LEARN and flags.CAN_SPEAK)
end]]

function calculateImportanceOfPosition(link)
    local entity=df.historical_entity.find(link.entity_id)
    return math.ceil(10000/df.entity_raw.find(entity.type).positions[entity.positions.assignments[link.assignment_id].position_id].precedence)
end

function calculateImportance(fig)
    local importance=0
    if v.info then
        for k,v in ipairs(fig.info.kills.killed_count) do
            importance=v+importance
        end
        importance=importance+(#fig.info.kills.events*5)
    end
    for k,link in ipairs(fig.entity_links) do
        if histfig_entity_link_enemyst:is_instance(link) then importance=math.ceil(link.link_strength/10)+importance end
        if histfig_entity_link_criminalst:is_instance(link) then importance=math.ceil(link.link_strength/5)+importance end
        if histfig_entity_link_former_prisonerst:is_instance(link) then importance=importance+math.ceil(link.link_strength/10) end
        if histfig_entity_link_positionst:is_instance(link) then importance=importance+calculateImportanceOfPosition(link) end
    end
end

function shuffle(tab)
    local rng=dfhack.random.new()
    local n, order, res = #tab-1, {}, {}

    for i=0,n do order[i] = { rnd = rng:drandom1(), idx = i } end
    table.sort(order, function(a,b) return a.rnd < b.rnd end)
    for i=0,n do res[i] = tab[order[i].idx] end
    return res
end

function assignDevilFruitUser(shuffledTable,number,fig)
    local fruit = shuffledTable[number]
    local persistentID='DEVIL_FRUIT/'..fruit.id
    if not dfhack.persistent.get(persistentID) then
		local matInfoFind=dfhack.matinfo.find(devilFruitPlant.id,fruit.id)
        dfhack.persistent.save({key='DEVIL_FRUIT/'..fruit.id,value=devilFruitPlant.id..':'..fruit.id,ints={fig.unit_id,matInfoFind.type,matInfoFind.subtype}})
    end
end

function assignDevilFruitUsersOnImportance()
    if dfhack.persistent.get_all('DEVIL_FRUIT',true) then return false end
    local importantFigures={{fig=nil,importance=nil}}
    for k,fig in ipairs(df.global.world.history.figures) do
        if df.creature_raw.find(fig.race).creature_id:find('HUMAN') then
            table.insert(importantFigures,{fig=fig,importance=calculateImportance(fig)})
        end
    end
    table.sort(importantFigures,function(a,b) return a[2]>b[2] end)
	local shuffledDevilFruitPlant=shuffle(devilFruitPlant.material)
    for k,v in ipairs(importantFigures) do
        assignDevilFruitUser(shuffledDevilFruitPlant,k,v['fig'])
    end
end

onUnitSpawn=dfhack.event.new()

function onUnitSpawnLoop()
    local units=df.global.world.units.active
    if #units>numUnitsBeforeCheck then 
        for i=#units,numUnitsBeforeCheck,-1 do
            onUnitSpawn(units[i].id)
        end
    end
    dfhack.timeout_active(onUnitSpawnTimeout,nil)
    onUnitSpawnTimeout=dfhack.timeout(10,'ticks',onUnitSpawnLoop())
end

local function assignSyndrome(target,syn_id) --taken straight from here, but edited so I can understand it better: https://gist.github.com/warmist/4061959/. Also implemented expwnent's changes for compatibility with syndromeTrigger.
    if target==nil then
        return nil
    end
    if alreadyHasSyndrome(target,syn_id) then
        local syndrome
        for k,v in ipairs(target.syndromes.active) do
            if v.type == syn_id then syndrome = v end
        end
        if not syndrome then return nil end
        syndrome.ticks=1
        return true
    end
    local newSyndrome=df.unit_syndrome:new()
    local target_syndrome=df.syndrome.find(syn_id)
    newSyndrome.type=target_syndrome.id
    newSyndrome.year=df.global.cur_year
    newSyndrome.year_time=df.global.cur_year_tick
    newSyndrome.ticks=1
    newSyndrome.unk1=1
    for k,v in ipairs(target_syndrome.ce) do
        local sympt=df.unit_syndrome.T_symptoms:new()
        sympt.ticks=1
        sympt.flags=2
        newSyndrome.symptoms:insert("#",sympt)
    end
    target.syndromes.active:insert("#",newSyndrome)
    return true
end

onUnitSpawn['onePiece']=function(unit_id)
    for k,v in ipairs(dfhack.persistent.get_all('DEVIL_FRUIT',true)) do
        if v.ints[1]==unit_id then
			local unit=df.unit.find(unit_id)
			local mat=df.matinfo.decode(v.ints[2],v.ints[3]).material
			for k,v in ipairs(mat.syndrome) do
				assignSyndrome(unit,v.type)
			end
		end
    end
end

dfhack.onStateChange['onePiece']=function(code)
    if code==SC_WORLD_LOADED then
        numUnitsBeforeCheck=0
        devilFruitPlant,devilFruitPlantKey=findDevilFruitPlant() 
        assignDevilFruitUsersOnImportance()
        onUnitSpawnLoop()
    end
end
local addon = CreateFrame('Frame')
local tracked = {}
local roster = {}
local inspection = {}
-- Item -> buff associations for WotLK 3.3.5a. Proc cooldowns are estimates.
local catalog = {
 [50360]={spell=71605,duration=20,icd=90}, -- Phylactery NM
 [50365]={spell=71636,duration=20,icd=90}, -- Phylactery HC
 [54572]={spell=75466,duration=15,icd=50}, -- Charred Twilight Scale NM
 [54588]={spell=75473,duration=15,icd=50}, -- Charred Twilight Scale HC
 [50353]={spell=71601,duration=20,icd=45}, -- Dislodged Foreign Object NM
 [50348]={spell=71644,duration=20,icd=45}, -- Dislodged Foreign Object HC
 [45518]={spell=64713,duration=10,icd=45}, -- Flare of the Heavens
 -- Muradin's Spyglass: stacking aura; no conventional internal proc cooldown.
 [50340]={spell=71572,duration=10,icd=nil,stacking=true},
 [50345]={spell=71575,duration=10,icd=nil,stacking=true},
}
local spells = {}
local spellItems = {}
for itemID,spec in pairs(catalog) do
 spells[spec.spell]=spec
 spellItems[spec.spell]=itemID
end
local lastAlert = {}
local function announceProc(name, spellID)
 local e=tracked[name]
 if not e or not e.items then return end
 local itemID=spellItems[spellID]
 if not itemID then return end
 -- The combat log identifies the effect even when inspection has not completed.
 -- Do not block alerts on equipment cache availability.
 local key=name..':'..spellID
 local now=GetTime()
 if lastAlert[key] and now-lastAlert[key]<3 then return end
 lastAlert[key]=now
 local itemName=GetItemInfo(itemID) or (e.items[13] and e.items[13].id==itemID and e.items[13].label) or (e.items[14] and e.items[14].id==itemID and e.items[14].label) or ('Item '..itemID)
 -- Local chat only: no SendChatMessage / raid broadcast.
 if DEFAULT_CHAT_FRAME then
  DEFAULT_CHAT_FRAME:AddMessage('|cffffd100[MTT]|r |cff69ccf0'..name..'|r ha activado |cffffd100'..itemName..'|r.',1,1,1)
 end
end
local function findAura(unit,spellID)
 if not unit or not UnitExists(unit) then return nil end
 for i=1,40 do
  local name,_,icon,_,_,duration,expiration,_,_,_,id=UnitBuff(unit,i)
  if not name then break end
  if id==spellID then return icon or select(3,GetSpellInfo(spellID)),expiration end
 end
 return nil
end
local function trinketState(entry,item,now,unit,slot)
 if not item or not item.id then return 'unknown' end
 local spec=catalog[item.id]
 if spec then
  local icon=findAura(unit,spec.spell)
  if icon then return 'active',icon end
  local proc=entry.procs and entry.procs[spec.spell]
  if proc and not proc.ended and now<proc.started+spec.duration then
   return 'active',select(3,GetSpellInfo(spec.spell))
  end
  if proc and spec.icd and now<proc.started+spec.icd then return 'cooldown' end
 end
 if unit=='player' then
  local start,duration,enabled=GetInventoryItemCooldown('player',slot)
  if enabled==1 and start and duration and duration>1 and start+duration>now then return 'cooldown' end
 end
 if spec then return 'ready' end
 return 'unknown'
end
local function shortname(n) return n and n:match('^[^-]+') or n end
local function isMage(unit) return UnitExists(unit) and select(2, UnitClass(unit)) == 'MAGE' end
local function getEntry(name)
 name=shortname(name)
 if not name then return end
 tracked[name]=tracked[name] or {procs={},items={}}
 return tracked[name]
end
local ui=CreateFrame('Frame','MageTrinketTrackerFrame',UIParent)
ui:SetWidth(130); ui:SetHeight(42); ui:SetPoint('CENTER',UIParent,'CENTER',350,80)
ui:SetMovable(true); ui:EnableMouse(true); ui:RegisterForDrag('LeftButton')
ui:SetScript('OnDragStart',function(self) if not MTTDB or not MTTDB.locked then self:StartMoving() end end)
ui:SetScript('OnDragStop',function(self) self:StopMovingOrSizing(); local p,_,rp,x,y=self:GetPoint(); MTTDB.point={p,rp,x,y} end)
ui:SetBackdrop({bgFile='Interface\\Tooltips\\UI-Tooltip-Background',edgeFile='Interface\\Tooltips\\UI-Tooltip-Border',edgeSize=10,insets={left=3,right=3,top=3,bottom=3}})
ui:SetBackdropColor(0.025,0.035,0.055,.78)
ui:SetBackdropBorderColor(.38,.44,.56,.8)
local title=ui:CreateFontString(nil,'OVERLAY')
title:SetFont('Fonts\\ARIALN.TTF',11,'OUTLINE')
title:SetTextColor(.88,.81,.60,1)
title:SetPoint('TOPLEFT',ui,'TOPLEFT',7,-5)
title:SetText('Trinkets | PI')
local close=CreateFrame('Button',nil,ui,'UIPanelCloseButton')
close:SetPoint('TOPRIGHT',ui,'TOPRIGHT',3,3);close:SetWidth(19);close:SetHeight(19)
local rowsUI={}
for i=1,25 do
 local row=CreateFrame('Frame',nil,ui)
 row:SetHeight(20)
 row:SetPoint('TOPLEFT',ui,'TOPLEFT',7,-23-(i-1)*20)
 row.name=row:CreateFontString(nil,'OVERLAY')
 row.name:SetFont('Fonts\\ARIALN.TTF',12,'OUTLINE')
 row.name:SetTextColor(.48,.76,1,1)
 row.name:SetPoint('LEFT',row,'LEFT',0,0)
 row.name:SetJustifyH('LEFT')
 -- Secure click-cast: the spell is cast on this row's mage without changing target.
 row.pi=CreateFrame('Button',nil,row,'SecureActionButtonTemplate')
 row.pi:SetWidth(17);row.pi:SetHeight(17)
 row.pi:RegisterForClicks('AnyUp')
 row.pi:SetAttribute('type','spell')
 row.pi:SetAttribute('type1','spell')
 row.pi:SetAttribute('spell',GetSpellInfo(10060) or 'Power Infusion')
 row.pi.icon=row.pi:CreateTexture(nil,'ARTWORK')
 row.pi.icon:SetAllPoints(row.pi)
 row.pi.icon:SetTexture('Interface\\Icons\\Spell_Holy_PowerInfusion')
 row.pi:SetScript('OnEnter',function() GameTooltip:Hide() end)
 row.icons={}
 for j=1,2 do
  local icon=CreateFrame('Frame',nil,row)
  icon:SetWidth(16);icon:SetHeight(16)
  icon.texture=icon:CreateTexture(nil,'ARTWORK')
  icon.texture:SetAllPoints(icon)
  icon.texture:SetTexture('Interface\\Icons\\INV_Misc_QuestionMark')
  row.icons[j]=icon
 end
 row:Hide()
 rowsUI[i]=row
end
local function refreshPlayerTrinkets()
 if not isMage('player') then return end
 local name=shortname(UnitName('player'))
 if not name then return end
 roster[name]='player'
 local e=getEntry(name)
 for _,slot in ipairs({13,14}) do
  local link=GetInventoryItemLink('player',slot)
  local id=link and tonumber(link:match('item:(%d+)'))
  if not id and GetInventoryItemID then id=GetInventoryItemID('player',slot) end
  if id then
   e.items[slot]={id=id,slot=slot,label=GetItemInfo(id) or link}
  else
   e.items[slot]=nil
  end
 end
 e.inspected=GetTime()
end
local function rebuildRoster()
 wipe(roster)
 if GetNumRaidMembers()>0 then
  for i=1,GetNumRaidMembers() do local u='raid'..i;if isMage(u) then local n=shortname(UnitName(u));roster[n]=u;getEntry(n) end end
 elseif GetNumPartyMembers()>0 then
  for i=1,GetNumPartyMembers() do local u='party'..i;if isMage(u) then local n=shortname(UnitName(u));roster[n]=u;getEntry(n) end end
  if isMage('player') then local n=shortname(UnitName('player'));roster[n]='player';getEntry(n) end
 else
  if isMage('player') then local n=shortname(UnitName('player'));roster[n]='player';getEntry(n) end
 end
 refreshPlayerTrinkets()
end
local function captureInspect()
 local unit=inspection.unit
 if not inspection.pending or not unit or not UnitExists(unit) or shortname(UnitName(unit))~=inspection.pending then return false end
 local e=getEntry(inspection.pending)
 e.items=e.items or {}
 local complete=true
 for _,slot in ipairs({13,14}) do
  local link=GetInventoryItemLink(unit,slot)
  if link then
   local id=tonumber(link:match('item:(%d+)'))
   e.items[slot]={id=id,label=GetItemInfo(link) or link,slot=slot}
  else
   complete=false
  end
 end
 -- Only mark fully inspected when BOTH trinket slots have been read.
 if e.items[13] and e.items[14] then complete=true end
 if complete then
  e.inspected=GetTime()
  inspection.pending=nil;inspection.unit=nil
  if ClearInspectPlayer then ClearInspectPlayer() end
  return true
 end
 return false
end
local function inspectMage(unit)
 if inspection.pending or not unit or not UnitExists(unit) or not UnitIsConnected(unit) then return end
 if not isMage(unit) or UnitIsDeadOrGhost(unit) then return end
 if unit~='player' and (not CanInspect(unit) or (InspectFrame and InspectFrame:IsShown())) then return end
 inspection.pending=shortname(UnitName(unit));inspection.unit=unit;inspection.requested=GetTime()
 if unit~='player' then NotifyInspect(unit) else captureInspect() end
end
local combatNames=nil
local function draw()
 if not ui:IsShown() then return end
 local names={}
 for name in pairs(roster) do table.insert(names,name) end
 table.sort(names)
 if InCombatLockdown() then
  if combatNames then names=combatNames end
 else
  combatNames={}
  for i,n in ipairs(names) do combatNames[i]=n end
 end
 -- One shared name-column width makes the two trinket columns perfectly aligned.
 local nameWidth=0
 for i=1,math.min(#names,25) do
  local row=rowsUI[i]
  row.name:SetText(names[i])
  local width=row.name:GetStringWidth()
  if width>nameWidth then nameWidth=width end
 end
 nameWidth=math.min(115,math.max(35,math.ceil(nameWidth)+2))
 local iconSize=16
 local gap=3
 local piX=nameWidth+gap
 local firstX=piX+17+gap
 local secondX=firstX+iconSize+gap
 local totalWidth=7+secondX+iconSize+7
 -- Header controls must fit even when the names are very short.
 ui:SetWidth(math.max(111,totalWidth))
 for i,row in ipairs(rowsUI) do
  local name=names[i]
  if name then
   if not InCombatLockdown() then row:Show() end
   row:SetWidth(totalWidth-14)
   row.name:SetWidth(nameWidth)
   row.name:SetText(name)
   row.pi:ClearAllPoints()
   row.pi:SetPoint('LEFT',row,'LEFT',piX,0)
   row.pi.mageName=name
   -- Visual availability only: do not modify secure attributes in combat.
   local unit=roster[name]
   local learned=GetSpellInfo(10060) and IsSpellKnown(10060)
   local start,duration,enabled=GetSpellCooldown(10060)
   local onCooldown=enabled==1 and start and duration and duration>0 and (start+duration-GetTime())>0.1
   local inRange=unit and UnitExists(unit) and UnitIsConnected(unit) and not UnitIsDeadOrGhost(unit)
   if inRange and IsSpellInRange then
    local range=IsSpellInRange(GetSpellInfo(10060) or 'Power Infusion',unit)
    if range==0 then inRange=false end
   end
   if learned and not onCooldown and inRange then
    row.pi.icon:SetDesaturated(false)
    row.pi.icon:SetVertexColor(1,1,1,1)
   else
    row.pi.icon:SetDesaturated(false)
    row.pi.icon:SetVertexColor(1,0.18,0.18,1)
   end
   -- Protected attributes cannot be changed during combat.
   if not InCombatLockdown() then
    row.pi:SetAttribute('unit',roster[name])
    row.pi:SetAttribute('spell',GetSpellInfo(10060) or 'Power Infusion')
   end
   for j=1,2 do
    local button=row.icons[j]
    button:ClearAllPoints()
    button:SetPoint('LEFT',row,'LEFT',j==1 and firstX or secondX,0)
   end
   local e=getEntry(name)
   for j,slot in ipairs({13,14}) do
    local item=e.items and e.items[slot]
    local button=row.icons[j]
    button.itemID=item and item.id or nil
    local texture=item and item.id and GetItemIcon(item.id)
    button.texture:SetTexture(texture or 'Interface\\Icons\\INV_Misc_QuestionMark')
    button.texture:SetDesaturated(not texture)
    local state,buffIcon=trinketState(e,item,GetTime(),name==shortname(UnitName('player')) and 'player' or roster[name],slot)
    button.state=state
    if state=='active' and buffIcon then button.texture:SetTexture(buffIcon) end
    if state=='cooldown' then
     button.texture:SetDesaturated(false);button.texture:SetVertexColor(1,0.18,0.18,1)
    elseif state=='active' or state=='ready' then
     button.texture:SetDesaturated(false);button.texture:SetVertexColor(1,1,1,1)
    else
     button.texture:SetDesaturated(true);button.texture:SetVertexColor(.65,.65,.65,1)
    end
   end
  else if not InCombatLockdown() then row:Hide() end end
 end
 ui:SetHeight(math.max(44,26+math.min(#names,25)*20))
end
local scanIndex=0
local scanTimer=0
local redrawTimer=0
local retryTimer=0
addon:SetScript('OnUpdate',function(self,elapsed)
 scanTimer=scanTimer+elapsed;redrawTimer=redrawTimer+elapsed;retryTimer=retryTimer+elapsed
 if redrawTimer>=.3 then
  redrawTimer=0
  local playerName=shortname(UnitName('player'))
  if playerName and isMage('player') then
   local e=getEntry(playerName)
   for slot=13,14 do
    local item=e.items and e.items[slot]
    local spec=item and catalog[item.id]
    if spec then
     local activeIcon=findAura('player',spec.spell)
     if activeIcon then
      local proc=e.procs[spec.spell]
      if not proc or proc.ended or GetTime()>=proc.started+spec.duration then
       e.procs[spec.spell]={started=GetTime()}
       announceProc(playerName,spec.spell)
      end
     end
    end
   end
  end
  draw()
 end
 if inspection.pending and retryTimer>=.25 then
  retryTimer=0
  if not captureInspect() and GetTime()-inspection.requested>2.5 then
   inspection.pending=nil;inspection.unit=nil
   if ClearInspectPlayer then ClearInspectPlayer() end
  end
 end
 if scanTimer>=2 then
  scanTimer=0
  refreshPlayerTrinkets()
  if not inspection.pending then
   local units={}
   for _,u in pairs(roster) do if u~='player' and not UnitIsUnit(u,'player') then table.insert(units,u) end end
   table.sort(units)
   if #units>0 then
    -- Rotate through units and refresh stale inspections; out-of-range units are skipped.
    for i=1,#units do
     scanIndex=scanIndex%#units+1
     local unit=units[scanIndex]
     local n=shortname(UnitName(unit))
     local e=n and getEntry(n)
     if e and (not e.inspected or GetTime()-e.inspected>120) then
      inspectMage(unit)
      if inspection.pending then break end
     end
    end
   end
  end
 end
end)
addon:RegisterEvent('PLAYER_EQUIPMENT_CHANGED');addon:RegisterEvent('UNIT_INVENTORY_CHANGED');addon:RegisterEvent('ADDON_LOADED');addon:RegisterEvent('RAID_ROSTER_UPDATE');addon:RegisterEvent('PARTY_MEMBERS_CHANGED');addon:RegisterEvent('PLAYER_ENTERING_WORLD');addon:RegisterEvent('COMBAT_LOG_EVENT_UNFILTERED');addon:RegisterEvent('INSPECT_READY')
addon:SetScript('OnEvent',function(self,event,...)
 if event=='ADDON_LOADED' then
  local name=...;if name~='MageTrinketTracker' then return end
  MTTDB=MTTDB or {locked=false,visible=false,scale=1}
  ui:SetScale(1)
  if MTTDB.point then
   local p,rp,x,y=unpack(MTTDB.point)
   if type(x)=='number' and type(y)=='number' and math.abs(x)<3000 and math.abs(y)<3000 then
    ui:ClearAllPoints();ui:SetPoint(p,UIParent,rp,x,y)
   end
  end
  if ui.SetClampedToScreen then ui:SetClampedToScreen(true) end
  -- Respect the saved visibility preference across relogs.
  if MTTDB.visible == true then ui:Show() else ui:Hide() end
  rebuildRoster()
 elseif event=='PLAYER_ENTERING_WORLD' or event=='RAID_ROSTER_UPDATE' or event=='PARTY_MEMBERS_CHANGED' then rebuildRoster()
 elseif event=='PLAYER_EQUIPMENT_CHANGED' or event=='UNIT_INVENTORY_CHANGED' then
  local unit=...
  if event=='PLAYER_EQUIPMENT_CHANGED' or unit=='player' then
   local n=shortname(UnitName('player')); local e=n and getEntry(n)
   if e then e.inspected=nil;e.items={} end
   refreshPlayerTrinkets()
   scanTimer=2
  end
 elseif event=='INSPECT_READY' then captureInspect()
 elseif event=='COMBAT_LOG_EVENT_UNFILTERED' then
  -- 3.3.5a combat log: spellID is argument 10 (not 11).
  local _,subevent,_,sourceGUID,sourceName,_,destGUID,destName,_,spellId=...
  if (subevent=='SPELL_AURA_APPLIED' or subevent=='SPELL_AURA_REFRESH' or subevent=='SPELL_AURA_REMOVED') and spells[spellId] then
   local name=shortname(destName)
   if name and roster[name] then
    local e=getEntry(name)
    if subevent=='SPELL_AURA_REMOVED' then
     if e.procs[spellId] then e.procs[spellId].ended=GetTime() end
    elseif subevent=='SPELL_AURA_APPLIED' then
     local wasActive=e.procs[spellId] and not e.procs[spellId].ended and GetTime()<e.procs[spellId].started+(spells[spellId].duration or 0)
     e.procs[spellId]={started=GetTime()}
     if not wasActive then announceProc(name,spellId) end
    elseif subevent=='SPELL_AURA_REFRESH' then
     -- Refreshes (including Muradin stacks) extend the aura, but do not spam chat.
     if not e.procs[spellId] or e.procs[spellId].ended then
      e.procs[spellId]={started=GetTime()}
     end
    end
   end
  end
 end
end)
SLASH_MAGETRINKETTRACKER1='/mtt'
SlashCmdList.MAGETRINKETTRACKER=function(msg)
 msg=(msg or ''):lower()
 if msg=='lock' then MTTDB.locked=not MTTDB.locked;print('MTT bloqueo: '..tostring(MTTDB.locked))
 elseif msg=='show' or msg=='on' then ui:Show();MTTDB.visible=true;draw()
 elseif msg=='hide' or msg=='off' then ui:Hide();MTTDB.visible=false
 elseif msg=='test' then if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage('|cffffd100[MTT]|r Alerta de prueba: chat funcionando.',1,1,1) end
 elseif msg=='size' then print('MTT: tamaño fijo')
 elseif msg=='reset' then wipe(tracked);rebuildRoster();print('MTT: historial reiniciado')
 elseif msg=='scan' then for _,e in pairs(tracked) do e.inspected=nil end;inspection.pending=nil;inspection.unit=nil;scanTimer=2;print('MTT: inspeccion solicitada (requiere alcance de inspeccion)')
 else if ui:IsShown() then ui:Hide();MTTDB.visible=false else ui:Show();MTTDB.visible=true end end
end
close:SetScript('OnClick',function()ui:Hide();MTTDB.visible=false end)

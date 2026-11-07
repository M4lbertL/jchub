-- JcHub Universal - client-visible Scanner & Action Watcher v1.0.5
-- Standalone, passive and local. No remote invocation, source extraction or uploads.
local Core={}
Core.LIMITS={nodes=false,events=false,connections=false,queue=false,attributes=80}
function Core.sensitive(key)
 local k=tostring(key or ''):lower():gsub('[^a-z0-9]','')
 return k:find('password',1,true)~=nil or k:find('webhook',1,true)~=nil
  or k:find('authorization',1,true)~=nil or k:find('credential',1,true)~=nil
  or k:find('cookie',1,true)~=nil or k:find('accesstoken',1,true)~=nil
  or k:find('authtoken',1,true)~=nil or k:find('refreshtoken',1,true)~=nil
  or k=='token' or k=='apikey' or k=='privatekey' or k=='secret' or k=='secretkey' or k=='sessionid'
end
function Core.privatePath(path,includeHubs)
 local p=tostring(path or ''):lower()
 for segment in p:gmatch('[^.]+') do if segment=='chat' or segment=='chats' or segment=='keysystem' then return true end end
 return p:find('experiencechat',1,true)~=nil or p:find('textchatservice',1,true)~=nil
  or p:find('bubblechat',1,true)~=nil or p:find('chatwindow',1,true)~=nil
  or p:find('chatlog',1,true)~=nil or p:find('jcsaescanner',1,true)~=nil
  or (not includeHubs and (p:find('jchub',1,true)~=nil or p:find('kpopassistant',1,true)~=nil))
  or p:find('coregui.devconsole',1,true)~=nil or p:find('.devconsolemaster',1,true)~=nil
  or p:find('coregui.robloxgui.modules.devconsole',1,true)~=nil
  or p:find('password',1,true)~=nil or p:find('webhook',1,true)~=nil
  or p:find('credential',1,true)~=nil or p:find('authorization',1,true)~=nil
end
function Core.cleanString(value)
 local text=tostring(value or '')
 if not utf8.len(text) then return '<binary string: '..#text..' bytes>' end
 local lower=text:lower()
 if lower:find('bearer ',1,true) or lower:find('discord.com/api/webhooks',1,true)
  or lower:find('discordapp.com/api/webhooks',1,true) or lower:find('roblosecurity',1,true)
  or text:match('[%w._%%+-]+@[%w.-]+%.%a%a+') then return '[REDACTED]' end
 if lower:find('https?://') and not (lower:find('roblox.com/asset',1,true) or lower:find('rbxcdn.com/',1,true)) then return '[URL REDACTED]' end
 if #text>400 then
  local cut=400
  if utf8.len(text) then cut=(utf8.offset(text,401) or #text+1)-1 end
  return text:sub(1,cut)..' [TRUNCATED]'
 end
 return text
end
function Core.safe(value,key,depth,seen,remote)
 if Core.sensitive(key) then return '[REDACTED]' end
 depth=depth or 0;seen=seen or {}
 local kind=typeof(value)
 if kind=='nil' then return '[nil]' end
 if kind=='boolean' then return value end
 if kind=='number' then return value==value and math.abs(value)<math.huge and value or '[nonfinite]' end
 if kind=='string' then return remote and ('<string: '..#value..' bytes>') or Core.cleanString(value) end
 if kind=='Vector3' then return {type='Vector3',x=value.X,y=value.Y,z=value.Z} end
 if kind=='Vector2' then return {type='Vector2',x=value.X,y=value.Y} end
 if kind=='CFrame' then return {type='CFrame',components={value:GetComponents()}} end
 if kind=='Color3' then return {type='Color3',r=value.R,g=value.G,b=value.B} end
 if kind=='EnumItem' then return tostring(value) end
 if kind=='Instance' then
  local ok,path=pcall(function()return value:GetFullName()end)
  return {type='Instance',class=value.ClassName,path=ok and not Core.privatePath(path) and Core.cleanString(path) or '[private/unavailable]'}
 end
 if kind=='table' then
  if seen[value] then return '[cycle]' end
  if depth>=3 then return '[depth limit]' end
  seen[value]=true
  local out={};local count=0
  for k,v in pairs(value) do
   if count>=50 then out.__truncated=true;break end
   if type(k)=='string' or type(k)=='number' then
    local name=Core.cleanString(k);out[name]=Core.safe(v,k,depth+1,seen,remote);count+=1
   end
  end
  seen[value]=nil;return out
 end
 return '<'..kind..'>'
end
function Core.consoleKey(message,level)
 local text=tostring(level).."\0"..tostring(message)
 local hash=5381
 for i=1,#text do hash=(hash*33+text:byte(i))%4294967296 end
 return tostring(#text)..":"..tostring(hash)
end
function Core.console(state,message,level)
 if not state.running or state.captureConsole==false then return nil end
 state.consoleOccurrences=(state.consoleOccurrences or 0)+1
 state.consoleGroups=state.consoleGroups or {}
 local key=Core.consoleKey(message,level)
 local slot=state.groupConsole~=false and state.consoleGroups[key] or nil
 local old=slot and state.events[slot]
 local now=state.clock()-state.started
 if old and old.kind=='CONSOLE_MESSAGE' then
  -- Replace the record, preserving an already-started Copy All snapshot.
  local updated={};for k,v in pairs(old) do updated[k]=v end
  local detail={};for k,v in pairs(old.detail) do detail[k]=v end
  detail.repeatCount=(detail.repeatCount or 1)+1;detail.lastAt=now
  updated.detail=detail;state.events[slot]=updated
  state.consoleGrouped=(state.consoleGrouped or 0)+1
  return updated
 end
 local event=Core.log(state,'CONSOLE_MESSAGE',nil,{message=Core.cleanString(message),level=tostring(level),repeatCount=1,firstAt=now,lastAt=now})
 if event and state.groupConsole~=false then state.consoleGroups[key]=state.eventCount end
 return event
end
function Core.fileComponent(value,fallback)
 local text=tostring(value or ''):gsub('[<>:"/\\|?*%c]','_'):gsub('^[%.%s]+',''):gsub('[%.%s]+$',''):gsub('_+','_')
 if text=='' then text=fallback or 'Game' end
 local base=text:match('^[^%.]+') or text
 if base:upper():match('^CON$') or base:upper():match('^PRN$') or base:upper():match('^AUX$') or base:upper():match('^NUL$') or base:upper():match('^COM[1-9]$') or base:upper():match('^LPT[1-9]$') then text='Game_'..text end
 if #text>60 then text=text:sub(1,60);while #text>0 and not utf8.len(text) do text=text:sub(1,-2) end end
 text=text:gsub('[%.%s]+$','');return text~='' and text or (fallback or 'Game')
end
function Core.categories(record)
 local a,p=record.attributes or {},record.properties or {};local c=record.class or '';local result={['All Objects']=true}
 local n=tostring(record.name or ''):lower();local item=tostring(a.ItemType or ''):lower()
 local gui={ScreenGui=true,SurfaceGui=true,BillboardGui=true,Frame=true,ScrollingFrame=true,CanvasGroup=true,TextLabel=true,TextButton=true,TextBox=true,ImageLabel=true,ImageButton=true,ViewportFrame=true,VideoFrame=true}
 if gui[c] then result.GUIs=true end
 if a.CardId or a.PhotocardId or item=='card' or item=='photocard' or ((c=='Tool' or c=='Model') and n:find('photocard',1,true)) then result.Photocards=true end
 if a.EggId or a.EggUID or item=='assetegg' or item=='egg' or (item=='' and (c=='Tool' or c=='Model') and n:find('egg',1,true)) then result.Eggs=true end
 if result.Eggs then result.Photocards=nil end
 if not result.Eggs and (a.PetId or item=='pet' or item=='asset') then result.Pets=true end
 if c=='Tool' then result.Tools=true end
 if c=='Model' then result.Models=true end
 if c=='Part' or c=='MeshPart' or c=='UnionOperation' then result.Parts=true end
 if c=='RemoteEvent' or c=='RemoteFunction' or c=='UnreliableRemoteEvent' then result.Remotes=true end
 if c=='ProximityPrompt' then result.Prompts=true end
 if c=='Sound' then result.Sounds=true end
 if c=='Script' or c=='LocalScript' or c=='ModuleScript' then result.Scripts=true end
 if c:find('Value',1,true) then result.Values=true end
 if (type(p.Image)=='string' and p.Image~='') or (type(p.MeshId)=='string' and p.MeshId~='') or (type(p.Texture)=='string' and p.Texture~='') then result.Assets=true end
 return result
end
function Core.group(record,category)
 local a=record.attributes or {}
 for _,key in ipairs({'Biome','BiomeName','Area','AreaName','Zone','SpawnBiome'}) do
  if type(a[key])=='string' and a[key]~='' and a[key]~='[REDACTED]' then return a[key] end
 end
 if category=='GUIs' then return record.class=='ScreenGui' and 'Screen GUIs' or record.class=='SurfaceGui' and 'Surface GUIs' or record.class=='BillboardGui' and 'Billboard GUIs' or 'GUI children' end
 return category=='Eggs' and 'Unknown biome' or 'Unspecified area'
end
function Core.index(state,record,obj)
 state.categories=state.categories or {};state.categoryCounts=state.categoryCounts or {};state.recordCategories=state.recordCategories or {}
 local old=state.recordCategories[record.id] or {};local current=Core.categories(record)
 for name in pairs(old) do if not current[name] then state.categories[name][record.id]=nil;state.categoryCounts[name]-=1 end end
 for name in pairs(current) do
  state.categories[name]=state.categories[name] or {};state.categoryCounts[name]=state.categoryCounts[name] or 0
  if not state.categories[name][record.id] then state.categoryCounts[name]+=1 end
  state.categories[name][record.id]=true
 end
 state.recordCategories[record.id]=current
 state.instances=state.instances or setmetatable({},{__mode='v'});state.instances[record.id]=obj
 state.browserRevision=(state.browserRevision or 0)+1
end
function Core.new(clock,pose)
 return {clock=clock,pose=pose,started=clock(),running=true,ids=setmetatable({},{__mode='k'}),records={},nextId=1,
  events={},head=1,eventCount=0,totalEvents=0,droppedEvents=0,nodeLimitHits=0,connectionLimitHits=0,queueLimitHits=0,
  scanCount=0,errors={},labels={},captureProperties=function()return {}end,includeHubUI=true,coreGuiEnabled=true,coreGuiStatus='Not checked',captureConsole=true,consoleAvailable=false,groupConsole=true,consoleGroups={},consoleOccurrences=0,consoleGrouped=0}
end
function Core.capture(state,obj)
 if not obj then return nil end
 if state.allowObject and not state.allowObject(obj) then return nil end
 local ok,path=pcall(function()return obj:GetFullName()end)
 if not ok or Core.privatePath(path,state.includeHubUI) then return nil end
 local ancestor=obj
 while ancestor do
  if Core.sensitive(ancestor.Name) and tostring(ancestor.Name):lower()~='secret' then return nil end
  if ancestor~=obj and ancestor:IsA('TextBox') then return nil end
  ancestor=ancestor.Parent
 end
 local id=state.ids[obj]
 if not id then
  id=state.nextId;state.nextId+=1;state.ids[obj]=id
 end
 local old=state.records[id]
 local record={id=id,firstSeen=old and old.firstSeen or state.clock()-state.started,path=old and old.path,previousPath=old and old.previousPath}
 if not obj.Parent and record.path then path=record.path end
 if record.path and record.path~=path then record.previousPath=record.path end
 record.name=Core.cleanString(obj.Name);record.class=obj.ClassName;record.path=Core.cleanString(path)
 record.parentId=obj.Parent and state.ids[obj.Parent] or nil
 record.lastSeen=state.clock()-state.started;record.present=obj.Parent~=nil
 if not obj.Parent and old then record.attributes=old.attributes;record.properties=old.properties;state.records[id]=record;return id end
 record.attributes={}
 local valid,attrs=pcall(function()return obj:GetAttributes()end)
 if valid and not obj:IsA('TextBox') then
  local count=0
  for key,value in pairs(attrs) do
   if count>=Core.LIMITS.attributes then record.attributes.__truncated=true;break end
   record.attributes[Core.cleanString(key)]=Core.safe(value,key);count+=1
  end
 end
 record.properties=state.captureProperties(obj)
 state.records[id]=record;Core.index(state,record,obj);return id
end
function Core.log(state,kind,obj,detail,force)
 if not state.running and not force then return end
 local id=obj and Core.capture(state,obj) or nil
 if obj and not id then return end
 state.totalEvents+=1
 local entry={sequence=state.totalEvents,elapsed=state.clock()-state.started,kind=kind,objectId=id,
  path=id and state.records[id].path or nil,detail=Core.safe(detail or {}),character=state.pose and state.pose() or nil}
 state.eventCount+=1
 state.events[state.eventCount]=entry
 return entry
end
function Core.orderedEvents(state)
 local out={}
 for i=1,state.eventCount do out[i]=state.events[i] end
 return out
end
function Core.positionText(pose)
 if not pose or not pose.position then return 'Character/root position unavailable' end
 local p=pose.position
 local lines={('Vector3.new(%.4f, %.4f, %.4f)'):format(p.x,p.y,p.z)}
 if pose.cframe then
  local fields={};for _,n in ipairs(pose.cframe) do fields[#fields+1]=('%.6f'):format(n) end
  lines[#lines+1]='CFrame.new('..table.concat(fields,', ')..')'
 end
 return table.concat(lines,'\n')
end

function Core.fullSnapshot(state,context)
 local labels,errors={},{}
 for i,v in ipairs(state.labels) do labels[i]=v end
 for i,v in ipairs(state.errors) do errors[i]=v end
 local objects={}
 for i=1,state.nextId-1 do if state.records[i] then objects[#objects+1]=state.records[i] end end
 return {schema=1,version='1.0.5',context=context,recording=state.running,
  objectCount=#objects,eventCount=state.eventCount,totalEvents=state.totalEvents,
  droppedEvents=state.droppedEvents,nodeLimitHits=state.nodeLimitHits,connectionLimitHits=state.connectionLimitHits,
  queueLimitHits=state.queueLimitHits,limits=Core.LIMITS,objects=objects,actions=Core.orderedEvents(state),
  markers=labels,errors=errors,scans=state.scanCount,
  captureOptions={coreGui=state.coreGuiEnabled,coreGuiStatus=state.coreGuiStatus,includeHubUI=state.includeHubUI,
   captureConsole=state.captureConsole,consoleAvailable=state.consoleAvailable,groupConsole=state.groupConsole,consoleOccurrences=state.consoleOccurrences,groupedConsoleRepeats=state.consoleGrouped},
  disclosure='Full retained session; no object/event/listener/queue count cap. RAM remains finite. Privacy and per-value bounds remain; not hidden server state.'}
end
function Core.beginPaste(state,context)
 local data=Core.fullSnapshot(state,context)
 local metadata={}
 for key,value in pairs(data) do
  if key~='objects' and key~='actions' and key~='markers' and key~='errors' then metadata[key]=value end
 end
 return {metadata=metadata,sections={{name='objects',values=data.objects},{name='actions',values=data.actions},
  {name='markers',values=data.markers},{name='errors',values=data.errors}},section=0,index=0,part=0,
  output={},bytes=0,offset=1,complete=false,processed=0,total=#data.objects+#data.actions+#data.markers+#data.errors}
end
function Core.nextPasteToken(paste,encode)
 if paste.section==0 then
  paste.section=1
  local metadata=encode(paste.metadata)
  return '=== JCHUB UNIVERSAL FULL SESSION SCAN v1.0.5 BEGIN ===\n'..metadata:sub(1,-2)
 end
 local section=paste.sections[paste.section]
 if section then
  if paste.index==0 then paste.index=1;return ',"'..section.name..'":[' end
  local value=section.values[paste.index]
  if value~=nil then
   local first=paste.index==1;paste.index+=1;paste.processed+=1
   return (first and '' or ',')..encode(value)
  end
  paste.section+=1;paste.index=0
  return ']'
 end
 if not paste.closed then paste.closed=true;return '}\n=== JCHUB UNIVERSAL FULL SESSION SCAN END ===' end
 paste.complete=true
end
function Core.stepPaste(paste,encode,maxBytes,maxTokens)
 maxBytes=maxBytes or 12000;maxTokens=maxTokens or 12
 if paste.complete then return nil,true end
 for _=1,maxTokens do
  if not paste.pending then
   paste.pending=Core.nextPasteToken(paste,encode);paste.offset=1
   if not paste.pending then break end
  end
  local room=maxBytes-paste.bytes
  local last=math.min(#paste.pending,paste.offset+room-1)
  while last<#paste.pending and last>=paste.offset do
   local byte=paste.pending:byte(last+1)
   if byte<128 or byte>=192 then break end
   last-=1
  end
  if last<paste.offset then break end
  local part=paste.pending:sub(paste.offset,last)
  paste.output[#paste.output+1]=part;paste.bytes+=#part;paste.offset=last+1
  if paste.offset>#paste.pending then paste.pending=nil end
  if paste.bytes>=maxBytes-3 then break end
 end
 if paste.complete or paste.bytes>=maxBytes-3 then
  local text=table.concat(paste.output)
  paste.output={};paste.bytes=0;paste.part+=1
  return text,paste.complete
 end
 return nil,false
end

-- RUNTIME ENTRY: Roblox services and observation-only listeners.
local Players=game:GetService('Players')
local Workspace=game:GetService('Workspace')
local ReplicatedStorage=game:GetService('ReplicatedStorage')
local RunService=game:GetService('RunService')
local UIS=game:GetService('UserInputService')
local Http=game:GetService('HttpService')
local PPS=game:GetService('ProximityPromptService')
local CoreGui,coreGuiConnected,attachCoreGui
local LogService
local logAvailable=false
local player=Players.LocalPlayer
if not player then error('Run the scanner on the client, not the server') end
local playerGui=player:WaitForChild('PlayerGui',15)
if not playerGui then error('PlayerGui not available') end
local env=type(getgenv)=='function' and getgenv() or nil
if env and type(env.JCSAE_Scanner_Unload)=='function' then pcall(env.JCSAE_Scanner_Unload) end
local alive=true
local connections,objectConnections={},{}
local watched=setmetatable({},{__mode='k'})
local pending,queued={},setmetatable({},{__mode='k'})
local queueHead=1
local gui,window,statusLabel,positionLabel,logLabel,launcher
local browserStep
local minimized=false;local restorePreview=false;local restoreMarker=false
local markerOverlay,markerInput,markerHint,pendingMarker
local status='Recording starts automatically. Play normally, then Export Data.'
local function pose()
 local character=player.Character
 local root=character and character:FindFirstChild('HumanoidRootPart')
 if not root then return nil end
 local hum=character:FindFirstChildOfClass('Humanoid')
 local answer={position={x=root.Position.X,y=root.Position.Y,z=root.Position.Z},cframe={root.CFrame:GetComponents()}}
 if hum then answer.health=hum.Health;answer.walkSpeed=hum.WalkSpeed;answer.state=tostring(hum:GetState()) end
 local camera=Workspace.CurrentCamera
 if camera then answer.cameraCFrame={camera.CFrame:GetComponents()};answer.cameraType=tostring(camera.CameraType) end
 return answer
end
local state=Core.new(os.clock,pose)
state.allowObject=function(obj)
 if CoreGui and not state.coreGuiEnabled then
  local ok,isCore=pcall(function()return obj==CoreGui or obj:IsDescendantOf(CoreGui)end)
  if ok and isCore then return false end
 end
 return true
end
local function readProps(obj)
 local fields={}
 local names={}
 if obj:IsA('BasePart') then names={'CFrame','Size','Anchored','CanCollide','CanQuery','Transparency','Material'}
 elseif obj:IsA('Attachment') then names={'CFrame','WorldPosition'}
 elseif obj:IsA('ProximityPrompt') then names={'ActionText','ObjectText','Enabled','HoldDuration','MaxActivationDistance','RequiresLineOfSight','KeyboardKeyCode'}
 elseif obj:IsA('GuiObject') and not obj:IsA('TextBox') then names={'Visible','Active','AbsolutePosition','AbsoluteSize','LayoutOrder'}
 elseif obj:IsA('ScreenGui') then names={'Enabled','DisplayOrder','ResetOnSpawn'}
 elseif obj:IsA('Humanoid') then names={'Health','MaxHealth','WalkSpeed','HipHeight','PlatformStand','Sit'}
 elseif obj:IsA('Tool') then names={'Enabled','ToolTip','TextureId','RequiresHandle'}
 elseif obj:IsA('ValueBase') then names={'Value'} end
 if obj:IsA('TextLabel') or obj:IsA('TextButton') then names[#names+1]='Text' end
 if obj:IsA('ImageLabel') or obj:IsA('ImageButton') then names[#names+1]='Image' end
 if obj:IsA('ScrollingFrame') then names[#names+1]='CanvasPosition';names[#names+1]='AbsoluteCanvasSize' end
 if obj:IsA('MeshPart') then names[#names+1]='MeshId';names[#names+1]='TextureID' end
 if obj:IsA('Decal') or obj:IsA('Texture') then names[#names+1]='Texture' end
 if obj:IsA('SurfaceGui') or obj:IsA('BillboardGui') then names[#names+1]='Enabled';names[#names+1]='Adornee' end
 for _,key in ipairs(names) do
  local ok,value=pcall(function()return obj[key]end)
  if ok then fields[key]=Core.safe(value,key) end
 end
 return fields
end
state.captureProperties=readProps
local function connect(signal,fn,owner)
 local ok,c=pcall(function()return signal:Connect(function(...)
  if owner and state.allowObject and not state.allowObject(owner) then return end
  return fn(...)
 end)end)
 if not ok then return end
 connections[#connections+1]=c
 if owner then objectConnections[owner]=objectConnections[owner] or {};table.insert(objectConnections[owner],c) end
 return c
end
local function enqueue(obj)
 if not obj or queued[obj] then return end
 local ok,path=pcall(function()return obj:GetFullName()end)
 if not ok or Core.privatePath(path,state.includeHubUI) or not state.allowObject(obj) then return end
 pending[#pending+1]=obj;queued[obj]=true
end
local function addError(where,message)
 if #state.errors<40 then state.errors[#state.errors+1]={where=where,message=Core.cleanString(message)} end
end
local function watch(obj)
 if watched[obj] then return end
 watched[obj]=true
 local id=Core.capture(state,obj)
 if not id then return end
 local last={}
 local function change(key)
  if not alive or not state.running then return end
  local now=os.clock()
  if now-(last[key] or -10)<.2 then Core.capture(state,obj);return end
  last[key]=now
  local before=state.records[id] and state.records[id].properties
  Core.capture(state,obj)
  Core.log(state,'PROPERTY',obj,{field=key,before=before and before[key],after=state.records[id].properties[key]})
 end
 local interesting=obj:IsA('Model') or obj:IsA('Folder') or obj:IsA('Tool') or obj:IsA('ProximityPrompt')
  or obj:IsA('GuiObject') or obj:IsA('ScreenGui') or obj:IsA('ValueBase') or obj:IsA('Humanoid') or next(state.records[id].attributes)~=nil
 if interesting then
  connect(obj.AttributeChanged,function(key)
   if not state.running then return end
   local before=state.records[id] and state.records[id].attributes[key]
   local ok,value=pcall(function()return obj:GetAttribute(key)end)
   Core.log(state,'ATTRIBUTE',obj,{field=Core.cleanString(key),before=before,after=ok and Core.safe(value,key) or '[unavailable]'})
  end,obj)
  connect(obj.AncestryChanged,function()
   if not state.running then return end
   Core.log(state,obj.Parent and 'REPARENTED' or 'REMOVED',obj)
   if state.records[id] then state.records[id].present=obj.Parent~=nil end
  end,obj)
 end
 if obj:IsA('GuiButton') then connect(obj.Activated,function()Core.log(state,'UI_ACTIVATED',obj)end,obj) end
 if obj:IsA('Tool') then
  connect(obj.Equipped,function()Core.log(state,'TOOL_EQUIPPED',obj)end,obj)
  connect(obj.Unequipped,function()Core.log(state,'TOOL_UNEQUIPPED',obj)end,obj)
  connect(obj.Activated,function()Core.log(state,'TOOL_ACTIVATED',obj)end,obj)
 end
 if obj:IsA('RemoteEvent') or obj:IsA('UnreliableRemoteEvent') then
  connect(obj.OnClientEvent,function(...)
   if not state.running then return end
   local args=table.pack(...);local payload={count=args.n,arguments={}}
   for i=1,math.min(args.n,12) do payload.arguments[i]=Core.safe(args[i],i,0,{},true) end
   Core.log(state,'REMOTE_RECEIVED',obj,payload)
  end,obj)
 end
 local props={}
 if obj:IsA('ScreenGui') then props={'Enabled'}
 elseif obj:IsA('GuiObject') and not obj:IsA('TextBox') then
  props={'Visible'}
  if obj:IsA('TextLabel') or obj:IsA('TextButton') then props[#props+1]='Text' end
  if obj:IsA('ImageLabel') or obj:IsA('ImageButton') then props[#props+1]='Image' end
  if obj:IsA('ScrollingFrame') then props[#props+1]='CanvasPosition' end
 elseif obj:IsA('ProximityPrompt') then props={'Enabled','ActionText','ObjectText'}
 elseif obj:IsA('ValueBase') then props={'Value'}
 elseif obj:IsA('Humanoid') then props={'Health','WalkSpeed','PlatformStand','Sit'} end
 for _,key in ipairs(props) do
  local ok,signal=pcall(function()return obj:GetPropertyChangedSignal(key)end)
  if ok then connect(signal,function()change(key)end,obj) end
 end
end
attachCoreGui=function()
 if not state.coreGuiEnabled then state.coreGuiStatus='Disabled';return end
 local ok,result=pcall(function()
  local root=CoreGui or game:GetService('CoreGui')
  assert(root,'CoreGui unavailable')
  root:GetChildren() -- Access probe only; permissions are never bypassed.
  return root
 end)
 if not ok then state.coreGuiStatus='Unavailable / access denied';addError('CoreGui access',result);return end
 CoreGui=result
 state.coreGuiStatus='Accessible'
 enqueue(CoreGui)
 if not coreGuiConnected then
  local connected=pcall(function()
   local c=connect(CoreGui.DescendantAdded,function(obj)
    if state.running and state.coreGuiEnabled then enqueue(obj);Core.log(state,'ADDED',obj) end
   end,CoreGui)
   assert(c,'Descendant listener unavailable')
  end)
  coreGuiConnected=connected
  if not connected then state.coreGuiStatus='Partial access; static scan only' end
 end
end
local logOK,logReason=pcall(function()
 LogService=game:GetService('LogService')
 local c=connect(LogService.MessageOut,function(message,level)Core.console(state,message,level)end)
 assert(c,'MessageOut listener unavailable')
end)
logAvailable=logOK;state.consoleAvailable=logOK
if not logOK then addError('Console capture',logReason) end
local function scan()
 state.scanCount+=1;state.manualScan=true
 enqueue(playerGui);enqueue(player:FindFirstChildOfClass('Backpack'));enqueue(player.Character)
 enqueue(Workspace);enqueue(ReplicatedStorage)
 attachCoreGui()
 local leader=player:FindFirstChild('leaderstats');if leader then enqueue(leader) end
 Core.log(state,'SCAN_REQUESTED',nil,{number=state.scanCount},true)
 status='Scan queued. CoreGui: '..state.coreGuiStatus
end
local function report()
 local position=pose()
 local lines={'JcHub Universal - Full Client Scanner v1.0.5',
  'PlaceId: '..game.PlaceId..' | GameId: '..game.GameId..' | Server JobId: '..game.JobId,
  'Recording: '..tostring(state.running)..' | Objects: '..(state.nextId-1)..' | Events retained: '..state.eventCount..' / '..state.totalEvents,
  'No count caps: dropped events='..state.droppedEvents..' | node refusals='..state.nodeLimitHits..' | listener refusals='..state.connectionLimitHits..' | queue refusals='..state.queueLimitHits,
  'CoreGui: '..state.coreGuiStatus..' | Include hub GUIs: '..tostring(state.includeHubUI),
  'Console capture: '..tostring(state.captureConsole)..' | Available: '..tostring(logAvailable)..' | Group repeats: '..tostring(state.groupConsole)..' | Messages: '..state.consoleOccurrences..' | Grouped repeats: '..state.consoleGrouped,
  'CURRENT CHARACTER LOCATION:',Core.positionText(position),
  'OBSERVATION LIMIT: client-visible/loaded data only. No server-only state, game script source, outbound remote hooks or complete catalogue guarantee.',
  'PRIVACY: TextBox contents/chat excluded. Sensitive fields redacted. Received-remote strings show lengths only.',
  '', 'RECENT ACTIONS (latest 250; full retained log is in the JSON export):'}
 lines[#lines+1]="LOCATION MARKERS (latest 25; all are included in Copy All):"
 for i=math.max(1,#state.labels-24),#state.labels do
  local marker=state.labels[i];local p=marker.character and marker.character.position
  lines[#lines+1]=(marker.name or "Marker").." | "..tostring(marker.purpose or "")..(p and (" | XYZ %.2f, %.2f, %.2f"):format(p.x,p.y,p.z) or "")
 end
 local events=state.events
 for i=math.max(1,#events-249),#events do
  local e=events[i];local obj=e.objectId and state.records[e.objectId]
  local p=e.character and e.character.position
  lines[#lines+1]=('%.2fs #%d %s | %s%s'):format(e.elapsed,e.sequence,e.kind,e.path or (obj and obj.path) or '-',
   p and (' | XYZ %.2f, %.2f, %.2f'):format(p.x,p.y,p.z) or '')
 end
 for _,e in ipairs(state.errors) do lines[#lines+1]='ERROR '..e.where..': '..e.message end
 return table.concat(lines,'\n')
end
local function shortReport()
 local text=report()
 if #text<=11000 then return text end
 local last=11000
 while last>0 do local byte=text:byte(last+1);if not byte or byte<128 or byte>=192 then break end;last-=1 end
 return text:sub(1,last)..'\n[Summary shortened. Copy All / Copy Next Part retain the complete session.]'
end
local function copyText(text)
 if type(setclipboard)=='function' then
  local ok,result=pcall(setclipboard,text)
  if ok and result~=false then
   if type(getclipboard)=='function' then local checked,current=pcall(getclipboard);if checked and type(current)=='string' and current~=text then return false end end
   return true
  end
 end
 return false
end
local function prepareCopyAll()
 state.pasteSnapshot=Core.beginPaste(state,{place=game.PlaceId,game=game.GameId,job=game.JobId,
  snapshotTime=os.time(),currentPosition=pose(),queued=math.max(0,#pending-queueHead+1)})
 return state.pasteSnapshot
end
local function copyAll()
 if state.copyJob then status='Preparing a paste part; please wait.';return end
 state.copyJob=prepareCopyAll()
 status='Preparing full session in small batches; recording state unchanged.'
end
local function copyNextPart()
 if state.copyJob then status='Preparing a paste part; please wait.';return end
 local snapshot=state.pasteSnapshot or prepareCopyAll()
 if snapshot.complete then status='Full snapshot finished. Press Copy All for a new snapshot.';return end
 state.copyJob=snapshot;status='Preparing next paste part from the same snapshot.'
end
local function stepCopy()
 local snapshot=state.copyJob
 if not snapshot then return end
 local ok,text,final=pcall(Core.stepPaste,snapshot,function(value)return Http:JSONEncode(value)end,12000,12)
 if not ok then state.copyJob=nil;status='Copy preparation failed; no data discarded. '..Core.cleanString(text);return end
 if not text then return end
 state.copyJob=nil
 if snapshot.part>1 or not final then
  text=('=== JCHUB SCAN PASTE PART %d %s BEGIN ===\n'):format(snapshot.part,final and 'FINAL' or 'MORE')..text..
   ('\n=== JCHUB SCAN PASTE PART %d END ==='):format(snapshot.part)
 end
 -- Retain only this small prepared part, never a second full serialized scan.
 snapshot.lastPart=text
 if copyText(text) then
  status=final and ('Full snapshot copied'..(snapshot.part>1 and ('; FINAL part '..snapshot.part) or '')..'. '..(state.running and 'Recording continues.' or 'Recording stopped.'))
   or ('Part '..snapshot.part..' copied. Paste it, then COPY NEXT PART. No scan data was dropped.')
 else
  state.pendingPasteText=text
  status='Clipboard unavailable; this part is shown for manual copy. '..(final and 'FINAL part.' or 'Then use Copy Next Part.')
 end
end
local function gameName()
 if state.gameName then return state.gameName end
 local ok,info=pcall(function()return game:GetService('MarketplaceService'):GetProductInfoAsync(game.PlaceId,Enum.InfoType.Asset)end)
 if not ok then ok,info=pcall(function()return game:GetService('MarketplaceService'):GetProductInfo(game.PlaceId,Enum.InfoType.Asset)end) end
 state.gameName=ok and type(info)=='table' and type(info.Name)=='string' and info.Name:match('%S') and info.Name or ('Game_'..game.PlaceId)
 return state.gameName
end
local function folder(path)
 if type(isfolder)=='function' then local ok,yes=pcall(isfolder,path);if ok and yes then return end end
 assert(type(makefolder)=='function','Folder export requires makefolder in this executor')
 local ok,result=pcall(makefolder,path)
 if not ok then
  local exists,yes=false,false;if type(isfolder)=='function' then exists,yes=pcall(isfolder,path) end
  assert(exists and yes,'Cannot create export folder: '..tostring(result))
 else assert(result~=false,'Folder creation returned false') end
end
local function writeExport(path,text)
 local ok,result=pcall(writefile,path,text);assert(ok and result~=false,'File write failed: '..path)
end
local function export()
 if state.exportJob then status='Export already running; wait for completion.';return false end
 if type(writefile)~='function' or type(makefolder)~='function' then status='Folder export needs writefile and makefolder; no export written.';return false end
 state.exportJob={preparing=true}
 local snapshot=Core.fullSnapshot(state,{place=game.PlaceId,game=game.GameId,job=game.JobId,snapshotTime=os.time(),currentPosition=pose()})
 local reportText=report()
 local ok,err=pcall(function()
  local title=gameName();local safe=Core.fileComponent(title,'Game_'..game.PlaceId)
  state.exportSerial=(state.exportSerial or 0)+1
  local stamp=os.date('!%Y%m%d_%H%M%S')..'_'..math.floor(os.clock()*1000)..'_'..state.exportSerial
  folder('JcHub_Scans')
  local directory='JcHub_Scans/'..safe..'_'..game.PlaceId..'_'..stamp
  if type(isfolder)=='function' then local attempts=0;while isfolder(directory) do attempts+=1;assert(attempts<50,'Cannot allocate unique export folder');directory=directory..'_'..attempts end end
  folder(directory)
  state.exportJob={directory=directory,prefix=safe,snapshot=snapshot,report=reportText,section=0,index=1,files={},title=title}
  status='Exporting '..directory..' (recording continues unless paused).'
 end)
 if not ok then state.exportJob=nil;status='Export could not start: '..Core.cleanString(err);return false end
 return true
end
local function stepExport()
 local job=state.exportJob;if not job or job.preparing then return end
 local ok,err=pcall(function()
  local name,data
  if job.section==0 then name=job.prefix..'_Report.txt';data=job.report;job.section=1
  elseif job.section==1 and job.index<=#job.snapshot.objects then
   local rows={};for i=job.index,math.min(job.index+999,#job.snapshot.objects) do rows[#rows+1]=job.snapshot.objects[i] end
   name=job.prefix..'_Objects_'..string.format('%04d',math.floor((job.index-1)/1000)+1)..'.json';data=Http:JSONEncode({schema=1,records=rows});job.index+=#rows
  elseif job.section<=2 then
   if job.section==1 then job.section=2;job.index=1 end
   if job.index<=#job.snapshot.actions then
    local rows={};for i=job.index,math.min(job.index+499,#job.snapshot.actions) do rows[#rows+1]=job.snapshot.actions[i] end
    name=job.prefix..'_Actions_'..string.format('%04d',math.floor((job.index-1)/500)+1)..'.json';data=Http:JSONEncode({schema=1,events=rows});job.index+=#rows
   else job.section=3 end
  end
  if name then writeExport(job.directory..'/'..name,data);table.insert(job.files,name);status='Exporting '..job.directory..' | '..#job.files..' files written';return end
  if job.section==3 then
   local snap=job.snapshot
   local manifest={schema=1,version='1.0.5',gameName=job.title,place=game.PlaceId,game=game.GameId,job=game.JobId,directory=job.directory,files=job.files,
    objectCount=snap.objectCount,eventCount=snap.eventCount,totalEvents=snap.totalEvents,recording=snap.recording,position=snap.context.currentPosition,
    droppedEvents=snap.droppedEvents,nodeLimitHits=snap.nodeLimitHits,connectionLimitHits=snap.connectionLimitHits,queueLimitHits=snap.queueLimitHits,
    errors=snap.errors,scans=snap.scans,markers=snap.markers,captureOptions=snap.captureOptions,limits=Core.LIMITS,disclosure=snap.disclosure}
   writeExport(job.directory..'/'..job.prefix..'_Manifest.json',Http:JSONEncode(manifest))
   state.lastExportDirectory=job.directory;state.exportJob=nil;status='Export complete: '..job.directory..' | '..#job.files..' data/report files plus manifest.';copyText(status)
  end
 end)
 if not ok then state.exportJob=nil;status='Export incomplete: '..Core.cleanString(err) end
end
local function unload()
 if not alive then return end
 Core.log(state,'SCANNER_UNLOADED',nil,{},true)
 alive=false;state.running=false
 for _,c in ipairs(connections) do pcall(function()c:Disconnect()end) end
 if gui then gui:Destroy() end
 if env then env.JCSAE_Scanner_Unload=nil end
end
if env then env.JCSAE_Scanner_Unload=unload end
local function new(kind,parent,props)
 local obj=Instance.new(kind)
 for k,v in pairs(props or {}) do obj[k]=v end
 obj.Parent=parent;return obj
end
gui=new('ScreenGui',playerGui,{Name='JCSAESCANNER',ResetOnSpawn=false,IgnoreGuiInset=false,DisplayOrder=40000})
window=new('Frame',gui,{Name='ScannerWindow',AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.new(.92,0,.85,0),BackgroundColor3=Color3.fromRGB(0,0,0),BorderSizePixel=0})
new('UISizeConstraint',window,{MinSize=Vector2.new(360,380),MaxSize=Vector2.new(1100,760)})
new('UICorner',window,{CornerRadius=UDim.new(0,10)})
new('UIStroke',window,{Color=Color3.fromRGB(210,32,52),Thickness=1.4,Transparency=.1})
local header=new('Frame',window,{Active=true,BackgroundTransparency=1,Size=UDim2.new(1,-56,0,49)})
local badge=new('TextLabel',header,{Position=UDim2.fromOffset(10,6),Size=UDim2.fromOffset(42,36),BackgroundColor3=Color3.fromRGB(32,5,12),
 Text='JC',TextSize=19,Font=Enum.Font.GothamBold,TextColor3=Color3.fromRGB(245,43,62),BorderSizePixel=0})
new('UICorner',badge,{CornerRadius=UDim.new(0,8)})
new('UIStroke',badge,{Color=Color3.fromRGB(120,20,35),Thickness=1})
new('TextLabel',header,{Position=UDim2.fromOffset(63,5),Size=UDim2.new(1,-66,0,23),BackgroundTransparency=1,
 Text='JcHub | UNIVERSAL SCANNER',Font=Enum.Font.GothamBold,TextSize=15,TextColor3=Color3.new(1,1,1),TextXAlignment=Enum.TextXAlignment.Left})
new('TextLabel',header,{Position=UDim2.fromOffset(63,28),Size=UDim2.new(1,-66,0,15),BackgroundTransparency=1,
 Text='UNIVERSAL / v1.0.5',Font=Enum.Font.Gotham,TextSize=10,TextColor3=Color3.fromRGB(170,170,180),TextXAlignment=Enum.TextXAlignment.Left})
new('Frame',window,{Position=UDim2.fromOffset(0,48),Size=UDim2.new(1,0,0,1),BackgroundColor3=Color3.fromRGB(115,18,31),BorderSizePixel=0})
local scanPage=new('Frame',window,{Name='ScanPage',Position=UDim2.fromOffset(148,52),Size=UDim2.new(1,-160,1,-62),BackgroundTransparency=1})
statusLabel=new('TextLabel',scanPage,{BackgroundTransparency=1,Position=UDim2.fromOffset(8,0),Size=UDim2.new(1,-24,0,54),TextWrapped=true,
 Text='',Font=Enum.Font.Gotham,TextSize=12,TextColor3=Color3.fromRGB(245,115,130),TextXAlignment=Enum.TextXAlignment.Left})
positionLabel=new('TextLabel',scanPage,{BackgroundTransparency=1,Position=UDim2.fromOffset(8,58),Size=UDim2.new(1,-24,0,26),
 Text='',Font=Enum.Font.Code,TextSize=12,TextColor3=Color3.fromRGB(240,205,130),TextXAlignment=Enum.TextXAlignment.Left})
local buttons=new('ScrollingFrame',scanPage,{BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=4,ScrollBarImageColor3=Color3.fromRGB(240,43,62),AutomaticCanvasSize=Enum.AutomaticSize.Y,CanvasSize=UDim2.new(),Position=UDim2.fromOffset(4,92),Size=UDim2.new(1,-8,1,-145)})
new('UIGridLayout',buttons,{CellSize=UDim2.new(.333,-5,0,42),CellPadding=UDim2.fromOffset(6,6),SortOrder=Enum.SortOrder.LayoutOrder})
local function button(label,fn)
 local accent=label=='COPY ALL' or label=='STOP + COPY ALL' or label=='MARK LOCATION'
 local b=new('TextButton',buttons,{BackgroundColor3=accent and Color3.fromRGB(110,14,31) or Color3.fromRGB(23,23,28),BorderSizePixel=0,Text=label,
  TextSize=12,Font=Enum.Font.GothamBold,TextColor3=Color3.new(1,1,1),TextWrapped=true})
 new('UICorner',b,{CornerRadius=UDim.new(0,6)})
 new('UIStroke',b,{Color=Color3.fromRGB(100,22,36),Thickness=1,Transparency=.2})
 connect(b.Activated,function()local ok,err=pcall(fn);if not ok then addError(label,err);status=label..' failed: '..Core.cleanString(err) end end)
 return b
end
local preview=new('TextBox',gui,{Visible=false,ClearTextOnFocus=false,MultiLine=true,TextEditable=false,TextWrapped=false,
 AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.52),Size=UDim2.fromScale(.9,.65),BackgroundColor3=Color3.fromRGB(15,15,20),
 TextColor3=Color3.new(1,1,1),TextSize=12,Font=Enum.Font.Code,TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Top})
local closePreview=new('TextButton',preview,{AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,-4,0,4),Size=UDim2.fromOffset(68,32),
 Text='CLOSE',Font=Enum.Font.GothamBold,TextSize=12,BackgroundColor3=Color3.fromRGB(55,30,45),TextColor3=Color3.new(1,1,1)})
connect(closePreview.Activated,function()preview.Visible=false end)
local function setMinimized(value)
 if not alive then return end
 minimized=value
 if minimized then
  restorePreview=preview.Visible;preview.Visible=false
  restoreMarker=markerOverlay and markerOverlay.Visible or false
  if markerOverlay then markerOverlay.Visible=false end
  if markerInput then pcall(function()markerInput:ReleaseFocus()end)end
 else
  if restorePreview then preview.Visible=true;restorePreview=false end
  if markerOverlay and restoreMarker then markerOverlay.Visible=true;restoreMarker=false end
 end
 window.Visible=not minimized;launcher.Visible=minimized
end
launcher=new('TextButton',gui,{Name='ScannerReopen',Visible=false,Position=UDim2.fromOffset(16,90),Size=UDim2.fromOffset(138,44),
 BackgroundColor3=Color3.fromRGB(110,14,31),TextColor3=Color3.new(1,1,1),Text='SCANNER | REC',TextSize=12,Font=Enum.Font.GothamBold,BorderSizePixel=0})
new('UICorner',launcher,{CornerRadius=UDim.new(0,8)})
connect(launcher.Activated,function()setMinimized(false)end)
local minimize=new('TextButton',window,{Name='MinimizeScanner',AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,-8,0,3),Size=UDim2.fromOffset(44,32),
 BackgroundColor3=Color3.fromRGB(110,14,31),TextColor3=Color3.new(1,1,1),Text='-',TextSize=20,Font=Enum.Font.GothamBold,BorderSizePixel=0})
connect(minimize.Activated,function()setMinimized(true)end)
local function copyReport()
 local text=shortReport()
 if copyText(text) then status='Summary copied. Export Data for all retained object/action JSON.'
 else preview.Text=text;preview.Visible=not preview.Visible;status='Report window open; manually select/copy text. Tap Copy Report again to close.' end
end
button('COPY ALL',copyAll)
button('COPY NEXT PART',copyNextPart)
local pause
pause=button('PAUSE',function()
 state.running=not state.running;if not state.running then state.manualScan=false end;pause.Text=state.running and 'PAUSE' or 'RESUME'
 Core.log(state,state.running and 'RECORDING_RESUMED' or 'RECORDING_PAUSED',nil,{},true)
 status=state.running and 'Recording resumed; rescanning current objects.' or 'Paused. Existing data retained.'
 if state.running then scan() end
end)
button('SCAN NOW',scan)
local coreGuiButton
coreGuiButton=button('COREGUI: ON',function()
 state.coreGuiEnabled=not state.coreGuiEnabled
 coreGuiButton.Text=state.coreGuiEnabled and 'COREGUI: ON' or 'COREGUI: OFF'
 attachCoreGui()
 Core.log(state,'COREGUI_OPTION',nil,{enabled=state.coreGuiEnabled,status=state.coreGuiStatus},true)
 status='CoreGui: '..state.coreGuiStatus..'. Existing captured data retained.'
end)
local hubsButton
hubsButton=button('HUB GUIS: ON',function()
 state.includeHubUI=not state.includeHubUI
 hubsButton.Text=state.includeHubUI and 'HUB GUIS: ON' or 'HUB GUIS: OFF'
 if state.includeHubUI then enqueue(playerGui);attachCoreGui() end
 Core.log(state,'HUB_GUI_OPTION',nil,{enabled=state.includeHubUI},true)
end)
local consoleButton
consoleButton=button('CONSOLE: ON',function()
 state.captureConsole=not state.captureConsole
 consoleButton.Text=state.captureConsole and 'CONSOLE: ON' or 'CONSOLE: OFF'
 Core.log(state,'CONSOLE_OPTION',nil,{enabled=state.captureConsole,available=logAvailable},true)
 status='Console recording '..(state.captureConsole and 'enabled' or 'disabled')..'; other scripts keep their own console output.'
end)
local repeatButton
repeatButton=button('GROUP REPEATS: ON',function()
 state.groupConsole=not state.groupConsole;state.consoleGroups={}
 repeatButton.Text=state.groupConsole and 'GROUP REPEATS: ON' or 'GROUP REPEATS: OFF'
 Core.log(state,'CONSOLE_GROUP_OPTION',nil,{enabled=state.groupConsole},true)
 status='Repeated messages '..(state.groupConsole and 'grouped with counts/times' or 'recorded individually')..' in this scan only.'
end)
button('COPY POSITION',function()
 local text='PlaceId: '..game.PlaceId..'\n'..Core.positionText(pose())
 Core.log(state,'POSITION_BOOKMARK',nil,{location=text},true)
 if copyText(text) then status='Character position and rotation copied.' else preview.Text=text;preview.Visible=true;status='Coordinates shown in report window.' end
end)
button('COPY SUMMARY',copyReport)
button('EXPORT DATA',export)
markerOverlay=new('Frame',gui,{Name='MarkerDialog',Visible=false,Active=true,Size=UDim2.fromScale(1,1),BackgroundColor3=Color3.new(0,0,0),BackgroundTransparency=.3,ZIndex=50})
local markerCard=new('Frame',markerOverlay,{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.new(.8,0,0,194),BackgroundColor3=Color3.fromRGB(9,9,12),BorderSizePixel=0,ZIndex=51})
new('UISizeConstraint',markerCard,{MinSize=Vector2.new(280,194),MaxSize=Vector2.new(400,194)})
new('UICorner',markerCard,{CornerRadius=UDim.new(0,9)})
new('UIStroke',markerCard,{Color=Color3.fromRGB(220,35,55),Thickness=1.4})
new('TextLabel',markerCard,{Position=UDim2.fromOffset(12,8),Size=UDim2.new(1,-24,0,26),BackgroundTransparency=1,Text='What is this location for?',TextColor3=Color3.new(1,1,1),TextSize=15,Font=Enum.Font.GothamBold,ZIndex=52})
markerHint=new('TextLabel',markerCard,{Position=UDim2.fromOffset(12,38),Size=UDim2.new(1,-24,0,24),BackgroundTransparency=1,Text='',TextColor3=Color3.fromRGB(180,180,190),TextSize=11,Font=Enum.Font.Code,ZIndex=52})
markerInput=new('TextBox',markerCard,{Name='MarkerPurpose',Position=UDim2.fromOffset(12,68),Size=UDim2.new(1,-24,0,44),BackgroundColor3=Color3.fromRGB(24,24,29),TextColor3=Color3.new(1,1,1),PlaceholderColor3=Color3.fromRGB(145,145,155),
 Text='',PlaceholderText='Sell stand / egg yard / hatch area...',ClearTextOnFocus=false,TextSize=14,Font=Enum.Font.Gotham,ZIndex=52})
new('UICorner',markerInput,{CornerRadius=UDim.new(0,6)})
local saveMarker=new('TextButton',markerCard,{Name='SaveMarker',Position=UDim2.fromOffset(12,128),Size=UDim2.new(.55,-16,0,44),BackgroundColor3=Color3.fromRGB(110,14,31),Text='SAVE MARK',TextColor3=Color3.new(1,1,1),TextSize=13,Font=Enum.Font.GothamBold,BorderSizePixel=0,ZIndex=52})
local cancelMarker=new('TextButton',markerCard,{Name='CancelMarker',Position=UDim2.new(.55,4,0,128),Size=UDim2.new(.45,-16,0,44),BackgroundColor3=Color3.fromRGB(24,24,29),Text='CANCEL',TextColor3=Color3.new(1,1,1),TextSize=13,Font=Enum.Font.GothamBold,BorderSizePixel=0,ZIndex=52})
new('UICorner',saveMarker,{CornerRadius=UDim.new(0,6)});new('UICorner',cancelMarker,{CornerRadius=UDim.new(0,6)})
connect(saveMarker.Activated,function()
 if not pendingMarker then return end
 local purpose=Core.cleanString(tostring(markerInput.Text or ''):match('^%s*(.-)%s*$'))
 if purpose=='' then markerHint.Text='Enter a short purpose, or press Cancel.';return end
 local number=#state.labels+1
 state.labels[number]={name='Marker '..number,purpose=purpose,character=pendingMarker.character,markedAt=pendingMarker.at,savedAt=os.clock()-state.started}
 local entry=Core.log(state,'USER_MARKER',nil,{name='Marker '..number,purpose=purpose,markedAt=pendingMarker.at},true)
 if entry then entry.character=pendingMarker.character end
 markerOverlay.Visible=false;pcall(function()markerInput:ReleaseFocus()end);pendingMarker=nil
 status='Marker '..number..' saved: '..purpose
end)
connect(cancelMarker.Activated,function()markerOverlay.Visible=false;pendingMarker=nil;pcall(function()markerInput:ReleaseFocus()end);status='Location mark cancelled.'end)
button('MARK LOCATION',function()
 local current=pose()
 if not current then status='Character/root unavailable; cannot mark this location.';return end
 pendingMarker={character=current,at=os.clock()-state.started}
 markerInput.Text='';markerOverlay.Visible=true
 local p=current.position;markerHint.Text=('Captured XYZ: %.2f, %.2f, %.2f'):format(p.x,p.y,p.z)
 pcall(function()markerInput:CaptureFocus()end)
end)
button('CLEAR LOG',function()
 state.events={};state.consoleGroups={};state.consoleOccurrences=0;state.consoleGrouped=0;state.head=1;state.eventCount=0;state.totalEvents=0;state.droppedEvents=0;state.pasteSnapshot=nil;state.pendingPasteText=nil;state.copyJob=nil
 Core.log(state,'LOG_CLEARED',nil,{},true);status='Action log cleared. Object snapshots retained.'
end)
button('SHOW/HIDE LOG',function()preview.Text=shortReport();preview.Visible=not preview.Visible end)
button('STOP + COPY ALL',function()
 if state.running then state.running=false;state.manualScan=false;pause.Text='RESUME';Core.log(state,'RECORDING_PAUSED',nil,{},true) end
 state.copyJob=nil
 copyAll()
end)
button('UNLOAD',unload)
logLabel=new('TextLabel',scanPage,{BackgroundTransparency=1,Position=UDim2.new(0,8,1,-46),Size=UDim2.new(1,-16,0,42),TextWrapped=true,
 Text='CoreGui capture depends on access. Repeats group in the report; other hubs still print normally. Developer-console GUI/chat/TextBox values are excluded. RShift hides/reopens. Scroll for more controls.',Font=Enum.Font.Gotham,TextSize=11,TextColor3=Color3.fromRGB(170,170,180),TextXAlignment=Enum.TextXAlignment.Left})
-- Local browser of observed records; never activates another hub's controls.
local browse={category='Scan',group='All',query='',page=1,rows={},token=0,lastRefresh=0,roots=true}
local sidebar=new('ScrollingFrame',window,{Name='CategoryTabs',Position=UDim2.fromOffset(8,54),Size=UDim2.new(0,132,1,-64),BackgroundTransparency=1,BorderSizePixel=0,AutomaticCanvasSize=Enum.AutomaticSize.Y,CanvasSize=UDim2.new(),ScrollBarThickness=3})
new('UIListLayout',sidebar,{Padding=UDim.new(0,6),SortOrder=Enum.SortOrder.LayoutOrder})
local browser=new('Frame',window,{Name='BrowserPage',Position=UDim2.fromOffset(148,54),Size=UDim2.new(1,-160,1,-64),BackgroundTransparency=1,Visible=false})
local function uiButton(parent,text,pos,size,fn)
 local b=new('TextButton',parent,{Position=pos,Size=size,Text=text,TextWrapped=true,TextSize=12,Font=Enum.Font.GothamBold,TextColor3=Color3.new(1,1,1),BackgroundColor3=Color3.fromRGB(30,18,24),BorderSizePixel=0})
 new('UICorner',b,{CornerRadius=UDim.new(0,6)});connect(b.Activated,fn);return b
end
local search=new('TextBox',browser,{Name='BrowserSearch',Position=UDim2.fromOffset(0,0),Size=UDim2.new(1,-104,0,34),Text='',PlaceholderText='Search observed names / paths / IDs',ClearTextOnFocus=false,TextColor3=Color3.new(1,1,1),BackgroundColor3=Color3.fromRGB(24,24,30),Font=Enum.Font.Gotham,TextSize=13})
local groupBar=new('ScrollingFrame',browser,{Name='ObservedAreas',Position=UDim2.fromOffset(0,43),Size=UDim2.new(1,0,0,34),CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.X,ScrollBarThickness=2,BackgroundTransparency=1,BorderSizePixel=0})
new('UIListLayout',groupBar,{FillDirection=Enum.FillDirection.Horizontal,Padding=UDim.new(0,5)})
local list=new('ScrollingFrame',browser,{Name='RecordList',Position=UDim2.fromOffset(0,84),Size=UDim2.new(.47,-5,1,-126),CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y,ScrollBarThickness=3,BackgroundColor3=Color3.fromRGB(12,12,16),BorderSizePixel=0})
new('UIListLayout',list,{Padding=UDim.new(0,5)})
local detailFrame=new('ScrollingFrame',browser,{Name='RecordDetails',Position=UDim2.new(.47,6,0,84),Size=UDim2.new(.53,-6,1,-126),CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y,ScrollBarThickness=3,BackgroundColor3=Color3.fromRGB(12,12,16),BorderSizePixel=0})
new('UIListLayout',detailFrame,{Padding=UDim.new(0,8)})
local picture=new('ImageLabel',detailFrame,{Name='ObservedImage',LayoutOrder=1,Size=UDim2.new(1,-8,0,165),BackgroundTransparency=1,ScaleType=Enum.ScaleType.Fit,Image='',Visible=false})
local viewport=new('ViewportFrame',detailFrame,{Name='ObservedModel',LayoutOrder=2,Size=UDim2.new(1,-8,0,165),BackgroundColor3=Color3.fromRGB(24,24,30),Visible=false})
local details=new('TextLabel',detailFrame,{LayoutOrder=4,Size=UDim2.new(1,-8,0,0),AutomaticSize=Enum.AutomaticSize.Y,Text='Select an observed object.',TextWrapped=true,TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Top,TextColor3=Color3.fromRGB(225,225,235),Font=Enum.Font.Code,TextSize=12,BackgroundTransparency=1})
local info=new('TextLabel',browser,{Position=UDim2.new(0,82,1,-31),Size=UDim2.new(1,-164,0,30),Text='',TextWrapped=true,TextSize=11,Font=Enum.Font.Gotham,TextColor3=Color3.fromRGB(190,190,200),BackgroundTransparency=1})
local tabButtons,rowButtons,groupButtons={},{},{}
local requestRefresh,renderRows,showRecord
local childButton
local linkButtons={}
local function clearButtons(items)for _,b in ipairs(items) do b:Destroy() end;table.clear(items)end
local function openCategory(name)
 browse.category=name;browse.group='All';browse.prefix=nil;browse.page=1;browse.selected=nil;clearButtons(linkButtons)
 picture.Visible=false;viewport.Visible=false;viewport:ClearAllChildren();details.Text='Select an observed object.'
 if childButton then childButton.Visible=false end
 scanPage.Visible=name=='Scan';browser.Visible=name~='Scan'
 for category,b in pairs(tabButtons) do b.BackgroundColor3=category==name and Color3.fromRGB(115,12,32) or Color3.fromRGB(23,23,29) end
 if name~='Scan' then requestRefresh() end
end
local function addTab(name)
 if tabButtons[name] then return end
 local b=uiButton(sidebar,name,UDim2.new(),UDim2.new(1,-5,0,38),function()openCategory(name)end)
 b.Name='Category_'..name;tabButtons[name]=b
end
requestRefresh=function()
 browse.token+=1;browse.work={token=browse.token,cursor=nil,seen={},rows={},groups={},category=browse.category,group=browse.group,query=browse.query,prefix=browse.prefix,roots=browse.roots}
 info.Text='Filtering recorded objects...'
end
local function modelPreview(obj)
 local ok=pcall(function()
  local descendants=obj:GetDescendants();assert(#descendants<=2000,'Model too large for preview')
  local clone=obj:Clone();assert(clone,'Model is not cloneable')
  for _,n in ipairs(clone:GetDescendants()) do
   if n:IsA('LuaSourceContainer') or n:IsA('ProximityPrompt') or n:IsA('Sound') or n:IsA('TextBox') or Core.privatePath(n:GetFullName(),true) then n:Destroy()
   elseif n:IsA('BasePart') then n.Anchored=true;n.CanCollide=false;n.CanTouch=false;n.CanQuery=false end
  end
  if clone:IsA('BasePart') then clone.Anchored=true;clone.CanCollide=false end
  viewport:ClearAllChildren()
  local world=Instance.new('WorldModel');world.Parent=viewport
  local model=clone
  if not clone:IsA('Model') then model=Instance.new('Model');clone.Parent=model end
  model.Parent=world
  local cf,size=model:GetBoundingBox();local radius=math.max(size.X,size.Y,size.Z,1)
  local camera=Instance.new('Camera');camera.CFrame=CFrame.lookAt(cf.Position+Vector3.new(1,.6,1).Unit*radius*1.6,cf.Position);camera.Parent=viewport;viewport.CurrentCamera=camera
  viewport.Visible=true
 end)
 return ok
end
local function ownInstance(id)return state.instances and state.instances[id] end
showRecord=function(id)
 local r=state.records[id];if not r then return end
 browse.selected=id;clearButtons(linkButtons);if childButton then childButton.Visible=browse.category=='GUIs' end;picture.Visible=false;picture.Image='';viewport.Visible=false;viewport:ClearAllChildren()
 local a,p=r.attributes or {},r.properties or {}
 local lines={r.name or '?',r.class or '?',r.path or '?','Present: '..tostring(r.present),'Area: '..Core.group(r,browse.category)}
 for _,key in ipairs({'UID','ItemType','CardId','PhotocardId','PetId','EggId','AssetCategory','Category','DisplayName','Rarity','Weight','Mutations'}) do if a[key]~=nil then lines[#lines+1]=key..': '..tostring(a[key]) end end
 local obj=ownInstance(id);local image=type(p.Image)=='string' and p.Image~='' and p.Image or type(p.Texture)=='string' and p.Texture~='' and p.Texture or nil
 if not image and obj and browse.category~='GUIs' then
  pcall(function()local seen=0;for _,n in ipairs(obj:GetDescendants()) do seen+=1;if seen>500 then break end;if (n:IsA('ImageLabel') or n:IsA('ImageButton')) and n.Image~='' and not Core.privatePath(n:GetFullName(),state.includeHubUI) then local ancestor=n.Parent;local private=false;while ancestor and ancestor~=obj do if ancestor:IsA('TextBox') then private=true;break end;ancestor=ancestor.Parent end;if not private then image=n.Image;break end end end end)
 end
 local model=obj and (r.class=='Model' or r.class=='Part' or r.class=='MeshPart') and obj or nil
 if browse.category=='Eggs' then
  lines[#lines+1]='Contents unknown unless explicit linked metadata is present.'
  for _,key in ipairs({'CardId','PhotocardId','ResultCardId','PetId','ResultPetId'}) do
   if a[key] then
    lines[#lines+1]='Recorded link '..key..': '..tostring(a[key])
    for linked in pairs(state.categories and state.categories.Photocards or {}) do
     local card=state.records[linked];local ca=card and card.attributes or {}
     if ca.CardId==a[key] or ca.PhotocardId==a[key] then
      local targetId=linked
      local b=uiButton(detailFrame,'LINKED CARD: '..tostring(card.name),UDim2.new(),UDim2.new(1,-8,0,34),function()openCategory('Photocards');showRecord(targetId)end)
      b.LayoutOrder=5;table.insert(linkButtons,b);break
     end
    end
   end
  end
  if type(a.AssetCategory)=='string' then
   lines[#lines+1]='Observed pet type: '..a.AssetCategory..' (AssetCategory; final result unverified)'
   for mid in pairs(state.categories and state.categories.Models or {}) do
    local candidate=state.records[mid]
    if candidate and candidate.name==a.AssetCategory and (candidate.path or ''):find('ReplicatedStorage.AssetModels.',1,true) then
     model=ownInstance(mid);lines[#lines+1]='Loaded pet model: '..candidate.path;break
    end
   end
  end
 end
 if image and image:sub(1,1)~='[' then picture.Image=image;picture.Visible=true;lines[#lines+1]='Preview uses a recorded image; rendering depends on asset access.' end
 if model and (not picture.Visible or browse.category=='Eggs') and modelPreview(model) then lines[#lines+1]='3D preview is a sanitized clone of the loaded model.' end
 if not picture.Visible and not viewport.Visible then lines[#lines+1]='No usable image/model preview available.' end
 local keys={};for key in pairs(a) do table.insert(keys,key) end;table.sort(keys)
 lines[#lines+1]='Recorded attributes:'
 for i=1,math.min(#keys,40) do local key=keys[i];local value=a[key];lines[#lines+1]=key..' = '..(type(value)=='table' and '[structured data in export]' or tostring(value)) end
 if browse.category=='GUIs' then lines[#lines+1]='Use View Children to inspect hierarchy. Browser selections never activate the original GUI.' end
 details.Text=table.concat(lines,'\n')
end
childButton=uiButton(detailFrame,'VIEW CHILDREN',UDim2.new(),UDim2.new(1,-8,0,32),function()
 local r=browse.selected and state.records[browse.selected]
 if r then browse.prefix=r.path;browse.roots=false;browse.page=1;requestRefresh() end
end);childButton.LayoutOrder=3;childButton.Visible=false
renderRows=function()
 clearButtons(rowButtons)
 local first=(browse.page-1)*24+1
 for i=first,math.min(first+23,#browse.rows) do
  local id=browse.rows[i];local r=state.records[id]
  if r then
   local b=uiButton(list,(r.name or '?')..'\n'..r.class..(r.present and '' or ' [historical]'),UDim2.new(),UDim2.new(1,-7,0,48),function()showRecord(id)end)
   b.Name='Observed_'..id;table.insert(rowButtons,b)
  end
 end
 info.Text=browse.category..' | '..#browse.rows..' matches | '..browse.page..'/'..math.max(1,math.ceil(#browse.rows/24))..(browse.prefix and '\n'..browse.prefix or '')
end
uiButton(browser,'PREV',UDim2.new(0,0,1,-32),UDim2.fromOffset(75,30),function()browse.page=math.max(1,browse.page-1);renderRows()end)
uiButton(browser,'NEXT',UDim2.new(1,-75,1,-32),UDim2.fromOffset(75,30),function()browse.page=math.min(math.max(1,math.ceil(#browse.rows/24)),browse.page+1);renderRows()end)
uiButton(browser,'BACK / ALL',UDim2.new(1,-98,0,0),UDim2.fromOffset(98,34),function()browse.prefix=nil;browse.group='All';browse.page=1;browse.selected=nil;requestRefresh()end)
connect(search:GetPropertyChangedSignal('Text'),function()browse.query=search.Text:lower();browse.page=1;requestRefresh()end)
addTab('Scan');openCategory('Scan')
local lastTabs=0
browserStep=function()
 local now=os.clock()
 local width=window.AbsoluteSize and window.AbsoluteSize.X or 1100
 local compact=width<650
 list.Size=UDim2.new(compact and 1 or .47,compact and 0 or -5,1,-126)
 detailFrame.Position=UDim2.new(compact and 0 or .47,compact and 0 or 6,0,84)
 detailFrame.Size=UDim2.new(compact and 1 or .53,compact and 0 or -6,1,-126)
 list.Visible=not compact or browse.selected==nil;detailFrame.Visible=not compact or browse.selected~=nil
 if now-lastTabs>.5 then
  lastTabs=now
  for _,name in ipairs({'Eggs','Photocards','Pets','GUIs','Tools','Models','Parts','Assets','Prompts','Remotes','Sounds','Values','Scripts','All Objects'}) do
   local n=state.categoryCounts and state.categoryCounts[name] or 0
   if n>0 then addTab(name);tabButtons[name].Text=name..' ('..n..')' end
  end
 end
 if browse.category=='Scan' then return end
 if not browse.work and now-browse.lastRefresh>4 then requestRefresh() end
 local work=browse.work;if not work then return end
 local set=state.categories and state.categories[work.category] or {};local budget=os.clock()+.003
 for i=1,1000 do
  local ok,id=pcall(next,set,work.cursor)
  if not ok then work.cursor=nil;ok,id=pcall(next,set,nil) end
  if not id then
   table.sort(work.rows);browse.rows=work.rows;browse.work=nil;browse.lastRefresh=now
   clearButtons(groupButtons)
   local names={'All'};for name in pairs(work.groups) do if name~='All' then table.insert(names,name) end end;table.sort(names,function(a,b)if a=='All' then return true elseif b=='All' then return false else return a<b end end)
   for _,name in ipairs(names) do
    local g=name
    local b=uiButton(groupBar,g,UDim2.new(),UDim2.fromOffset(140,29),function()browse.group=g;browse.page=1;requestRefresh()end)
    b.BackgroundColor3=g==browse.group and Color3.fromRGB(110,12,30) or Color3.fromRGB(24,24,30);table.insert(groupButtons,b)
   end
   renderRows();return
  end
  work.cursor=id
  if not work.seen[id] then
   work.seen[id]=true;local r=state.records[id]
   if r then
    local root=r.class=='ScreenGui' or r.class=='SurfaceGui' or r.class=='BillboardGui'
    local inTree=not work.prefix or (r.path or ''):sub(1,#work.prefix+1)==work.prefix..'.'
    local include=work.category~='GUIs' or work.prefix or root or work.query~=''
    if inTree and include then
     local group=Core.group(r,work.category);work.groups[group]=true
     local hay=(tostring(r.name)..' '..tostring(r.path)..' '..tostring((r.attributes or {}).CardId or '')..' '..tostring((r.attributes or {}).UID or '')):lower()
     if (work.group=='All' or work.group==group) and (work.query=='' or hay:find(work.query,1,true)) then table.insert(work.rows,id) end
    end
   end
  end
  if os.clock()>=budget then return end
 end
end

local drag,dragStart,dragOrigin
connect(header.InputBegan,function(input)
 if input.UserInputType==Enum.UserInputType.Touch or input.UserInputType==Enum.UserInputType.MouseButton1 then drag=input;dragStart=input.Position;dragOrigin=window.Position end
end)
connect(UIS.InputChanged,function(input)
 if not drag or (input~=drag and input.UserInputType~=Enum.UserInputType.MouseMovement) then return end
 local size=Workspace.CurrentCamera and Workspace.CurrentCamera.ViewportSize
 if not size or size.X<=0 or size.Y<=0 then return end
 local d=input.Position-dragStart
 local x=math.clamp(dragOrigin.X.Scale+d.X/size.X,0,1);local y=math.clamp(dragOrigin.Y.Scale+d.Y/size.Y,0,1)
 window.Position=UDim2.fromScale(x,y)
end)
connect(UIS.InputEnded,function(input)if input==drag or input.UserInputType==Enum.UserInputType.MouseButton1 then drag=nil end end)
local keys={W=true,A=true,S=true,D=true,E=true,F=true,Q=true,R=true,Space=true,LeftShift=true,RightShift=true,
 One=true,Two=true,Three=true,Four=true,Five=true,Six=true,Seven=true,Eight=true,Nine=true,Zero=true}
connect(UIS.InputBegan,function(input,processed)
 local focused=UIS:GetFocusedTextBox()
 if input.UserInputType==Enum.UserInputType.Keyboard and input.KeyCode.Name=='RightShift' then
  if not focused or focused==preview then setMinimized(not minimized) end
  return
 end
 if focused then return end
 if input.UserInputType==Enum.UserInputType.Keyboard and keys[input.KeyCode.Name] then Core.log(state,'GAME_CONTROL',nil,{key=input.KeyCode.Name,processed=processed})
 elseif not processed and (input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch) then
  Core.log(state,'WORLD_POINTER',nil,{type=tostring(input.UserInputType),screen=Core.safe(input.Position)})
 end
end)
for _,kind in ipairs({'PromptTriggered','PromptButtonHoldBegan','PromptButtonHoldEnded'}) do
 local ok,signal=pcall(function()return PPS[kind]end)
 if ok then connect(signal,function(prompt,who)
  if who==nil or who==player then Core.log(state,kind,prompt) end
 end) end
end
connect(player.CharacterAdded,function(character)Core.log(state,'CHARACTER_ADDED',character);enqueue(character)end)
for _,root in ipairs({Workspace,ReplicatedStorage,playerGui,player}) do
 local scope=root
 connect(scope.DescendantAdded,function(obj)
  if not state.running or scope==player and obj:IsDescendantOf(playerGui) then return end
  enqueue(obj);Core.log(state,'ADDED',obj)
 end)
end
local lastMovement,lastPose,lastUI=0,nil,0
connect(RunService.Heartbeat,function()
 if not alive then return end
 stepCopy();stepExport()
 if browserStep then browserStep() end
 local budget=os.clock()+.004;local processed=0
 while (state.running or state.manualScan) and queueHead<=#pending and processed<100 and os.clock()<budget do
  local obj=pending[queueHead];queueHead+=1;queued[obj]=nil;processed+=1
  local ok,err=pcall(function()
   if Core.capture(state,obj) then
    watch(obj)
    for _,child in ipairs(obj:GetChildren()) do enqueue(child) end
   end
  end)
  if not ok then addError('scan',err) end
 end
 if queueHead>#pending then pending={};queueHead=1;state.manualScan=false end
 local now=os.clock()
 if state.running and now-lastMovement>=1 then
  lastMovement=now;local current=pose()
  if current then
   local p=current.position;local prior=lastPose and lastPose.position
   local cameraChanged=false
   if lastPose and current.cameraCFrame and lastPose.cameraCFrame then
    for i,value in ipairs(current.cameraCFrame) do if math.abs(value-lastPose.cameraCFrame[i])>.05 then cameraChanged=true;break end end
   end
   if not prior or cameraChanged or (Vector3.new(p.x,p.y,p.z)-Vector3.new(prior.x,prior.y,prior.z)).Magnitude>=2 or current.state~=lastPose.state then Core.log(state,'MOVEMENT_SAMPLE',nil);lastPose=current end
  end
 end
 if now-lastUI>.4 then
  lastUI=now
  launcher.Text=(state.running and 'SCANNER | REC ' or 'SCANNER | PAUSED ')..state.eventCount
  if state.pendingPasteText and not minimized then preview.Text=state.pendingPasteText;preview.Visible=true;state.pendingPasteText=nil end
  statusLabel.Text=(state.running and 'RECORDING' or 'PAUSED')..' | '..(state.nextId-1)..' objects | '..state.eventCount..' events | queued '..math.max(0,#pending-queueHead+1)..'\nCoreGui: '..state.coreGuiStatus..' | Console '..state.consoleOccurrences..' messages / '..state.consoleGrouped..' repeats grouped\n'..status
  local current=pose();local p=current and current.position
  positionLabel.Text=p and ('XYZ: %.2f, %.2f, %.2f'):format(p.x,p.y,p.z) or 'Character position unavailable'
 end
end)
Core.log(state,'SCANNER_STARTED',nil,{version='1.0.5'},true)
scan()

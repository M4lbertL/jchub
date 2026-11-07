-- Steal an Egg - client-visible Scanner & Action Watcher v1.0.3
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
function Core.privatePath(path)
 local p=tostring(path or ''):lower()
 for segment in p:gmatch('[^.]+') do if segment=='chat' or segment=='chats' or segment=='keysystem' then return true end end
 return p:find('experiencechat',1,true)~=nil or p:find('textchatservice',1,true)~=nil
  or p:find('bubblechat',1,true)~=nil or p:find('chatwindow',1,true)~=nil
  or p:find('chatlog',1,true)~=nil or p:find('jcsaescanner',1,true)~=nil
  or p:find('jchub',1,true)~=nil or p:find('kpopassistant',1,true)~=nil
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
function Core.new(clock,pose)
 return {clock=clock,pose=pose,started=clock(),running=true,ids=setmetatable({},{__mode='k'}),records={},nextId=1,
  events={},head=1,eventCount=0,totalEvents=0,droppedEvents=0,nodeLimitHits=0,connectionLimitHits=0,queueLimitHits=0,
  scanCount=0,errors={},labels={},captureProperties=function()return {}end}
end
function Core.capture(state,obj)
 if not obj then return nil end
 local ok,path=pcall(function()return obj:GetFullName()end)
 if not ok or Core.privatePath(path) then return nil end
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
 state.records[id]=record;return id
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
 return {schema=1,version='1.0.3',context=context,recording=state.running,
  objectCount=#objects,eventCount=state.eventCount,totalEvents=state.totalEvents,
  droppedEvents=state.droppedEvents,nodeLimitHits=state.nodeLimitHits,connectionLimitHits=state.connectionLimitHits,
  queueLimitHits=state.queueLimitHits,limits=Core.LIMITS,objects=objects,actions=Core.orderedEvents(state),
  markers=labels,errors=errors,scans=state.scanCount,
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
  return '=== STEAL AN EGG FULL SESSION SCAN v1.0.3 BEGIN ===\n'..metadata:sub(1,-2)
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
 if not paste.closed then paste.closed=true;return '}\n=== STEAL AN EGG FULL SESSION SCAN END ===' end
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
 local ok,c=pcall(function()return signal:Connect(fn)end)
 if not ok then return end
 connections[#connections+1]=c
 if owner then objectConnections[owner]=objectConnections[owner] or {};table.insert(objectConnections[owner],c) end
 return c
end
local function enqueue(obj)
 if not obj or queued[obj] then return end
 local ok,path=pcall(function()return obj:GetFullName()end)
 if not ok or Core.privatePath(path) then return end
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
local function scan()
 state.scanCount+=1;state.manualScan=true
 enqueue(playerGui);enqueue(player:FindFirstChildOfClass('Backpack'));enqueue(player.Character)
 enqueue(Workspace);enqueue(ReplicatedStorage)
 local leader=player:FindFirstChild('leaderstats');if leader then enqueue(leader) end
 Core.log(state,'SCAN_REQUESTED',nil,{number=state.scanCount},true)
 status='Scan queued. Loaded UI, world, character and replicated data.'
end
local function report()
 local position=pose()
 local lines={'Steal an Egg - Full Client Scanner v1.0.3',
  'PlaceId: '..game.PlaceId..' | GameId: '..game.GameId..' | Server JobId: '..game.JobId,
  'Recording: '..tostring(state.running)..' | Objects: '..(state.nextId-1)..' | Events retained: '..state.eventCount..' / '..state.totalEvents,
  'No count caps: dropped events='..state.droppedEvents..' | node refusals='..state.nodeLimitHits..' | listener refusals='..state.connectionLimitHits..' | queue refusals='..state.queueLimitHits,
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
  text=('=== STEAL AN EGG PASTE PART %d %s BEGIN ===\n'):format(snapshot.part,final and 'FINAL' or 'MORE')..text..
   ('\n=== STEAL AN EGG PASTE PART %d END ==='):format(snapshot.part)
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
local function export()
 local stamp=tostring(os.time())..'_'..tostring(math.floor(os.clock()*1000))
 state.exportSerial=(state.exportSerial or 0)+1
 local prefix='StealAnEgg_Scan_'..tostring(game.PlaceId)..'_'..stamp..'_'..state.exportSerial
 if type(writefile)~='function' then
  local copied=copyText(report())
  status=copied and 'No file API: summary copied only. Full JSON has NOT been saved.' or 'No file or clipboard support. Use Copy Report text window.'
  return false
 end
 local files={};local ok,err=pcall(function()
  writefile(prefix..'_Report.txt',report());files[#files+1]=prefix..'_Report.txt'
  for first=1,#state.records,1000 do
   local records={};for i=first,math.min(first+999,#state.records) do records[#records+1]=state.records[i] end
   local name=prefix..'_Objects_'..math.floor((first-1)/1000+1)..'.json'
   writefile(name,Http:JSONEncode({schema=1,records=records}));files[#files+1]=name
  end
  local events=Core.orderedEvents(state)
  for first=1,#events,500 do
   local part={};for i=first,math.min(first+499,#events) do part[#part+1]=events[i] end
   local name=prefix..'_Actions_'..math.floor((first-1)/500+1)..'.json'
   writefile(name,Http:JSONEncode({schema=1,events=part}));files[#files+1]=name
  end
  local manifest={schema=1,version='1.0.3',place=game.PlaceId,game=game.GameId,job=game.JobId,
   files=files,objectCount=state.nextId-1,eventCount=state.eventCount,totalEvents=state.totalEvents,
   droppedEvents=state.droppedEvents,nodeLimitHits=state.nodeLimitHits,connectionLimitHits=state.connectionLimitHits,
   queueLimitHits=state.queueLimitHits,position=pose(),errors=state.errors,scans=state.scanCount,markers=state.labels,
   limits=Core.LIMITS,disclosure='Loaded client data only; no server-only state/source/outgoing interception. Private fields omitted.'}
  writefile(prefix..'_Manifest.json',Http:JSONEncode(manifest))
 end)
 if not ok then status='Export incomplete: '..Core.cleanString(err);return false end
 status='Saved '..prefix..'_Manifest.json plus '..#files..' report/data files.'
 copyText(status);return true
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
window=new('Frame',gui,{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.new(.7,0,0,318),BackgroundColor3=Color3.fromRGB(0,0,0),BorderSizePixel=0})
new('UISizeConstraint',window,{MinSize=Vector2.new(300,318),MaxSize=Vector2.new(580,318)})
new('UICorner',window,{CornerRadius=UDim.new(0,10)})
new('UIStroke',window,{Color=Color3.fromRGB(210,32,52),Thickness=1.4,Transparency=.1})
local header=new('Frame',window,{Active=true,BackgroundTransparency=1,Size=UDim2.new(1,-56,0,49)})
local badge=new('TextLabel',header,{Position=UDim2.fromOffset(10,6),Size=UDim2.fromOffset(42,36),BackgroundColor3=Color3.fromRGB(32,5,12),
 Text='JC',TextSize=19,Font=Enum.Font.GothamBold,TextColor3=Color3.fromRGB(245,43,62),BorderSizePixel=0})
new('UICorner',badge,{CornerRadius=UDim.new(0,8)})
new('UIStroke',badge,{Color=Color3.fromRGB(120,20,35),Thickness=1})
new('TextLabel',header,{Position=UDim2.fromOffset(63,5),Size=UDim2.new(1,-66,0,23),BackgroundTransparency=1,
 Text='JcHub | SCANNER',Font=Enum.Font.GothamBold,TextSize=15,TextColor3=Color3.new(1,1,1),TextXAlignment=Enum.TextXAlignment.Left})
new('TextLabel',header,{Position=UDim2.fromOffset(63,28),Size=UDim2.new(1,-66,0,15),BackgroundTransparency=1,
 Text='UNIVERSAL / v1.0.3',Font=Enum.Font.Gotham,TextSize=10,TextColor3=Color3.fromRGB(170,170,180),TextXAlignment=Enum.TextXAlignment.Left})
new('Frame',window,{Position=UDim2.fromOffset(0,48),Size=UDim2.new(1,0,0,1),BackgroundColor3=Color3.fromRGB(115,18,31),BorderSizePixel=0})
statusLabel=new('TextLabel',window,{BackgroundTransparency=1,Position=UDim2.fromOffset(12,52),Size=UDim2.new(1,-24,0,34),TextWrapped=true,
 Text='',Font=Enum.Font.Gotham,TextSize=12,TextColor3=Color3.fromRGB(245,115,130),TextXAlignment=Enum.TextXAlignment.Left})
positionLabel=new('TextLabel',window,{BackgroundTransparency=1,Position=UDim2.fromOffset(12,88),Size=UDim2.new(1,-24,0,26),
 Text='',Font=Enum.Font.Code,TextSize=12,TextColor3=Color3.fromRGB(240,205,130),TextXAlignment=Enum.TextXAlignment.Left})
local buttons=new('ScrollingFrame',window,{BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=4,ScrollBarImageColor3=Color3.fromRGB(240,43,62),CanvasSize=UDim2.fromOffset(0,192),Position=UDim2.fromOffset(10,118),Size=UDim2.new(1,-20,0,144)})
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
 state.events={};state.head=1;state.eventCount=0;state.totalEvents=0;state.droppedEvents=0;state.pasteSnapshot=nil;state.pendingPasteText=nil;state.copyJob=nil
 Core.log(state,'LOG_CLEARED',nil,{},true);status='Action log cleared. Object snapshots retained.'
end)
button('SHOW/HIDE LOG',function()preview.Text=shortReport();preview.Visible=not preview.Visible end)
button('STOP + COPY ALL',function()
 if state.running then state.running=false;state.manualScan=false;pause.Text='RESUME';Core.log(state,'RECORDING_PAUSED',nil,{},true) end
 state.copyJob=nil
 copyAll()
end)
button('UNLOAD',unload)
logLabel=new('TextLabel',window,{BackgroundTransparency=1,Position=UDim2.fromOffset(12,268),Size=UDim2.new(1,-24,0,40),TextWrapped=true,
 Text='Client-visible data only. No chat/TextBox values or outgoing-remote hooks. Copy All or Export before unloading. RShift hides/reopens; recording continues. Scroll for more buttons.',Font=Enum.Font.Gotham,TextSize=11,TextColor3=Color3.fromRGB(170,170,180),TextXAlignment=Enum.TextXAlignment.Left})
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
 stepCopy()
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
  statusLabel.Text=(state.running and 'RECORDING' or 'PAUSED')..' | '..(state.nextId-1)..' objects | '..state.eventCount..' events | queued '..math.max(0,#pending-queueHead+1)..'\n'..status
  local current=pose();local p=current and current.position
  positionLabel.Text=p and ('XYZ: %.2f, %.2f, %.2f'):format(p.x,p.y,p.z) or 'Character position unavailable'
 end
end)
Core.log(state,'SCANNER_STARTED',nil,{version='1.0.3'},true)
scan()

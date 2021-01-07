local Editor = {}

function Editor:Init()
  self.Position = {0, 0}
  self.Zoom = 1
  self.DraggingWorld = false
  self.DraggingGate = nil

  self.DrawingConnection = false
  self.DrawingFromInput = false
  self.DrawingFromOutput = false
  self.DrawingConnectionFrom = nil

  self.LastMousePos = {0, 0}
  self.MouseDown = false

  self.GateSize = 5
  self.IOSize = 2

  self.BackgroundColor = Color(32, 32, 32, 255)
  self.NodeColor = Color(100, 100, 100, 255)
  self.ConnectionColor = Color(200, 200, 200, 255)

  self.NormalColor = Color(190, 190, 255, 255) --Very light blue nearing white
  self.Vector2Color = Color(150, 255, 255, 255) --Light blue
  self.VectorColor = Color(70, 160, 255, 255) --Blue
  self.Vector4Color = Color(0, 50, 255, 255) --Dark blue
  self.AngleColor = Color(100, 200, 100, 255) --Light green
  self.StringColor = Color(250, 160, 90, 255) --Orange
  
  self.ArrayColor = Color(20, 110, 20, 255) --Dark green
  self.EntityColor = Color(255, 100, 100, 255) --Dark red
  self.RangerColor = Color(130, 100, 60, 255) --Brown
  self.WirelinkColor = Color(200, 80, 200, 255) --Deep purple

  self.UsedInputNames = {}
  self.UsedOutputNames = {}

  self.C = {}
  self:InitComponents()

  self.Nodes = {}

  --MsgC(Color(0, 150, 255), table.ToString(GateActions, "Gate Actions", true))
end

-- ceil	=	{
--   label	=	function: 0x01eca99bda28,
--   group	=	"Arithmetic",
--   is_banned	=	false,
--   name	=	"Ceiling (Round up)",
--   output	=	function: 0x01eca99bd9f8,
--   inputs	=	{
--       "A",
--       },
--     },

-- COMPONENTS

function Editor:InitComponents()
  self.C = {}

	self.C.TopBar = vgui.Create("DPanel", self)
  self.C.TopBar:Dock(TOP)
  self.C.TopBar:SetHeight(24)
  self.C.TopBar:DockPadding(5,5,5,5)
  self.C.TopBar:SetBackgroundColor(Color(170, 174, 179, 255))

  self.C.Name = vgui.Create("DTextEntry", self.C.TopBar)
  self.C.Name:SetEditable(true)
  self.C.Name:SetSize(140, 20)
  self.C.Name:Dock(LEFT)
  -- this doesnt work
  self.C.Name.OnLoseFocus = function (self)
    if self:GetValue() == "" then
    	self:SetValue("empty")
	  end
  end

  --Gate spawning
  self.C.Holder = vgui.Create("DPanel", self)
  self.C.Holder:SetWidth(300)
  self.C.Holder:Dock(RIGHT)
  self.C.Holder:SetBackgroundColor(Color(170, 174, 179, 255))

  self.C.Tree = vgui.Create("DTree", self.C.Holder)
  self.C.Tree:Dock(FILL)
  --self.C.Tree:DockMargin(5,0,5,5)


  --utility
  local function FillSubTree(tree, node, temp, type)
    node.Icon:SetImage("icon16/folder.png")

    local subtree = {}
    for k, v in pairs(temp) do
      subtree[#subtree+1] = {action = k, gate = v, name = v.name}
    end

    table.SortByMember(subtree, "name", true)

    for index=1, #subtree do
      local action, gate = subtree[index].action, subtree[index].gate
      local node2 = node:AddNode(gate.name or "No name found :(")
      node2.name = gate.name
      node2.action = action
      editor = self
      function node2:DoClick()
        editor:CreateNode(type, self.action)
      end
      node2.Icon:SetImage("icon16/newspaper.png")
    end
    tree:InvalidateLayout()
  end

  --FPGA gates
  local CategoriesSorted = {}

  for gatetype, gatefuncs in pairs(FPGAGatesSorted) do
    local allowed_gates = {}
    local any_allowed = false
    for k,v in pairs(gatefuncs) do
      if not v.is_banned then
        allowed_gates[k] = v
        any_allowed = true
      end
    end
    if any_allowed then
      CategoriesSorted[#CategoriesSorted+1] = {gatetype = gatetype, gatefuncs = allowed_gates}
    end
  end

  table.sort(CategoriesSorted, function(a, b) return a.gatetype < b.gatetype end)

  local fpgaNode = self.C.Tree:AddNode("FPGA", "icon16/bricks.png")
  function fpgaNode:DoClick()
    self:SetExpanded(not self.m_bExpanded)
  end

  for i=1,#CategoriesSorted do
    local gatetype = CategoriesSorted[i].gatetype
    local gatefuncs = CategoriesSorted[i].gatefuncs

    local node = fpgaNode:AddNode(gatetype)
    node.Icon:SetImage("icon16/folder.png")
    FillSubTree(self.C.Tree, node, gatefuncs, "fpga")
    function node:DoClick()
      self:SetExpanded(not self.m_bExpanded)
    end
  end

  --WIREMOD gates
  local CategoriesSorted = {}

  for gatetype, gatefuncs in pairs(WireGatesSorted) do
    local allowed_gates = {}
    local any_allowed = false
    for k,v in pairs(gatefuncs) do
      if not v.is_banned then
        allowed_gates[k] = v
        any_allowed = true
      end
    end
    if any_allowed then
      CategoriesSorted[#CategoriesSorted+1] = {gatetype = gatetype, gatefuncs = allowed_gates}
    end
  end

  table.sort(CategoriesSorted, function(a, b) return a.gatetype < b.gatetype end)

  local wiremodNode = self.C.Tree:AddNode("Wire", "icon16/connect.png")
  function wiremodNode:DoClick()
    self:SetExpanded(not self.m_bExpanded)
  end

  for i=1,#CategoriesSorted do
    local gatetype = CategoriesSorted[i].gatetype
    local gatefuncs = CategoriesSorted[i].gatefuncs

    local node = wiremodNode:AddNode(gatetype)
    node.Icon:SetImage("icon16/folder.png")
    FillSubTree(self.C.Tree, node, gatefuncs, "wire")
    function node:DoClick()
      self:SetExpanded(not self.m_bExpanded)
    end
  end
end


-- INTERACTION
function Editor:GetData() 
  return WireLib.von.serialize({
      Name = self.C.Name:GetValue(),
      Nodes = self.Nodes,
      Position = self.Position,
      Zoom = self.Zoom,
      UsedInputNames = self.UsedInputNames,
      UsedOutputNames = self.UsedOutputNames,
    }, false)
end

function Editor:SetData(data) 
  local data = WireLib.von.deserialize(data)
  -- error check

  self.C.Name:SetValue(data.Name)
  self.Nodes = data.Nodes
  self.Position = data.Position
  self.Zoom = data.Zoom
  self.UsedInputNames = data.UsedInputNames
  self.UsedOutputNames = data.UsedOutputNames
end

function Editor:ClearData()
  self.C.Name:SetValue("empty")
  -- self.Nodes = {{type = "wire", gate = "floor", x = 0, y = 50, connections = {[1] = {5, 1}}},
  --   {type = "wire", gate = "ceil", x = 0, y = 150, connections = {[1] = {5, 1}}},
  --   {type = "wire", gate = "+", x = 50, y = 100, connections = {[1] = {1, 1}, [2] = {2, 1}}},
  --   {type = "wire", gate = "exp", x = 150, y = 100, connections = {[1] = {3, 1}}},
  --   {type = "io", gate = "in-number", ioName = "A", x = -100, y = 100, connections = {}},
  --   {type = "io", gate = "out-number", ioName = "Out", x = 200, y = 100, connections = {[1] = {4, 1}}}
  -- }

  -- self.Nodes = {{type = "wire", gate = "+", x = 50, y = 100, connections = {[1] = {2, 1}, [2] = {2, 1}}},
  --   {type = "io", gate = "in-number", ioName = "A", x = -100, y = 100, connections = {}},
  --   {type = "io", gate = "out-number", ioName = "Out", x = 200, y = 100, connections = {[1] = {1, 1}}}
  -- }

  -- self.Nodes = {{type = "wire", gate = "+", x = 0, y = 100, connections = {[1] = {2, 1}, [2] = {2, 1}}},
  --   {type = "fpga", gate = "normal-input", ioName = "A", x = -50, y = 90, connections = {}},
  --   {type = "fpga", gate = "normal-input", ioName = "B", x = -50, y = 110, connections = {}},
  --   {type = "fpga", gate = "normal-output", ioName = "Out", x = 50, y = 100, connections = {[1] = {1, 1}}}
  -- }
  self.Nodes = {}
  self.Position = {0, 0}
  self.Zoom = 1
  self.UsedInputNames = {}
  self.UsedOutputNames = {}

end

function Editor:GetName()
  return self.C.Name:GetValue()
end

-- GATES
function Editor:GetGate(node)
  if node.type == "wire" then 
    return GateActions[node.gate]
  elseif node.type == "fpga" then
    return FPGAGateActions[node.gate]
  end
end

function Editor:GetInputType(gate, inputNum)
  if gate.inputtypes then
    return gate.inputtypes[inputNum] or "NORMAL"
  else
    return "NORMAL"
  end
end

function Editor:GetOutputType(gate, outputNum)
  if gate.outputtypes then
    return gate.outputtypes[outputNum] or "NORMAL"
  else
    return "NORMAL"
  end
end

-- UTILITY
function Editor:PosToScr(x, y)
  return (self:GetWide()-300)/2 - (self.Position[1] - x) * self.Zoom, self:GetTall()/2 - (self.Position[2] - y) * self.Zoom
end

function Editor:ScrToPos(x, y)
  return self.Position[1] - ((self:GetWide()-300)/2 - x) / self.Zoom, self.Position[2] - (self:GetTall()/2 - y) / self.Zoom
end

function Editor:NodeInputPos(node, input)
  return node.x - self.GateSize/2 - self.IOSize/2, node.y + (input - 1) * self.GateSize
end

function Editor:NodeOutputPos(node, output)
  return node.x + self.GateSize/2 + self.IOSize/2, node.y + (output - 1) * self.GateSize
end

-- DETECTION
function Editor:GetNodeAt(x, y)
  local gx, gy = self:ScrToPos(x, y)

  for k, node in pairs(self.Nodes) do
    if gx < node.x - self.GateSize/2 then continue end
    if gx > node.x + self.GateSize/2 then continue end
    if gy < node.y - self.GateSize/2 then continue end
    if gy > node.y + self.GateSize/2 then continue end

    return k
  end

  return nil
end

function Editor:GetNodeInputAt(x, y)
  local gx, gy = self:ScrToPos(x, y)

  for k, node in pairs(self.Nodes) do
    local gate = self:GetGate(node)

    if gx < node.x - self.GateSize/2 - self.IOSize then continue end
    if gx > node.x + self.GateSize/2 + self.IOSize then continue end
    if gy < node.y - self.GateSize/2 then continue end
    if gy > node.y - self.GateSize/2 + self.GateSize * table.Count(gate.inputs) then continue end

    for inputNum, _ in pairs(gate.inputs) do
      local ix, iy = self:NodeInputPos(node, inputNum)

      if gx < ix - self.IOSize/2 then continue end
      if gx > ix + self.IOSize/2 then continue end
      if gy < iy - self.IOSize/2 then continue end
      if gy > iy + self.IOSize/2 then continue end

      return k, inputNum
    end
  end

  return nil
end

function Editor:GetNodeOutputAt(x, y)
  local gx, gy = self:ScrToPos(x, y)

  for k, node in pairs(self.Nodes) do
    local gate = self:GetGate(node)

    if gx < node.x - self.GateSize/2 - self.IOSize then continue end
    if gx > node.x + self.GateSize/2 + self.IOSize then continue end
    if gy < node.y - self.GateSize/2 then continue end
    if gy > node.y + self.GateSize/2 then continue end

    local ix, iy = self:NodeOutputPos(node, 1)

    if gx < ix - self.IOSize/2 then continue end
    if gx > ix + self.IOSize/2 then continue end
    if gy < iy - self.IOSize/2 then continue end
    if gy > iy + self.IOSize/2 then continue end

    return k, 1
  end

  return nil
end

-- DRAWING
function Editor:PaintConnection(nodeFrom, output, nodeTo, input)
  local x1, y1 = self:NodeOutputPos(nodeFrom, output)
  local x2, y2 = self:NodeInputPos(nodeTo, input)

  local sx1, sy1 = self:PosToScr(x1, y1)
  local sx2, sy2 = self:PosToScr(x2, y2)

  surface.SetDrawColor(self.ConnectionColor)
  surface.DrawLine(sx1, sy1, sx2, sy2)
end

function Editor:PaintConnections()
  for k1, node in pairs(self.Nodes) do
    for inputNum, connectedTo in pairs(node.connections) do
      self:PaintConnection(self.Nodes[connectedTo[1]], connectedTo[2], node, inputNum)
    end
  end
end

function Editor:GetTypeColor(type)
  if type == "NORMAL" then
    return self.NormalColor
  elseif type == "VECTOR2" then
    return self.Vector2Color
  elseif type == "VECTOR" then
    return self.VectorColor
  elseif type == "VECTOR4" then
    return self.Vector4Color
  elseif type == "ANGLE" then
    return self.AngleColor
  elseif type == "STRING" then
    return self.StringColor
  elseif type == "ARRAY" then
    return self.ArrayColor
  elseif type == "ENTITY" then
    return self.EntityColor
  elseif type == "RANGER" then
    return self.RangerColor
  elseif type == "WIRELINK" then
    return self.WirelinkColor
  else
    return Color(0,0,0,255)
  end
end

function Editor:PaintNode(node)
  local gate = self:GetGate(node)

  local amountOfInputs = 0
  if gate.inputs then
    amountOfInputs = table.Count(gate.inputs)
  end
  local amountOfOutputs = 1
  if gate.outputs then
    amountOfOutputs = table.Count(gate.outputs)
  end
  -- if gate.outputtypes then
  --   amountOfOutputs = math.max(amountOfOutputs, table.Count(gate.outputtypes))
  -- end

  local x, y = self:PosToScr(node.x, node.y)

  local size = self.Zoom * self.GateSize
  local ioSize = self.Zoom * self.IOSize
  
  -- Inputs
  if gate.inputs then
    for k, _ in pairs(gate.inputs) do
      local type = self:GetInputType(gate, k)
      surface.SetDrawColor(self:GetTypeColor(type))
      -- This should rely on a function
      surface.DrawRect(x - size/2 - ioSize, y - ioSize/2 + (k-1) * size, ioSize*2, ioSize)
    end
  end

  -- Output
  if gate.outputs then
    for k, _ in pairs(gate.outputs) do
      local type = self:GetOutputType(gate, k)
      surface.SetDrawColor(self:GetTypeColor(type))

      surface.DrawRect(x + size/2 - ioSize, y - ioSize/2 + (k-1) * size, ioSize*2, ioSize)
    end
  else 
    local type = self:GetOutputType(gate, 1)
    surface.SetDrawColor(self:GetTypeColor(type))

    surface.DrawRect(x + size/2 - ioSize, y - ioSize/2, ioSize*2, ioSize)
  end

  -- Body
  local height = math.max(amountOfInputs, amountOfOutputs, 1)

  surface.SetDrawColor(self.NodeColor)
  surface.DrawRect(x-size/2, y-size/2, size, size * height)

  -- Name
  surface.SetFont("Default")
  surface.SetTextColor(255, 255, 255)
  local tx, ty = surface.GetTextSize(gate.name)
	surface.SetTextPos(x-tx/2, y-ty/2-size/1.2) 
  surface.DrawText(gate.name)
end

function Editor:PaintNodes()
  for k, node in pairs(self.Nodes) do
    self:PaintNode(node)
  end
end

function Editor:Paint()
  surface.SetDrawColor(self.BackgroundColor)
  surface.DrawRect(0, 0, self:GetWide()-290, self:GetTall())

  self:PaintNodes()
  self:PaintConnections()

  self:PaintDebug()

  -- moving the plane
  if self.DraggingWorld then
    local x, y = self:CursorPos()
    local dx, dy = self.LastMousePos[1] - x, self.LastMousePos[2] - y
    self.Position = {self.Position[1] + dx * (1/self.Zoom), self.Position[2] + dy * (1/self.Zoom)}
  end
  -- moving a node
  if self.DraggingNode then
    local x, y = self:CursorPos()
    local gx, gy = self:ScrToPos(x, y)
    self.Nodes[self.DraggingNode].x = gx
    self.Nodes[self.DraggingNode].y = gy
  end
  -- drawing a connection
  if self.DrawingConnection then
    local x, y = 0, 0
    if self.DrawingFromInput then
      x, y = self:NodeInputPos(self.Nodes[self.DrawingConnectionFrom[1]], self.DrawingConnectionFrom[2])
    elseif self.DrawingFromOutput then
      x, y = self:NodeOutputPos(self.Nodes[self.DrawingConnectionFrom[1]], self.DrawingConnectionFrom[2])
    end
    local sx, sy = self:PosToScr(x, y)
    local mx, my = self:CursorPos()
    surface.SetDrawColor(self.ConnectionColor)
    surface.DrawLine(sx, sy, mx, my)
  end

  local x, y = self:CursorPos()
  self.LastMousePos = {x, y}
end


function Editor:PaintDebug()
  surface.SetFont("Default")
	surface.SetTextColor(255, 255, 255)
	surface.SetTextPos(10, 50) 
  surface.DrawText(self.Position[1] .. ", " .. self.Position[2])
  surface.SetTextPos(10, 70) 
	surface.DrawText(self.Zoom)
end

--ACTIONS
function Editor:BeginDrawingConnection(x, y)
  local nodeId, inputNum = self:GetNodeInputAt(x, y)
  if nodeId then
    --check if something is connected to this input
    node = self.Nodes[nodeId]
    Input = node.connections[inputNum]

    --Input already connected
    if Input then
      local connectedNode, connectedOutput = Input[1], Input[2]
      node.connections[inputNum] = nil
      self.DrawingConnectionFrom = {connectedNode, connectedOutput}
      self.DrawingFromOutput = true
    else 
      --input not connected
      self.DrawingConnectionFrom = {nodeId, inputNum}
      self.DrawingFromInput = true
    end
    
    self.DrawingConnection = true
  end

  local nodeId, outputNum = self:GetNodeOutputAt(x, y)
  if nodeId then
    self.DrawingConnection = true
    self.DrawingFromOutput = true
    self.DrawingConnectionFrom = {nodeId, outputNum}
  end
end

function Editor:GetInputName()
  local i = 1
  while self.UsedInputNames[i] do
    i = i + 1
  end
  self.UsedInputNames[i] = true

  return "I" .. i
end

function Editor:GetOutputName()
  local i = 1
  while self.UsedOutputNames[i] do
    i = i + 1
  end
  self.UsedOutputNames[i] = true

  return "O" .. i
end

function Editor:FreeName(name)
  local type = string.sub(name, 1, 1)
  local index = string.sub(name, 2, -1)
  --print("freeing " .. type .. tonumber(index))
  if type == "I" then
    self.UsedInputNames[tonumber(index)] = false
  elseif type == "O" then
    self.UsedOutputNames[tonumber(index)] = false
  end
end

function Editor:CreateNode(type, gate)
  node = {
    type = type,
    gate = gate,
    x = self.Position[1],
    y = self.Position[2],
    connections = {}
  }

  local gateInfo = self:GetGate(node)

  if gateInfo.isInput then
    node.ioName = self:GetInputName()
  elseif gateInfo.isOutput then
    node.ioName = self:GetOutputName()
  end

  print("Created " .. table.ToString(node, "node", false))

  table.insert(self.Nodes, node)
end

function Editor:DeleteNode(nodeId)
  print("Deleted " .. nodeId)
  
  --remove all connections to this node
  for k1, node in pairs(self.Nodes) do
    for inputNum, connection in pairs(node.connections) do
      if connection[1] == nodeId then
        node.connections[inputNum] = nil
      end
    end
  end

  --clear name, if it used one
  if self.Nodes[nodeId].ioName then
    self:FreeName(self.Nodes[nodeId].ioName)
  end

  --finally remove node
  self.Nodes[nodeId] = nil
end

--EVENTS
function Editor:OnMousePressed(code)
	if code == MOUSE_LEFT then
    self.MouseDown = true

    local x, y = self:CursorPos()

    --NODE DRAGGING
    local node = self:GetNodeAt(x, y)
    if node then
      self.DraggingNode = node
    end

    --CONNECTION DRAWING
    self:BeginDrawingConnection(x, y)
  elseif code == MOUSE_RIGHT then
    -- PLANE DRAGGING
		self.DraggingWorld = true
	end
end

function Editor:OnMouseReleased(code)
  --if not self.MouseDown  then return end
  local x, y = self:CursorPos()

	if code == MOUSE_LEFT then
    self.MouseDown = false
    self.DraggingNode = nil

    if self.DrawingConnection then
      self:OnDrawConnectionFinished(x, y)
    end
  elseif code == MOUSE_RIGHT then
    self.DraggingWorld = false
  end
  
end

function Editor:OnDrawConnectionFinished(x, y)
  if self.DrawingFromOutput then
    local nodeId, inputNum = self:GetNodeInputAt(x, y)

    if nodeId then
      local inputNode = self.Nodes[nodeId]
      local outputNode = self.Nodes[self.DrawingConnectionFrom[1]]
      --check type
      local inputType = self:GetInputType(self:GetGate(inputNode), inputNum)
      local outputType = self:GetOutputType(self:GetGate(outputNode), self.DrawingConnectionFrom[2])

      print(inputType .. " " .. outputType)

      if inputType == outputType then
        --connect up
        inputNode.connections[inputNum] = {self.DrawingConnectionFrom[1], self.DrawingConnectionFrom[2]}
      end
    end

  elseif self.DrawingFromInput then
    local nodeId, outputNum = self:GetNodeOutputAt(x, y)

    if nodeId then
      local inputNode = self.Nodes[self.DrawingConnectionFrom[1]]
      local outputNode = self.Nodes[nodeId]
      --check type
      local inputType = self:GetInputType(self:GetGate(inputNode), self.DrawingConnectionFrom[2])
      local outputType = self:GetOutputType(self:GetGate(outputNode), outputNum)

      if inputType == outputType then
        --connect up
        inputNode.connections[self.DrawingConnectionFrom[2]] =  {nodeId, outputNum}
      end
    end
  end

  self.DrawingConnection = false
  self.DrawingFromInput = false
  self.DrawingFromOutput = false
end

function Editor:OnMouseWheeled(delta)
  self.Zoom = self.Zoom + delta * 0.1
	if self.Zoom < 0.1 then self.Zoom = 0.1 end
	if self.Zoom > 10 then self.Zoom = 10 end
end

function Editor:OnKeyCodePressed(code)
  local x, y = self:CursorPos()

  if code == KEY_X then
    --Delete
    local node = self:GetNodeAt(x, y)
    if node then
      self:DeleteNode(node)
    end
  end
end



vgui.Register("FPGAEditor", Editor, "Panel");
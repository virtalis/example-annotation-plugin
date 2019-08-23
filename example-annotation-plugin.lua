-- define the plugin functions as local functions
local function name()
  return "Annotation Exporter"
end

local function version()
  return "1.0.0"
end

local function init()
end

local function cleanup()
end

-- specify that this plugin exports XML files
local function exportFormats()
  return [[
    <filetypes>
      <type ext="xml" desc="XML File" />
    </filetypes>
  ]]
end

local exportFile
local exportFolder
local id

-- function called during annotation tree traversal, writing out XML data depending on the type of node encountered
local function visitAnnotationNode(node)
  local t = node:type(false)
   
  if t == "Annotation" then
    io.write("<annotation name=\"" .. node:getName() .. "\" author=\"" .. node.CreatedBy .. "\">\n")
    node:forEachChild(visitAnnotationNode)
    io.write("</annotation>\n")
    return
  end
   
  if t == "AnnotationComment" then
    io.write("<comment author=\"" .. node.CreatedBy .. "\">\n") 
    io.write(node.Comment)
    io.write("\n")
    io.write("</comment>\n")
    return
  end
  
  -- for viewpoints in annotations we also export the screenshot that was taken when the viewpoint was created
  if t == "Viewpoint" then
    local pos, rot, scale = vrNodeDecomposeTransform(node)
    io.write("<viewpoint position=\"" .. tostring(pos) .. "\" rotation = \"" .. tostring(rot) .. "\">\n")
    local tex = node:sibling("Texture")
    if tex then
      local filename = exportFolder .. "\\viewpoint-" .. id .. ".png"
      id = id + 1
      io.write("<texture filename=\"" .. filename .. "\" />\n")
      vrExtractBinaryAssets(tex, filename, true, vrNodeGetMetaNode(tex, true))   
    end
    io.write("</viewpoint>\n")
  end
   
  node:forEachChild(visitAnnotationNode)
end

local function exportAsXml(file, s)
  local fd = io.open(exportFile, "w")
  if not fd then
    vrMessageBox("Failed to open " .. exportFile, name(), "ok,error")
    return 1
  end
   
  io.output(fd)
  io.write("<annotations exported=\"" .. os.date() .. "\">\n")
  visitAnnotationNode(s)
  io.write("</annotations>\n")
  io.close(fd)
  return 0
end

-- finds the Annotations node in the Scenes tree and exports them to XML
local function export(file, root, scenes, libs, recipePath)
  local s = scenes:child("AnnotationList", "Annotations")
  if not s then
    vrMessageBox("No annotations found", name(), "ok,error")
    return 1
  else
    exportFile = file
    exportFolder = file:match("(.+)%..+$")
    id = 1
    return exportAsXml(file, s);
  end
end

-- export the functions to the Lua state
return {
  name = name,
  version = version,
  init = init,
  cleanup = cleanup,
  exportFormats = exportFormats,
  export = export
}
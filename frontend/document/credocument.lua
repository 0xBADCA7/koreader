local Geom = require("ui/geometry")
local CreOptions = require("ui/data/creoptions")
local Document = require("document/document")
local Configurable = require("ui/reader/configurable")
local Font = require("ui/font")
local Device = require("ui/device")
local Screen = require("ui/screen")
local DEBUG = require("dbg")
-- TBD: DrawContext

local CreDocument = Document:new{
	-- this is defined in kpvcrlib/crengine/crengine/include/lvdocview.h
	SCROLL_VIEW_MODE = 0,
	PAGE_VIEW_MODE = 1,

	_document = false,
	engine_initilized = false,

	line_space_percent = 100,
	default_font = "FreeSerif",
	header_font = "FreeSans",
	fallback_font = "Droid Sans Fallback",
	default_css = "./data/cr3.css",
	options = CreOptions,
}

-- NuPogodi, 20.05.12: inspect the zipfile content
function CreDocument.zipContentExt(self, fname)
	local outfile = "./data/zip_content"
	local s = ""
	os.execute("unzip ".."-l \""..fname.."\" > "..outfile)
	local i = 1
	if io.open(outfile,"r") then
		for lines in io.lines(outfile) do
			if i == 4 then s = lines break else i = i + 1 end
		end
	end
	-- return the extention
	return string.lower(string.match(s, ".+%.([^.]+)"))
end

function CreDocument:engineInit()
	if not engine_initilized then
		-- initialize cache
		cre.initCache(1024*1024*64)

		-- we need to initialize the CRE font list
		local fonts = Font:getFontList()
		for _k, _v in ipairs(fonts) do
			if _v ~= "Dingbats.cff" and _v ~= "StandardSymL.cff" then
				local ok, err = pcall(cre.registerFont, Font.fontdir..'/'.._v)
				if not ok then
					DEBUG(err)
				end
			end
		end

		local default_font = G_reader_settings:readSetting("cre_font")
		if default_font then
			self.default_font = default_font
		end

		local header_font = G_reader_settings:readSetting("header_font")
		if header_font then
			self.header_font = header_font
		end

		engine_initilized = true
	end
end

function CreDocument:init()
	require "libs/libkoreader-cre"
	self:engineInit()
	self.configurable:loadDefaults(self.options)

	local ok
	local file_type = string.lower(string.match(self.file, ".+%.([^.]+)"))
	if file_type == "zip" then
		-- NuPogodi, 20.05.12: read the content of zip-file
		-- and return extention of the 1st file
		file_type = self:zipContentExt(self.file)
	end
	-- these two format use the same css file
	if file_type == "html" then
		file_type = "htm"
	end
	-- if native css-file doesn't exist, one needs to use default cr3.css
	if not io.open("./data/"..file_type..".css") then
		file_type = "cr3"
	end
	self.default_css = "./data/"..file_type..".css"

	-- @TODO check the default view_mode to a global user configurable
	-- variable  22.12 2012 (houqp)
	ok, self._document = pcall(cre.newDocView,
		Screen:getWidth(), Screen:getHeight(), self.PAGE_VIEW_MODE
	)
	if not ok then
		self.error_message = self.doc -- will contain error message
		return
	end
	
	-- adjust font sizes according to screen dpi
	self._document:adjustFontSizes(Screen:getDPI())
	
	-- set fallback font face
	self._document:setStringProperty("crengine.font.fallback.face", self.fallback_font)
	
	self.is_open = true
	self.info.has_pages = false
	self:_readMetadata()
	self.info.configurable = true
end

function CreDocument:loadDocument()
	self._document:loadDocument(self.file)
	if not self.info.has_pages then
		self.info.doc_height = self._document:getFullHeight()
	end
	if Device:getModel() ~= "KindleDXG" then
		self:setVisiblePageCount(1)
	end
end

function CreDocument:close()
	self._document:saveDefaults()
	Document.close(self)
end

function CreDocument:getPageCount()
	return self._document:getPages()
end

function CreDocument:getWordFromPosition(pos)
	local word_box = self._document:getWordFromPos(pos.x, pos.y)
	if word_box.word then
		return {
			word = word_box.word,
			page = self._document:getCurrentPage(),
			sbox = {
				x = word_box.x0, y = word_box.y0,
				w = word_box.x1 - word_box.x0,
				h = word_box.y1 - word_box.y0,
			}
		}
	end
end

function CreDocument:getTextFromPositions(doc, pos0, pos1)
	DEBUG("getTextFromPositions not finished yet")
end

function CreDocument:drawCurrentView(target, x, y, rect, pos)
	tile_bb = Blitbuffer.new(rect.w, rect.h)
	self._document:drawCurrentPage(tile_bb)
	target:blitFrom(tile_bb, x, y, 0, 0, rect.w, rect.h)
	tile_bb:free()
end

function CreDocument:drawCurrentViewByPos(target, x, y, rect, pos)
	self._document:gotoPos(pos)
	self:drawCurrentView(target, x, y, rect)
end

function CreDocument:drawCurrentViewByPage(target, x, y, rect, page)
	self._document:gotoPage(page)
	self:drawCurrentView(target, x, y, rect)
end

function CreDocument:hintPage(pageno, zoom, rotation)
end

function CreDocument:drawPage(target, x, y, rect, pageno, zoom, rotation)
end

function CreDocument:renderPage(pageno, rect, zoom, rotation)
end

function CreDocument:gotoXPointer(xpointer)
	DEBUG("CreDocument: goto xpointer", xpointer)
	self._document:gotoXPointer(xpointer)
end

function CreDocument:getXPointer()
	return self._document:getXPointer()
end

function CreDocument:getPosFromXPointer(xp)
	return self._document:getPosFromXPointer(xp)
end

function CreDocument:getPageFromXPointer(xp)
	return self._document:getPageFromXPointer(xp)
end

function CreDocument:getFontFace()
	return self._document:getFontFace()
end

function CreDocument:getCurrentPos()
	return self._document:getCurrentPos()
end

function CreDocument:getPageLinks()
	return self._document:getPageLinks()
end

function Document:gotoPos(pos)
	DEBUG("CreDocument: goto position", pos)
	self._document:gotoPos(pos)
end

function CreDocument:gotoPage(page)
	DEBUG("CreDocument: goto page", page)
	self._document:gotoPage(page)
end

function CreDocument:gotoLink(link)
	DEBUG("CreDocument: goto link", link)
	self._document:gotoLink(link)
end

function CreDocument:goBack()
	DEBUG("CreDocument: go back")
	self._document:goBack()
end

function CreDocument:goForward(link)
	DEBUG("CreDocument: go forward")
	self._document:goForward()
end

function CreDocument:getCurrentPage()
	return self._document:getCurrentPage()
end

function CreDocument:setFontFace(new_font_face)
	if new_font_face then
		DEBUG("CreDocument: set font face", new_font_face)
		self._document:setFontFace(new_font_face)
	end
end

function CreDocument:getFontSize()
	return self._document:getFontSize()
end

function CreDocument:setFontSize(new_font_size)
	if new_font_size then
		DEBUG("CreDocument: set font size", new_font_size)
		self._document:setFontSize(new_font_size)
	end
end

function CreDocument:setViewMode(new_mode)
	if new_mode then
		DEBUG("CreDocument: set view mode", new_mode)
		if new_mode == "scroll" then
			self._document:setViewMode(self.SCROLL_VIEW_MODE)
		else
			self._document:setViewMode(self.PAGE_VIEW_MODE)
		end
	end
end

function CreDocument:setHeaderFont(new_font)
	if new_font then
		DEBUG("CreDocument: set header font", new_font)
		self._document:setHeaderFont(new_font)
	end
end

function CreDocument:zoomFont(delta)
	DEBUG("CreDocument: zoom font", delta)
	self._document:zoomFont(delta)
end

function CreDocument:setInterlineSpacePercent(percent)
	DEBUG("CreDocument: set interline space", percent)
	self._document:setDefaultInterlineSpace(percent)
end

function CreDocument:toggleFontBolder()
	DEBUG("CreDocument: toggle font bolder")
	self._document:toggleFontBolder()
end

function CreDocument:setGammaIndex(index)
	DEBUG("CreDocument: set gamma index", index)
	cre.setGammaIndex(index)
end

function CreDocument:setStyleSheet(new_css)
	DEBUG("CreDocument: set style sheet", new_css)
	self._document:setStyleSheet(new_css)
end

function CreDocument:setEmbeddedStyleSheet(toggle)
	DEBUG("CreDocument: set embedded style sheet", toggle)
	self._document:setEmbeddedStyleSheet(toggle)
end

function CreDocument:setPageMargins(left, top, right, bottom)
	DEBUG("CreDocument: set page margins", left, top, right, bottom)
	self._document:setPageMargins(left, top, right, bottom)
end

function CreDocument:setFloatingPunctuation(enabled)
	DEBUG("CreDocument: set floating punctuation", enabled)
	self._document:setIntProperty("crengine.style.floating.punctuation.enabled", enabled)
end

function CreDocument:setVisiblePageCount(new_count)
	DEBUG("CreDocument: set visible page count", new_count)
	self._document:setVisiblePageCount(new_count)
end

function CreDocument:setBatteryState(state)
	DEBUG("CreDocument: set battery state", state)
	self._document:setBatteryState(state)
end

function CreDocument:register(registry)
	registry:addProvider("txt", "application/txt", self)
	registry:addProvider("epub", "application/epub", self)
	registry:addProvider("fb2", "application/fb2", self)
	registry:addProvider("html", "application/html", self)
	registry:addProvider("htm", "application/htm", self)
	registry:addProvider("zip", "application/zip", self)
	registry:addProvider("rtf", "application/rtf", self)
	registry:addProvider("mobi", "application/mobi", self)
	registry:addProvider("prc", "application/prc", self)
	registry:addProvider("azw", "application/azw", self)
	registry:addProvider("chm", "application/chm", self)
	registry:addProvider("pdb", "application/pdb", self)
	registry:addProvider("doc", "application/doc", self)
	registry:addProvider("tcr", "application/tcr", self)
end

return CreDocument

local InputContainer = require("ui/widget/container/inputcontainer")
local Geom = require("ui/geometry")
local Device = require("ui/device")
local DocSettings = require("docsettings")
local Event = require("ui/event")
local UIManager = require("ui/uimanager")
local _ = require("gettext")

local ReaderView = require("ui/reader/readerview")
local ReaderZooming = require("ui/reader/readerzooming")
local ReaderPanning = require("ui/reader/readerpanning")
local ReaderRotation = require("ui/reader/readerrotation")
local ReaderPaging = require("ui/reader/readerpaging")
local ReaderRolling = require("ui/reader/readerrolling")
local ReaderToc = require("ui/reader/readertoc")
local ReaderBookmark = require("ui/reader/readerbookmark")
local ReaderFont = require("ui/reader/readerfont")
local ReaderTypeset = require("ui/reader/readertypeset")
local ReaderMenu = require("ui/reader/readermenu")
local ReaderGoto = require("ui/reader/readergoto")
local ReaderConfig = require("ui/reader/readerconfig")
local ReaderCropping = require("ui/reader/readercropping")
local ReaderKoptListener = require("ui/reader/readerkoptlistener")
local ReaderCoptListener = require("ui/reader/readercoptlistener")
local ReaderHinting = require("ui/reader/readerhinting")
local ReaderHighlight = require("ui/reader/readerhighlight")
local ReaderScreenshot = require("ui/reader/readerscreenshot")
local ReaderFrontLight = require("ui/reader/readerfrontlight")
local ReaderDictionary = require("ui/reader/readerdictionary")
local ReaderHyphenation = require("ui/reader/readerhyphenation")
local ReaderActivityIndicator = require("ui/reader/readeractivityindicator")

--[[
This is an abstraction for a reader interface

it works using data gathered from a document interface
]]--

local ReaderUI = InputContainer:new{
	key_events = {
		Close = { { "Home" },
			doc = _("close document"), event = "Close" },
	},
	active_widgets = {},

	-- our own size
	dimen = Geom:new{ w = 400, h = 600 },
	-- if we have a parent container, it must be referenced for now
	dialog = nil,

	-- the document interface
	document = nil,

	-- initial page or percent inside document on opening
	start_pos = nil,
	-- password for document unlock
	password = nil,

	postInitCallback = nil,
}

function ReaderUI:init()
	self.postInitCallback = {}
	-- if we are not the top level dialog ourselves, it must be given in the table
	if not self.dialog then
		self.dialog = self
	end

	if Device:hasKeyboard() then
		self.key_events.Back = {
			{ "Back" }, doc = _("close document"),
			event = "Close" }
	end

	self.doc_settings = DocSettings:open(self.document.file)

	-- a view container (so it must be child #1!)
	self[1] = ReaderView:new{
		dialog = self.dialog,
		dimen = self.dimen,
		ui = self,
		document = self.document,
	}
	-- rotation controller
	self[2] = ReaderRotation:new{
		dialog = self.dialog,
		view = self[1],
		ui = self
	}
	-- reader menu controller
	self[3] = ReaderMenu:new{
		view = self[1],
		ui = self
	}
	self.menu = self[3] -- hold reference to menu widget
	-- Table of content controller
	self[4] = ReaderToc:new{
		dialog = self.dialog,
		view = self[1],
		ui = self
	}
	self.toc = self[4] -- hold reference to bm widget
	-- bookmark controller
	local reader_bm = ReaderBookmark:new{
		dialog = self.dialog,
		view = self[1],
		ui = self
	}
	table.insert(self, reader_bm)
	-- text highlight
	local highlight = ReaderHighlight:new{
		dialog = self.dialog,
		view = self[1],
		ui = self,
		document = self.document,
	}
	table.insert(self, highlight)
	-- goto
	table.insert(self, ReaderGoto:new{
		dialog = self.dialog,
		view = self[1],
		ui = self,
		document = self.document,
	})
	-- dictionary
	local dict = ReaderDictionary:new{
		dialog = self.dialog,
		view = self[1],
		ui = self,
		document = self.document,
	}
	table.insert(self, dict)
	-- screenshot controller
	local reader_ss = ReaderScreenshot:new{
		dialog = self.dialog,
		view = self[1],
		ui = self
	}
	table.insert(self.active_widgets, reader_ss)
	if Device:getFrontlight() then
		-- frontlight controller
		table.insert(self, ReaderFrontLight:new{
			dialog = self.dialog,
			view = self[1],
			ui = self
		})
	end

	if self.document.info.has_pages then
		-- for page specific controller

		-- if needed, insert a paging container
		local pager = ReaderPaging:new{
			dialog = self.dialog,
			view = self[1],
			ui = self
		}
		table.insert(self, pager)
		-- zooming controller
		local zoomer = ReaderZooming:new{
			dialog = self.dialog,
			view = self[1],
			ui = self
		}
		table.insert(self, zoomer)
		-- panning controller
		local panner = ReaderPanning:new{
			dialog = self.dialog,
			view = self[1],
			ui = self
		}
		table.insert(self, panner)
		-- cropping controller
		local cropper = ReaderCropping:new{
			dialog = self.dialog,
			view = self[1],
			ui = self,
			document = self.document,
		}
		table.insert(self, cropper)
		-- hinting controller
		local hinter = ReaderHinting:new{
			dialog = self.dialog,
			zoom = zoomer,
			view = self[1],
			ui = self,
			document = self.document,
		}
		table.insert(self, hinter)
	else
		if Device:getModel() ~= "KindleDXG" then
			self.document:setVisiblePageCount(1)
		end
		-- make sure we load document first before calling any callback
		table.insert(self.postInitCallback, function()
			self.document:loadDocument()
		end)
		-- rolling controller
		local roller = ReaderRolling:new{
			dialog = self.dialog,
			view = self[1],
			ui = self
		}
		table.insert(self, roller)
		-- font menu
		local font_menu = ReaderFont:new{
			dialog = self.dialog,
			view = self[1],
			ui = self
		}
		table.insert(self, font_menu)
		-- typeset controller
		local typeset = ReaderTypeset:new{
			dialog = self.dialog,
			view = self[1],
			ui = self
		}
		table.insert(self, typeset)

		table.insert(self, ReaderHyphenation:new{
			dialog = self.dialog,
			view = self[1],
			ui = self
		})
	end
	if self.document.info.configurable then
		-- configurable controller
		local config_dialog = ReaderConfig:new{
			configurable = self.document.configurable,
			options = self.document.options,
			dialog = self.dialog,
			view = self[1],
			ui = self
		}
		table.insert(self, config_dialog)
		-- kopt option controller
		local koptlistener = ReaderKoptListener:new{
			dialog = self.dialog,
			view = self[1],
			ui = self,
			document = self.document,
		}
		table.insert(self, koptlistener)
		-- cre option controller
		local coptlistener = ReaderCoptListener:new{
			dialog = self.dialog,
			view = self[1],
			ui = self,
			document = self.document,
		}
		table.insert(self, coptlistener)
		-- activity indicator
		local activity_listener = ReaderActivityIndicator:new{
			dialog = self.dialog,
			view = self[1],
			ui = self,
			document = self.document,
		}
		table.insert(self, activity_listener)
	end
	--DEBUG(self.doc_settings)
	-- we only read settings after all the widgets are initialized
	self:handleEvent(Event:new("ReadSettings", self.doc_settings))
	-- notify childs of dimensions
	self:handleEvent(Event:new("SetDimensions", self.dimen))

	for _,v in ipairs(self.postInitCallback) do
		v()
	end
end

function ReaderUI:onSetDimensions(dimen)
	self.dimen = dimen
end

function ReaderUI:onClose()
	DEBUG("closing reader")
	self:handleEvent(Event:new("CloseDocument"))
	self.doc_settings:flush()
	if self.document ~= nil then
		self.document:close()
		self.document = nil
		self.start_pos = nil
	end
	UIManager:close(self.dialog)
	return true
end

return ReaderUI

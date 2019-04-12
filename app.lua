-- libraries
local lapis       = require "lapis"
local config      = require ("lapis.config").get()
local respond_to  = require ("lapis.application").respond_to
local app         = lapis.Application()

-- enable views
app:enable("etlua")
app.layout = require "views.layout"

-- controllers
local index       = require "controllers.index"
local login       = require "controllers.login"
local error       = require "controllers.error"
local error_404   = require "controllers.error_404"
local feed        = require "controllers.feed"
local catalog     = require "controllers.catalog"
local thread      = require "controllers.thread"

-- before routes
app:before_filter(check_auth)

-- error handling
app.handle_404 = error_404

-- controller routes
app:match("index", "/",                                         index)
app:match("error", "/error/:errorCode",                         error)
app:match("404", "/404",                                        error_404)
app:match("login", "/login",                                    respond_to(login))
app:match("feed", "/feed/:feedName[%a](/page/:pageNumber[%d])", respond_to(feed))
app:match("thread", "/feed/:feedName[%a]/:threadID[%d]",        respond_to(thread))
app:match("catalog", "/catalog/:feedName[%a]",                  respond_to(catalog))

return app

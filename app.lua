-- libraries
local lapis       = require "lapis"
local config      = require ("lapis.config").get()
local respond_to  = require ("lapis.application").respond_to
local app         = lapis.Application()

-- enable views
app:enable("etlua")
app.layout = require "views.layout"

-- before
local check_auth = require "controllers.check_auth"

-- controllers
local index       = require "controllers.index"
local login       = require "controllers.login"
local error       = require "controllers.error"
local error_404   = require "controllers.error_404"
local catalog     = require "controllers.catalog"
local thread      = require "controllers.thread"

-- before routes
app:before_filter(check_auth)

-- error handling
app.handle_404 = error_404

-- controller routes
app:match("index", "/",                                         respond_to(index))
app:match("error", "/error/:errorCode",                         error)
app:match("404", "/404",                                        error_404)
app:match("login", "/login",                                    respond_to(login))
--app:match("thread", "/feed/:feedName[%a]/:threadID[%d]",        respond_to(thread))

return app

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
local error       = require "controllers.error"
local login       = require "controllers.login"
local profile     = require "controllers.profile"
local error_404   = require "controllers.error_404"

-- API controllers
local APIfollow   = require "controllers.APIfollow"

-- before routes
app:before_filter(check_auth)

-- error handling
app.handle_404 = error_404

-- controller routes
app:match("index", "/",                                         respond_to(index))
app:match("error", "/error/:errorCode",                         error)
app:match("404", "/404",                                        error_404)
app:match("login", "/login",                                    respond_to(login))
app:match("profile", "/:userHandle(/:postID)",                  respond_to(profile))
--app:match("thread", "/feed/:feedName[%a]/:threadID[%d]",        respond_to(thread))

-- API routes
app:match("APIfollow", "/API/follow/:userHandle/:followHandle", APIfollow)

return app

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
local index         = require "controllers.index"
local error         = require "controllers.error"
local login         = require "controllers.login"
local notifications = require "controllers.notifications"
local profile       = require "controllers.profile"
local error_404     = require "controllers.error_404"
local settings      = require "controllers.settings"


-- mobile
local mobile_login  = require "mobile.mobile_login"

-- API controllers
local APIfollow    = require "API.follow"
local APIlikes     = require "API.likes"
local APIposts     = require "API.posts"
local APItags      = require "API.tags"
local APItheme     = require "API.theme"

-- before routes
app:before_filter(check_auth)

-- error handling
app.handle_404 = error_404

-- controller routes
app:match("index", "/",                                         respond_to(index))
app:match("error", "/error/:errorCode",                         error)
app:match("404", "/404",                                        error_404)
app:match("login", "/login",                                    respond_to(login))
app:match("notifications", "/notifications",                    respond_to(notifications))
app:match("profile", "/:userHandle(/:postID[%d])",              respond_to(profile))
app:match("settings", "/settings",                              respond_to(settings))
app:match("search", "/search(/:searchString)",                  respond_to(search))
app:match("profile", "/:userHandle(/:postID[%d])",              respond_to(profile))

-- API routes
app:match("follow", "/API/follow/:followHandle(/:toggle(/:APIKey))",  APIfollow)
app:match("likes", "/API/likes/:option/:ID[%d](/:APIKey)",            APIlikes)
app:match("posts", "/API/posts/:option(/:ID(/:ID2))",                 APIposts)
app:match("tags", "/API/tags/:option/:ID[%d](/:APIKey)",              APItags)
app:match("theme", "/API/change_theme",                                 APItheme)

-- mobile routes
app:match("mobile_login", "/m/mobile_login", respond_to(mobile_login))

return app

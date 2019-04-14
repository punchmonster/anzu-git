local csrf        = require "lapis.csrf"
local db          = require "lapis.db"
local Model       = require ("lapis.db.model").Model
local Posts       = require "models.posts"
local Text        = require "models.text"
local Bans        = require "models.bans"

return {

  before = function(self)
    -- Page title
    self.page_title = "home"

    -- build url
    self.submit_url = self:url_for("index")
  end,

  GET = function(self)

    -- generate token for page verification
    self.csrf_token = csrf.generate_token(self)

    return { render = "index" }
    --return { redirect_to = self:url_for("404") }
  end,

  POST = function(self)

    -- spam detection
    if #self.params.email > 1 then
      return { redirect_to = self:url_for("error", { errorCode = "err_not_allowed" }) }
    end

    --[[ check if person is banned
    if Bans:check(ngx.var.remote_addr) then
      return { redirect_to = self:url_for("index") }
    end]]

    -- check csrf protection
    csrf.assert_token(self)

    -- posting configuration
    local x = {
      userID = self.session.current_user,
      postBody = self.req.params_post['postBody'],
      postImage = self.params.postImage,
      sessionID = self.session.userID
    }

    -- return post status
    local completed, error = Posts:submit(x)
    -- pass thread to model
    if completed == true then
      -- go back to feed view
      return { redirect_to = self:url_for("feed", { feedName = self.params.feedName }) }
    else
      return { redirect_to = self:url_for("error", { errorCode = error }) }
    end

  end
}

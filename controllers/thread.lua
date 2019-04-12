local csrf        = require "lapis.csrf"
local db          = require "lapis.db"
local Model       = require ("lapis.db.model").Model
local Posts       = require "models.posts"
local Feeds       = require "models.feeds"
local Text        = require "models.text"
local Bans        = require "models.bans"

return {

  before = function(self)
    -- get feeds for navigation
    self.nav_data = Feeds:get_all()
  end,

  GET = function(self)

    -- generate token for page verification
    self.csrf_token = csrf.generate_token(self)
    self.submit_url = self:url_for("feed")

    -- retrieve feed data from database
    local feed_info = Feeds:get_info(self.params.feedName)

    -- check if feed exists
    if feed_info ~= nil then

      -- retrieve posts in thread
      self.thread_data = db.select("* from `" .. feed_info.feedName .. "` where threadID = ?", self.params.threadID)

      -- checks if thread exists, if not checks if post exists in a thread and redirects there if it does
      if #self.thread_data < 1 then
        local thread_redirect = db.select("* from `" .. feed_info.feedName .. "` where postID = ?", self.params.threadID)
        if #thread_redirect < 1 then
          return { redirect_to = self:url_for("feed", { feedName = feed_info.feedName }) }
        else
          self.thread_data = db.select("* from `" .. feed_info.feedName .. "` where threadID = ?", thread_redirect[1]['threadID'])
          --BELOW: more HTTP requests but URL ends up prettier
          --return { redirect_to = self:url_for("thread", { feedName = feed_info.feedName, threadID = thread_redirect[1]['threadID'] .. "#" .. thread_redirect[1]['postID'] }) }
        end
      end

      -- add post crosslinks to posts
      for k, v in pairs(self.thread_data) do
        v.postBody = Text:post_sanitize(v.postBody, self:url_for("feed", { feedName = feed_info.feedName }))
      end

      -- page title and description
      self.page_title = tostring(feed_info.feedName .. " - " .. self.thread_data[1]['threadID'])
      self.feed_desc  = feed_info.feedDesc

      -- pass current UNIX timestamp to view
      self.current_time = ngx.time()

      return { render = "thread" }
    else
      return { redirect_to = self:url_for("404") }
    end
  end,

  POST = function(self)

    -- spam detection
    if #self.params.email > 1 then
      return { redirect_to = self:url_for("error", { errorCode = "err_not_allowed" }) }
    end

    -- check if person is banned
    if Bans:check(ngx.var.remote_addr) then
      return { redirect_to = self:url_for("index") }
    end

    -- check csrf protection
    csrf.assert_token(self)

    -- posting configuration
    local x = {
      feedName    = self.params.feedName,
      postBody    = self.req.params_post['postBody'],
      IP          = ngx.var.remote_addr,
      thread      = self.params.threadID,
      postImage   = self.params.postImage
    }

    -- return post status
    local completed, error = Posts:submit(x)
    -- pass thread to model
    if completed == true then
      -- go back to feed view
      return { redirect_to = self:url_for("thread", { feedName = self.params.feedName, threadID = self.params.threadID }) }
    else
      return { redirect_to = self:url_for("error", { errorCode = error }) }
    end
  end
}

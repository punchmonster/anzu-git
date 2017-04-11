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

      -- check if pagenumber was supplied and calculate offset
      local page_offset
      local pageNumber
      if tonumber(self.params.pageNumber) ~= nil then
        page_offset = " offset " .. (tonumber(self.params.pageNumber) * 15 - 15)
        pageNumber = self.params.pageNumber
      else
        page_offset, pageNumber = "", ""
      end

      -- page title
      self.page_title = feed_info.feedName
      self.feed_desc =  feed_info.feedDesc

      -- retrieve posts
      self.post_data = db.select("* from `" .. feed_info.feedName .. "` order by postID DESC limit 15" .. page_offset)

      for k, v in pairs(self.post_data) do
        v.postBody = Text:post_sanitize(v.postBody, self:url_for("feed", { feedName = feed_info.feedName }))
      end

      -- pass current UNIX timestamp to view
      self.current_time = ngx.time()

      return { render = "feed" }
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
      feedName = self.params.feedName,
      threadTitle = self.req.params_post['threadTitle'],
      postBody = self.req.params_post['postBody'],
      IP       = ngx.var.remote_addr,
      postImage = self.params.postImage
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

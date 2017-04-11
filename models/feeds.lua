local db       = require "lapis.db"
local Model    = require ("lapis.db.model").Model
local Feeds    = Model:extend("feeds")

-- mapping database table to model
local Feeds       = Model:extend("feeds", {
  primary_key = { "feedName" }
})

-- FUNCTION: gets info for 1 feed
-- arg1: name of feed you want
-- RETURN: feed information in a table if it exists, if not, nil
function Feeds:get_info(arg1)

  -- retrieve feed data from database
  local feed_data = Feeds:select("where feedName = ?", arg1)

  if type(feed_data[1]) ~= "nil" then
    return { feedID = feed_data[1]['feedID'], feedName = feed_data[1]['feedName'], feedDesc = feed_data[1]['feedDesc'] }
  else
    return nil
  end
end

-- FUNCTION: gets info for 1 feed
-- RETURN: table with all feed data
function Feeds:get_all()
  return Feeds:select("order by feedID")
end

return Feeds

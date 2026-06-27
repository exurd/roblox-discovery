-- data variables to keep roblox-ltgrab from getting too large

local mod = {}


-- thumbnail vars start --

mod.THUMBNAIL_SIZES = {"30x30", "42x42", "50x50", "60x62", "75x75", "110x110",
                        "140x140", "150x150", "160x100", "160x600", "250x250",
                        "256x144", "300x250", "304x166", "384x216", "396x216",
                        "420x420", "480x270", "512x512", "576x324", "700x700",
                        "728x90", "768x432", "1200x80", "330x110", "660x220"}
-- slim table for thumbnails with specific sizes:
mod.SLIM_ITEMS = {
  "users/outfits?userOutfitIds",
  "users/avatar?userIds",
  "users/avatar-bust?userIds",
  "users/avatar-headshot?userIds",
  "groups/icons?groupIds",
  "bundles/thumbnails?bundleIds",
  "badges/icons?badgeIds",  -- this is 150x150 only, but slim'll do
  "game-passes?gamePassIds",  -- this one too
  "developer-products/icons?developerProductIds",
  "games/icons?universeIds",
  "places/gameicons?placeIds"
}
mod.THUMBNAIL_SIZES_SLIM = {"512x512", "420x420", "250x250", "150x150", "140x140",
                            "110x110", "75x75", "50x50", "30x30"}
mod.THUMBNAIL_SIZES_UNI = {"768x432", "576x324", "480x270", "384x216", "256x144"}
mod.THUMBNAIL_FORMATS = {"Png", "Jpeg", "Webp"}

-- thumbnail vars end --


-- asset type vars start --

mod.ASSET_TYPES_CATALOG_FAVORITES = {
  -- from https://inventory.roblox.com/v1/users/{USER_ID}/categories/favorites
  -- (strange that it's not a standalone api and needs a user id?
  --  keep this in mind when edge cases appear)
  -- any new asset types that support catalog api should be added here
  2,     -- TShirt
  3,     -- Audio
  8,     -- Hat
  -- 9,  -- Place  (Invalid type), different api used for this
  10,    -- Model
  11,    -- Shirt
  12,    -- Pants
  13,    -- Decal
  -- 16, -- Avatar (Invalid type)
  -- 17, -- Head   (Doesn't show up)
  18,    -- Face
  19,    -- Gear
  24,    -- Animation
  27,    -- Torso
  28,    -- RightArm
  29,    -- LeftArm
  30,    -- LeftLeg
  31,    -- RightLeg
  38,    -- Plugin
  40,    -- MeshPart
  41,    -- HairAccessory
  42,    -- FaceAccessory
  43,    -- NeckAccessory
  44,    -- ShoulderAccessory
  45,    -- FrontAccessory
  46,    -- BackAccessory
  47,    -- WaistAccessory
  48,    -- ClimbAnimation
  50,    -- FallAnimation
  51,    -- IdleAnimation
  52,    -- JumpAnimation
  53,    -- RunAnimation
  54,    -- SwimAnimation
  55,    -- WalkAnimation
  56,    -- PoseAnimation
  61,    -- EmoteAnimation
  62,    -- Video
  64,    -- TShirtAccessory
  65,    -- ShirtAccessory
  66,    -- PantsAccessory
  67,    -- JacketAccessory
  68,    -- SweaterAccessory
  69,    -- ShortsAccessory
  70,    -- LeftShoeAccessory
  71,    -- RightShoeAccessory
  72,    -- DressSkirtAccessory
  76,    -- EyebrowAccessory
  77,    -- EyelashAccessory
  78,    -- MoodAnimation
  88,    -- FaceMakeup
  89,    -- LipMakeup
  90     -- EyeMakeup
}
mod.ASSET_TYPES_CATALOG_FAVORITES_DIFFERENTLAYOUT = {
  -- some types like EmoteAnimations have a completely different
  -- json layout... great! just what i needed
  2,     -- TShirt
  8,     -- Hat
  11,    -- Shirt
  12,    -- Pants
  19,    -- Gear
  41,    -- HairAccessory
  42,    -- FaceAccessory
  43,    -- NeckAccessory
  44,    -- ShoulderAccessory
  45,    -- FrontAccessory
  46,    -- BackAccessory
  47,    -- WaistAccessory
  61,    -- EmoteAnimation
  64,    -- TShirtAccessory
  65,    -- ShirtAccessory
  66,    -- PantsAccessory
  67,    -- JacketAccessory
  68,    -- SweaterAccessory
  69,    -- ShortsAccessory
  70,    -- LeftShoeAccessory
  71,    -- RightShoeAccessory
  72,    -- DressSkirtAccessory
  76,    -- EyebrowAccessory
  77,    -- EyelashAccessory
  78,    -- MoodAnimation
  88,    -- FaceMakeup
  89,    -- LipMakeup
  90     -- EyeMakeup
}
mod.ASSET_TYPES_CATALOG_FAVORITES_DEVTYPES = {
  -- these also have a different layout, but they're developer types
  -- so they make more sense to be different. not enough sense but still
  3,     -- Audio
  10,    -- Model
  13,    -- Decal
  38     -- Plugin
}
mod.ASSET_TYPES_CATALOG_INVENTORY = {
  -- from https://inventory.roblox.com/v1/users/{USER_ID}/categories/favorites
  -- (strange that it's not a standalone api and needs a user id?
  --  keep this in mind when edge cases appear)
  -- any new asset types that support catalog api should be added here
  2,     -- TShirt
  3,     -- Audio
  8,     -- Hat
  9,     -- Place  (Invalid type), different api used for this
  10,    -- Model  (Hidden?)
  11,    -- Shirt
  12,    -- Pants
  13,    -- Decal
  17,    -- Head
  -- 16, -- Avatar (Invalid type)
  18,    -- Face
  19,    -- Gear
  24,    -- Animation
  27,    -- Torso
  28,    -- RightArm
  29,    -- LeftArm
  30,    -- LeftLeg
  31,    -- RightLeg
  32,    -- Package
  38,    -- Plugin
  40,    -- MeshPart
  41,    -- HairAccessory
  42,    -- FaceAccessory
  43,    -- NeckAccessory
  44,    -- ShoulderAccessory
  45,    -- FrontAccessory
  46,    -- BackAccessory
  47,    -- WaistAccessory
  48,    -- ClimbAnimation
  50,    -- FallAnimation
  51,    -- IdleAnimation
  52,    -- JumpAnimation
  53,    -- RunAnimation
  54,    -- SwimAnimation
  55,    -- WalkAnimation
  56,    -- PoseAnimation
  61,    -- EmoteAnimation
  62,    -- Video
  64,    -- TShirtAccessory
  65,    -- ShirtAccessory
  66,    -- PantsAccessory
  67,    -- JacketAccessory
  68,    -- SweaterAccessory
  69,    -- ShortsAccessory
  70,    -- LeftShoeAccessory
  71,    -- RightShoeAccessory
  72,    -- DressSkirtAccessory
  76,    -- EyebrowAccessory
  77,    -- EyelashAccessory
  78,    -- MoodAnimation
  88,    -- FaceMakeup
  89,    -- LipMakeup
  90     -- EyeMakeup
}
-- mod.BUNDLE_TYPES_CATALOG = {
--   -- from https://create.roblox.com/docs/reference/engine/enums/BundleType
--   1,  -- BodyParts
--   2,  -- Animations
--   3,  -- Shoes
--   4   -- DynamicHead
-- }
-- from https://devforum.roblox.com/t/official-list-of-deprecated-web-endpoints/62889/96
mod.ASSET_TYPES_CREATORSTORE = {
  3,     -- Audio
  10,    -- Model
  13,    -- Decal
  24,    -- Animation
  38,    -- Plugin
  40,    -- MeshPart
  62     -- Video
}

-- asset types end --


return mod

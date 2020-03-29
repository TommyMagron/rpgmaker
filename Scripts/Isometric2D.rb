TILE_WIDTH = 128
TILE_HEIGHT = 64

TILE_WIDTH_HALF = TILE_WIDTH / 2
TILE_HEIGHT_HALF = TILE_HEIGHT / 2

SPACE_BETWEEN_ORIGIN_TILEMAP_AND_SCREEN_TOP_BORDER = 64

class Sprite_Character < Sprite_Base

  def initialize(viewport, character = nil)
    super(viewport)
    #@debug = QDebug.new
    @character = character
    @balloon_duration = 0
    update
  end

  #--------------------------------------------------------------------------
  # * Set Character Bitmap
  #--------------------------------------------------------------------------
  def set_character_bitmap
    self.bitmap = Cache.character(@character_name)
    sign = @character_name[/^[\!\$]./]
    if sign && sign.include?('$')
      @cw = bitmap.width / 3
      @ch = bitmap.height / 4
    else
      @cw = bitmap.width / 8
      @ch = bitmap.height / 4
    end
    self.ox = @cw / 2
    self.oy = @ch
  end

  #--------------------------------------------------------------------------
  # * Update Transfer Origin Rectangle
  #--------------------------------------------------------------------------
  def update_src_rect
    if @tile_id == 0
      #index = @character.character_index : le personnage possède tout son sprite
      pattern = @character.pattern < 8 ? @character.pattern : 1 #@TODO : change pattern calculation (pattern represents one column)
      sx = pattern * @cw #@TODO test sprite complet, replace (index % 4 * 3 + pattern) * @cw
      sy = ((@character.direction - 2) / 2) * @ch
      self.src_rect.set(sx, sy, @cw, @ch)
    end
  end
end

class Game_CharacterBase

  SPACE_BETWEEN_CHARACTERN_PATTERN = 12

  #--------------------------------------------------------------------------
  # * Initialize Public Member Variables
  #--------------------------------------------------------------------------
  def init_public_members
    #@debug = QDebug.new
    @id = 0
    @x = 0
    @y = 0
    @real_x = 0
    @real_y = 0
    @tile_id = 0
    @character_name = ""
    @character_index = 0
    @move_speed = 4
    @move_frequency = 6
    @walk_anime = true
    @step_anime = false
    @direction_fix = false
    @opacity = 255
    @blend_type = 0
    @direction = 6
    @pattern = 1
    @priority_type = 1
    @through = false
    @bush_depth = 0
    @animation_id = 0
    @balloon_id = 0
    @transparent = false
  end

  #--------------------------------------------------------------------------
  # * Get Screen X-Coordinates
  #--------------------------------------------------------------------------
  def screen_x
    ($game_map.adjust_x(@real_x) - $game_map.adjust_y(@real_y)) * TILE_WIDTH_HALF + (Graphics.width / 2)
  end
  #--------------------------------------------------------------------------
  # * Get Screen Y-Coordinates
  #--------------------------------------------------------------------------
  def screen_y
    ($game_map.adjust_x(@real_x) + $game_map.adjust_y(@real_y)) * TILE_HEIGHT_HALF + SPACE_BETWEEN_CHARACTERN_PATTERN - jump_height - TILE_HEIGHT_HALF + (Graphics.height / 2)
  end
end

class Spriteset_Map

  def initialize
    #@debug = QDebug.new
    create_viewports
    create_tilemap
    create_parallax
    create_characters
    create_shadow
    create_weather
    create_pictures
    create_timer
    update
  end

  #--------------------------------------------------------------------------
  # * Update Tilemap
  #--------------------------------------------------------------------------
  def update_tilemap
    @tilemap.map_data = $game_map.data
    if @parallax.bitmap == nil
      @parallax_name = $game_map.parallax_name
      @parallax.bitmap = Cache.parallax(@parallax_name)
    end
    @tilemap.ox = ($game_map.display_x - $game_map.display_y) * TILE_WIDTH_HALF + (@parallax.bitmap.width / 2) - (Graphics.width / 2)
    @tilemap.oy = ($game_map.display_x + $game_map.display_y) * TILE_HEIGHT_HALF
    @tilemap.update
  end

  #--------------------------------------------------------------------------
  # * Update Weather
  #--------------------------------------------------------------------------
  def update_weather
    @weather.type = $game_map.screen.weather_type
    @weather.power = $game_map.screen.weather_power
    @weather.ox = $game_map.display_x * TILE_WIDTH_HALF
    @weather.oy = $game_map.display_y * TILE_HEIGHT
    @weather.update
  end
end

class Game_Map

  MAP_DATA_OFFSET_X_TO_ADJUST_MAP_ORIGIN = 118
  MAP_DATA_OFFSET_Y_TO_ADJUST_MAP_ORIGIN = 15

  #--------------------------------------------------------------------------
  # * Object Initialization
  #--------------------------------------------------------------------------
  def initialize
    #@debug = QDebug.new
    @screen = Game_Screen.new
    @interpreter = Game_Interpreter.new
    @map_id = 0
    @events = {}
    @display_x = 0
    @display_y = 0
    create_vehicles
    @name_display = true
  end

  #--------------------------------------------------------------------------
  # * Number of Horizontal Tiles on Screen
  #--------------------------------------------------------------------------
  def screen_tile_x
    Graphics.width / TILE_WIDTH
  end

  #--------------------------------------------------------------------------
  # * Number of Vertical Tiles on Screen
  #--------------------------------------------------------------------------
  def screen_tile_y
    Graphics.height / TILE_HEIGHT
  end

  #--------------------------------------------------------------------------
  # * Calculate X Coordinate of Parallax Display Origin
  # * Add an offset equal to middle of map to center camera on the map
  #--------------------------------------------------------------------------
  def parallax_ox(bitmap)
      offset_camera_width = (bitmap.width / 2) - (Graphics.width / 2)
      (@parallax_x - @parallax_y) * TILE_WIDTH_HALF + offset_camera_width
  end

  #--------------------------------------------------------------------------
  # * Calculate Y Coordinate of Parallax Display Origin
  #--------------------------------------------------------------------------
  def parallax_oy(bitmap)
      (@parallax_x + @parallax_y) * TILE_HEIGHT_HALF
  end

  #--------------------------------------------------------------------------
  # * Set Display Position
  #--------------------------------------------------------------------------
  def set_display_pos(x, y)
    x = [x, width - screen_tile_x].min
    y = [y, height - screen_tile_y].min
    @parallax_x = x
    @parallax_y = y
  end

  #--------------------------------------------------------------------------
  # * Scroll Setup
  #--------------------------------------------------------------------------
  def setup_scroll
    @scroll_direction = 2
    @scroll_rest = 0
    @scroll_speed = 4
  end

  #--------------------------------------------------------------------------
  # * Calculate Scroll Distance
  #--------------------------------------------------------------------------
  def scroll_distance
    2 ** @scroll_speed / 256.0
  end

  #--------------------------------------------------------------------------
  # * Scroll Down
  #--------------------------------------------------------------------------
  def scroll_down(distance)
    if loop_vertical?
      @display_y += distance
      @display_y %= @map.height
      @parallax_y += distance if @parallax_loop_y
    else
      last_y = @display_y
      @display_y = [@display_y + distance, height - screen_tile_y].min
      @parallax_y += @display_y - last_y
    end
  end
  #--------------------------------------------------------------------------
  # * Scroll Left
  #--------------------------------------------------------------------------
  def scroll_left(distance)
    if loop_horizontal?
      @display_x += @map.width - distance
      @display_x %= @map.width 
      @parallax_x -= distance if @parallax_loop_x
    else
      last_x = @display_x
      @display_x = [@display_x - distance, 0].max
      @parallax_x += @display_x - last_x
    end
  end
  #--------------------------------------------------------------------------
  # * Scroll Right
  #--------------------------------------------------------------------------
  def scroll_right(distance)
    if loop_horizontal?
      @display_x += distance
      @display_x %= @map.width
      @parallax_x += distance if @parallax_loop_x
    else
      last_x = @display_x
      @display_x = [@display_x + distance, (width - screen_tile_x)].min
      @parallax_x += @display_x - last_x
    end
  end
  #--------------------------------------------------------------------------
  # * Scroll Up
  #--------------------------------------------------------------------------
  def scroll_up(distance)
    if loop_vertical?
      @display_y += @map.height - distance
      @display_y %= @map.height
      @parallax_y -= distance if @parallax_loop_y
    else
      last_y = @display_y
      @display_y = [@display_y - distance, 0].max
      @parallax_y += @display_y - last_y
    end
  end

  #--------------------------------------------------------------------------
  # * Check Passage
  #     bit:  Inhibit passage check bit
  # @TODO For now stop passage does not takes care of passage, surely problem with Tile ID...
  #--------------------------------------------------------------------------
  def check_passage(x, y, bit)
    all_tiles(x, y).each do |tile_id|
      flag = tileset.flags[tile_id]
      next if flag & 0x10 != 0            # [☆]: No effect on passage
      return true  if flag & bit == 0     # [○] : Passable
      return false if flag & bit == bit   # [×] : Impassable
    end
    return false                          # Impassable
  end

  def map_tile_adjust_xy(x, y)
    tile_x = (2 * (x - y)) + MAP_DATA_OFFSET_X_TO_ADJUST_MAP_ORIGIN
    tile_y = (x + y) + MAP_DATA_OFFSET_Y_TO_ADJUST_MAP_ORIGIN

    point = Class.new do
      attr_accessor :x, :y
    end.new
    
    point.x = tile_x
    point.y = tile_y

    return point
  end

  #--------------------------------------------------------------------------
  # * Get Array of All Layer Tiles (Top to Bottom) at Specified Coordinates
  #--------------------------------------------------------------------------
  def layered_tiles(x, y)
    newTilePoint = map_tile_adjust_xy(x, y)
    [2, 1, 0].collect {|z| tile_id(newTilePoint.x, newTilePoint.y, z) }
  end
  #--------------------------------------------------------------------------
  # * Get Array of All Tiles (Including Events) at Specified Coordinates
  #--------------------------------------------------------------------------
  def all_tiles(x, y)
    newTilePoint = map_tile_adjust_xy(x, y)
    tile_events_xy(newTilePoint.x, newTilePoint.y).collect {|ev| ev.tile_id } + layered_tiles(x, y)
  end
end

class Game_Player < Game_Character
  def initialize
    super
    #@debug = QDebug.new
    @vehicle_type = :walk           # Type of vehicle currently being ridden
    @vehicle_getting_on = false     # Boarding vehicle flag
    @vehicle_getting_off = false    # Getting off vehicle flag
    @followers = Game_Followers.new(self)
    @transparent = $data_system.opt_transparent
    clear_transfer_info
  end

  #--------------------------------------------------------------------------
  # * Frame Update
  #--------------------------------------------------------------------------
  def update
    last_real_x = @real_x
    last_real_y = @real_y
    last_moving = moving?
    move_by_input
    super
    update_scroll(last_real_x, last_real_y)
    update_vehicle
    update_nonmoving(last_moving) unless moving?
    @followers.update
  end

  #--------------------------------------------------------------------------
  # * Move to Designated Position
  #--------------------------------------------------------------------------
  def moveto(x, y)
    super
    center(x, y)
    make_encounter_count
    vehicle.refresh if vehicle
    @followers.synchronize(x, y, direction)
  end

  #--------------------------------------------------------------------------
  # * Get Screen X-Coordinates
  #--------------------------------------------------------------------------
  def screen_x
     Graphics.width / 2
  end
  #--------------------------------------------------------------------------
  # * Get Screen Y-Coordinates
  #--------------------------------------------------------------------------
  def screen_y
    Graphics.height / 2 + SPACE_BETWEEN_CHARACTERN_PATTERN - jump_height - TILE_HEIGHT_HALF
  end

  #--------------------------------------------------------------------------
  # * X Coordinate of Screen Center
  #--------------------------------------------------------------------------
  def center_x
    (Graphics.width / TILE_WIDTH_HALF - 1) / 2
  end

  #--------------------------------------------------------------------------
  # * Y Coordinate of Screen Center
  #--------------------------------------------------------------------------
  def center_y
    (Graphics.height / TILE_HEIGHT - 1) / 2
  end

  def center_screen_x
    Graphics.width / 2 
  end

  def center_screen_y
    Graphics.height / 2
  end


  #----------------------------------------------------------------------------------------------
  # * Set Map Display Position to Center of Screen
  #----------------------------------------------------------------------------------------------
  def center(x, y)

    # Get screen coordinates
    screen_x = (x - y) * TILE_WIDTH_HALF + (Graphics.width / 2)
    screen_y = (x + y) * TILE_HEIGHT_HALF + (Graphics.height / 2)

    # Calculate distance from center screen
    distance_from_center_x = screen_x - center_screen_x
    distance_from_center_y = screen_y - center_screen_y

    # Calculate parallax origin tile with new screen coordinates
    parallax_x = (distance_from_center_x / TILE_WIDTH_HALF + distance_from_center_y / TILE_HEIGHT_HALF) / 2
    parallax_y = (distance_from_center_y / TILE_HEIGHT_HALF - distance_from_center_x / TILE_WIDTH_HALF) / 2

    $game_map.set_display_pos(parallax_x, parallax_y)
  end

  #--------------------------------------------------------------------------
  # * Scroll Processing
  #--------------------------------------------------------------------------
  def update_scroll(last_real_x, last_real_y)
    $game_map.scroll_down (@real_y - last_real_y) if @real_y > last_real_y
    $game_map.scroll_left (last_real_x - @real_x) if @real_x < last_real_x
    $game_map.scroll_right(@real_x - last_real_x) if @real_x > last_real_x
    $game_map.scroll_up   (last_real_y - @real_y) if @real_y < last_real_y
  end
end

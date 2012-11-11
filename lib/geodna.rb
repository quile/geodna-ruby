
module GeoDNA
  extend self

  VERSION = '0.0.1'

  RADIUS_OF_EARTH = 6378100.0
  ALPHABET        = [ "g", "a", "t", "c" ]
  DECODE_MAP      = {
    "g" => 0,
    "a" => 1,
    "t" => 2,
    "c" => 3,
  }

  SQRT2 = Math.sqrt(2.0)

  class Point
    def initialize( *args )
      if args.length == 1
        self.init_with_code( args[0] )
      else
        self.init_with_coordinates( *args )
      end
    end

    def init_with_code( code )
      @point = code
      coords = GeoDNA.decode( @point )
      @lat = coords[0]
      @lon = coords[1]
      @options = {
        :radians => true,
        :precision => @point.length,
      }
    end

    def init_with_coordinates( *args )
      @lat = args[0]
      @lon = args[1]
      if args.length > 2
        @options = args[2]
      else
        @options = {
          :radians => true,
        }
      end
      @point = GeoDNA.encode( @lat, @lon, @options )
    end

    def to_s
      return @point
    end

    def coordinates
      # TODO:kd - maybe change this to return two values?
      return [ @lat, @lon ]
    end

    def add_vector( dy, dx )
      coords = GeoDNA.add_vector( @point, dy, dx )
      GeoDNA::Point.new( *coords )
    end

    def neighbours
      GeoDNA.neighbours( @point ).map { |p| Point.new( p ) }
    end

    def distance_in_km( geodna )
      GeoDNA.distance_in_km( @point, geodna.to_s )
    end

    def neighbours_within_radius( radius, options={} )
      GeoDNA.neighbours_within_radius( @point, radius ).map { |p| Point.new( p ) }
    end

    def reduced_neighbours_within_radius( radius, options={} )
      GeoDNA.reduce( GeoDNA.neighbours_within_radius( @point, radius ) ).map { |p| Point.new( p ) }
    end

    def contains( g )
      g.to_s.match( "^" + @point )
    end
  end

# Returns a GeoDNA code (which is a string) for latitude, longitude.
# Possible options are:
# * radians => true/false
#   A true value means the latitude and longitude are in radians
# * precision => Integer (defaults to 22)
#   number of characters in the GeoDNA code.
#   Note that any more than 22 chars and you're kinda splitting hairs.
#
# * *Args*    :
#   - +latitude, longitude, options+
# * *Returns* :
#   - +String GeoDNA code+ representing (latitude, longitude)
#

  def encode( latitude, longitude, options={} )
    precision = options['precision'] || 22
    radians   = options['radians']   || false

    geodna = ''
    loni = []
    lati = []

    if radians
      latitude  = rad2deg( latitude )
      longitude = rad2deg( longitude )
    end

    if longitude < 0.0
      geodna = geodna + 'w'
      loni = [ -180.0, 0.0 ]
    else
      geodna = geodna + 'e'
      loni = [ 0.0, 180.0 ]
    end

    lati = [ -90.0, 90.0 ]

    while geodna.length < precision
      ch = 0

      mid = ( loni[0] + loni[1] ) / 2.0
      if longitude > mid
        ch |= 2
        loni[0] = mid
      else
        loni[1] = mid
      end

      mid = ( lati[0] + lati[1] ) / 2.0
      if latitude > mid
        ch |= 1
        lati[0] = mid
      else
        lati[1] = mid
      end

      geodna = geodna + ALPHABET[ch]
    end

    return geodna
  end

# Returns an array [latitude, longitude] representing
# the centre of the bounding box of the GeoDNA code.
# Possible options are:
# * radians => true/false
#   A true value means the latitude and longitude returned
#   will be in radians (default: false)
#
# * *Args*    :
#   - +GeoDNA code+
# * *Returns* :
#   - +[latitude, longitude]+
#
  def decode( geodna, options={} )
    box = bounding_box( geodna )
    lati = box[0]
    loni = box[1]
    lat = ( lati[0] + lati[1] ) / 2.0
    lon = ( loni[0] + loni[1] ) / 2.0

    if options['radians']
      return [ deg2rad( lat ), deg2rad( lon ) ]
    end
    return [ lat, lon ]
  end

  def bounding_box( geodna )
    chars = geodna.split(//)

    loni = []
    lati = [ -90.0, 90.0 ]

    first = chars.shift
    if first == 'w'
      loni = [ -180.0, 0.0 ]
    elsif first == 'e'
      loni = [ 0.0, 180.0 ]
    end

    chars.each do |c|
      cd = DECODE_MAP[c]

      if !cd
        raise "Couldn't map #{c}"
      end

      if cd & 2 != 0
        loni = [ ( loni[0] + loni[1] ) / 2.0, loni[1] ]
      else
        loni = [ loni[0], ( loni[0] + loni[1] ) / 2.0 ]
      end
      if cd & 1 != 0
        lati = [ ( lati[0] + lati[1] ) / 2.0, lati[1] ]
      else
        lati = [ lati[0], ( lati[0] + lati[1] ) / 2.0 ]
      end
    end

    return [ lati, loni ]
  end

  def add_vector( geodna, dy, dx )
    point = decode( geodna )
    lat = point[0]
    lon = point[1]
    return [
      f_mod( ( lat + 90.0 + dy  ), 180.0 ) - 90.0,
      f_mod( ( lon + 180.0 + dx ), 360.0 ) - 180.0
    ]
  end

  def normalise( lat, lon )
    return [
      f_mod( ( lat + 90.0 ),  180.0 ) - 90.0,
      f_mod( ( lon + 180.0 ), 360.0 ) - 180.0
    ]
  end

# For a given GeoDNA code, returns an array of the eight neighbouring same-sized
# GeoDNA codes.
#
# * *Args*    :
#   - +GeoDNA code+
# * *Returns* :
#   - +[neigbouring codes]+
#
  def neighbours( geodna )
    box = bounding_box( geodna )
    lati = box[0]
    loni = box[1]

    width  = ( loni[1] - loni[0] ).abs
    height = ( lati[1] - lati[0] ).abs

    neighbours = []

    [ -1, 0, 1 ].each do |y|
      [ -1, 0, 1 ].each do |x|
        if x != 0 || y != 0
          centre = add_vector( geodna, height * y, width * x )
          neighbours.push( encode( *centre ) )
        end
      end
    end
    return neighbours
  end

  def point_from_point_bearing_and_distance( geodna, bearing, distance, options={} )
    distance = distance * 1000; # make it metres instead of kilometres
    precision = options['precision'] || geodna.length
    bits = decode( geodna, { "radians" => true } )
    lat1 = bits[0]
    lon1 = bits[1]
    lat2 = Math.asin( Math.sin( lat1 ) * Math.cos( distance / RADIUS_OF_EARTH ) +
                      Math.cos( lat1 ) * Math.sin( distance / RADIUS_OF_EARTH ) * Math.cos( bearing ) )
    lon2 = lon1 + Math.atan2( Math.sin( bearing ) * Math.sin( distance / RADIUS_OF_EARTH ) * Math.cos( lat1 ),
                      Math.cos( distance / RADIUS_OF_EARTH ) - Math.sin( lat1 ) * Math.sin( lat2 ))
    encode( lat2, lon2, { "precision" => precision, "radians" => true } )
  end

  def distance_in_km( ga, gb )
      a = decode( ga );
      b = decode( gb );

      # if a[1] and b[1] have different signs, we need to translate
      # everything a bit in order for the formulae to work.
      if a[1] * b[1] < 0.0 && ( a[1] - b[1] ).abs > 180.0
          a = add_vector( ga, 0.0, 180.0 )
          b = add_vector( gb, 0.0, 180.0 )
      end
      x = ( deg2rad(b[1]) - deg2rad(a[1]) ) * Math.cos( ( deg2rad(a[0]) + deg2rad(b[0])) / 2.0 )
      y = ( deg2rad(b[0]) - deg2rad(a[0]) )
      d = Math.sqrt( x*x + y*y ) * RADIUS_OF_EARTH
      return d / 1000.0
  end


# Returns a raw list of GeoDNA codes of a certain size contained within the
# radius (specified in kilometres) about the point represented by a
# code.
#
# The size of the returned codes will either be specified in options, or
# will be the default (12).
#
# * *Args*    :
#   - +GeoDNA code+
#   - +Radius (in km)+
#   - +Options+
# * *Returns* :
#   - +[neigbouring codes within radius]+def radius]+
#
  def neighbours_within_radius( geodna, radius, options={} )
      options['precision'] = options['precision'] || 12

      neighbours = []
      rh = radius * SQRT2

      startp = point_from_point_bearing_and_distance( geodna, -( Math::PI / 4 ), rh, options )
        endp = point_from_point_bearing_and_distance( geodna, Math::PI / 4, rh, options )

      bbox = bounding_box( startp )
      bits = decode( startp )
      slon = bits[1]
      bits = decode( endp )
      elon = bits[1]
      dheight = ( bbox[0][1] - bbox[0][0] ).abs
      dwidth  = ( bbox[1][1] - bbox[1][0] ).abs

      n = normalise( 0.0, ( elon - slon ).abs )

      delta = n[1].abs
      tlat = 0.0
      tlon = 0.0
      current = startp

      while tlat <= delta do
          while tlon <= delta do
              cbits = add_vector( current, 0.0, dwidth )
              current = encode( cbits[0], cbits[1], options )
              d = distance_in_km( current, geodna )
              if d <= radius
                  neighbours.push( current )
              end
              tlon = tlon + dwidth
          end

          tlat = tlat + dheight
          bits = add_vector( startp, -tlat , 0.0 )
          current = encode( bits[0], bits[1], options )
          tlon = 0.0
      end

      return neighbours
  end

# This takes an array of GeoDNA codes and reduces it to its
# minimal set of codes covering the same area.
# Needs a more optimal impl.
#
# * *Args*    :
#   - +[GeoDNA codes]+
# * *Returns* :
#   - +[Minimal covering set]+
  def reduce( geodna_codes )
      # hash all the codes
      codes = {}
      geodna_codes.each do |code|
        codes[code] = 1
      end

      reduced = []

      geodna_codes.each do |code|
        if codes.has_key?( code )
          parent = code[ 0, code.length - 1 ]

            if codes.has_key?( parent + 'a' ) && codes.has_key?( parent + 't' ) && codes.has_key?( parent + 'g' ) && codes.has_key?( parent + 'c' )
                codes.delete( parent + 'a' )
                codes.delete( parent + 't' )
                codes.delete( parent + 'g' )
                codes.delete( parent + 'c' )
                reduced.push( parent )
          else
              reduced.push( code )
          end
        end
      end
      if geodna_codes.length == reduced.length
          return reduced
      end
      return reduce( reduced )
  end


  #-----------------------------------------------

  private

  def f_mod( x, m )
    return ( x % m + m ) % m;
  end

  def deg2rad(d)
      ( d / 180.0 ) * Math::PI
  end

  def rad2deg(r)
      ( r / Math::PI ) * 180
  end

end
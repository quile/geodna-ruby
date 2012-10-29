module GeoDNA
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

  def GeoDNA.f_mod( x, m )
    # floating point modulus
    return ( x % m + m ) % m;
  end

  def GeoDNA.deg2rad(d)
      ( d / 180.0 ) * Math::PI
  end

  def GeoDNA.rad2deg(r)
      ( r / Math::PI ) * 180
  end

  def GeoDNA.encode( latitude, longitude, options={} )
    precision = options['precision'] || 22
    radians   = options['radians']   || false

    geodna = ''
    loni = []
    lati = []

    if radians
      latitude  = GeoDNA.rad2deg( latitude )
      longitude = GeoDNA.rad2deg( longitude )
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

  def GeoDNA.decode( geodna, options={} )
    box = bounding_box( geodna )
    lati = box[0]
    loni = box[1]
    lat = ( lati[0] + lati[1] ) / 2.0
    lon = ( loni[0] + loni[1] ) / 2.0

    if options['radians']
      return [ GeoDNA.deg2rad( lat ), GeoDNA.deg2rad( lon ) ]
    end
    return [ lat, lon ]
  end

  #  # locates the min/max lat/lons around the geo_dna

  def GeoDNA.bounding_box( geodna )
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

      #puts "char is #{c}, map is #{cd}, loni is #{loni}, lati is #{lati}"

    end

    return [ lati, loni ]
  end

  def GeoDNA.add_vector( geodna, dy, dx )
    point = decode( geodna )
    lat = point[0]
    lon = point[1]
    return [
      f_mod( ( lat + 90.0 + dy  ), 180.0 ) - 90.0,
      f_mod( ( lon + 180.0 + dx ), 360.0 ) - 180.0
    ]
  end

  def GeoDNA.normalise( lat, lon )
    return [
      f_mod( ( lat + 90.0 ),  180.0 ) - 90.0,
      f_mod( ( lon + 180.0 ), 360.0 ) - 180.0
    ]
  end

  def GeoDNA.neighbours( geodna )
    box = bounding_box( geodna )
    lati = box[0]
    loni = box[1]

    width  = ( loni[1] - loni[0] ).abs
    height = ( lati[1] - lati[0] ).abs

    neighbours = []

    [ -1, 0, 1 ].each do |y|
      [ -1, 0, 1 ].each do |x|
        if x != 0 || y != 0
          centre = GeoDNA.add_vector( geodna, height * y, width * x )
          neighbours.push( GeoDNA.encode( *centre ) )
        end
      end
    end
    return neighbours
  end

  def GeoDNA.point_from_point_bearing_and_distance( geodna, bearing, distance, options={} )
    distance = distance * 1000; # make it metres instead of kilometres
    precision = options['precision'] || geodna.length
    bits = GeoDNA.decode( geodna, { "radians" => true } )
    lat1 = bits[0]
    lon1 = bits[1]
    lat2 = Math.asin( Math.sin( lat1 ) * Math.cos( distance / RADIUS_OF_EARTH ) +
                      Math.cos( lat1 ) * Math.sin( distance / RADIUS_OF_EARTH ) * Math.cos( bearing ) )
    lon2 = lon1 + Math.atan2( Math.sin( bearing ) * Math.sin( distance / RADIUS_OF_EARTH ) * Math.cos( lat1 ),
                      Math.cos( distance / RADIUS_OF_EARTH ) - Math.sin( lat1 ) * Math.sin( lat2 ))
    GeoDNA.encode( lat2, lon2, { "precision" => precision, "radians" => true } )
  end

  def GeoDNA.distance_in_km( ga, gb )
      a = GeoDNA.decode( ga );
      b = GeoDNA.decode( gb );

      # if a[1] and b[1] have different signs, we need to translate
      # everything a bit in order for the formulae to work.
      if a[1] * b[1] < 0.0 && Math.abs( a[1] - b[1] ) > 180.0
          a = GeoDNA.add_vector( ga, 0.0, 180.0 )
          b = GeoDNA.add_vector( gb, 0.0, 180.0 )
      end
      x = ( GeoDNA.deg2rad(b[1]) - GeoDNA.deg2rad(a[1]) ) * Math.cos( ( GeoDNA.deg2rad(a[0]) + GeoDNA.deg2rad(b[0])) / 2.0 )
      y = ( GeoDNA.deg2rad(b[0]) - GeoDNA.deg2rad(a[0]) )
      d = Math.sqrt( x*x + y*y ) * RADIUS_OF_EARTH
      return d / 1000.0
  end

  def GeoDNA.neighbours_within_radius( geodna, radius, options={} )
      options['precision'] = options['precision'] || 12

      neighbours = []
      rh = radius * SQRT2

      startp = GeoDNA.point_from_point_bearing_and_distance( geodna, -( Math::PI / 4 ), rh, options )
        endp = GeoDNA.point_from_point_bearing_and_distance( geodna, Math::PI / 4, rh, options )

      bbox = GeoDNA.bounding_box( startp )
      bits = GeoDNA.decode( startp )
      slon = bits[1]
      bits = GeoDNA.decode( endp )
      elon = bits[1]
      dheight = ( bbox[0][1] - bbox[0][0] ).abs
      dwidth  = ( bbox[1][1] - bbox[1][0] ).abs

      n = GeoDNA.normalise( 0.0, ( elon - slon ).abs )

      delta = n[1].abs
      tlat = 0.0
      tlon = 0.0
      current = startp

      #puts "elon: " + elon.to_s, "slon: " + slon.to_s, "n: " + n.to_s, "rh: " + rh.to_s
      #puts "start: " + startp, "end: " + endp

      while tlat <= delta do
          while tlon <= delta do
              cbits = GeoDNA.add_vector( current, 0.0, dwidth )
              current = GeoDNA.encode( cbits[0], cbits[1], options )
              d = GeoDNA.distance_in_km( current, geodna )
              if d <= radius
                  neighbours.push( current )
              end
              tlon = tlon + dwidth
          end

          tlat = tlat + dheight
          bits = GeoDNA.add_vector( startp, -tlat , 0.0 )
          current = GeoDNA.encode( bits[0], bits[1], options )
          tlon = 0.0
      end

      return neighbours
  end

  #  # This takes an array of GeoDNA codes and reduces it to its
  #  # minimal set of codes covering the same area.
  #  # Needs a more optimal impl.
  def GeoDNA.reduce( geodna_codes )
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
      return GeoDNA.reduce( reduced )
  end

end
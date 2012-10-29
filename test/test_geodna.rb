require 'geodna'
require 'test/unit'

class GeoDNATest < Test::Unit::TestCase

  def test_must_encode_correctly
    wellington = GeoDNA.encode( -41.288889, 174.777222, { "precision" => 22 } )
    assert_equal wellington, "etctttagatagtgacagtcta", "Encoded Wellington correctly"

    nelson = GeoDNA.encode( -41.283333, 173.283333, { "precision" => 16 } )
    assert_equal nelson, 'etcttgctagcttagt', "Encode Nelson correctly"

    somewhere = GeoDNA.encode( 7.0625, -95.677068 )
    assert_equal somewhere, 'watttatcttttgctacgaagt', "Encoded somewhere else"
  end

  def test_must_decode_correctly
    point = GeoDNA.decode( "etctttagatagtgacagtcta" )
    assert_in_delta( point[0], -41.288889, 0.005 )
    assert_in_delta( point[1], 174.777222, 0.005 )

    point = GeoDNA.decode( "etcttgctagcttagt" )
    assert_in_delta( point[0], -41.283333, 0.005 )
    assert_in_delta( point[1],  173.283333, 0.005 )
  end

  def test_add_vector
    # This add_vector crosses the 180.0 line:
    wellington = GeoDNA.encode( -41.288889, 174.777222, { "precision" => 22 } )
    point = GeoDNA.add_vector( wellington, 10.0, 10.0 )
    assert_in_delta( point[0], -31.288889, 0.005 )
    assert_in_delta( point[1], -175.222777, 0.005 )
  end

  def test_neighbours
    neighbours = GeoDNA.neighbours( 'etctttagatag' )
    assert_equal neighbours.length, 8
    # TODO:kd - check actual neighbour codes
  end


  def test_bounding_box
    box = GeoDNA.bounding_box( 'etctttagatag' )
    assert_equal box,  [
      [ -41.30859375, -41.220703125 ],
      [ 174.7265625, 174.814453125 ]
    ]
  end

  def test_distance
    wellington = GeoDNA.encode( -41.288889, 174.777222, { "precision" => 22 } )
    nelson = GeoDNA.encode( -41.283333, 173.283333, { "precision" => 16 } )

    distance = GeoDNA.distance_in_km( wellington, nelson )

    assert distance > 120.0 && distance < 140.0, "Nelson is about 130km from Wellington"
  end

  def test_reduce
    wellington = GeoDNA.encode( -41.288889, 174.777222, { "precision" => 22 } )
    nelson = GeoDNA.encode( -41.283333, 173.283333, { "precision" => 16 } )

    neighbours = GeoDNA.neighbours_within_radius( nelson, 140.0, { "precision" => 11 } )
    reduced = GeoDNA.reduce( neighbours )

    found = ( reduced.collect { |g| wellington.match("^" + g) }.length > 0 )
    assert found, "Found Wellington in proximity to Nelson."

    vienna = GeoDNA.encode( 48.208889, 16.3725, { "precision" => 22 } )
    found = ( reduced.select { |g| vienna.match("^" + g) }.length > 0 )
    assert !found, "Didn't find Vienna anywhere near Nelson."
  end
end

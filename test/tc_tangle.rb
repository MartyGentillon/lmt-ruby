require 'test/unit'
require 'lmt/lmt'

class TestTangler < Test::Unit::TestCase
  def test_self_tangle
    Lmt::Tangle.self_test()
    tangler = Lmt::Tangle::Tangler.new("src/lmt/lmt.rb.lmd")
    tangler.tangle
  end
end

require 'test/unit'
require 'lastpass'
require_relative 'helper'

class FetcherTest < Test::Unit::TestCase
    def test_make_key
        keys = {
            1 => 'C/Bh2SGWxI8JDu54DbbpV8J9wa6pKbesIb9MAXkeF3Y='.decode64,
            5 => 'pE9goazSCRqnWwcixWM4NHJjWMvB5T15dMhe6ug1pZg='.decode64,
            10 => 'n9S0SyJdrMegeBHtkxUx8Lzc7wI6aGl+y3/udGmVey8='.decode64,
            50 => 'GwI8/kNy1NjIfe3Z0VAZfF78938UVuCi6xAL3MJBux0='.decode64,
            100 => 'piGdSULeHMWiBS3QJNM46M5PIYwQXA6cNS10pLB3Xf8='.decode64,
            500 => 'OfOUvVnQzB4v49sNh4+PdwIFb9Fr5+jVfWRTf+E2Ghg='.decode64,
            1000 => 'z7CdwlIkbu0XvcB7oQIpnlqwNGemdrGTBmDKnL9taPg='.decode64
        }

        keys.each do |iterations, key|
            assert_equal key, LastPass::Fetcher.make_key('postlass@gmail.com', 'pl1234567890', iterations)
        end
    end

    def test_make_hash
        hashes = {
            1 => 'a1943cfbb75e37b129bbf78b9baeab4ae6dd08225776397f66b8e0c7a913a055',
            5 => 'a95849e029a7791cfc4503eed9ec96ab8675c4a7c4e82b00553ddd179b3d8445',
            10 => '0da0b44f5e6b7306f14e92de6d629446370d05afeb1dc07cfcbe25f169170c16',
            50 => '1d5bc0d636da4ad469cefe56c42c2ff71589facb9c83f08fcf7711a7891cc159',
            100 => '82fc12024acb618878ba231a9948c49c6f46e30b5a09c11d87f6d3338babacb5',
            500 => '3139861ae962801b59fc41ff7eeb11f84ca56d810ab490f0d8c89d9d9ab07aa6',
            1000 => '03161354566c396fcd624a424164160e890e96b4b5fa6d942fc6377ab613513b',
        }

        hashes.each do |iterations, hash|
            assert_equal hash, LastPass::Fetcher.make_hash('postlass@gmail.com', 'pl1234567890', iterations)
        end
    end

    # This is a slow test that goes on the internets to fetch some data from LastPass.
    # Disabled by default.  To enable, remove the leading underscore.
    def _test_fetch
        fetcher = LastPass::Fetcher.fetch 'postlass@gmail.com', 'pl1234567890'
        assert_equal 'OfOUvVnQzB4v49sNh4+PdwIFb9Fr5+jVfWRTf+E2Ghg='.decode64, fetcher.encryption_key
        assert_equal 500, fetcher.iterations
        assert_match /^TFBB/, fetcher.blob
    end
end

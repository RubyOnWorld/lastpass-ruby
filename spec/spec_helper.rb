# Copyright (C) 2013 Dmitry Yakimenko (detunized@gmail.com).
# Licensed under the terms of the MIT license. See LICENCE for details.

# Only calculate test coverage on TravisCI
if ENV["CI"] == "true" && ENV["TRAVIS"] == "true"
    require "coveralls"
    Coveralls.wear!
end

require "base64"
require "lastpass"
require "rspec/its"

class String
    def decode64
        Base64.decode64 self
    end

    def decode_hex
        scan(/../).map { |i| i.to_i 16 }.pack "c*"
    end
end

module LastPass
    class Session
        def == other
            id == other.id && key_iteration_count == other.key_iteration_count
        end
    end

    class Blob
        def == other
            bytes == other.bytes && key_iteration_count == other.key_iteration_count
        end
    end

    class Chunk
        def == other
            id == other.id && payload == other.payload
        end
    end
end

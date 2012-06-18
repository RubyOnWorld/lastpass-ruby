require "base64"
require "stringio"

module LastPass
    class Parser
        class << self
            def parse blob
                parser = Parser.new blob
                parser.send :parse # to avoid exposing the private 'parse' method

                parser
            end
        end

        private

        def initialize blob
            @blob = blob
        end

        def parse
            decode_blob @blob
        end

        def decode_blob blob
            if not String === blob
                raise ArgumentError, 'Blob should be a string'
            end

            if blob[0, 4] != 'TFBB'
                raise ArgumentError, 'Blob doesn\'t seem to be base64 encoded'
            end

            decode_base64 blob
        end

        #
        # IO
        #

        def read_chunk stream
            # LastPass blob chunk is made up of 4-byte ID, 4-byte size and payload of that size
            # Example:
            #   0000: 'IDID'
            #   0004: 4
            #   0008: 0xDE 0xAD 0xBE 0xEF
            #   000C: --- Next chunk ---
            id = stream.read 4
            size = read_uint32 stream
            payload = stream.read size

            {:id => id, :size => size, :payload => payload}
        end

        def read_uint32 stream
            stream.read(4).unpack('N').first
        end

        #
        # Decoders
        #

        def decode_base64 data
            Base64.decode64 data
        end
    end
end

# Copyright (C) 2013 Dmitry Yakimenko (detunized@gmail.com).
# Licensed under the terms of the MIT license. See LICENCE for details.

require "base64"
require "openssl"
require "stringio"

require_relative "chunk"

module LastPass
    class Parser
        def self.extract_chunks blob
            chunks = Hash.new { |hash, key| hash[key] = [] }

            StringIO.open blob.bytes do |stream|
                while !stream.eof?
                    chunk = read_chunk stream
                    chunks[chunk.id] << chunk
                end
            end

            chunks
        end

        def self.parse_account chunk
            StringIO.open chunk.payload do |io|
                id = read_item io
                name = read_item io
                group = read_item io
                url = decode_hex read_item io
                skip_item io
                skip_item io
                skip_item io
                username = read_item io
                password = read_item io

                Account.new id, name, username, password, url, group
            end
        end

        def self.read_chunk stream
            # LastPass blob chunk is made up of 4-byte ID,
            # big endian 4-byte size and payload of that size.
            #
            # Example:
            #   0000: 'IDID'
            #   0004: 4
            #   0008: 0xDE 0xAD 0xBE 0xEF
            #   000C: --- Next chunk ---

            Chunk.new read_id(stream), read_payload(stream, read_size(stream))
        end

        def self.read_item stream
            # An item in an itemized chunk is made up of the
            # big endian size and the payload of that size.
            #
            # Example:
            #   0000: 4
            #   0004: 0xDE 0xAD 0xBE 0xEF
            #   0008: --- Next item ---

            read_payload stream, read_size(stream)
        end

        def self.skip_item stream
            read_item stream
        end

        def self.read_id stream
            stream.read 4
        end

        def self.read_size stream
            read_uint32 stream
        end

        def self.read_payload stream, size
            stream.read size
        end

        def self.read_uint32 stream
            stream.read(4).unpack('N').first
        end

        def self.decode_hex data
            # TODO: Check for input validity
            data.scan(/../).map { |i| i.to_i 16 }.pack "c*"
        end

        #
        # To be killed
        #

        def parse_chunks raw_chunks
            parsed_chunks = {}

            raw_chunks.each do |id, chunks|
                parse_method = "parse_chunk_#{id}"
                if respond_to? parse_method, true
                    parsed_chunks[id] = chunks.map do |chunk|
                        StringIO.open chunk do |stream|
                            send parse_method, stream
                        end
                    end
                end
            end

            parsed_chunks
        end

        def read_item stream
            # An item in an itemized chunk is made up of a size and the payload
            # Example:
            #   0000: 4
            #   0004: 0xDE 0xAD 0xBE 0xEF
            #   0008: --- Next item ---
            size = read_uint32 stream
            payload = stream.read size

            {:size => size, :payload => payload}
        end

        def read_uint32 stream
            stream.read(4).unpack('N').first
        end

        #
        # Decoders
        #

        # Allowed encodings:
        #  - nil or :plain
        #  - :base64
        def decode data, encoding = nil
            if encoding.nil? || encoding == :plain
                data
            else
                send "decode_#{encoding}", data
            end
        end

        def decode_base64 data
            # TODO: Check for input validity
            Base64.decode64 data
        end

        # Guesses AES encoding/cipher from the length of the data.
        def decode_aes256 data
            length = data.length
            length16 = length % 16
            length64 = length % 64

            if length == 0
                ''
            elsif length16 == 0
                decode_aes256_ecb_plain data
            elsif length64 == 0 || length64 == 24 || length64 == 44
                decode_aes256_ecb_base64 data
            elsif length16 == 1
                decode_aes256_cbc_plain data
            elsif length64 == 6 || length64 == 26 || length64 == 50
                decode_aes256_cbc_base64 data
            else
                raise RuntimeError, "'#{data.inspect}' doesn't seem to be AES-256 encrypted"
            end
        end

        def decode_aes256_ecb_plain data
            if data.empty?
                ''
            else
                _decode_aes256 :ecb, '', data
            end
        end

        def decode_aes256_ecb_base64 data
            decode_aes256_ecb_plain decode_base64 data
        end

        # LastPass AES-256/CBC encryted string starts with '!'.
        # Next 16 bytes are the IV for the cipher.
        # And the rest is the encrypted payload.
        def decode_aes256_cbc_plain data
            if data.empty?
                ''
            else
                # TODO: Check for input validity!
                _decode_aes256 :cbc, data[1, 16], data[17..-1]
            end
        end

        # LastPass AES-256/CBC/base64 encryted string starts with '!'.
        # Next 24 bytes are the base64 encoded IV for the cipher.
        # Then comes the '|'.
        # And the rest is the base64 encoded encrypted payload.
        def decode_aes256_cbc_base64 data
            if data.empty?
                ''
            else
                # TODO: Check for input validity!
                _decode_aes256 :cbc, decode_base64(data[1, 24]), decode_base64(data[26..-1])
            end
        end

        # Hidden, so it's not discoverable as 'decode_*'.
        # Allowed ciphers are :ecb and :cbc.
        # If for :ecb iv is not used and should be set to ''.
        def _decode_aes256 cipher, iv, data
            aes = OpenSSL::Cipher::Cipher.new "aes-256-#{cipher}"
            aes.decrypt
            aes.key = @encryption_key
            aes.iv = iv
            aes.update(data) + aes.final
        end

        #
        # Parsing
        #

        # Generic itemized chunk parser.  Info parameter should look like this:
        # [
        #   {:name => 'item_name1'},
        #   {:name => 'item_name2', :encoding => :hex},
        #   {:name => 'item_name3', :encoding => :aes256}
        # ]
        def parse_itemized_chunk stream, info
            chunk = {}

            info.each do |item_info|
                chunk[item_info[:name]] = parse_item stream, item_info[:encoding]
            end

            chunk
        end

        # Itemized chunk item parser. For the list of allowed encodings see 'decode'.
        # Returns decoded payload.
        def parse_item stream, encoding = nil
            decode read_item(stream)[:payload], encoding
        end

        #
        # Chunk parsers
        #

        # 'LPAV' chunk seems to be storing some kind of version information
        def parse_chunk_LPAV stream
            stream.read
        end

        # 'ENCU' chunk contains encrypted user name
        def parse_chunk_ENCU stream
            decode_aes256 stream.read
        end

        # 'NMAC' chunk contains number of accounts
        def parse_chunk_NMAC stream
            stream.read
        end

        # 'ACCT' chunk contains account information
        def parse_chunk_ACCT stream
            parse_itemized_chunk stream, [
                {:name => :id},
                {:name => :name, :encoding => :aes256},
                {:name => :group, :encoding => :aes256},
                {:name => :url, :encoding => :hex},
                {:name => :extra},
                {:name => :favorite},
                {:name => :shared_from_id},
                {:name => :username, :encoding => :aes256},
                {:name => :password, :encoding => :aes256},
                {:name => :password_protected},
                {:name => :generated_password},
                {:name => :sn}, # ?
                {:name => :last_touched},
                {:name => :auto_login},
                {:name => :never_autofill},
                {:name => :realm_data},
                {:name => :fiid}, # ?
                {:name => :custom_js},
                {:name => :submit_id},
                {:name => :captcha_id},
                {:name => :urid}, # ?
                {:name => :basic_authorization},
                {:name => :method},
                {:name => :action, :encoding => :hex},
                {:name => :group_id},
                {:name => :deleted},
                {:name => :attach_key},
                {:name => :attach_present},
                {:name => :individual_share},
                {:name => :unknown1}
            ]
        end

        # 'EQDN' chunk contains information about equivalent domains
        def parse_chunk_EQDN stream
            parse_itemized_chunk stream, [
                {:name => :id},
                {:name => :domain, :encoding => :hex}
            ]
        end
    end
end

# Copyright (C) 2013 Dmitry Yakimenko (detunized@gmail.com).
# Licensed under the terms of the MIT license. See LICENCE for details.

require "pbkdf2"
require "httparty"

require_relative "exceptions"
require_relative "session"
require_relative "blob"

module LastPass
    class Fetcher
        def self.login username, password
            key_iteration_count = request_iteration_count username
            request_login username, password, key_iteration_count
        end

        def self.fetch session, web_client = HTTParty
            response = web_client.get "https://lastpass.com/getaccts.php?mobile=1&b64=1&hash=0.0",
                                      format: :plain,
                                      cookies: {"PHPSESSID" => URI.encode(session.id)}

            raise NetworkError unless response.response.is_a? Net::HTTPOK
            response.parsed_response
        end

        def self.request_iteration_count username, web_client = HTTParty
            response = web_client.post "https://lastpass.com/iterations.php",
                                       query: {email: username}

            raise NetworkError unless response.response.is_a? Net::HTTPOK

            begin
                count = Integer response.parsed_response
            rescue ArgumentError
                raise InvalidResponse, "Key iteration count is invalid"
            end

            raise InvalidResponse, "Key iteration count is not positive" unless count > 0

            count
        end

        def self.request_login username, password, key_iteration_count, web_client = HTTParty
            response = web_client.post "https://lastpass.com/login.php",
                                       format: :xml,
                                       body: {
                                           method: "mobile",
                                           web: 1,
                                           xml: 1,
                                           username: username,
                                           hash: make_hash(username, password, key_iteration_count),
                                           iterations: key_iteration_count
                                       }

            raise NetworkError unless response.response.is_a? Net::HTTPOK

            parsed_response = response.parsed_response
            raise InvalidResponse unless parsed_response.is_a? Hash

            create_session parsed_response, key_iteration_count or
                raise login_error parsed_response
        end

        def self.create_session parsed_response, key_iteration_count
            ok = parsed_response["ok"]
            if ok.is_a? Hash
                session_id = ok["sessionid"]
                if session_id.is_a? String
                    return Session.new session_id, key_iteration_count
                end
            end

            nil
        end

        def self.login_error parsed_response
            error = (parsed_response["response"] || {})["error"]
            return UnknownResponseSchema unless error.is_a? Hash

            exceptions = {
                "unknownemail" => LastPassUnknownUsername,
                "unknownpassword" => LastPassInvalidPassword,
            }

            cause = error["cause"]
            message = error["message"]

            if cause
                (exceptions[cause] || LastPassUnknownError).new message || cause
            else
                InvalidResponse.new message
            end
        end

        def self.make_key username, password, key_iteration_count
            if key_iteration_count == 1
                Digest::SHA256.digest username + password
            else
                PBKDF2
                    .new(password: password,
                         salt: username,
                         iterations: key_iteration_count,
                         key_length: 32)
                    .bin_string
                    .force_encoding "BINARY"
            end
        end

        def self.make_hash username, password, key_iteration_count
            if key_iteration_count == 1
                Digest::SHA256.hexdigest Digest.hexencode(make_key(username, password, 1)) + password
            else
                PBKDF2
                    .new(password: make_key(username, password, key_iteration_count),
                         salt: password,
                         iterations: 1,
                         key_length: 32)
                    .hex_string
            end
        end

        # Can't instantiate Fetcher
        private_class_method :new
    end
end

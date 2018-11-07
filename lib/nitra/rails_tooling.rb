module Nitra
  class RailsTooling
    ##
    # Find the database config for the current TEST_ENV_NUMBER and manually initialise a connection.
    #
    def self.connect_to_database
      return unless defined?(Rails)

      disconnect_from_database

      # Config files are read at load time. Since we load rails in one env then
      # change some flags to get different environments through forking we need
      # always reload our database config...
      ActiveRecord::Base.configurations = YAML.load(ERB.new(IO.read("#{Rails.root}/config/database.yml")).result)
      ActiveRecord::Base.default_connection_handler = ActiveRecord::ConnectionAdapters::ConnectionHandler.new if ActiveRecord::Base.respond_to?(:default_connection_handler)
      ActiveRecord::Base.establish_connection
    end

    def self.disconnect_from_database
      return unless defined?(Rails)
      ActiveRecord::Base.clear_all_connections!
    end
    
    def self.reset_cache
      return unless defined?(Rails)
      Rails.cache.reset if Rails.cache.respond_to?(:reset)
    end
  end
end

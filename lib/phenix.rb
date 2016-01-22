require 'phenix/version'
require 'erb'

module Phenix
  class << self
    attr_accessor :database_config_path, :schema_config_path
    attr_accessor :current_configuration

    def configure
      self.database_config_path = File.join(Bundler.root, 'test', 'database.yml')
      self.schema_config_path   = File.join(Bundler.root, 'test', 'schema.rb')

      yield(self) if block_given?
    end
  end

  def load_database_config(config_path = Phenix.database_config_path)
    config_content = IO.read(config_path)
    config_content = ERB.new(config_content).result
    ActiveRecord::Base.configurations = Phenix.current_configuration = YAML.load(config_content)
  end

  def create_databases
    for_each_database do |name, conf|
      run_mysql_command(conf, "CREATE DATABASE #{conf['database']}")
      ActiveRecord::Base.establish_connection(name.to_sym)
      yield if block_given?
    end
  end

  def create_and_populate_databases
    create_databases do
      ActiveRecord::Migration.verbose = false
      load(Phenix.schema_config_path)
      yield if block_given?
    end
  end

  def drop_databases
    for_each_database do |name, conf|
      run_mysql_command(conf, "DROP DATABASE IF EXISTS #{conf['database']}")
    end
  end

  private

  def for_each_database
    Phenix.current_configuration.each do |name, conf|
      next if conf['database'].nil?
      next if respond_to?(:skip_database?) && skip_database?(name, conf)
      yield(name, conf)
    end
  end

  def run_mysql_command(conf, command)
    @mysql_command ||= begin
      commands = [
        'mysql',
        "--user=#{conf['username']}"
      ]
      commands << "--host=#{conf['host']}" if conf['host'].present?
      commands << "--port=#{conf['port']}" if conf['port'].present?
      commands << " --password=#{conf['password']} 2> /dev/null" if conf['password'].present?
      commands.join(' ')
    end
    `echo "#{command}" | #{@mysql_command}`
  end
end

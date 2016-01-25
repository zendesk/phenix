require 'phenix/version'
require 'erb'

module Phenix
  class << self
    attr_accessor :database_config_path, :schema_path, :skip_database
    attr_accessor :current_configuration

    def configure
      self.database_config_path = File.join(Dir.pwd, 'test', 'database.yml')
      self.schema_path          = File.join(Dir.pwd, 'test', 'schema.rb')
      self.skip_database        = ->(_, _) { false }

      yield(self) if block_given?
    end
  end

  def rise!(with_schema: true, config_path: Phenix.database_config_path)
    load_database_config(config_path)
    drop_databases
    with_schema ? create_and_populate_databases : create_databases
  end

  def burn!
    drop_databases
  end

  def load_database_config(config_path = Phenix.database_config_path)
    erb_config = IO.read(config_path)
    yaml_config = ERB.new(erb_config).result
    ActiveRecord::Base.configurations = Phenix.current_configuration = YAML.load(yaml_config)
  end

  private

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
      load(Phenix.schema_path)
      yield if block_given?
    end
  end

  def drop_databases
    for_each_database do |name, conf|
      run_mysql_command(conf, "DROP DATABASE IF EXISTS #{conf['database']}")
    end
  end

  def for_each_database
    Phenix.current_configuration.each do |name, conf|
      next if conf['database'].nil?
      next if Phenix.skip_database.call(name, conf)
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

  extend self
end

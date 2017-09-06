# frozen_string_literal: true
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
    create_databases(with_schema)
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

  def create_databases(with_schema)
    for_each_database do |name, conf|
      run_mysql_command(conf, "CREATE DATABASE IF NOT EXISTS #{conf['database']}")
      ActiveRecord::Base.establish_connection(name.to_sym)
      populate_database if with_schema
    end
  end

  def populate_database
    ActiveRecord::Migration.verbose = false
    load(Phenix.schema_path)
  end

  def drop_databases
    for_each_database do |name, conf|
      run_mysql_command(conf, "DROP DATABASE IF EXISTS #{conf['database']}")
    end
  end

  def for_each_database
    ActiveRecord::Base.configurations.each do |name, conf|
      next if conf['database'].nil?
      next if Phenix.skip_database.call(name, conf)
      yield(name, conf)
    end
  end

  def run_mysql_command(conf, execute)
    command = ['mysql']
    command << "--user" << conf['username'].to_s if conf['username'].present?
    command << "--host" << conf['host'].to_s if conf['host'].present?
    command << "--port" << conf['port'].to_s if conf['port'].present?
    command << "--password" << conf['password'].to_s if conf['password'].present?
    command << "--execute"
    command << execute

    pio = IO.popen(command, err: '/dev/null')
    result = pio.read
    pio.close
    raise "Failed to execute #{execute}" unless $?.success?
    result
  end

  extend self
end

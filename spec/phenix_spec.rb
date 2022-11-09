# frozen_string_literal: true

require 'spec_helper'
require 'active_record'
require 'tmpdir'

SingleCov.covered! uncovered: (ActiveRecord::VERSION::STRING < '6.1' ? 2 : 3)

describe Phenix do
  include Phenix

  def with_bad_mysql
    Dir.mktmpdir do |dir|
      file = "#{dir}/mysql"
      File.write(file, "nope")
      File.chmod 0777, file
      begin
        old = ENV['PATH']
        ENV['PATH'] = "#{dir}:#{ENV['PATH']}"
        yield
      ensure
        ENV['PATH'] = old
      end
    end
  end

  let(:test_directory) { File.join(File.dirname(__FILE__), '..', 'test') }

  let(:simple_database_path)  { File.join(test_directory, 'simple_database.yml') }
  let(:complex_database_path) { File.join(test_directory, 'complex_database.yml') }
  let(:three_tier_database_path) { File.join(test_directory, 'three_tier_database.yml') }

  let(:exists_method)  { (ActiveRecord::VERSION::MAJOR < 5 ? :table_exists? : :data_source_exists?) }

  before { Phenix.configure }

  it 'has a version number' do
    expect(Phenix::VERSION).not_to be nil
  end

  describe :configure do
    it 'sets default values' do
      expect(Phenix.database_config_path).to match(%r{/test/database.yml})
      expect(Phenix.schema_path)         .to match(%r{/test/schema.rb})
    end

    it 'allows a block to configure' do
      Phenix.configure do |config|
        config.database_config_path = 'my/path/database.yml'
        config.schema_path          = 'my/path/schema.rb'
      end

      expect(Phenix.database_config_path).to eq('my/path/database.yml')
      expect(Phenix.schema_path)         .to eq('my/path/schema.rb')
    end

    if ActiveRecord::VERSION::STRING >= '6.1'
      describe :three_tier_database_configs do
        describe :parse_configuration_hashes do
          it 'creates configuration_hashes for each database' do
            load_database_config(three_tier_database_path)

            expect(Phenix.send(:parse_configuration_hashes).length).to eq(ActiveRecord::Base.configurations.configurations.length)
          end
        end
      end
    end
  end

  describe :load_database_config do
    it 'returns the database configuration past as parameter' do
      result = load_database_config(simple_database_path)

      expect(result.keys).to eq(%w(development))
      expect(result['development']['database']).to eq('phenix_database_1')
    end

    it 'returns the database configuration set in the configure block' do
      Phenix.configure { |config| config.database_config_path = simple_database_path }

      result = load_database_config

      expect(result.keys).to eq(%w(development))
      expect(result['development']['database']).to eq('phenix_database_1')
    end

    it 'handles complex configurations' do
      result = load_database_config(complex_database_path)

      expect(result.keys).to eq(%w(mysql database2 database3))

      expect(result['database2']['database']).to eq('phenix_database_2')
      expect(result['database2']['encoding']).to eq('utf8')
      expect(result['database3']['adapter']) .to eq('mysql2')
    end
  end

  describe :create_databases do
    describe :without_schema do
      before do
        load_database_config(complex_database_path)
      end

      after do
        drop_databases
      end

      it 'creates the databases' do
        ActiveRecord::Base.establish_connection(:database2)
        expect { ActiveRecord::Base.connection }.to raise_error(ActiveRecord::NoDatabaseError)

        create_databases(false)

        { database2: 'phenix_database_2', database3: 'phenix_database_3'}.each do |name, database|
          ActiveRecord::Base.establish_connection(name)
          current_database = ActiveRecord::Base.connection.select_value('select DATABASE()')
          expect(current_database).to eq(database)
        end
      end

      it 'does not fail when databases already existed' do
        create_databases(false)
        create_databases(false)
      end

      it 'fails when mysql fails' do
        with_bad_mysql do
          expect { create_databases(false) }.to raise_error(
            RuntimeError,
            "Failed to execute CREATE DATABASE IF NOT EXISTS phenix_database_2"
          )
        end
      end
    end

    describe :with_schema do
      before do
        Phenix.configure do |config|
          config.database_config_path = complex_database_path
        end
        load_database_config(complex_database_path)
      end

      after do
        drop_databases
      end

      it 'creates the databases and adds the tables from the schema' do
        create_databases(true)

        %i{database2 database3}.each do |name|
          ActiveRecord::Base.establish_connection(name)
          expect(ActiveRecord::Base.connection.send(exists_method, 'tests')).to be true
        end
      end

      it 'resets verbose after' do
        create_databases(true)
        expect(ActiveRecord::Migration.verbose).to eq(true)
      end
    end
  end

  describe 'rise! and burn!' do
    before do
      Phenix.rise!(config_path: complex_database_path)
    end

    after do
      Phenix.burn!
    end

    it 'creates the databases and adds the tables from the schema' do
      %i{database2 database3}.each do |name|
        ActiveRecord::Base.establish_connection(name)
        expect(ActiveRecord::Base.connection.send(exists_method, 'tests')).to be true
      end
    end
  end

  describe :skip_database do
    before do
      Phenix.configure do |config|
        config.database_config_path = complex_database_path
        config.skip_database = ->(name, _conf) { name == 'database3' }
      end
      Phenix.rise!
    end

    after do
      Phenix.burn!
    end

    it 'uses the skip_database lamba when creating databases' do
      ActiveRecord::Base.establish_connection(:database2)
      current_database = ActiveRecord::Base.connection.select_value('select DATABASE()')
      expect(current_database).to eq('phenix_database_2')

      ActiveRecord::Base.establish_connection(:database3)
      expect { ActiveRecord::Base.connection }.to raise_error(ActiveRecord::NoDatabaseError)
    end
  end
end

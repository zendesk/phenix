# Phenix

Helps you spawn ActiveRecord databases at the beginning of your tests and destroying them when you're done.
Handles database configuration with YAML.
Only works for mysql at the moment.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'phenix'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install phenix

## Usage

```ruby
  # helper.rb
  Phenix.configure do |config| # do not pass any block if you just want the defaults
    config.database_config_path = '/my/path/database.yml' # defaults to 'test/database.yml'
    config.schema_path          = 'my/path/schema.rb'     # defaults to 'test/schema.rb'

    config.skip_database = ->(name, conf) { name =~ /do_not_create/ } # define this lambda if you want to skip the creation of some databases
  end

  # in your test file
  before do
    Phenix.rise! # pass with_schema: false if you don't want the schema loaded
  end

  after do
    Phenix.burn!
  end
```

## How do I run tests?

`bundle exec rspec`
This will assume that your DB is accessible via localhost for root with no password.
For a different configuration, you can use the MYSQL_URL environment variable (see test/complex_database.yml).

### Releasing a new version
A new version is published to RubyGems.org every time a change to `version.rb` is pushed to the `main` branch.
In short, follow these steps:
1. Update `version.rb`,
2. update version in all `Gemfile.lock` files,
3. merge this change into `main`, and
4. look at [the action](https://github.com/zendesk/phenix/actions/workflows/publish.yml) for output.

To create a pre-release from a non-main branch:
1. change the version in `version.rb` to something like `1.2.0.pre.1` or `2.0.0.beta.2`,
2. push this change to your branch,
3. go to [Actions → “Publish to RubyGems.org” on GitHub](https://github.com/zendesk/phenix/actions/workflows/publish.yml),
4. click the “Run workflow” button,
5. pick your branch from a dropdown.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/zendesk/phenix.

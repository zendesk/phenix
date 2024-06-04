# frozen_string_literal: true
require "debug/prelude"
require "debug/config"
require 'bundler/setup'
require 'single_cov'
SingleCov.setup :rspec, branches: false

require 'phenix'

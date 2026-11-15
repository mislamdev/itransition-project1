ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

# The parallel workers share the same test database instead of getting a
# database of their own.  Creating one database per worker means a
# `CREATE DATABASE` statement, which blocks on this machine (the workers
# then wait for it forever).  Every test runs inside a transaction that is
# rolled back at the end, so the workers never see each other's data.
ActiveSupport.parallelize_test_databases = false

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers.
    #
    # Two workers are used on purpose: the number of processors of the
    # machine (ten on the development laptop) is too many for the test
    # suite, the workers run out of memory and the Ruby processes crash.
    parallelize(workers: 2)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
  end
end

require 'test/test_helper'
require 'hbase'
require 'shell/formatter'

module Hbase
  class HbaseTest < Test::Unit::TestCase
    def setup
      @formatter = Shell::Formatter::Console.new(:format_width => 110)
    end

    define_test "Hbase::Hbase constructor should initialize hbase configuration object" do
      hbase = ::Hbase::Hbase.new
      assert_kind_of(org.apache.hadoop.conf.Configuration, hbase.configuration)
    end

    define_test "Hbase::Hbase#admin should create a new admin object when called the first time" do
      hbase = ::Hbase::Hbase.new
      assert_kind_of(::Hbase::Admin, hbase.admin(@formatter))
    end

    define_test "Hbase::Hbase#admin should create a new admin object every call" do
      hbase = ::Hbase::Hbase.new
      assert_not_same(hbase.admin(@formatter), hbase.admin(@formatter))
    end

    define_test "Hbase::Hbase#table should create a new table object when called the first time" do
      hbase = ::Hbase::Hbase.new
      assert_kind_of(::Hbase::Table, hbase.table('.META.', @formatter))
    end

    define_test "Hbase::Hbase#table should create a new table object every call" do
      hbase = ::Hbase::Hbase.new
      assert_not_same(hbase.table('.META.', @formatter), hbase.table('.META.', @formatter))
    end
  end
end

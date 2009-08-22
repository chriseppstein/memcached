class String
  def underscore
    self.gsub(/::/, '/').
      gsub(/([A-Z]+)([A-Z][a-z])/,'\1_\2').
      gsub(/([a-z\d])([A-Z])/,'\1_\2').
      tr("-", "_").
      downcase
  end
  def humanize
    self.gsub(/_id$/, "").gsub(/_/, " ").capitalize
  end
end

require "#{File.dirname(__FILE__)}/../../lib/memcached/rails"
require "#{File.dirname(__FILE__)}/../test_helper"

module TimeOuts
  def get_without_timeout_error_support(*args, &block); raise Memcached::ATimeoutOccurred.new("timeout occured"); end
  def cas_without_timeout_error_support(*args, &block); raise Memcached::ATimeoutOccurred.new("timeout occured"); end
  def get_multi_without_timeout_error_support(*args, &block); raise Memcached::ATimeoutOccurred.new("timeout occured"); end
  def set_without_timeout_error_support(*args, &block); raise Memcached::ATimeoutOccurred.new("timeout occured"); end
  def add_without_timeout_error_support(*args, &block); raise Memcached::ATimeoutOccurred.new("timeout occured"); end
  def incr_without_timeout_error_support(*args, &block); raise Memcached::ATimeoutOccurred.new("timeout occured"); end
  def decr_without_timeout_error_support(*args, &block); raise Memcached::ATimeoutOccurred.new("timeout occured"); end
end

module OtherErrors
  def get_without_mem_cache_mem_cache_error_support(*args, &block); raise Memcached::Failure.new("WTF?!"); end
  def cas_without_mem_cache_mem_cache_error_support(*args, &block); raise Memcached::Failure.new("WTF?!"); end
  def get_multi_without_mem_cache_mem_cache_error_support(*args, &block); raise Memcached::Failure.new("WTF?!"); end
  def set_without_mem_cache_mem_cache_error_support(*args, &block); raise Memcached::Failure.new("WTF?!"); end
  def add_without_mem_cache_mem_cache_error_support(*args, &block); raise Memcached::Failure.new("WTF?!"); end
  def incr_without_mem_cache_mem_cache_error_support(*args, &block); raise Memcached::Failure.new("WTF?!"); end
  def decr_without_mem_cache_mem_cache_error_support(*args, &block); raise Memcached::Failure.new("WTF?!"); end
end

class RailsTest < Test::Unit::TestCase

  def setup
    @servers = ['127.0.0.1:43042', '127.0.0.1:43043', "#{UNIX_SOCKET_NAME}0"]
    @namespace = 'rails_test'
    @cache = Memcached::Rails.new(:servers => @servers, :namespace => @namespace)
    @value = OpenStruct.new(:a => 1, :b => 2, :c => GenericClass)
    @marshalled_value = Marshal.dump(@value)
  end

  def test_get
    @cache.set key, @value
    result = @cache.get key
    assert_equal @value, result
  end
  
  def test_get_multi
    @cache.set key, @value
    result = @cache.get_multi([key])
    assert_equal(
      {key => @value}, 
      result
    )
  end
  
  def test_delete
    @cache.set key, @value
    assert_nothing_raised do
      @cache.delete key
    end
    assert_nil(@cache.get(key))
  end
  
  def test_delete_missing
    assert_nothing_raised do
      @cache.delete key
      assert_nil(@cache.delete(key))
    end
  end

  def test_bracket_accessors
    @cache[key] = @value
    result = @cache[key]
    assert_equal @value, result
  end
  
  def test_cas
    cache = Memcached::Rails.new(:servers => @servers, :namespace => @namespace, :support_cas => true)
    value2 = OpenStruct.new(:d => 3, :e => 4, :f => GenericClass)

    # Existing set
    cache.set key, @value
    cache.cas(key) do |current|
      assert_equal @value, current
      value2
    end
    assert_equal value2, cache.get(key)

    # Missing set
    cache.delete key
    assert_nothing_raised do
      cache.cas(key) { @called = true }
    end
    assert_nil cache.get(key)
    assert_nil @called

    # Conflicting set
    cache.set key, @value
    begin
      cache.cas(key) do |current|
        cache.set key, value2
        current
      end
      assert false, "An error was not raised"
    rescue MemCache::MemCacheError => e
      assert_equal "Connection data exists: Key {\"test_cas\"=>\"127.0.0.1:43043:8\"}", e.message
    end
  end  

  def test_timeout_errors
    @cache.extend TimeOuts
    assert_raises Timeout::Error do
      @cache.cas(key){"asdf"}
    end
    assert_raises Timeout::Error do
      @cache.set(key, "asdf")
    end
    assert_raises Timeout::Error do
      @cache.add(key, "asdf")
    end
    assert_raises Timeout::Error do
      @cache.get(key)
    end
    assert_raises Timeout::Error do
      @cache.get_multi(key, "asdf", "bacon")
    end
    assert_raises Timeout::Error do
      @cache.incr(key)
    end
    assert_raises Timeout::Error do
      @cache.decr(key)
    end
  end
  
  def test_other_errors
    @cache.extend OtherErrors
    assert_raises MemCache::MemCacheError do
      @cache.cas(key){"asdf"}
    end
    assert_raises MemCache::MemCacheError do
      @cache.set(key, "asdf")
    end
    assert_raises MemCache::MemCacheError do
      @cache.add(key, "asdf")
    end
    assert_raises MemCache::MemCacheError do
      @cache.get(key)
    end
    assert_raises MemCache::MemCacheError do
      @cache.get_multi(key, "asdf", "bacon")
    end
    assert_raises MemCache::MemCacheError do
      @cache.incr(key)
    end
    assert_raises MemCache::MemCacheError do
      @cache.decr(key)
    end
  end
  
  def test_get_missing
    @cache.delete key rescue nil
    result = @cache.get key
    assert_equal nil, result
  end    
  
  def test_get_nil
    @cache.set key, nil, 0
    result = @cache.get key
    assert_equal nil, result
  end  
  
  def test_namespace
    assert_equal @namespace, @cache.namespace
  end

  private
  
  def key
    caller.first[/.*[` ](.*)'/, 1] # '
  end
  
end
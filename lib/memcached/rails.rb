unless defined?(Timeout::Error)
  module Timeout
    class Error < Interrupt; end
  end
end

unless defined?(MemCache::MemCacheError)
  class MemCache
    class MemCacheError < RuntimeError; end
  end
end

class Memcached

  (instance_methods - NilClass.instance_methods).each do |method_name|
    eval("alias :'#{method_name}_orig' :'#{method_name}'")
  end

  # A legacy compatibility wrapper for the Memcached class. It has basic compatibility with the <b>memcache-client</b> API.
  class Rails < ::Memcached
    
    DEFAULTS = {}

    def self.translate_exception(method, mapping)
      from_exception = mapping.keys.first
      to_exception = mapping.values.first
      exception_supported = (to_exception || from_exception).name.underscore.gsub(%r{/},'_')
      old_method_name = "#{method}_without_#{exception_supported}_support".to_sym
      eval %Q{alias #{old_method_name} #{method}}
      action_to_perform = if to_exception
       %Q{
         raise #{to_exception.name}, "\#{e.class.name.split('::').last.underscore.humanize}: \#{e.message}", e.backtrace
       }
      else
        %Q{nil}
      end
      eval %Q{
        def #{method}(*args, &block)
          #{old_method_name}(*args, &block)
        rescue #{from_exception.name} => e
          #{action_to_perform}
        end
      }
    end

    alias :servers= :set_servers

    # See Memcached#new for details.
    def initialize(*args)
      opts = args.last.is_a?(Hash) ? args.pop : {}
      servers = Array(
        args.any? ? args.unshift : opts.delete(:servers)
      ).flatten.compact

      opts[:prefix_key] ||= opts[:namespace]
      super(servers, DEFAULTS.merge(opts))
    end

    # Wraps Memcached#get so that it doesn't raise. This has the side-effect of preventing you from
    # storing <tt>nil</tt> values.
    def get(key, raw=false)
      super(key, !raw)
    end
    translate_exception :get, NotFound => nil
    translate_exception :get, ATimeoutOccurred => Timeout::Error
    translate_exception :get, Memcached::Error => MemCache::MemCacheError

    # Wraps Memcached#cas so that it doesn't raise. Doesn't set anything if no value is present.
    def cas(key, ttl=@default_ttl, raw=false, &block)
      super(key, ttl, !raw, &block)
    rescue NotFound
    end

    alias :compare_and_swap :cas
    translate_exception :cas, NotFound => nil
    translate_exception :cas, ATimeoutOccurred => Timeout::Error
    translate_exception :cas, Memcached::Error => MemCache::MemCacheError

    # Wraps Memcached#get.
    def get_multi(keys, raw=false)
      get_orig(keys, !raw)
    end

    translate_exception :get_multi, ATimeoutOccurred => Timeout::Error
    translate_exception :get_multi, Memcached::Error => MemCache::MemCacheError

    # Wraps Memcached#set.
    def set(key, value, ttl=@default_ttl, raw=false)
      super(key, value, ttl, !raw)
    end
    translate_exception :set, ATimeoutOccurred => Timeout::Error
    translate_exception :set, Memcached::Error => MemCache::MemCacheError

    # Wraps Memcached#add so that it doesn't raise.
    def add(key, value, ttl=@default_ttl, raw=false)
      super(key, value, ttl, !raw)
      true
    rescue NotStored
      false
    end

    translate_exception :add, ATimeoutOccurred => Timeout::Error
    translate_exception :add, Memcached::Error => MemCache::MemCacheError
    
    # Wraps Memcached#delete so that it doesn't raise.
    translate_exception :delete, NotFound => nil
    
    # Wraps Memcached#delete so that it doesn't raise.
    def delete(key)
      super
    rescue NotFound
    end

    # Wraps Memcached#incr so that it doesn't raise.
    def incr(*args)
      super
    end
    
    translate_exception :incr, NotFound => nil
    translate_exception :incr, ATimeoutOccurred => Timeout::Error
    translate_exception :incr, Memcached::Error => MemCache::MemCacheError

    # Wraps Memcached#decr so that it doesn't raise.
    def decr(*args)
      super
    end

    translate_exception :decr, NotFound => nil
    translate_exception :decr, ATimeoutOccurred => Timeout::Error
    translate_exception :decr, Memcached::Error => MemCache::MemCacheError
    
    # Wraps Memcached#append so that it doesn't raise.
    def append(*args)
      super
    rescue NotStored
    end

    # Wraps Memcached#prepend so that it doesn't raise.
    def prepend(*args)
      super
    rescue NotStored
    end

    # Namespace accessor.
    def namespace
      options[:prefix_key]
    end

    alias :flush_all :flush

    alias :"[]" :get
    alias :"[]=" :set

  end
end
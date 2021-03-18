require "yaml"

class YAMLCache
  def initialize(file = nil)
    if file
      @file = file
      begin
        @cache = YAML.load(File.read(file, mode: "r:UTF-8"))
      rescue => err
        puts "Info: No cache found, creating empty cache."
        @cache = {}
      end
    else
      @file = nil
      @cache = {}
    end
  end

  def ensureArray(*names)
    names.each do |name|
      @cache[name] = [] unless @cache[name]
    end
  end

  def ensureHash(*names)
    names.each do |name|
      @cache[name] = {} unless @cache[name]
    end
  end

  def [](key)
    return @cache[key]
  end

  def []=(key, value)
    @cache[key] = value
  end

  def save
    if @file
      saveTo(@file)
    else
      puts "ERROR: Cannot save because the cache has no connected file, use saveTo to specify the destination."
    end
  end

  def saveTo(file)
    File.write(file, @cache.to_yaml, mode: "w:UTF-8")
  end
end

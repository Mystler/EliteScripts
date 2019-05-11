module Interactive
  # SPECIAL NOTE: By default these function check for existing cmd arguments first.
  # You can disable that behavior by setting the optional parameter to false.

  # Fetch next cmd argument or wait for input
  def self.GetInputOrArg(checkArgs = true)
    arg = checkArgs ? ARGV.shift : nil
    unless arg
      return gets.chomp
    end
    puts arg
    return arg
  end

  def self.UserInputPrompt(pretext, name, checkArgs = true)
    puts pretext if pretext
    print "#{name}: " if name
    return GetInputOrArg(checkArgs)
  end
end

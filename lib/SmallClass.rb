class SmallClass
  @@class_list = (1000..2000).to_a
  def initialize
    @field = "blablablabla"
    @list = (1..1000).to_a
  end
  #def to_s
  def inspect
    to_s
  end

end


c = SmallClass.new
  puts c.inspect
  puts c.to_s
c.xx
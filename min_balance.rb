#!/usr/bin/ruby -w

UNIT = 1200
MIN_MINERALS = 200
YEARS = 3
GAME = "drknrg"
if true
    RACE = "Bird"
    FREIGHTER = "Fast Shipper"
    PLAYERNO = 2
    FACTS = 18
    FACT_COST = 4
    POPMAX = 1100000
    HOMEWORLD = {'Kirk' => 1, 'Sand Castle' => 1}
    FUN = [0,0,10,30,40,50,60,70,80,90,100]
else
    RACE = "Mercinary"
    FREIGHTER = "Large Freighter \\(2\\)"
    PLAYERNO = 1
    FACTS = 25
    FACT_COST = 3
    POPMAX = 1100000
    HOMEWORLD = {'Salsa' => 1}
    FUN = [0,0,0,0,0,0,0,0,0,70,84]
end

module Enumerable
    # inject(n) { |n, i| ...}
    def inject(n)
	each { |i|
	    n = yield(n, i)
	}
	n
    end
    def sum
	inject(0) {|n, i|  n + i }
    end
end

class Array
    def elementsum(a)
	a.each_with_index do |v,i|
	    self[i] += v
	end
	self
    end
end
	    
class Point
    attr_reader(:x, :y)
    def initialize(x, y)
	@x = x.to_i
	@y = y.to_i
    end
    def -(t)
	return(Math.sqrt((@x - t.x)**2 + (@y - t.y)**2))
    end
end

class Race
    attr_reader(:name, :planets)
    def initialize(name)
	@name = name
	@planets = []
    end
    def new_planet(p)
	@planets.push(p)
    end
    def summary
	@tot_pla = @planets.size
	@tot_res = @planets.map {|p| p.res}.sum
	@tot_min = @planets.map {|p| p.mins}.inject([0, 0, 0]) do |n, i|
	    n.elementsum(i)
	end
	print "Total planets  = #{@tot_pla}\n"
	print "Total resource = #{@tot_res} (#{@tot_res/@tot_pla})\n"
	print "Total minerals = #{@tot_min.join(%Q(\t))}\n"
	print "  Ave minerals = #{@tot_min.map{|n| n / @tot_pla}.join(%Q(\t))}\n"
	print "scaled @ 500   = #{mineral_targets(500).join(%Q(\t))}\n"
	print "scaled @ 2000  = #{mineral_targets(2000).join(%Q(\t))}\n"
	print "-----------------\n"
    end	
    def mineral_targets(res)
	@tot_min.map{|n| (n * (res.to_f / @tot_res)).floor}
    end
	
end

class Planet
    attr_reader(:name, :owner, :res, :mins, :extra, :gaterange)
    attr_reader(:pos)
    attr_accessor(:input_nodes, :output_nodes, :node)
    protected(:gaterange, :pos)
    def initialize(x, y)
	@pos = Point.new(x, y)
	@shipped_mins = [0,0,0,0]
	@input_nodes = []
	@output_nodes = []
    end
    def planet_info(p)
	@name = p.Planet_Name
	@owner = p.Owner
	@pop = p.Population.to_i
	if p.Value		# handle 'nil' values
	    @value = p.Value.sub('%', '').to_i
	end
	@res = p.Resources.to_i
	i = p.members.index("S_Iron")
	@mins = p.values[i..i+2].collect {|n| n.to_i}
	i = p.members.index("Iron_MR")
	@min_rate = p.values[i..i+2].collect {|n| n.to_i}
	@owner.new_planet(self)
	@factories = p.Factories.to_i
	@gaterange = p.GateRange.to_i
    end
    def shipped_mins(m)
	m.each_with_index do |v,i|
	    @shipped_mins[i] += v
	end
    end
    def calc_extra()
	@extra = [0, 0, 0, 0]
	if @pop < 1000
	    return   # not tech trading planets
	end
	if @shipped_mins.max > 0
	    print "#{@name} shipped #{@shipped_mins.join(', ')}\n"
	end
	targets = @owner.mineral_targets(@res)
	if @factories < @pop/10000 * FACTS 
	    # need more germ for factories
	    more_germ = (@pop/10000 * FACTS - @factories) * FACT_COST
	    print "#{@name} needs #{more_germ} more germ for factories\n"
	    targets[2] += more_germ
	end
	@mins.each_with_index do |v,i|
	    v += @min_rate[i] * YEARS + @shipped_mins[i]
	    @extra[i] = ((v - targets[i]) / UNIT.to_f).to_i  #trunc
	    if @extra[i] == 0 && v < MIN_MINERALS
		@extra[i] = -1
	    end
	    if v - @extra[i] * UNIT < MIN_MINERALS
		@extra[i] -= (MIN_MINERALS / UNIT.to_f).ceil
	    end
	    print "#{@name} #{i} at #{v} want #{targets[i]} extra #{@extra[i]}\n"
	end
	# handle population
	extra[3] = 0
	v = @pop + @shipped_mins[3]
	plamax = @value * POPMAX / 100.0
	if (@value < 40 || HOMEWORLD[@name]) && v < plamax
	    extra[3] = ((v - plamax) / (100.0*UNIT)).to_i
	elsif @value <= 95 && v < 400000
	    extra[3] = ((v - 400000) / (100.0*UNIT)).to_i
	elsif @value > 95
	    extra[3] = ((v - 400000) / (100.0*UNIT)).to_i # trunc
	end
	print "#{@name} 3(#{@value}) at #{v} extra #{@extra[3]}\n"
    end
    def <=>(b)
	self.name <=> b.name
    end
    def dist(p, loaded)
	dist = @pos - p.pos
	mass = 209 + 1200 * loaded
	if loaded == 0 && dist < @gaterange && dist < p.gaterange
	    1
	else
	    warp = 10
	    while warp > 0
		rtime = (dist / warp**2).ceil
		f = FUN[warp] * (dist/rtime).ceil / 200
		fuel = (mass * f + 9)/100 * rtime;
		break if 0.85 * fuel < 2600  # IFE
		warp -= 1
	    end
	    rtime
	end
    end
end

class Transport
    attr_reader(:cnt, :dest, :eta)
    attr_accessor(:node)
    def initialize(cnt, dest, eta)
	@cnt = cnt
	@dest = dest
	@eta = eta
    end
end

class Node
    attr_reader(:type, :data, :min, :link)
    protected(:link)
    @@nextnode = 1
    @@nodes = []
    def Node.num_nodes
	@@nextnode - 1
    end
    def Node.lookup(num)
	@@nodes[num]
    end
    def initialize(type, data=nil, min=nil)
	@type = type
	@data = data
	@min = min
	@node = @@nextnode
	@link = []
	@@nextnode += 1
	@@nodes[@node] = self
    end
    def to_int
	@node
    end
    def addlink(amm, to)
	@link.push([amm, to])
    end
    def walk(off)
	case @type
	when "ship"
	    print @type
	when "planet"
	    print "planet #{@data.name}"
	when "input", "output"
	    print "#{@type} #{@data.name} #{@min}"
	when "done"
	    print "done\n"
	    return
	end
	print "\n"
	off += "\t"
	@link.each do |n|
	    print "#{off}#{n[0]} "
	    n[1].walk(off)
	end
    end
    def findpath
	ret = []
	n = self
	while n.link.size > 0
	    e = n.link[0]
	    e[1]
	    ret.push(e[1])
	    if e[0] == 1
		n.link.shift
	    else 
		e[0] -= 1
	    end
	    n = e[1]
	end
	ret
    end
end

def parse_stars_file(structname, filename)
    file = File.new(filename)
    file.readline
    chomp
    sub!(/\r$/, '')
    gsub!(" ", "_")    # can't have method's with spaces
    fields = split "\t"
    st = Struct.new(structname, *fields)
    array = []
    file.each do |line|
	line.chomp!
	line.sub!(/\r$/, '')
	fields = line.split("\t")
	obj = st.new(*fields)
	if iterator?
	    yield obj
	else
	    array << obj
	end
    end
    return array
end
    
planets = {}
ships = []
parse_stars_file("Map", GAME + ".map") do |p|
    pla = Planet.new(p.X, p.Y)
    planets[p.Name] = pla
end

races = Hash.new

parse_stars_file("Planet_info", GAME + ".p" + PLAYERNO.to_s) do |p|
    if !races.has_key? p.Owner
	races[p.Owner] = Race.new(p.Owner)
    end
    p.Owner = races[p.Owner]
    planets[p.Planet_Name].planet_info(p)
end

parse_stars_file("Fleet_info", GAME + ".f" + PLAYERNO.to_s) do |p|
    pla = planets[p.Planet]
    dest = planets[p.Destination]
    pla = nil if pla && pla.owner.name != RACE
    dest = nil if dest && dest.owner.name != RACE
    
    if dest && p.Task == "QuikDrop"
	dest.shipped_mins([p.Iron, p.Bora, p.Germ, p.Col].collect {|s| s.to_i})
    end
    if p.Fleet_Name =~ /^#{RACE} #{FREIGHTER}/
	if pla && p.Destination == '-- ' && p.Task == "(no task here)"
	    ships.push(Transport.new(p.Unarmed.to_i, pla, 0));
	elsif dest != nil
	    print "ETA #{p.ETA}\n"
	    ships.push(Transport.new(p.Unarmed.to_i, dest, p.ETA.to_i))
	else
	    print "#{p.inspect}\n"
	end
    end
end
num_ships = ships.map {|s| s.cnt }.sum

races[RACE].summary

done_node = Node.new("done")

network = File.open("network.dmx.x", "w");
# node 1 is output node
arcs = 0

network.printf("n 1 -%d\n", num_ships)

# add nodes for incoming transports
for s in ships do
    s.node = Node.new('ship', s)
    network.printf("n %d %d\n",
		   s.node, s.cnt);
end

# assign planets nodes
races[RACE].planets.each do |p|
    p.node = Node.new("planet", p)
end

# connect transports to planets
ships.each do |s|
    network.printf("a %d %d 0 %d %d\n", s.node, s.dest.node, s.cnt, s.eta)
    arcs += 1
end

# add graph for empty transports
for s in races[RACE].planets do
    for n in races[RACE].planets do 
	next if s == n;

	network.printf("a %d %d 0 %d %d\n",
		       s.node, n.node,
		       num_ships,
		       s.dist(n, 0))
	arcs += 1
    end
end
	
plasource = [0, 0, 0, 0]
planeeded = [0, 0, 0, 0]
sumsource = [0, 0, 0, 0]
sumneeded = [0, 0, 0, 0]
source = []
needed = []
for i in 0..3 do
	source[i] = []
	needed[i] = []
end
# add supply and needed nodes
for p in races[RACE].planets do
    p.calc_extra
    for min in 0..3 do
	extra = p.extra[min]
	if extra != 0
	    if extra > 0
		source[min].push(p)
		p.input_nodes[min] = Node.new('input', p, min)
		network.printf("a %d %d 0 %d 0\n", 
			       p.node, p.input_nodes[min], extra)
		arcs += 1
		plasource[min] += 1
		sumsource[min] += extra
	    else
		needed[min].push(p)
		p.output_nodes[min] = Node.new('output', p, min)
		network.printf("a %d 1 0 %d 0\n", p.output_nodes[min], -extra)
		arcs += 1
		planeeded[min] += 1
		sumneeded[min] += -extra
	    end
	end
    end
end

# connect supply and needed nodes
for min in 0..3 do
    for s in source[min] do
	for n in needed[min] do
	    network.printf("a %d %d 0 %d %d\n",
			   s.input_nodes[min],
			   n.output_nodes[min],
			   num_ships,
			   s.dist(n, 1))
	    arcs += 1
	end
    end
end
source = needed = nil

print "---------\n"
print "Num ships = #{num_ships}\n"
print "Planets supply = #{plasource.join(%Q(\t))} = #{plasource.sum}\n"
print "Total   supply = #{sumsource.join(%Q(\t))} = #{sumsource.sum}\n"
print "Planets needed = #{planeeded.join(%Q(\t))} = #{planeeded.sum}\n"
print "Total   needed = #{sumneeded.join(%Q(\t))} = #{sumneeded.sum}\n"

network.close
network = File.open("network.dmx", "w");
network.print "p min #{Node.num_nodes} #{arcs}\n"
File.open("network.dmx.x", "r") do |i|
    network.write(i.read)
end
network.close
File.unlink("network.dmx.x")

system("mcf -o -v -q -w network.out ./network.dmx")

File.open("network.out", "r").each do |$_|
    if /^f (\d+) (\d+) (\d+)/
	from, to, amm = Node.lookup($1.to_i), Node.lookup($2.to_i), $3.to_i

	from.addlink(amm, to)
    end
end

min_name = ['iron', 'boron', 'germ', 'col']

ship = {}
ships.each do |s|
#   if s.eta == 0
#	s.node.walk('')
#   end
    s.cnt.times do
	path = s.node.findpath
	if s.eta == 0 && path.size > 1
	    from = s.dest
	    ship[from] ||= {}
	    
	    case path[1].type 
	    when 'input'
		to = path[2].data
		min = path[2].min
#		print "from #{from} to #{to} #{UNIT} #{min_name[min]}\n"
		ship[from][to] ||= Hash.new(0)
		ship[from][to][min] += 1 
	    when 'planet'
		to = path[1].data
		ship[from][to] ||= Hash.new(0)
		ship[from][to][4] += 1 
#		print "move 1 from #{from} to #{to}\n"
	    else
		puts path[1].type
		raise
	    end
	end
    end
end
    
print "done\n"
	    
for from in ship.keys.sort do
    print "Ship from #{from.name}:\n"
    for to in ship[from].keys.sort do
	for min in ship[from][to].keys.sort do
	    cnt = ship[from][to][min]
	    print "\t#{to.name}"
	    if min == 4
		print "(#{from.dist(to,0)}) #{cnt} ships\n"
	    else 
		print "(#{from.dist(to,1)}) #{cnt.*UNIT}kT #{min_name[min]}\n"
	    end
	end
    end
end

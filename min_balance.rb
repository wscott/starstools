#!/usr/bin/ruby -w

# %Z%%K%

# TODO
#  Read race description from file
#  Handle stopping for gas when delivering
#  execptions for min and pop targets for some planets
#  fix hardcoded transport info

UNIT = 1200			# minerals in one loaded freighter
MIN_MINERALS = 200		# min minerals to leave on any planet
YEARS = 3
GAME = "drknrg"
HOMEWORLD = {
    'Kirk' => 1,	# Birds
    'Sand Castle' => 1, # Zedd :)
    'Salsa' => 1,	# Mercinary
    'Mamie' => 1,	# Fermi
    'Simple' => 1,	# Geovirus :(
    'Timbuktu' => 1,	# Engineers
    'Bakwele' => 1,	# Randoms
    'Libra' => 1,	# Romans
    'Omega' => 1,	# Speedbumps :(
}

# configuration parameters
# 
#   MAX_POP_VALUE = 50
# try to bring any planet with a value of < 50% to max population.

#   MIN_HOLD_LEVEL = 350_000
# All planets not being maximize need at least 350,000 people

#   BREEDER_VALUE = 90
# Any planet over 90% is a breeder and is considered for exporting people
# if loading a freighter will still leave the planet over MIN_HOLD_LEVEL 
# people

case ARGV[0]
when "2"
    RACE = "Bird"
    FREIGHTER = "Fast Shipper"
    PLAYERNO = 2
    FACTS = 18			# Number of factories operated
    FACT_COST = 4		# cost in Germ per factory
    POPMAX = 1100000		# max population on 100% world
    FUELEFF = 0.85  # IFE	# 1 for no-IFE

    # Fuel efficiency numbers from Stars! spreadsheet
    FUN = [0,0,10,30,40,50,60,70,80,90,100]
    FREIGHTER_MASS = 209	# mass of empty freighter
    FREIGHTER_FUEL = 2600
    MAX_POP_VALUE = 70
    MIN_HOLD_LEVEL = 350_000
    BREEDER_VALUE = 90
    OVERRIDES = {}
when "1"
    RACE = "Mercinary"
    FREIGHTER = "Large Freighter \\(2\\)"
#    FREIGHTER = "Large Freighter"
    PLAYERNO = 1
    FACTS = 25
    FACT_COST = 3
    POPMAX = 1100000
    FUELEFF = 0.85
    FUN = [0,0,0,0,0,0,0,0,0,70,84]
    FREIGHTER_MASS = 183
    FREIGHTER_FUEL = 2600
    MAX_POP_VALUE = 70
    MIN_HOLD_LEVEL = 350_000
    BREEDER_VALUE = 90
    OVERRIDES = {'Arnold' => [nil, nil, 0]}
else
    print "Race #{ARGV[0]} not handled\n"
    exit 1
end

MIN_NAME = ['iron', 'boron', 'germ', 'col']

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
    attr_reader(:name, :planets, :tot_min)
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
	print "Total resource\t= #{@tot_res} (#{@tot_res/@tot_pla})\n"
	print "\t\t\tiron\tboron\tgerm\n"
	print "Total minerals =\t#{@tot_min.join(%Q(\t))}\n"
	print "  Ave minerals =\t#{@tot_min.map{|n| n / @tot_pla}.join(%Q(\t))}\n"
	print "scaled @ 500   =\t#{mineral_targets(500).join(%Q(\t))}\n"
	print "scaled @ 2000  =\t#{mineral_targets(2000).join(%Q(\t))}\n"
	print "-----------------\n"
    end	
    def mineral_targets(res)
	@tot_min.map{|n| (n * (res.to_f / @tot_res)).floor}
    end
end

class Planet
    attr_reader(:name, :owner, :res, :mins, :gaterange)
    attr_reader(:pos)
    attr_accessor(:input_nodes, :output_nodes, :node)
    attr_accessor(:popneeded)
    protected(:gaterange, :pos)
    @@planets = {}
    def Planet.lookup(name)
	@@planets[name]
    end
    def initialize(name, x, y)
	@name = name
	@pos = Point.new(x, y)
	@shipped_mins = [0,0,0,0]
	@input_nodes = []
	@output_nodes = []
	@extra = nil
	@@planets[@name] = self
    end
    def planet_info(p)
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
    def pop
	@pop + @shipped_mins[3] * 100
    end
    def maxpop
	[@value * POPMAX / 100.0, POPMAX/20].max
    end
    def mineral_targets(res, pop)
	targets = @owner.mineral_targets(res)
	# account for extra germ to build new factories, assuming new 
	# people arrive
	more_germ = (pop/10000 * FACTS - @factories) * FACT_COST
	if more_germ > 0
	    print "#{@name} needs #{more_germ} extra germ to finish factories\n"
	    targets[2] += more_germ
	end
	if a = OVERRIDES[@name]
	    targets.each_with_index do |v,i|
		targets[i] = a[i] || v
	    end
	end
	targets
    end
    def extra
	return @extra if @extra
	@extra = [0, 0, 0, 0]
	if @pop < 1000
	    return  @extra # not tech trading planets
	end
	if @shipped_mins.max > 0
	    print "#{@name} shipped #{@shipped_mins.join(', ')}\n"
	end
	# handle population
	if @value < MAX_POP_VALUE || HOMEWORLD[@name]
	    # when filling a planet allow a 1/2 a freighter overcommit
	    # so the planet gets closer to full.  We could get completely
	    # full, but these a freighter might be almost empty
	    target = maxpop
	    target += 50 * UNIT if pop < target
	else 
	    target = MIN_HOLD_LEVEL
	end
	extra[3] = ((pop - target) / (100.0*UNIT)).to_i
	# only export from breeders
	if extra[3] > 0 && @value < BREEDER_VALUE && pop < maxpop
	    extra[3] = 0
	end
	newpop = pop
	if extra[3] < 0
	    newpop +=  -extra[3] * 100 * UNIT
	    newpop = [newpop,maxpop].min
	end
	targets = mineral_targets(@res, newpop)

	@mins.each_with_index do |v,i|
	    v += @min_rate[i] * YEARS + @shipped_mins[i]
	    @extra[i] = ((v - targets[i]) / UNIT.to_f).to_i  #trunc
	    if @extra[i] == 0 && v < MIN_MINERALS
		@extra[i] = -1
	    end
	    if v - @extra[i] * UNIT < MIN_MINERALS
		@extra[i] -= (MIN_MINERALS / UNIT.to_f).ceil
	    end
	    if @extra[i] != 0
		print "#{@name} #{MIN_NAME[i]} at #{v} want #{targets[i]} extra #{@extra[i]}\n"
	    end
	end
	if @extra[3] != 0
	    print "#{@name} col(#{@value}) at #{pop} extra #{@extra[3]}\n"
	end
	@shipped_mins.each_with_index do |sh,i|
	    if @extra[i] > 0 && sh > 0
		print "#{@name} importing and exporting #{MIN_NAME[i]} ???\n"
	    end
	end
	@extra
    end
    def <=>(b)
	self.name <=> b.name
    end
    def dist(p, loaded)
	dist = @pos - p.pos
	mass = FREIGHTER_MASS + UNIT * loaded
	if loaded == 0 && dist < @gaterange && dist < p.gaterange
	    1
	else
	    warp = 10
	    while warp > 0
		rtime = (dist / warp**2).ceil
		f = FUN[warp] * (dist/rtime).ceil / 200
		fuel = (mass * f + 9)/100 * rtime;
		fuel *= FUELEFF
		break if fuel < FREIGHTER_FUEL
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
    # used for debugging...
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
    file.each do |line|
	line.chomp!
	line.sub!(/\r$/, '')
	fields = line.split("\t")
	yield st.new(*fields)
    end
end
    
ships = []
parse_stars_file("Map", GAME + ".map") do |p|
    pla = Planet.new(p.Name, p.X, p.Y)
end

races = Hash.new

parse_stars_file("Planet_info", GAME + ".p" + PLAYERNO.to_s) do |p|
    if !races.has_key? p.Owner
	races[p.Owner] = Race.new(p.Owner)
    end
    p.Owner = races[p.Owner]
    Planet.lookup(p.Planet_Name).planet_info(p)
end

parse_stars_file("Fleet_info", GAME + ".f" + PLAYERNO.to_s) do |p|
    pla = Planet.lookup(p.Planet)
    dest = Planet.lookup(p.Destination)
    pla = nil if pla && pla.owner.name != RACE
    dest = nil if dest && dest.owner.name != RACE
    
    if dest && p.Task == "QuikDrop"
	dest.shipped_mins([p.Iron, p.Bora, p.Germ, p.Col].collect {|s| s.to_i})
    end
    if p.Fleet_Name =~ /^#{RACE} #{FREIGHTER}/
	if pla && p.Destination == '-- ' && p.Task == "(no task here)"
	    ships.push(Transport.new(p.Unarmed.to_i, pla, 0));
	elsif dest != nil
	    ships.push(Transport.new(p.Unarmed.to_i, dest, p.ETA.to_i))
	else
	    print "Ignoring #{p.Fleet_Name} at '#{p.Planet}' going to '#{p.Destination}' task #{p.Task}\n"
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
for s in ships do
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
for p in races[RACE].planets.sort do
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

print "---------\n"
print "Num ships = #{num_ships}\n"
print "\t\t  "
MIN_NAME.each do |m|
    print "#{m}\t"
end
print "  total\n"
print "Planets supply\t= #{plasource.join(%Q(\t))}\t= #{plasource.sum}\n"
print "Total   supply\t= #{sumsource.join(%Q(\t))}\t= #{sumsource.sum}\n"
print "Planets needed\t= #{planeeded.join(%Q(\t))}\t= #{planeeded.sum}\n"
print "Total   needed\t= #{sumneeded.join(%Q(\t))}\t= #{sumneeded.sum}\n"

network.close
network = File.open("network.dmx", "w");
network.print "p min #{Node.num_nodes} #{arcs}\n"
File.open("network.dmx.x", "r") do |i|
    network.write(i.read)
end
network.close
File.unlink("network.dmx.x")
File.unlink("network.out") if File.file?("network.out")
system("./mcf -o -v -q -w network.out ./network.dmx") || raise

File.open("network.out", "r").each do |$_|
    if /^f (\d+) (\d+) (\d+)/
	from, to, amm = Node.lookup($1.to_i), Node.lookup($2.to_i), $3.to_i

	from.addlink(amm, to)
    end
end


ship = {}
unused_ships = Hash.new(0)
unused_in_transit = 0
ships.each do |s|
#   if s.eta == 0
#	s.node.walk('')
#   end
    s.cnt.times do
	path = s.node.findpath
	if path.size <= 1
	    if s.eta == 0
		unused_ships[s.dest.name] += 1
	    else
		unused_in_transit += 1
	    end
	end
	if s.eta == 0 && path.size > 1
	    from = s.dest
	    ship[from] ||= {}
	    
	    case path[1].type 
	    when 'input'
		to = path[2].data
		min = path[2].min
#		print "from #{from} to #{to} #{UNIT} #{MIN_NAME[min]}\n"
		ship[from][to] ||= Hash.new(0)
		ship[from][to][min] += UNIT 
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
    
# Track how many people a planet really needs because we can overcommit
for p in needed[3]
    p.popneeded = ((p.maxpop - p.pop) / 100).floor
end

for from in ship.keys.sort do
    print "Ship from #{from.name}:\n"
    for to in ship[from].keys.sort do
	for min in ship[from][to].keys.sort do
	    cnt = ship[from][to][min]
	    print "\t#{to.name}"
	    if min == 4
		print "(#{from.dist(to,0)}) #{cnt} ships\n"
	    else 
		if min == 3	# population
		    cnt = [cnt,to.popneeded].min
		    to.popneeded -= cnt
		end
		print "(#{from.dist(to,1)}) #{cnt}kT #{MIN_NAME[min]}\n"
	    end
	end
    end
end

print "\nUnused Freighters:\n"
for p in unused_ships.keys.sort do
    print "\t#{p} #{unused_ships[p]}\n"
end
print "Unused Freighter currently in transit: #{unused_in_transit}\n"

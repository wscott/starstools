#!/usr/bin/ruby -w

UNIT = 1200
MIN_MINERALS = 200
YEARS = 3
GAME = "drknrg"
if true
    RACE = "Bird"
    FREIGHTER = "Fast Shipper"
    PLAYERNO = 2
    WARP = 100.0
    FACTS = 18
    FACT_COST = 4
else
    RACE = "Mercinary"
    FREIGHTER = "Large Freighter"
    PLAYERNO = 1
    WARP = 81.0
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
    attr_reader(:name, :owner, :res, :mins, :extra)
    attr_reader(:pos)
    attr_accessor(:transports)
    def initialize(x, y)
	@pos = Point.new(x, y)
	@shipped_mins = [0,0,0]
	@transports = 0
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
    end
    def shipped_mins(m)
	m.each_with_index do |v,i|
		@shipped_mins[i] += v
	end
    end
    def calc_extra()
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
	@extra = []
	@mins.each_with_index do |v,i|
	    v += @min_rate[i] * YEARS + @shipped_mins[i]
	    @extra[i] = ((v - targets[i]) / UNIT.to_f).to_i  #trunc
	    if @extra[i] == 0 && v < MIN_MINERALS
		@extra[i] = -1
	    end
	    if v - @extra[i] * UNIT < MIN_MINERALS
		@extra[i] -= (MIN_MINERALS / UNIT).ceil
	    end
	    print "#{@name} #{i} at #{v} want #{targets[i]} extra #{@extra[i]}\n"
	end
    end
    def <=>(b)
	self.name <=> b.name
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
parse_stars_file("Map", GAME + ".map") { |p|
    pla = Planet.new(p.X, p.Y)
    planets[p.Name] = pla
}

races = Hash.new

parse_stars_file("Planet_info", GAME + ".p" + PLAYERNO.to_s) { |p|
    if !races.has_key? p.Owner
	races[p.Owner] = Race.new(p.Owner)
    end
    p.Owner = races[p.Owner]
    planets[p.Planet_Name].planet_info(p)
}
parse_stars_file("Fleet_info", GAME + ".f" + PLAYERNO.to_s) { |p|
    if p.Task == "QuikDrop"
	planets[p.Destination].shipped_mins([p.Iron, p.Bora, p.Germ].collect {|s| s.to_i})
    end
    if p.Fleet_Name =~ /^#{RACE} #{FREIGHTER}/ && 
	    p.Destination == '-- ' && 
	    p.Task == "(no task here)"
	planets[p.Planet].transports += p.Unarmed.to_i
    end
}

races[RACE].summary

sum = [0, 0, 0]
source = {}
needed = {}
for i in 0..2 do
	source[i] = {}
	needed[i] = {}
end
for p in races[RACE].planets do
    p.calc_extra
    for min in 0..2 do
	extra = p.extra[min]
	if extra != 0
	    if extra > 0
		source[min][p] = extra
	    else
		needed[min][p] = -extra
	    end
	    sum[min] += extra
	end
    end
end

for min in 0..2 do
    print "total #{min} #{sum[min]}\n"
end
print "done\n"


ship = {}
for min in 0..2 do
    if source[min].values.sum > needed[min].values.sum
	s = needed[min]
	n = source[min]
	rev = 1
    else
	s = source[min]
	n = needed[min]
	rev = 0
    end

    # compute distance array
    dist = {}
    for sp in s.keys do
	dist[sp] = {}
	for np in n.keys do
	    dist[sp][np] = ((sp.pos - np.pos)/WARP).ceil
	end
    end
    while s.size > 0
	# find the source planet with the largest min distance
	max_min = 0
	for sp in s.keys do
	    dmin = 1e6
	    for np in n.keys do
		d = dist[sp][np]
		# if you do not have any ships it will take an extra year
		if (rev==0 ? sp : np).transports <= 0
		    d += 1
		end
		if d < dmin
		    dmin = d
		    dp = np
		end
	    end
	    if dmin > max_min 
		max_min = dmin
		from = sp
		to = dp
	    end
	end
	if rev == 1
	    src = to
	    dest = from
	else
	    src = from
	    dest = to
	end
	amount = [s[from], n[to]].min
	if src.transports > 0 && src.transports < amount
	    amount = src.transports
	end
	s[from] -= amount
	n[to] -= amount
	if s[from] == 0 
	    s.delete(from)
	end
	if n[to] == 0
	    n.delete(to)
	end
	trans = [amount, src.transports].min
	src.transports -= trans

	ship[src] ||= {}
	ship[src][dest] ||= []
	ship[src][dest].push([min, amount, trans, max_min])
    end
end

min_name = ['iron', 'boron', 'germ']

extra_freighters = 0
total_trips = 0
total_length = 0
for from in ship.keys.sort do
    print "Ship from #{from.name}:\n"
    tot_trans = 0
    ship[from].values.each {|a1| a1.each {|a2| tot_trans += a2[2]}}
    if tot_trans > 0
	print "    #{tot_trans} transports waiting\n"
    end    
    for to in ship[from].keys.sort do
	for e in ship[from][to] do
	    min, amount, trans, max_min = *e
	    print "\t#{to.name} "
	    y = max_min
	    total_trips += amount
	    total_length += y
	    if trans > 0
		print "(#{y}) "
	    else
		print "(#{y-1}+1) "
		extra_freighters += amount 
	    end
	    print "#{amount.*UNIT}kT #{min_name[min]}\n"
	end
    end
end
printf "\nShip %d freighters for an average length of %.1f years\n",
    total_trips, total_length/total_trips.to_f

print "\nPlanets with unused freighters:\n"
for p in races[RACE].planets.sort do
    if p.transports > 0
	print "\t#{p.transports} #{p.name}\n"
	extra_freighters -= p.transports
    end
end

if extra_freighters > 0 then
    print "\nNumber of addition frieghters needed: #{extra_freighters}\n"
end


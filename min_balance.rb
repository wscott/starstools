#!/usr/bin/ruby -w

UNIT = 1200
PROD_RES = 1500
PROD_MIN = 5000
PROD_MAX = 10000
MINE_MIN = 100
MINE_MAX = 500
RACE = "Bird"
FREIGHTER = "Fast Shipper"
YEARS = 5
GAME = "drknrg"
PLAYERNO = 2

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

class Planet
    attr_reader(:name, :owner, :pop, :value, :mines, :fact, :mins, :extra, :prod)
    attr_reader(:pos)
    attr_writer(:id)
    attr_accessor(:transports)
    def initialize(x, y)
	@pos = Point.new(x, y)
	@owner = ""
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
	@mines = p.Mines.to_i
	@fact = p.Factories.to_i
	i = p.members.index("S_Iron")
	@mins = p.values[i..i+2].collect {|n| n.to_i}
	i = p.members.index("Iron_MR")
	@min_rate = p.values[i..i+2].collect {|n| n.to_i}
    end
    def shipped_mins(m)
	m.each_with_index do |v,i|
		@shipped_mins[i] += v
	end
    end
    def fleets(p)
	@transports += p
    end
    def calc_extra()
	res = @pop / 1000 + @fact * 1.2
	if res > PROD_RES
	    min = PROD_MIN
	    max = PROD_MAX
	    @prod = 1
	else
	    min = MINE_MIN
	    max = MINE_MAX
	    @prod = 0
	end
	@extra = []
	@mins.each_with_index do |v,i|
	    if v + @min_rate[i] * YEARS + @shipped_mins[i] < min
		@extra[i] = -((min - v) / UNIT.to_f).ceil
	    elsif v > max && v > min + UNIT
		@extra[i] = ((v - min) / UNIT.to_f).floor
	    else
		@extra[i] = 0
	    end
	end
	if @shipped_mins.max > 0
	    print "#{@name} shipped #{@shipped_mins.join(', ')}\n"
	end
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
    
maxid = 0
plist = []
planets = {}
parse_stars_file("Map", GAME + ".map") { |p|
    pla = Planet.new(p.X, p.Y)
    pla.id = maxid
    maxid += 1
    plist << pla
    planets[p.Name] = pla
}
parse_stars_file("Planet_info", GAME + ".p" + PLAYERNO.to_s) { |p|
    planets[p.Planet_Name].planet_info(p)
#    print p.inspect, "\n"
}
parse_stars_file("Fleet_info", GAME + ".f" + PLAYERNO.to_s) { |p|
    if p.Task == "QuikDrop"
	planets[p.Destination].shipped_mins([p.Iron, p.Bora, p.Germ].collect {|s| s.to_i})
    end
#    print p.inspect, "\n"
    if p.Fleet_Name =~ /^#{RACE} #{FREIGHTER}/ && p.Destination == '-- ' && p.Task == "(no task here)"
#	print p.inspect, "\n";
	planets[p.Planet].fleets(p.Ship_Cnt.to_i)
    end
}

names = planets.keys
names.sort!

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

sum = [0, 0, 0]
source = {}
needed = {}
for i in 0..2 do
	source[i] = {}
	needed[i] = {}
end
tot_prod = 0
for i in names do
    if planets[i].owner != RACE
	    next
    end
    planets[i].calc_extra
    tot_prod += planets[i].prod
    for min in 0..2 do
	extra = planets[i].extra[min]
	if extra != 0
	    if extra > 0
		source[min][i] = extra
	    else
		needed[min][i] = -extra
	    end
	    print "#{i} #{min} #{extra}\n"
	    sum[min] += extra
	end
    end
end

for min in 0..2 do
    print "total #{min} #{sum[min]}\n"
end
print "#{tot_prod} production planets\n"
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
	    dist[sp][np] = ((planets[sp].pos - planets[np].pos))
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
		if planets[rev==0 ? sp : np].transports <= 0
		    d += 100
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
	amount = [s[from], n[to]].min
	s[from] -= amount
	n[to] -= amount
	if s[from] == 0 
	    s.delete(from)
	end
	if n[to] == 0
	    n.delete(to)
	end
	if rev == 1 
	    t = from
	    from = to
	    to = t
	end
	trans = [amount / UNIT, planets[from].transports].min
	planets[from].transports -= trans

	ship[from] ||= {}
	ship[from][to] ||= {}
	ship[from][to][min] = [amount, trans, max_min]
    end
end

min_name = ['iron', 'boron', 'germ']

for from in ship.keys.sort do
    print "Ship from #{from}:\n"
    for to in ship[from].keys.sort do
	print "\t#{to} "
	for min in ship[from][to].keys.sort do
	    amount, trans, max_min = *ship[from][to][min]
	    print "#{amount.*UNIT}kT #{min_name[min]} "
	end
	if trans > 0
	    print " * "
	end
	print "#{(max_min / 100.0).ceil} years\n"
    end
end




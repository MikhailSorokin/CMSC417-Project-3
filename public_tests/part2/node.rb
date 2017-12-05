require_relative 'node_helpers'

$port = nil
$hostname = nil
$server = nil

# --------------------- General Classes ------------ #

class Message
	attr_accessor :socket, :msg
	def initialize(socket, msg)
		@socket = socket
		@msg = msg
	end
end

class Neighbor
	attr_accessor :name, :socket, :cost
	def initialize(name, socket, cost)
		@name = name
		@socket = socket
		@cost = cost
	end
	
	def ==(other)
		self.name == other
	end
	
	def to_s
		"#{name},#{cost}"
	end
end

class RoutingInfo
	attr_accessor :src, :dst, :nextHop, :distance
	def initialize(src, dst, nextHop, distance)
		@src = src
		@dst = dst
		@nextHop = nextHop
		@distance = distance
	end
	def to_s
		"#{src},#{dst},#{nextHop},#{distance}"
	end
end

# --------------------- Part 1 --------------------- # 

def edgeb(cmd)
	if cmd.length < 3
		STDOUT.puts "Not enough arguments"		
	end

	#Parse
	srcIP = cmd[0]
	destIP = cmd[1]
	destNode = cmd[2]

	clientSocket = TCPSocket.new(destIP, $nodeToPort[destNode])
	#Open connection towards destination IP from source)
	newmsg = "APPLYEDGE" << " " << destNode
	$internalMsgQueue.push(Message.new(clientSocket, newmsg))
end

def dumptable(cmd)
	out_file = File.new(cmd[0], "w+")
	$rtable.each do |node, entry|
		out_file.puts("#{entry}")
	end

	#TODO - not outputting new lines for some reason
	out_file.close
end

def shutdown(cmd)
	#Create a connection for each TCP Socket again
	STDOUT.flush
	#$semaphore.synchronize {
		$socketsArray.each do |socket|
			socket.close
		end
	#}
	exit(0)
end

# --------------------- Part 2 --------------------- # 
def edged(cmd)
	if cmd.length < 1
		STDOUT.puts "Not enough arguments"		
	end

	#Parse
	destNode = cmd[0]

	#Delete the node locally
	handleEntryDelete(destNode)

	#TODO - Connection needs to end here
end

def edgeU(cmd)
	if cmd.length < 2
		STDOUT.puts "Not enough arguments"		
	end

	#Parse
	destNode = cmd[0]
	cost = cmd[1]

	#Update the node locally
	handleEntryUpdate(destNode, cost)
end

def status()
	STDOUT.puts "Not implemented son"
end


# --------------------- Part 3 --------------------- # 
def sendmsg(cmd)
	STDOUT.puts "SENDMSG: not implemented"
end

def ping(cmd)
	STDOUT.puts "PING: not implemented"
end

def traceroute(cmd)
	STDOUT.puts "TRACEROUTE: not implemented"
end

# --------------------- Part 4 --------------------- # 


def ftp(cmd)
	STDOUT.puts "FTP: not implemented"
end

def circuit(cmd)
	STDOUT.puts "CIRCUIT: not implemented"
end


# --------------------- Main Loop --------------------- # 
def main()

	while(line = STDIN.gets())
		line = line.strip()
		arr = line.split(' ')
		cmd = arr[0]
		args = arr[1..-1]
		case cmd
		when "EDGEB"; edgeb(args)
		when "EDGED"; edged(args)
		when "EDGEU"; edgeU(args)
		when "DUMPTABLE"; dumptable(args)
		when "SHUTDOWN"; shutdown(args)
		when "STATUS"; status()
		when "SENDMSG"; sendmsg(args)
		when "PING"; ping(args)
		when "TRACEROUTE"; traceroute(args)
		when "FTP"; ftp(args);
		when "CIRCUIT"; circuit(args);

		else STDERR.puts "ERROR: INVALID COMMAND \"#{cmd}\""
		end
	end

end

def setup(hostname, port, nodes, config)
	$hostname = hostname #this is the SRC node
	$port = port

	$semaphore = Mutex.new

	#set up ports, server, buffers
	$socketsArray = [] #Array of sockets
	$rtable = {} #Hashmap to routing info by index node
	$socketBuf = {} #Hashmap to index input buffers by socket
	$nodeToPort = {} #Hashmap of node to port, gotten from the NODES.txt file

	File.open(nodes, "r") do |f|
		f.each_line do |line|
			line = line.strip()
			arr = line.split(',')

			# Assign values to a hashmap
			nodeName = arr[0]
			portNum = arr[1]
			$nodeToPort[nodeName] = portNum
		end
	end

	$updateInterval = nil
	$maxPayload = nil
	$pingTimeout = nil

	num = 0
	File.open(config, "r") do |f|
		f.each_line do |line|
			line = line.strip()
			arr = line.split('=')

			# Assign values from values in the config file - Mike
			value = arr[1]

			if num == 0
				$updateInterval = value.to_i()
			elsif num == 1
				$maxPayload = value.to_i()
			elsif num == 2
				$pingTimeout = value.to_i()
			end

			num = num + 1
		end
	end

	$clock_val = Time.now().to_i()
	$update_time = $clock_val + $updateInterval
	
	#A timer loop that updates the current clock and is used to synchronize updates
	#between nodes - Mike
	t = Thread.new(){
	while(true)
	   sleep(1)
	   $clock_val = $clock_val + 1
	end
	 
	}
	
	$internalMsgQueue = Queue.new

	Thread.new{listeningloop()}
	Thread.new{receivingloop()}
	Thread.new{msgHandler()}
	main()
end

setup(ARGV[0], ARGV[1], ARGV[2], ARGV[3])

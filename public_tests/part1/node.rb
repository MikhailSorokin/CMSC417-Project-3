require 'socket' #Required import to allow server connection 
require 'io/wait' #Using ready? method to see if data available in each socket

$port = nil
$hostname = nil
$server = nil

# --------------------- Part 1 --------------------- # 
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
	$socketBuf[clientSocket] = newmsg
end

def dumptable(cmd)
	out_file = File.new(cmd[0], "w+")
	$rtable.each do |node, entry|
		out_file.puts("#{entry}")
	end
	out_file.close
end

def shutdown(cmd)
	#Create a connection for each TCP Socket again
	STDOUT.flush
	$socketsArray.each do |socket|
		socket.close
	end
	exit(0)
end

# ----------------------- Loops methods -----------------------#
def listeningloop()
	STDOUT.puts "LISTENING"
	$server = TCPServer.new $port
	loop do
		Thread.fork($server.accept) do |clientSocket|
			$socketsArray.push(clientSocket)
		end
	end
end

def receivingloop()
	STDOUT.puts "RECEIVING"
	loop do
		$socketsArray.each do |servSocket|
		  	ready = IO.select([servSocket])
    		readable = ready[0] #0 is sockets for reading

    		readable.each do |socket|
	            if socket == servSocket
	                buf = socket.recv(1024)
	                if buf.length == 0
	                    STDERR.puts "The connection is dead. Try again. Exit."
	                    exit(1)
	                else
						$socketBuf[socket] = buf
	                end
	            end
            end
		end
	end
end

#Need to parse messages and clear buffer as messages are read
def msgHandler()
	STDOUT.puts "WRITING"
	loop do
		$socketBuf.each do |socket, str|
			str = str.strip()
			args = str.split(" ")
			cmd = args[0]
			destNode = args[1]
			case (cmd)		
			#Acknowledgements
			when "APPLYEDGE"; handleEntryAdd(socket,destNode)
			else STDERR.puts "ERROR: INVALID COMMAND \"#{cmd}\""
			end
		end
	end
end
	
# - Helpers to add stuff to tables
def handleEntryAdd(socket, destNode)
	if(!addtotable(destNode))
		STDERR.puts "ERROR: INVALID ACKNOWLEDGEMENT"
	end
	socket.write("APPLYEDGE" << " " << $hostname)
	$socketBuf.clear
end

def addtotable(node)
	# You know, I'm not sure this is even necessary. I think we could assume that addtotable is only called on new destinations.
	if $rtable.has_key?(node)
		return false
	else
		$rtable[node] = RoutingInfo.new($hostname, node, node, 1)
		return true
	end
end

# --------------------- Part 2 --------------------- # 
def edged(cmd)
	STDOUT.puts "EDGED: not implemented"
end

def edgeu(cmd)
	STDOUT.puts "EDGEu: not implemented"
end

def status()
	STDOUT.puts "STATUS: not implemented"
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

	#$semaphore = Mutex.new

	#set up ports, server, buffers
	$socketsArray = [] #Array of sockets
	$rtable = {} #Hashmap to routing info by index node
	$socketBuf = {} #Hashmap to index input buffers by socket
	$nodeToPort = {} #Hashmap of node to port

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

	Thread.new{listeningloop()}
	Thread.new{receivingloop()}
	Thread.new{msgHandler()}
	main()
end

setup(ARGV[0], ARGV[1], ARGV[2], ARGV[3])
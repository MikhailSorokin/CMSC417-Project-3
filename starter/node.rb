require 'socket' #Required import to allow server connection 

$port = nil
$hostname = nil
$server = nil
$BUF_SIZE = 1024

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
	#Parse
	srcIP = cmd[0]
	destIP = cmd[1]
	destNode = cmd[2]

	clientPort = nil

	serverRI = RoutingInfo.new($hostname, destNode, destNode, 1)

	#Establish a connection between two nodes.
	$server = TCPServer.new(srcIP, $port)
	$socketToNode[$server] = serverRI.src

	loop do
		#There will be three threads
		#(1) - Listening Thread - (Accepts and receives new connections)
		#(2) - Receiving Thread - (Polls existing connections for new info)
		#(3) - MSG Handler - (Parses and handles input and pushes to output buffers)

		#New thread will allow us to establish multiple connections from clients
	  	Thread.start($server.accept) do |client|
	  		$socketToNode[client] = destNode
	  		clientPort = client.addr[1]
	    	client.write(serverRI.to_s) #send information to the client
	    end

	    #Another thread for receiving
	    Thread.start(clientSocket = TCPSocket.new(destIP, clientPort))
			recvStr = clientSocket.recv(BUF_SIZE)	

		strArray = recvStr.split(",")
		clientRI = RoutingInfo.new(strArray[1], strArray[0],
		strArray[2],strArray[3]) #server src and dst are in reverse
  	end
end

def dumptable(cmd)
	STDOUT.puts "DUMPTABLE: not implemented"
end

def shutdown(cmd)
	#Create a connection for each TCP Socket again

	$socketToNode.each do |client|
		client.close
	end
	exit(0)
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




# do main loop here.... 
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

	#set up ports, server, buffers
	$BUF_SIZE = 1023

	$socketToNode = {} #Hashmap to index node by socket

	main()

end

setup(ARGV[0], ARGV[1], ARGV[2], ARGV[3])
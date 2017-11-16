require 'socket' #Required import to allow server connection 
require 'io/wait' #Using ready? method to see if data available in each socket

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
	if cmd.length < 3
		STDOUT.puts "Not enough arguments"		
	end

	#Parse
	srcIP = cmd[0]
	destIP = cmd[1]
	destNode = cmd[2]

    #Another thread for receiving
	#Open connection towards destination IP from source
	$semaphore.synchronize {
		$socketToNode[destNode] = TCPSocket.new(destIP, $nodeToPort[destNode])
		$socketInputBuf[destNode] = ""
	}
    Thread.new{sendEdge(clientSocket, destNode, srcIP)}
end

def sendEdge(clientSocket, destNode, srcIP)
	str = "" << $hostname << " EDGEB " << destNode << " " << srcIP
	clientSocket.puts str
	clientSocket.flush
end
	

def dumptable(cmd)
	$rtable.each do |entry|
		puts entry
	end
end

def receivingloop()
	loop do
		$semaphore.synchronize {
			$socketToNode.each do |socket, node|
				if(socket.ready?)
					socketInputBuf[socket] << socket.gets()
				end
			end
		}
	end
end

def shutdown(cmd)
	#Create a connection for each TCP Socket again
	STDOUT.flush
	$semaphore.synchronize {
		$socketToNode.each do |socket, node|
			socket.close
		end
	}
	exit(0)
end

def addtotable(cmd)
	#Parse
	destNode = cmd[1]

	# You know, I'm not sure this is even necessary. I think we could assume that addtotable is only called on new destinations.
	if $rtable.has_key?(destNode)
		return false
	else
		$rtable[destNode] = RoutingInfo.new($hostname, destNode, destNode, 1)
		return true
	end
end

def listeningloop()
	$server = TCPServer.open($port)
	loop do
		Thread.fork($server.accept) do |client| 
			# Need to add client socket to $socketToNode, 
			# Let's assume the client will only send one line
			line = client.gets()
			line = line.strip()
			arr = line.split(' ')

			$semaphore.synchronize {
				$socketToNode[client] = arr[0]
				$socketInputBuf[client] = ""
			}
			
			cmd = arr[1]
			args = arr[2..-1]
			case cmd
			when "EDGEB"
				if(addtotable(cmd))
					str = "ENTRYADDED " << $hostname
					clientSocket = TCPSocket.new(arr[2], $port)
					clientSocket.write(str)
				end
			else client.puts "ERROR: INVALID COMMAND \"#{cmd}\""
			end
		end
	end
end

def ackedgeb(args)
	Thread.new{finalize(args)} 
end

def finalize(cmd)
	if(addtotable(cmd))
		#TODO send acknowledgement back?
	else client.puts "ERROR: INVALID COMMAND \"#{cmd}\""
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

		#Acknowledgements
		when "ENTRYADDED"; ackedgeb(args)

		else STDERR.puts "ERROR: INVALID COMMAND \"#{cmd}\""
		end
	end

end

def setup(hostname, port, nodes, config)
	$hostname = hostname #this is the SRC node
	$port = port

	$socketToNode = {} #Hashmap to index node by socket
	$rtable = {} #Hashmap to routing info by index node
	$socketInputBuf = {} #Hashmap to index input buffers by socket
	$nodeToPort = {} #Hashmap of node to port

	$semaphore = Mutex.new

	File.open(nodes, "r") do |f|
		f.each_line do |line|
			line = line.strip()
			arr = line.split(',')

			# Assign values to a hashmap
			nodeName = arr[0]
			portNum = arr[1]
			nodeToPort[nodeName] = portNum
		end
	end

	#set up ports, server, buffers
	$BUF_SIZE = 1023

	Thread.new{listeningloop()}
	Thread.new{receivingloop()}
	main()
end

setup(ARGV[0], ARGV[1], ARGV[2], ARGV[3])

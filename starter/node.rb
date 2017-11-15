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
	if cmd.length < 3
		STDOUT.puts "Not enough arguments"		
	end

	#Parse
	srcIP = cmd[0]
	destIP = cmd[1]
	destNode = cmd[2]

    #Another thread for receiving
	#Open connection towards destination IP from source
	clientSocket = TCPSocket.new(srcIP, $port)
    Thread.new{sendLoop(clientSocket, destNode, destIP)}
end

def sendLoop(clientSocket, destNode, destIP)
	str = "EDGEB " << destNode << " " << destIP
	clientSocket.puts str
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

def addtotable(cmd)
	#Parse
	puts "AHH"
	destNode = cmd[1]

	if $rtable.has_key?(destNode)
		return false
	else
		$rtable[destNode] = RoutingInfo.new($hostname, destNode, destNode, 1)
		return true
	end
end

def serverloop()
	$server = TCPServer.open($port)
	loop do
		Thread.fork($server.accept) do |client| 
			# Can we assume the client will only send one line?
			line = client.gets()
			line = line.strip()
			arr = line.split(' ')
			cmd = arr[0]
			args = arr[1..-1]
			case cmd
			when "EDGEB"
				# Right now addtotable will only fail if that destination is already in the table
				# are there any other cases where we might not want to reply to the other node?

				if(addtotable(cmd))
					str = "ENTRYADDED " << $hostname
					clientSocket = TCPSocket.new(arr[2], $port)
					clientSocket.write(str)
				else client.puts "ERROR: INVALID COMMAND \"#{cmd}\""
				end 
			end
			client.close
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

	#set up ports, server, buffers
	$BUF_SIZE = 1023

	$socketToNode = {} #Hashmap to index node by socket
	$rtable = {} #Hashmap to routing info by index node

	Thread.new{serverloop()}
	main()
end

setup(ARGV[0], ARGV[1], ARGV[2], ARGV[3])

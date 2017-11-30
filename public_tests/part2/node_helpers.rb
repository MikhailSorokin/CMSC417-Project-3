require 'socket' #Required import to allow server connection 
require 'thread'

$port = nil
$hostname = nil
$server = nil

# ----------------------- Loop methods -----------------------#
class message
	attr_accessor :socket, :msg
	def initialize(socket, msg)
		@socket = socket
		@msg = msg
	end
end

class neighbor
	attr_accessor :name, :socket, :cost
	def initilaize(name, socket, cost)
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
	loop do
		$socketsArray.each do |servSocket|
		  	ready = IO.select([servSocket])
    		readable = ready[0] #0 is sockets for reading

    		readable.each do |socket|
	            if socket == servSocket
	                buf = socket.recv(1024)
	                if buf.length == 0
	                    STDOUT.puts "The connection is dead. Try again. Exit."
	                    exit(1)
	                else
            			$semaphore.synchronize {
							$socketBuf[socket] = buf
						}
	                end
	            end
            end
		end
	end
end

#Need to parse messages and clear buffer as messages are read
def msgHandler()
	loop do
		incoming = $internalMsgQueue.pop
		str = incoming.str.strip()
		args = str.split(" ")
		cmd = args[0]
		case (cmd)		
		#Acknowledgements
		when "APPLYEDGE"; handleEntryAdd(socket,args[1])
		when "LSA";
		else STDOUT.puts "ERROR: INVALID COMMAND \"#{cmd}\""
		end
		
		if($clock_val > $update_time)
			$update_time = $clock_val + $updateInterval
			
		end
	end
end
	
# -------------- Helpers to do stuff to tables ----------------------- $
def handleEntryAdd(socket, destNode)
	$neighbors.push(new neighbor(destNode, socket, 1))
	socket.write("APPLYEDGE" << " " << $hostname)
end

# Handles deleting entries from the table - ASYMMETRIC
def handleEntryDelete(destNode)
	$neighbors.delete_if {|n| n.name == destNode}
end

#Handles updating edge costs on the table
def handleEntryUpdate(destNode, newcost)
	if(!canUpdateTable(destNode, newcost))
		STDOUT.puts "ERROR: INVALID ACKNOWLEDGEMENT"
	end
end

def canUpdateTable(node, newcost)
	#Only update one way
	if $rtable.has_key?(node)
		$rtable[node].distance = newcost
		return true
	else
		return false
	end
end

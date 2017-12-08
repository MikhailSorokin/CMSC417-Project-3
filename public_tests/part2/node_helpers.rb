require 'socket' #Required import to allow server connection 
require 'thread'

$port = nil
$hostname = nil

# ----------------------- Loop methods -----------------------#
class Message
	attr_accessor :socket, :msg
	def initialize(socket, msg)
		@socket = socket
		@msg = msg
	end
end

class Neighbor
	attr_accessor :name, :socket, :cost,
	:seqNum, :neighborArray
	def initialize(name, socket, cost)
		@name = name
		@socket = socket
		@cost = cost
	end

	def initialize(name, cost, seqNum, neighborArray)
		@name = name
		@socket = nil
		@cost = cost
		@seqNum = seqNum
		@neighborArray = neighborArray
	end
	
	def ==(other)
		self.name == other
	end
	
	def to_s
		"#{name},#{cost}"
	end

end

# ----------------- Classes ------------------ #

def listeningloop()
	$server = TCPServer.new $port
	loop do
		Thread.fork($server.accept) do |clientSocket|
			$recvBuffer.push(clientSocket)
		end
	end
end

def receivingloop()
	loop do
		$recvBuffer.each do |servSocket|
		  	ready = IO.select([servSocket])
    		readable = ready[0] #0 is sockets for reading

    		readable.each do |socket|
	            if socket == servSocket
	                buf = socket.recv(1024)
	                if buf.length == 0
	                    STDOUT.puts "The payload exceeds 1024 bytes."
	                    exit(1)
	                else
            			$semaphore.synchronize {
							$internalMsgQueue.push(buf)
						}
	                end
	            end
            end
		end

		if !$recvBuffer.empty?
			$recvBuffer.clear
		end
	end
end

#Need to parse messages and clear buffer as messages are read
def msgHandler()
	loop do

		if !$internalMsgQueue.empty?
			incoming = $internalMsgQueue.pop
			str = incoming.str.strip()
			args = str.split(" ")
			cmd = args[0]
			case (cmd)		
			#Acknowledgements
			when "APPLYEDGE"; handleEntryAdd($socketToBuf[args[1]],args[1])
			when "LSA"; receiveUpdatedNeighbors(args[1], args[2], args[3])
			else STDOUT.puts "ERROR: INVALID COMMAND \"#{cmd}\""
			end
		end

		if($clock_val > $update_time)
			$update_time = $clock_val + $updateInterval
			
			performDijkstra()
		end
	endS
end

def receiveUpdatedNeighbors(origName, origSeqNum, neighbors)
	#TODO - update here
end

def createLSAMessage(name, seqString, neighbors)
	message = "" << name << " " << seqString << " "

	neighbors.each do |neighbor|
		message << neighbor.name << ";" << neighbor.cost  << ","
	end

	message.chop! #Remove the last character, which will be a space

	if $nodeToSocket.has_key?(name)
		$nodeToSocket[name].write("LSA " << message)
	end
end

#DIJKSTRA
def performDijkstra()
	#We have the neighbors, so just initialize all distances to Infinity
	nodesToDistance = {}

	nodeQueue = []

	$nodeToPort.each do |neighbor, port|
		nodesToDistance[neighbor] = Float::INFINITY
		nodeQueue.push(neighbor)
	end

	nodesToDistance[$hostname] = 0
	nodeQueue.push($hostname)

	while !nodeQueue.empty?
		#now use the neighbors array to see what is min distance
		minCost = Float::INFINITY
		vertexToRemove = nil

		nodeQueue.each do |node, cost|
			if cost <= minCost
				minCost = cost
				vertexToRemove = node
			end
		end

		currentVertex = nodeQueue.remove(vertexToRemove)

		nodeQueue.each do |neighborNode|
			currDist = currentVertex + $neighbors[neighborNode].cost

			if currDist < $neighbors[neighborNode].cost
				$neighbors[neighborNode].cost = currDist
				#TODO - Path for TraceRoute?
			end
		end	
	end

	createLSAMessage($hostname, $update_time.to_s, $neighbors)

end
	
	
# -------------- Helpers to do stuff to neighbors ----------------------- $
def handleEntryAdd(socket, destNode)
	$neighbors.push(Neighbor.new(destNode, socket, 1))
	socket.write("APPLYEDGE" << " " << $hostname)
end

# Handles deleting entries from the table - ASYMMETRIC
def handleEntryDelete(destNode)
	$neighbors.delete_if {|n| n.name == destNode}
end

#Handles updating edge costs on the table
def handleEntryUpdate(destNode, newcost)
	i = $neighbors.index{|n| n.name == destNode}
	$neighbors[i].cost = newcost
end

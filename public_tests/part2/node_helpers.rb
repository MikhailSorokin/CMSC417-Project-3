require 'socket' #Required import to allow server connection 
require 'thread'

$port = nil
$hostname = nil

# ----------------------- Loop methods -----------------------#
class Neighbor
	attr_accessor :name, :socket, :cost, :seqNum

	def initialize(name, socket, cost)
		@name = name
		@socket = socket
		@cost = cost
	end

	def initialize(name, cost, seqNum)
		@name = name
		@socket = nil
		@cost = cost
		@seqNum = seqNum
	end
	
	def ==(other)
		self.name == other
	end
	
	def to_s
		"#{name}\:#{cost}"
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
			STDOUT.puts "Receving a message"
		  	ready = IO.select([servSocket])
    		readable = ready[0] #0 is sockets for reading

    		readable.each do |socket|
	            if socket == servSocket
	                buf = socket.recv(1024)
	                if buf.length == 0
	                    STDOUT.puts "The payload exceeds 1024 bytes."
	                    exit(1)
	                else
            			$internalMsgQueue.push(buf)
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
			socket = incoming[0]
			msg = incoming[1]
			args = str.split(" ")
			cmd = args[0]
			case (cmd)		
			#Acknowledgements
			when "APPLYEDGE"; handleEntryAdd(args[1])
			when "LSA"; receiveUpdatedNeighbors(args[1], args[2], args[3])
			else STDOUT.puts "ERROR: INVALID COMMAND \"#{cmd}\""
			end
		end

		if($clock_val > $update_time)
			$update_time = $clock_val + $updateInterval

			performDijkstra()
		end
	end
end

def receiveUpdatedNeighbors(origName, origSeqNum, neighbors)
	#Update the cost of the neighbors here with the sequence number
	STDOUT.puts "LSA Message being received"
	neighborGroup = neighbors.split(",")
	$graphInfo[origName].clear

	neighborGroup.each do |neighbor|
		neighborArr = neighbor.split(";")
		neighborName = neighborArr[0]
		neighborCost = neighborArr[1]

		$graphInfo[origName].push([seqNum,Neighbor.new(neighborName, neighborCost, seqNum)])
	end
end

def createLSAMessage(name, seqString, neighbors)
	STDOUT.puts "LSA Message being created"
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
	nodesToPrevious = {}

	nodeQueue = []

	$nodeToPort.each do |node, port|
		nodesToDistance[node] = Float::INFINITY
		nodeQueue.push(node)
	end

	nodesToDistance[$hostname] = 0

	while !nodeQueue.empty?
		#now use the neighbors array to see what is min distance
		minCost = Float::INFINITY
		vertexToRemove = nil

		cost = 0
		nodeQueue.each do |node|
			if cost <= minCost
				minCost = cost
				vertexToRemove = node
			end
		end

		nodeQueue.delete(vertexToRemove)
		# Graph info is a mapping from node name to that node's neighbor information
		# A two element array contains the node's neighbor information
		# the first element is the sequence number which Dijkstra's ignores
		# The second element is an array of Neighbor class items corresponding to that node's neighbors
		# We are iterating over vertexToRemove's neighbors, not our own.
		$graphInfo[vertexToRemove].at(1).each do |othersNeighbor| 
			altDist = nodesToDistance[vertexToRemove] + othersNeighbor.cost

			if currDist < nodesToDistance[othersNeighbor.name].cost
				nodesToDistance[othersNeighbor.name] = currDist
				nodesToPrevious[othersNeighbor.name] = vertexToRemove
			end
		end	
	end
	
	# We have the cost to travel to all other nodes and also the previous node in their path.
	# We want to find the next hop from us, the source node, and then assign that to our routing table.
	$rtable.clear
	nodesToPrevious.each do |node, prev|
		nextHop = nodesToPrevious[prev]
		while(!$neighbors.include?(nextHop))
			nextHop = nodesToPrevious[prev]
		end
		$rtable.push(new RoutingInfo($hostname, node, nextHop, nodesToDistance[node]))
	end

	createLSAMessage($hostname, $update_time.to_s, $neighbors)

end
	
	
# -------------- Helpers to do stuff to neighbors ----------------------- $
def handleEntryAdd(destNode)
	$neighbors.push(Neighbor.new(destNode, socket, 1))
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